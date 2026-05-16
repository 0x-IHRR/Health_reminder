import Foundation
import HealthReminderCore

final class FocusTaskStore {
    private let defaults: UserDefaults
    private let currentTaskTitleKey = "currentFocusTaskTitle"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var currentTask: FocusTask? {
        guard let title = defaults.string(forKey: currentTaskTitleKey) else {
            return nil
        }

        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedTitle.isEmpty ? nil : FocusTask(title: trimmedTitle)
    }

    func setCurrentTask(_ task: FocusTask?) {
        guard let task else {
            defaults.removeObject(forKey: currentTaskTitleKey)
            return
        }

        let trimmedTitle = task.title.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedTitle.isEmpty {
            defaults.removeObject(forKey: currentTaskTitleKey)
        } else {
            defaults.set(trimmedTitle, forKey: currentTaskTitleKey)
        }
    }
}
