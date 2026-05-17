import Foundation

public struct ReminderPresentationMessage: Equatable {
    public let title: String
    public let body: String

    public init(title: String, body: String) {
        self.title = title
        self.body = body
    }
}

public enum ReminderPresentationComposer {
    public static func compose(
        healthReminders: [ReminderDefinition],
        focusTask: FocusTask?
    ) -> ReminderPresentationMessage? {
        if let focusTask {
            return focusMessage(for: focusTask, healthReminders: healthReminders)
        }

        switch healthReminders.count {
        case 0:
            return nil
        case 1:
            guard let reminder = healthReminders.first else {
                return nil
            }
            return ReminderPresentationMessage(title: reminder.title, body: reminder.body)
        default:
            return ReminderPresentationMessage(
                title: "休息一下",
                body: joinedHealthTitles(from: healthReminders)
            )
        }
    }

    private static func focusMessage(
        for focusTask: FocusTask,
        healthReminders: [ReminderDefinition]
    ) -> ReminderPresentationMessage {
        guard !healthReminders.isEmpty else {
            return ReminderPresentationMessage(title: "回到主线任务", body: focusTask.title)
        }

        return ReminderPresentationMessage(
            title: "回到主线任务",
            body: "\(focusTask.title)\n顺手：\(joinedHealthTitles(from: healthReminders))"
        )
    }

    private static func joinedHealthTitles(from reminders: [ReminderDefinition]) -> String {
        reminders.map(\.title).joined(separator: " · ")
    }
}
