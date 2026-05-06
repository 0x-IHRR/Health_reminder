import XCTest
@testable import HealthReminderCore

final class ReminderEngineTests: XCTestCase {
    func testActiveUseTriggersEachReminderAtConfiguredInterval() {
        var engine = makeEngine()

        XCTAssertEqual(engine.tick(idleSeconds: 0).remindersToSend.map(\.id), [])
        XCTAssertEqual(engine.tick(idleSeconds: 0).remindersToSend.map(\.id), [])

        let firstResult = engine.tick(idleSeconds: 0)

        XCTAssertEqual(firstResult.remindersToSend.map(\.id), ["eyes"])
        XCTAssertEqual(engine.state, .overdue)
        XCTAssertEqual(engine.progress(for: "eyes")?.elapsedActiveTime, 3)
        XCTAssertEqual(engine.progress(for: "water")?.elapsedActiveTime, 3)

        let secondResult = engine.tick(idleSeconds: 0)

        XCTAssertEqual(secondResult.remindersToSend.map(\.id), ["water"])
        XCTAssertEqual(engine.progress(for: "water")?.elapsedActiveTime, 4)
    }

    func testIdleUsePausesAllRemindersWithoutIncreasingActiveTime() {
        var engine = makeEngine()

        _ = engine.tick(idleSeconds: 0)
        _ = engine.tick(idleSeconds: 5)

        XCTAssertEqual(engine.progress(for: "eyes")?.elapsedActiveTime, 2)
        XCTAssertEqual(engine.progress(for: "water")?.elapsedActiveTime, 2)
        XCTAssertEqual(engine.state, .tracking)

        let result = engine.tick(idleSeconds: 60)

        XCTAssertEqual(result.remindersToSend, [])
        XCTAssertEqual(engine.progress(for: "eyes")?.elapsedActiveTime, 2)
        XCTAssertEqual(engine.progress(for: "water")?.elapsedActiveTime, 2)
        XCTAssertEqual(engine.state, .pausedByIdle)
    }

    func testOverdueReminderRepeatsOnlyAfterRepeatInterval() {
        var engine = makeEngine()

        for _ in 0..<3 {
            _ = engine.tick(idleSeconds: 0)
        }

        XCTAssertEqual(engine.currentOverdueReminder?.definition.id, "eyes")

        XCTAssertEqual(engine.tick(idleSeconds: 0).remindersToSend.map(\.id), ["water"])
        XCTAssertEqual(engine.tick(idleSeconds: 0).remindersToSend.map(\.id), [])

        let repeatResult = engine.tick(idleSeconds: 0)

        XCTAssertEqual(repeatResult.remindersToSend.map(\.id), ["eyes"])
        XCTAssertEqual(engine.state, .overdue)
    }

    func testIdleDoesNotAdvanceRepeatReminderCountdown() {
        var engine = makeEngine()

        for _ in 0..<3 {
            _ = engine.tick(idleSeconds: 0)
        }

        _ = engine.tick(idleSeconds: 60)
        _ = engine.tick(idleSeconds: 60)

        XCTAssertEqual(engine.tick(idleSeconds: 0).remindersToSend.map(\.id), ["water"])
        XCTAssertEqual(engine.tick(idleSeconds: 0).remindersToSend.map(\.id), [])
        XCTAssertEqual(engine.tick(idleSeconds: 0).remindersToSend.map(\.id), ["eyes"])
    }

    func testMarkCompletedResetsOnlySelectedReminder() {
        var engine = makeEngine()

        for _ in 0..<4 {
            _ = engine.tick(idleSeconds: 0)
        }

        XCTAssertEqual(engine.progress(for: "eyes")?.state, .overdue)
        XCTAssertEqual(engine.progress(for: "water")?.state, .overdue)

        engine.markCompleted(reminderID: "eyes")

        XCTAssertEqual(engine.progress(for: "eyes")?.state, .tracking)
        XCTAssertEqual(engine.progress(for: "eyes")?.elapsedActiveTime, 0)
        XCTAssertEqual(engine.progress(for: "water")?.state, .overdue)
        XCTAssertEqual(engine.progress(for: "water")?.elapsedActiveTime, 4)
        XCTAssertEqual(engine.state, .overdue)
    }

    func testNextReminderUsesNearestRemainingActiveTime() {
        var engine = makeEngine()

        _ = engine.tick(idleSeconds: 0)

        XCTAssertEqual(engine.nextReminder?.definition.id, "eyes")

        for _ in 0..<3 {
            _ = engine.tick(idleSeconds: 0)
        }
        engine.markCompleted(reminderID: "eyes")

        XCTAssertEqual(engine.nextReminder?.definition.id, "eyes")
        XCTAssertEqual(engine.currentOverdueReminder?.definition.id, "water")
    }

    private func makeEngine() -> ReminderEngine {
        ReminderEngine(
            reminders: [
                ReminderDefinition(
                    id: "eyes",
                    title: "放松眼睛",
                    body: "眨眨眼，看一下远处。",
                    interval: 3,
                    repeatReminderInterval: 3
                ),
                ReminderDefinition(
                    id: "water",
                    title: "喝水",
                    body: "喝几口水。",
                    interval: 4,
                    repeatReminderInterval: 3
                )
            ],
            idleThreshold: 60,
            tickInterval: 1
        )
    }
}
