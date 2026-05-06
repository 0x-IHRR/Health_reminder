import AppKit
import CoreGraphics
import Foundation
import HealthReminderCore
import UserNotifications

private final class HealthReminderApp: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    private static let repeatReminderInterval: TimeInterval = 5 * 60

    private let reminderDefinitions: [ReminderDefinition] = [
        ReminderDefinition(
            id: "eye-relax",
            title: "眨眼放松",
            body: "眨眨眼，看一下远处。",
            interval: 10 * 60,
            repeatReminderInterval: HealthReminderApp.repeatReminderInterval
        ),
        ReminderDefinition(
            id: "movement-break",
            title: "该休息一下了",
            body: "看一次远处，站起来动一下。",
            interval: 20 * 60,
            repeatReminderInterval: HealthReminderApp.repeatReminderInterval
        ),
        ReminderDefinition(
            id: "posture",
            title: "调整坐姿",
            body: "放松肩膀，坐直一点。",
            interval: 30 * 60,
            repeatReminderInterval: HealthReminderApp.repeatReminderInterval
        ),
        ReminderDefinition(
            id: "water",
            title: "喝水",
            body: "喝几口水，别等口渴了再喝。",
            interval: 45 * 60,
            repeatReminderInterval: HealthReminderApp.repeatReminderInterval
        ),
        ReminderDefinition(
            id: "neck-shoulder",
            title: "放松肩颈",
            body: "转转脖子，活动一下肩膀。",
            interval: 60 * 60,
            repeatReminderInterval: HealthReminderApp.repeatReminderInterval
        )
    ]

    private let idleThreshold: TimeInterval = 60
    private let tickInterval: TimeInterval = 1
    private let anyInputEventType = CGEventType(rawValue: UInt32.max)!
    private let bundleIdentifier = "com.healthreminder.app"
    private let notificationCategoryIdentifier = "HEALTH_REMINDER_CATEGORY"
    private let completedActionIdentifier = "COMPLETED_ACTION"
    private let reminderIDUserInfoKey = "reminderID"

    private var statusItem: NSStatusItem!
    private var statusMenu = NSMenu()
    private var statusMenuItem = NSMenuItem()
    private var completedMenuItem = NSMenuItem()
    private var reminderEngine: ReminderEngine!
    private var notificationRequestIDsByReminder: [String: Set<String>] = [:]
    private var timer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        reminderEngine = ReminderEngine(
            reminders: reminderDefinitions,
            idleThreshold: idleThreshold,
            tickInterval: tickInterval
        )
        configureMenuBar()
        configureNotifications()
        installLaunchAgentIfRunningFromAppBundle()
        startTimer()
    }

    private func configureMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let icon = NSImage(systemSymbolName: "figure.walk.motion", accessibilityDescription: "健康提醒")
        icon?.isTemplate = true
        statusItem.button?.image = icon
        statusItem.button?.imagePosition = .imageOnly

        statusMenuItem.isEnabled = false
        statusMenu.addItem(statusMenuItem)

        completedMenuItem = NSMenuItem(title: "已完成", action: #selector(markCurrentReminderCompleted), keyEquivalent: "")
        completedMenuItem.target = self
        statusMenu.addItem(completedMenuItem)

        statusMenu.addItem(.separator())

        let quitItem = NSMenuItem(title: "退出", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        statusMenu.addItem(quitItem)

        statusItem.menu = statusMenu
        updateMenu()
    }

    private func configureNotifications() {
        let completedAction = UNNotificationAction(
            identifier: completedActionIdentifier,
            title: "已完成",
            options: []
        )
        let category = UNNotificationCategory(
            identifier: notificationCategoryIdentifier,
            actions: [completedAction],
            intentIdentifiers: [],
            options: []
        )

        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.setNotificationCategories([category])
        center.requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error {
                NSLog("HealthReminder notification authorization failed: \(error.localizedDescription)")
            }
            if !granted {
                NSLog("HealthReminder notification authorization was not granted.")
            }
        }
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
        let result = reminderEngine.tick(idleSeconds: idleSeconds)

        for reminder in result.remindersToSend {
            sendReminderNotification(for: reminder)
        }

        updateMenu()
    }

    private func sendReminderNotification(for reminder: ReminderDefinition) {
        let content = UNMutableNotificationContent()
        content.title = reminder.title
        content.body = reminder.body
        content.sound = .default
        content.categoryIdentifier = notificationCategoryIdentifier
        content.userInfo = [reminderIDUserInfoKey: reminder.id]

        let requestIdentifier = "health-reminder-\(reminder.id)-\(UUID().uuidString)"

        let request = UNNotificationRequest(
            identifier: requestIdentifier,
            content: content,
            trigger: nil
        )

        notificationRequestIDsByReminder[reminder.id, default: []].insert(requestIdentifier)
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                NSLog("HealthReminder notification delivery failed: \(error.localizedDescription)")
            }
        }
    }

    @objc private func markCurrentReminderCompleted() {
        guard let reminderID = reminderEngine.currentOverdueReminder?.definition.id else {
            return
        }

        markCompleted(reminderID: reminderID)
    }

    private func markCompleted(reminderID: String) {
        reminderEngine.markCompleted(reminderID: reminderID)
        removeDeliveredNotifications(for: reminderID)
        updateMenu()
    }

    private func removeDeliveredNotifications(for reminderID: String) {
        guard let requestIdentifiers = notificationRequestIDsByReminder.removeValue(forKey: reminderID) else {
            return
        }

        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: Array(requestIdentifiers))
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func updateMenu() {
        switch reminderEngine.state {
        case .tracking:
            if let nextReminder = reminderEngine.nextReminder {
                statusMenuItem.title = "\(nextReminder.definition.title)：约 \(minutesText(for: nextReminder.remainingActiveTime))后提醒"
            } else {
                statusMenuItem.title = "计时中"
            }
            completedMenuItem.isEnabled = false
            statusItem.button?.contentTintColor = nil
        case .pausedByIdle:
            statusMenuItem.title = "已离开，计时暂停"
            completedMenuItem.isEnabled = false
            statusItem.button?.contentTintColor = NSColor.systemBlue
        case .overdue:
            if let currentReminder = reminderEngine.currentOverdueReminder {
                statusMenuItem.title = currentReminder.definition.title
            } else {
                statusMenuItem.title = "有提醒待完成"
            }
            completedMenuItem.isEnabled = true
            statusItem.button?.contentTintColor = NSColor.systemOrange
        }
    }

    private func minutesText(for seconds: TimeInterval) -> String {
        let remainingMinutes = max(1, Int(ceil(seconds / 60)))
        return "\(remainingMinutes) 分钟"
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if response.actionIdentifier == completedActionIdentifier,
           let reminderID = response.notification.request.content.userInfo[reminderIDUserInfoKey] as? String {
            DispatchQueue.main.async {
                self.markCompleted(reminderID: reminderID)
            }
        }
        completionHandler()
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
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
