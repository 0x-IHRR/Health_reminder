import Foundation

public enum ReminderEngineState: Equatable {
    case tracking
    case pausedByIdle
}

public struct ReminderDefinition: Equatable {
    public let id: String
    public let title: String
    public let body: String
    public let interval: TimeInterval

    public init(
        id: String,
        title: String,
        body: String,
        interval: TimeInterval
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.interval = interval
    }
}

public struct ReminderProgress: Equatable {
    public let definition: ReminderDefinition
    public let elapsedActiveTime: TimeInterval
    public let state: ReminderEngineState

    public var remainingActiveTime: TimeInterval {
        max(0, definition.interval - elapsedActiveTime)
    }
}

public struct ReminderTickResult: Equatable {
    public let remindersToSend: [ReminderDefinition]

    public var shouldSendReminder: Bool {
        !remindersToSend.isEmpty
    }
}

public struct ReminderEngine {
    public let idleThreshold: TimeInterval
    public let tickInterval: TimeInterval

    public private(set) var state: ReminderEngineState
    private var records: [ReminderRecord]

    public init(
        reminders: [ReminderDefinition],
        idleThreshold: TimeInterval,
        tickInterval: TimeInterval
    ) {
        precondition(Set(reminders.map(\.id)).count == reminders.count, "Reminder IDs must be unique.")

        self.idleThreshold = idleThreshold
        self.tickInterval = tickInterval
        self.state = .tracking
        self.records = reminders.map { ReminderRecord(definition: $0) }
    }

    public var reminders: [ReminderProgress] {
        records.map(\.progress)
    }

    public var nextReminder: ReminderProgress? {
        reminders
            .filter { $0.state == .tracking }
            .min { $0.remainingActiveTime < $1.remainingActiveTime }
    }

    public func progress(for reminderID: String) -> ReminderProgress? {
        records.first { $0.definition.id == reminderID }?.progress
    }

    public mutating func tick(idleSeconds: TimeInterval) -> ReminderTickResult {
        if idleSeconds >= idleThreshold {
            updateOverallState(isIdle: true)
            return ReminderTickResult(remindersToSend: [])
        }

        var remindersToSend: [ReminderDefinition] = []

        for index in records.indices {
            if let reminder = records[index].tick(tickInterval: tickInterval) {
                remindersToSend.append(reminder)
            }
        }

        updateOverallState(isIdle: false)
        return ReminderTickResult(remindersToSend: remindersToSend)
    }

    private mutating func updateOverallState(isIdle: Bool) {
        state = isIdle ? .pausedByIdle : .tracking
    }
}

private struct ReminderRecord {
    let definition: ReminderDefinition
    private(set) var elapsedActiveTime: TimeInterval
    private(set) var state: ReminderEngineState

    init(definition: ReminderDefinition) {
        self.definition = definition
        self.elapsedActiveTime = 0
        self.state = .tracking
    }

    var progress: ReminderProgress {
        ReminderProgress(
            definition: definition,
            elapsedActiveTime: elapsedActiveTime,
            state: state
        )
    }

    mutating func tick(tickInterval: TimeInterval) -> ReminderDefinition? {
        state = .tracking
        elapsedActiveTime += tickInterval

        if elapsedActiveTime >= definition.interval {
            reset()
            return definition
        }

        return nil
    }

    mutating func reset() {
        elapsedActiveTime = 0
        state = .tracking
    }
}
