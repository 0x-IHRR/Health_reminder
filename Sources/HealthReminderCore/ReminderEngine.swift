import Foundation

public enum ReminderEngineState: Equatable {
    case tracking
    case pausedByIdle
    case overdue
}

public struct ReminderTickResult: Equatable {
    public let shouldSendReminder: Bool
}

public struct ReminderEngine {
    public let reminderInterval: TimeInterval
    public let repeatReminderInterval: TimeInterval
    public let idleThreshold: TimeInterval
    public let tickInterval: TimeInterval

    public private(set) var elapsedActiveTime: TimeInterval
    public private(set) var state: ReminderEngineState
    private var elapsedSinceLastReminder: TimeInterval?

    public init(
        reminderInterval: TimeInterval,
        repeatReminderInterval: TimeInterval,
        idleThreshold: TimeInterval,
        tickInterval: TimeInterval
    ) {
        self.reminderInterval = reminderInterval
        self.repeatReminderInterval = repeatReminderInterval
        self.idleThreshold = idleThreshold
        self.tickInterval = tickInterval
        self.elapsedActiveTime = 0
        self.state = .tracking
        self.elapsedSinceLastReminder = nil
    }

    public mutating func tick(idleSeconds: TimeInterval) -> ReminderTickResult {
        if state == .overdue {
            return tickOverdue()
        }

        if idleSeconds >= idleThreshold {
            state = .pausedByIdle
            return ReminderTickResult(shouldSendReminder: false)
        }

        state = .tracking
        elapsedActiveTime += tickInterval

        if elapsedActiveTime >= reminderInterval {
            state = .overdue
            elapsedSinceLastReminder = 0
            return ReminderTickResult(shouldSendReminder: true)
        }

        return ReminderTickResult(shouldSendReminder: false)
    }

    public mutating func markRested() {
        elapsedActiveTime = 0
        state = .tracking
        elapsedSinceLastReminder = nil
    }

    private mutating func tickOverdue() -> ReminderTickResult {
        guard let currentElapsedSinceLastReminder = elapsedSinceLastReminder else {
            elapsedSinceLastReminder = 0
            return ReminderTickResult(shouldSendReminder: true)
        }

        let nextElapsedSinceLastReminder = currentElapsedSinceLastReminder + tickInterval
        if nextElapsedSinceLastReminder >= repeatReminderInterval {
            elapsedSinceLastReminder = 0
            return ReminderTickResult(shouldSendReminder: true)
        }

        elapsedSinceLastReminder = nextElapsedSinceLastReminder
        return ReminderTickResult(shouldSendReminder: false)
    }
}
