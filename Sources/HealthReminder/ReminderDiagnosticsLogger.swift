import Foundation
import HealthReminderCore

final class ReminderDiagnosticsLogger {
    private let logURL: URL
    private let dateFormatter: ISO8601DateFormatter

    init(
        logURL: URL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/HealthReminder/reminder.log")
    ) {
        self.logURL = logURL
        self.dateFormatter = ISO8601DateFormatter()
        self.dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    }

    func logLaunch(configuration: AppConfiguration, activeHealthReminderIDs: [String]) {
        let activeHealthIDs = activeHealthReminderIDs.joined(separator: ",")
        write(
            "launch tickInterval=\(format(configuration.tickInterval)) " +
                "idleThreshold=\(format(configuration.idleThreshold)) " +
                "healthEnabled=\(configuration.healthRemindersEnabled) " +
                "activeHealthIDs=\(activeHealthIDs)"
        )
    }

    func logSnapshot(
        idleSeconds: TimeInterval,
        healthState: ReminderEngineState,
        nextHealthReminder: ReminderProgress?,
        focusTaskIsSet: Bool,
        focusState: ReminderEngineState,
        focusRemainingActiveTime: TimeInterval
    ) {
        let nextHealth = nextHealthReminder.map {
            "\($0.definition.id):\(format($0.remainingActiveTime))"
        } ?? "none"

        write(
            "snapshot idle=\(format(idleSeconds)) " +
                "healthState=\(healthState.logValue) " +
                "nextHealth=\(nextHealth) " +
                "focusTaskSet=\(focusTaskIsSet) " +
                "focusState=\(focusState.logValue) " +
                "focusRemaining=\(format(focusRemainingActiveTime))"
        )
    }

    func logTriggered(healthReminderIDs: [String], focusTaskTriggered: Bool) {
        let triggeredHealthIDs = healthReminderIDs.joined(separator: ",")
        write(
            "triggered healthIDs=\(triggeredHealthIDs) " +
                "focusTaskTriggered=\(focusTaskTriggered)"
        )
    }

    private func write(_ message: String) {
        do {
            try FileManager.default.createDirectory(
                at: logURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let line = "\(dateFormatter.string(from: Date())) \(message)\n"
            if FileManager.default.fileExists(atPath: logURL.path) {
                let handle = try FileHandle(forWritingTo: logURL)
                try handle.seekToEnd()
                try handle.write(contentsOf: Data(line.utf8))
                try handle.close()
            } else {
                try line.write(to: logURL, atomically: true, encoding: .utf8)
            }
        } catch {
            NSLog("HealthReminder diagnostics log failed: \(error.localizedDescription)")
        }
    }

    private func format(_ value: TimeInterval) -> String {
        String(format: "%.1f", value)
    }
}

private extension ReminderEngineState {
    var logValue: String {
        switch self {
        case .tracking:
            return "tracking"
        case .pausedByIdle:
            return "pausedByIdle"
        }
    }
}
