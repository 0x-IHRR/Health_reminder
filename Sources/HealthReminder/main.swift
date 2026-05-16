import AppKit
import CoreGraphics
import Foundation
import HealthReminderCore

private final class HealthReminderApp: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let reminderDefinitions: [ReminderDefinition] = [
        ReminderDefinition(
            id: "movement-break",
            title: "放松眼睛，活动一下",
            body: "看一下远处，站起来动一动。",
            interval: 30 * 60
        ),
        ReminderDefinition(
            id: "water",
            title: "喝水",
            body: "喝几口水，别等口渴了再喝。",
            interval: 60 * 60
        ),
        ReminderDefinition(
            id: "posture-relax",
            title: "调整坐姿，放松肩颈",
            body: "坐直一点，转转脖子，活动一下肩膀。",
            interval: 90 * 60
        )
    ]

    private let defaultKanbanURL = URL(
        fileURLWithPath: "/Users/ihrr/Library/Mobile Documents/iCloud~md~obsidian/Documents/起源之地/0x.Start/_Meta/Kanban.md"
    )
    private let focusReminderInterval: TimeInterval = 15 * 60
    private let idleThreshold: TimeInterval = 60
    private let tickInterval: TimeInterval = 1
    private let anyInputEventType = CGEventType(rawValue: UInt32.max)!
    private let bundleIdentifier = "com.healthreminder.app"

    private let focusTaskStore = FocusTaskStore()
    private let kanbanTaskReader = KanbanTaskReader()
    private let overlayPresenter = ReminderOverlayPresenter()

    private var statusItem: NSStatusItem!
    private var statusMenu = NSMenu()
    private var statusMenuItem = NSMenuItem()
    private var focusStatusMenuItem = NSMenuItem()
    private var kanbanMenu = NSMenu()
    private var completeFocusTaskItem = NSMenuItem()
    private var reminderEngine: ReminderEngine!
    private var focusReminderEngine: FocusReminderEngine!
    private var timer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        reminderEngine = ReminderEngine(
            reminders: reminderDefinitions,
            idleThreshold: idleThreshold,
            tickInterval: tickInterval
        )
        focusReminderEngine = FocusReminderEngine(
            interval: focusReminderInterval,
            idleThreshold: idleThreshold,
            tickInterval: tickInterval,
            currentTask: focusTaskStore.currentTask
        )
        configureMenuBar()
        installLaunchAgentIfRunningFromAppBundle()
        startTimer()
    }

    private func configureMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let icon = NSImage(systemSymbolName: "figure.walk.motion", accessibilityDescription: "健康提醒")
        icon?.isTemplate = true
        statusItem.button?.image = icon
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

        let quitItem = NSMenuItem(title: "退出", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        statusMenu.addItem(quitItem)

        statusItem.menu = statusMenu
        refreshKanbanSubmenu()
        updateMenu()
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
        timer = Timer.scheduledTimer(withTimeInterval: tickInterval, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    private func tick() {
        let idleSeconds = CGEventSource.secondsSinceLastEventType(
            .combinedSessionState,
            eventType: anyInputEventType
        )

        let healthResult = reminderEngine.tick(idleSeconds: idleSeconds)
        for reminder in healthResult.remindersToSend {
            overlayPresenter.show(title: reminder.title, body: reminder.body)
        }

        let focusResult = focusReminderEngine.tick(idleSeconds: idleSeconds)
        if let task = focusResult.taskToRemind {
            overlayPresenter.show(title: "回到主线任务", body: task.title)
        }

        updateMenu()
    }

    private func refreshKanbanSubmenu() {
        kanbanMenu.removeAllItems()

        do {
            let tasks = try kanbanTaskReader.readInboxTasks(from: defaultKanbanURL)

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
            let remaining = max(0, focusReminderInterval - focusReminderEngine.elapsedActiveTime)
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
