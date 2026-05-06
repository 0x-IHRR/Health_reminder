import XCTest
@testable import HealthReminderCore

final class ReminderEngineTests: XCTestCase {
    func testActiveUseTriggersEachReminderAtConfiguredIntervalAndAutoResetsIt() {
        var engine = makeEngine()

        XCTAssertEqual(engine.tick(idleSeconds: 0).remindersToSend.map(\.id), [])
        XCTAssertEqual(engine.tick(idleSeconds: 0).remindersToSend.map(\.id), [])

        let firstResult = engine.tick(idleSeconds: 0)

        XCTAssertEqual(firstResult.remindersToSend.map(\.id), ["movement"])
        XCTAssertEqual(engine.state, .tracking)
        XCTAssertEqual(engine.progress(for: "movement")?.elapsedActiveTime, 0)
        XCTAssertEqual(engine.progress(for: "water")?.elapsedActiveTime, 3)

        let secondResult = engine.tick(idleSeconds: 0)

        XCTAssertEqual(secondResult.remindersToSend.map(\.id), ["water"])
        XCTAssertEqual(engine.progress(for: "water")?.elapsedActiveTime, 0)
        XCTAssertEqual(engine.progress(for: "movement")?.elapsedActiveTime, 1)
    }

    func testIdleUsePausesAllRemindersWithoutIncreasingActiveTime() {
        var engine = makeEngine()

        _ = engine.tick(idleSeconds: 0)
        _ = engine.tick(idleSeconds: 5)

        XCTAssertEqual(engine.progress(for: "movement")?.elapsedActiveTime, 2)
        XCTAssertEqual(engine.progress(for: "water")?.elapsedActiveTime, 2)
        XCTAssertEqual(engine.state, .tracking)

        let result = engine.tick(idleSeconds: 60)

        XCTAssertEqual(result.remindersToSend, [])
        XCTAssertEqual(engine.progress(for: "movement")?.elapsedActiveTime, 2)
        XCTAssertEqual(engine.progress(for: "water")?.elapsedActiveTime, 2)
        XCTAssertEqual(engine.state, .pausedByIdle)
    }

    func testAutoResetDoesNotCreateRepeatReminders() {
        var engine = makeEngine()

        for _ in 0..<3 {
            _ = engine.tick(idleSeconds: 0)
        }

        XCTAssertEqual(engine.progress(for: "movement")?.elapsedActiveTime, 0)

        XCTAssertEqual(engine.tick(idleSeconds: 0).remindersToSend.map(\.id), ["water"])
        XCTAssertEqual(engine.tick(idleSeconds: 0).remindersToSend.map(\.id), [])

        let nextMovementResult = engine.tick(idleSeconds: 0)

        XCTAssertEqual(nextMovementResult.remindersToSend.map(\.id), ["movement"])
        XCTAssertEqual(engine.state, .tracking)
    }

    func testNextReminderUsesNearestRemainingActiveTime() {
        var engine = makeEngine()

        _ = engine.tick(idleSeconds: 0)

        XCTAssertEqual(engine.nextReminder?.definition.id, "movement")

        for _ in 0..<2 {
            _ = engine.tick(idleSeconds: 0)
        }

        XCTAssertEqual(engine.nextReminder?.definition.id, "water")
    }

    func testMultipleRemindersCanTriggerOnTheSameTick() {
        var engine = ReminderEngine(
            reminders: [
                ReminderDefinition(
                    id: "movement",
                    title: "活动",
                    body: "动一下。",
                    interval: 3
                ),
                ReminderDefinition(
                    id: "posture",
                    title: "坐姿",
                    body: "坐直。",
                    interval: 3
                )
            ],
            idleThreshold: 60,
            tickInterval: 1
        )

        _ = engine.tick(idleSeconds: 0)
        _ = engine.tick(idleSeconds: 0)

        XCTAssertEqual(engine.tick(idleSeconds: 0).remindersToSend.map(\.id), ["movement", "posture"])
        XCTAssertEqual(engine.progress(for: "movement")?.elapsedActiveTime, 0)
        XCTAssertEqual(engine.progress(for: "posture")?.elapsedActiveTime, 0)
    }

    private func makeEngine() -> ReminderEngine {
        ReminderEngine(
            reminders: [
                ReminderDefinition(
                    id: "movement",
                    title: "放松眼睛，活动一下",
                    body: "看一下远处，站起来动一动。",
                    interval: 3
                ),
                ReminderDefinition(
                    id: "water",
                    title: "喝水",
                    body: "喝几口水。",
                    interval: 4
                )
            ],
            idleThreshold: 60,
            tickInterval: 1
        )
    }
}
