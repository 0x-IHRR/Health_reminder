import AppKit
import CoreGraphics
import Foundation
import HealthReminderCore

private final class HealthReminderApp: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let configuration = AppConfiguration.load(from: AppConfiguration.localConfigURL)
    private let anyInputEventType = CGEventType(rawValue: UInt32.max)!
    private let bundleIdentifier = "com.healthreminder.app"
    private let diagnosticsLogger = ReminderDiagnosticsLogger()

    private let focusTaskStore = FocusTaskStore()
    private let kanbanTaskReader = KanbanTaskReader()
    private lazy var overlayPresenter = ReminderOverlayPresenter(configuration: configuration.overlay)
    private lazy var overlaySettingsWindowController = OverlaySettingsWindowController(
        configURL: AppConfiguration.localConfigURL,
        testReminderHandler: { [weak self] title, body in
            self?.overlayPresenter.show(title: title, body: body)
        }
    )

    private var statusItem: NSStatusItem!
    private var statusMenu = NSMenu()
    private var statusMenuItem = NSMenuItem()
    private var focusStatusMenuItem = NSMenuItem()
    private var kanbanMenu = NSMenu()
    private var completeFocusTaskItem = NSMenuItem()
    private var reminderEngine: ReminderEngine!
    private var focusReminderEngine: FocusReminderEngine!
    private var timer: Timer?
    private var lastDiagnosticsSnapshotDate: Date?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        reminderEngine = ReminderEngine(
            reminders: reminderDefinitions(),
            idleThreshold: configuration.idleThreshold,
            tickInterval: configuration.tickInterval
        )
        focusReminderEngine = FocusReminderEngine(
            interval: configuration.focusReminderInterval,
            idleThreshold: configuration.idleThreshold,
            tickInterval: configuration.tickInterval,
            currentTask: focusTaskStore.currentTask
        )
        diagnosticsLogger.logLaunch(
            configuration: configuration,
            activeHealthReminderIDs: reminderDefinitions().map(\.id)
        )
        configureMenuBar()
        installLaunchAgentIfRunningFromAppBundle()
        startTimer()
    }

    private func configureMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = statusBarIcon()
        statusItem.button?.imagePosition = .imageOnly

        statusMenu.delegate = self

        statusMenuItem.isEnabled = false
        focusStatusMenuItem.isEnabled = false
        statusMenu.addItem(statusMenuItem)
        statusMenu.addItem(focusStatusMenuItem)
        statusMenu.addItem(.separator())

        let setFocusTaskItem = NSMenuItem(
            title: "设置当前主线任务...",
            action: #selector(promptForFocusTask),
            keyEquivalent: ""
        )
        setFocusTaskItem.target = self
        statusMenu.addItem(setFocusTaskItem)

        let kanbanMenuItem = NSMenuItem(title: "从 Obsidian 收件箱选择", action: nil, keyEquivalent: "")
        kanbanMenu.delegate = self
        statusMenu.addItem(kanbanMenuItem)
        statusMenu.setSubmenu(kanbanMenu, for: kanbanMenuItem)

        completeFocusTaskItem = NSMenuItem(
            title: "完成当前主线任务",
            action: #selector(completeCurrentFocusTask),
            keyEquivalent: ""
        )
        completeFocusTaskItem.target = self
        statusMenu.addItem(completeFocusTaskItem)
        statusMenu.addItem(.separator())

        let settingsItem = NSMenuItem(title: "设置...", action: #selector(showSettings), keyEquivalent: ",")
        settingsItem.target = self
        statusMenu.addItem(settingsItem)

        let quitItem = NSMenuItem(title: "退出", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        statusMenu.addItem(quitItem)

        statusItem.menu = statusMenu
        refreshKanbanSubmenu()
        updateMenu()
    }

    private func statusBarIcon() -> NSImage? {
        if let icon = NSImage(named: "StatusBarIcon") {
            icon.isTemplate = true
            icon.size = NSSize(width: 18, height: 18)
            return icon
        }

        let fallbackIcon = NSImage(systemSymbolName: "figure.walk.motion", accessibilityDescription: "健康提醒")
        fallbackIcon?.isTemplate = true
        return fallbackIcon
    }

    private func installLaunchAgentIfRunningFromAppBundle() {
        guard let bundleURL = Bundle.main.bundleURLIfAppBundle else {
            return
        }

        do {
            let launchAgentsDirectory = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/LaunchAgents", isDirectory: true)
            try FileManager.default.createDirectory(
                at: launchAgentsDirectory,
                withIntermediateDirectories: true
            )

            let plistURL = launchAgentsDirectory.appendingPathComponent("\(bundleIdentifier).plist")
            let plist: [String: Any] = [
                "Label": bundleIdentifier,
                "ProgramArguments": ["/usr/bin/open", bundleURL.path],
                "RunAtLoad": true
            ]
            let data = try PropertyListSerialization.data(
                fromPropertyList: plist,
                format: .xml,
                options: 0
            )

            if FileManager.default.fileExists(atPath: plistURL.path),
               let existingData = try? Data(contentsOf: plistURL),
               existingData == data {
                return
            }

            try data.write(to: plistURL, options: .atomic)
        } catch {
            NSLog("HealthReminder launch agent installation failed: \(error.localizedDescription)")
        }
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: configuration.tickInterval, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    private func tick() {
        let idleSeconds = CGEventSource.secondsSinceLastEventType(
            .combinedSessionState,
            eventType: anyInputEventType
        )
        let screenAwake = isAnyDisplayAwake()
        let healthShouldPause = shouldPauseHealthReminder(
            idleSeconds: idleSeconds,
            screenAwake: screenAwake
        )

        let healthResult = reminderEngine.tick(shouldPause: healthShouldPause)
        let focusResult = focusReminderEngine.tick(idleSeconds: idleSeconds)
        if healthResult.shouldSendReminder || focusResult.shouldRemind {
            diagnosticsLogger.logTriggered(
                healthReminderIDs: healthResult.remindersToSend.map(\.id),
                focusTaskTriggered: focusResult.shouldRemind
            )
        }
        if let message = ReminderPresentationComposer.compose(
            healthReminders: healthResult.remindersToSend,
            focusTask: focusResult.taskToRemind
        ) {
            overlayPresenter.show(title: message.title, body: message.body)
        }

        logDiagnosticsSnapshotIfNeeded(
            idleSeconds: idleSeconds,
            screenAwake: screenAwake,
            healthShouldPause: healthShouldPause
        )
        updateMenu()
    }

    private func shouldPauseHealthReminder(idleSeconds: TimeInterval, screenAwake: Bool) -> Bool {
        switch configuration.healthReminderCountingMode {
        case "input_active":
            return idleSeconds >= configuration.idleThreshold
        default:
            return !screenAwake
        }
    }

    private func isAnyDisplayAwake() -> Bool {
        let maximumDisplayCount: UInt32 = 16
        var activeDisplays = [CGDirectDisplayID](repeating: 0, count: Int(maximumDisplayCount))
        var activeDisplayCount: UInt32 = 0
        let result = CGGetActiveDisplayList(maximumDisplayCount, &activeDisplays, &activeDisplayCount)

        guard result == .success, activeDisplayCount > 0 else {
            return CGDisplayIsAsleep(CGMainDisplayID()) == 0
        }

        return activeDisplays.prefix(Int(activeDisplayCount)).contains { displayID in
            CGDisplayIsAsleep(displayID) == 0
        }
    }

    private func logDiagnosticsSnapshotIfNeeded(
        idleSeconds: TimeInterval,
        screenAwake: Bool,
        healthShouldPause: Bool
    ) {
        let now = Date()
        if let lastDiagnosticsSnapshotDate,
           now.timeIntervalSince(lastDiagnosticsSnapshotDate) < 60 {
            return
        }

        lastDiagnosticsSnapshotDate = now
        let focusRemaining = focusReminderEngine.currentTask == nil
            ? 0
            : max(0, configuration.focusReminderInterval - focusReminderEngine.elapsedActiveTime)
        diagnosticsLogger.logSnapshot(
            idleSeconds: idleSeconds,
            healthCountingMode: configuration.healthReminderCountingMode,
            screenAwake: screenAwake,
            healthShouldPause: healthShouldPause,
            healthState: reminderEngine.state,
            nextHealthReminder: reminderEngine.nextReminder,
            focusTaskIsSet: focusReminderEngine.currentTask != nil,
            focusState: focusReminderEngine.state,
            focusRemainingActiveTime: focusRemaining
        )
    }

    private func refreshKanbanSubmenu() {
        kanbanMenu.removeAllItems()

        do {
            let tasks = try kanbanTaskReader.readInboxTasks(
                from: URL(fileURLWithPath: configuration.kanbanPath),
                inboxSectionTitle: configuration.kanbanInboxSection
            )

            guard !tasks.isEmpty else {
                kanbanMenu.addItem(disabledItem(title: "收件箱没有未完成任务"))
                return
            }

            for task in tasks {
                let item = NSMenuItem(title: task, action: #selector(selectKanbanTask(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = task
                kanbanMenu.addItem(item)
            }
        } catch {
            kanbanMenu.addItem(disabledItem(title: "无法读取 Kanban：\(error.localizedDescription)"))
        }
    }

    private func disabledItem(title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    private func setCurrentFocusTaskTitle(_ title: String?) {
        let trimmedTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let task = trimmedTitle.isEmpty ? nil : FocusTask(title: trimmedTitle)

        focusTaskStore.setCurrentTask(task)
        focusReminderEngine.setTask(task)
        updateMenu()

        if let task {
            overlayPresenter.show(title: "已设置主线任务", body: task.title)
        }
    }

    @objc private func promptForFocusTask() {
        let alert = NSAlert()
        alert.messageText = "设置当前主线任务"
        alert.informativeText = "只保存一个当前主线任务；设置后按 15 分钟活跃时间召回。"
        alert.addButton(withTitle: "保存")
        alert.addButton(withTitle: "取消")

        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 360, height: 24))
        input.stringValue = focusReminderEngine.currentTask?.title ?? ""
        alert.accessoryView = input

        NSApp.activate(ignoringOtherApps: true)

        if alert.runModal() == .alertFirstButtonReturn {
            setCurrentFocusTaskTitle(input.stringValue)
        }
    }

    @objc private func selectKanbanTask(_ sender: NSMenuItem) {
        guard let title = sender.representedObject as? String else {
            return
        }

        setCurrentFocusTaskTitle(title)
    }

    @objc private func completeCurrentFocusTask() {
        setCurrentFocusTaskTitle(nil)
        overlayPresenter.show(title: "主线任务已完成", body: "选择下一条主线前，召回提醒会暂停。")
    }

    @objc private func showSettings() {
        overlaySettingsWindowController.show()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func updateMenu() {
        switch reminderEngine.state {
        case .tracking:
            if let nextReminder = reminderEngine.nextReminder {
                statusMenuItem.title = "下一项：\(nextReminder.definition.title)，约 \(minutesText(for: nextReminder.remainingActiveTime))后"
            } else {
                statusMenuItem.title = "计时中"
            }
            statusItem.button?.contentTintColor = nil
        case .pausedByIdle:
            statusMenuItem.title = "已离开，计时暂停"
            statusItem.button?.contentTintColor = NSColor.systemBlue
        }

        if let task = focusReminderEngine.currentTask {
            let remaining = max(0, configuration.focusReminderInterval - focusReminderEngine.elapsedActiveTime)
            focusStatusMenuItem.title = "主线：\(task.title)，约 \(minutesText(for: remaining))后召回"
            completeFocusTaskItem.isEnabled = true
        } else {
            focusStatusMenuItem.title = "主线：未设置"
            completeFocusTaskItem.isEnabled = false
        }
    }

    private func minutesText(for seconds: TimeInterval) -> String {
        let remainingMinutes = max(1, Int(ceil(seconds / 60)))
        return "\(remainingMinutes) 分钟"
    }

    func menuWillOpen(_ menu: NSMenu) {
        if menu === statusMenu || menu === kanbanMenu {
            refreshKanbanSubmenu()
            updateMenu()
        }
    }

    private func reminderDefinitions() -> [ReminderDefinition] {
        guard configuration.healthRemindersEnabled else {
            return []
        }

        return configuration.healthReminders.compactMap { reminder -> ReminderDefinition? in
            guard reminder.isEnabled else {
                return nil
            }

            return ReminderDefinition(
                id: reminder.id,
                title: reminder.title,
                body: reminder.body,
                interval: reminder.interval
            )
        }
    }
}

private extension AppConfiguration {
    static var localConfigURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/HealthReminder/config.env")
    }
}

private extension Bundle {
    var bundleURLIfAppBundle: URL? {
        let url = bundleURL
        return url.pathExtension == "app" ? url : nil
    }
}

private let app = NSApplication.shared
private let delegate = HealthReminderApp()
app.delegate = delegate
app.run()
