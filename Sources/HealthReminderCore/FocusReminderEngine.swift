import Foundation

public struct FocusTask: Equatable {
    public let title: String

    public init(title: String) {
        self.title = title
    }
}

public struct FocusReminderTickResult: Equatable {
    public let taskToRemind: FocusTask?

    public init(taskToRemind: FocusTask?) {
        self.taskToRemind = taskToRemind
    }

    public var shouldRemind: Bool {
        taskToRemind != nil
    }
}

public struct FocusReminderEngine {
    public let interval: TimeInterval
    public let idleThreshold: TimeInterval
    public let tickInterval: TimeInterval

    public private(set) var currentTask: FocusTask?
    public private(set) var elapsedActiveTime: TimeInterval
    public private(set) var state: ReminderEngineState

    public init(
        interval: TimeInterval,
        idleThreshold: TimeInterval,
        tickInterval: TimeInterval,
        currentTask: FocusTask? = nil
    ) {
        self.interval = interval
        self.idleThreshold = idleThreshold
        self.tickInterval = tickInterval
        self.currentTask = currentTask
        self.elapsedActiveTime = 0
        self.state = .tracking
    }

    public mutating func setTask(_ task: FocusTask?) {
        currentTask = task
        elapsedActiveTime = 0
        state = .tracking
    }

    public mutating func tick(idleSeconds: TimeInterval) -> FocusReminderTickResult {
        guard let currentTask else {
            elapsedActiveTime = 0
            state = idleSeconds >= idleThreshold ? .pausedByIdle : .tracking
            return FocusReminderTickResult(taskToRemind: nil)
        }

        if idleSeconds >= idleThreshold {
            state = .pausedByIdle
            return FocusReminderTickResult(taskToRemind: nil)
        }

        state = .tracking
        elapsedActiveTime += tickInterval

        if elapsedActiveTime >= interval {
            elapsedActiveTime = 0
            return FocusReminderTickResult(taskToRemind: currentTask)
        }

        return FocusReminderTickResult(taskToRemind: nil)
    }
}
