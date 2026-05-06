import AppKit
import CoreGraphics
import Foundation
import HealthReminderCore
import UserNotifications

private final class HealthReminderApp: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    private let reminderInterval: TimeInterval = 20 * 60
    private let repeatReminderInterval: TimeInterval = 5 * 60
    private let idleThreshold: TimeInterval = 60
    private let tickInterval: TimeInterval = 1
    private let anyInputEventType = CGEventType(rawValue: UInt32.max)!
    private let bundleIdentifier = "com.healthreminder.app"
    private let notificationCategoryIdentifier = "BREAK_REMINDER_CATEGORY"
    private let restedActionIdentifier = "RESTED_ACTION"

    private var statusItem: NSStatusItem!
    private var statusMenu = NSMenu()
    private var statusMenuItem = NSMenuItem()
    private var restedMenuItem = NSMenuItem()
    private var reminderEngine: ReminderEngine!
    private var timer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        reminderEngine = ReminderEngine(
            reminderInterval: reminderInterval,
            repeatReminderInterval: repeatReminderInterval,
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

        restedMenuItem = NSMenuItem(title: "已休息", action: #selector(markRested), keyEquivalent: "")
        restedMenuItem.target = self
        statusMenu.addItem(restedMenuItem)

        statusMenu.addItem(.separator())

        let quitItem = NSMenuItem(title: "退出", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        statusMenu.addItem(quitItem)

        statusItem.menu = statusMenu
        updateMenu()
    }

    private func configureNotifications() {
        let restedAction = UNNotificationAction(
            identifier: restedActionIdentifier,
            title: "已休息",
            options: []
        )
        let category = UNNotificationCategory(
            identifier: notificationCategoryIdentifier,
            actions: [restedAction],
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

        if result.shouldSendReminder {
            sendReminderNotification()
        }

        updateMenu()
    }

    private func sendReminderNotification() {
        let content = UNMutableNotificationContent()
        content.title = "该休息一下了"
        content.body = "看一次远处，站起来动一下。"
        content.sound = .default
        content.categoryIdentifier = notificationCategoryIdentifier

        let request = UNNotificationRequest(
            identifier: "health-reminder-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                NSLog("HealthReminder notification delivery failed: \(error.localizedDescription)")
            }
        }
    }

    @objc private func markRested() {
        reminderEngine.markRested()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        updateMenu()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func updateMenu() {
        switch reminderEngine.state {
        case .tracking:
            let remainingMinutes = max(0, Int(ceil((reminderInterval - reminderEngine.elapsedActiveTime) / 60)))
            statusMenuItem.title = "计时中，约 \(remainingMinutes) 分钟后提醒"
            restedMenuItem.isEnabled = false
            statusItem.button?.contentTintColor = nil
        case .pausedByIdle:
            statusMenuItem.title = "已离开，计时暂停"
            restedMenuItem.isEnabled = false
            statusItem.button?.contentTintColor = NSColor.systemBlue
        case .overdue:
            statusMenuItem.title = "该休息一下了"
            restedMenuItem.isEnabled = true
            statusItem.button?.contentTintColor = NSColor.systemOrange
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if response.actionIdentifier == restedActionIdentifier {
            DispatchQueue.main.async {
                self.markRested()
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
