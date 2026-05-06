import XCTest
@testable import HealthReminderCore

final class ReminderEngineTests: XCTestCase {
    func testActiveUseTriggersReminderAtConfiguredInterval() {
        var engine = makeEngine()
        var reminderCount = 0

        for _ in 0..<19 {
            reminderCount += engine.tick(idleSeconds: 0).shouldSendReminder ? 1 : 0
        }

        XCTAssertEqual(reminderCount, 0)
        XCTAssertEqual(engine.state, .tracking)
        XCTAssertEqual(engine.elapsedActiveTime, 19)

        reminderCount += engine.tick(idleSeconds: 0).shouldSendReminder ? 1 : 0

        XCTAssertEqual(reminderCount, 1)
        XCTAssertEqual(engine.state, .overdue)
        XCTAssertEqual(engine.elapsedActiveTime, 20)
    }

    func testIdleUsePausesWithoutIncreasingActiveTime() {
        var engine = makeEngine()

        _ = engine.tick(idleSeconds: 0)
        _ = engine.tick(idleSeconds: 5)

        XCTAssertEqual(engine.elapsedActiveTime, 2)
        XCTAssertEqual(engine.state, .tracking)

        let result = engine.tick(idleSeconds: 60)

        XCTAssertFalse(result.shouldSendReminder)
        XCTAssertEqual(engine.elapsedActiveTime, 2)
        XCTAssertEqual(engine.state, .pausedByIdle)
    }

    func testOverdueReminderRepeatsOnlyAfterRepeatInterval() {
        var engine = makeEngine()
        var reminderCount = 0

        for _ in 0..<20 {
            reminderCount += engine.tick(idleSeconds: 0).shouldSendReminder ? 1 : 0
        }

        XCTAssertEqual(reminderCount, 1)

        for _ in 0..<4 {
            reminderCount += engine.tick(idleSeconds: 0).shouldSendReminder ? 1 : 0
        }

        XCTAssertEqual(reminderCount, 1)

        reminderCount += engine.tick(idleSeconds: 0).shouldSendReminder ? 1 : 0

        XCTAssertEqual(reminderCount, 2)
        XCTAssertEqual(engine.state, .overdue)
    }

    func testMarkRestedResetsTrackingState() {
        var engine = makeEngine()

        for _ in 0..<20 {
            _ = engine.tick(idleSeconds: 0)
        }

        XCTAssertEqual(engine.state, .overdue)

        engine.markRested()

        XCTAssertEqual(engine.state, .tracking)
        XCTAssertEqual(engine.elapsedActiveTime, 0)
        XCTAssertFalse(engine.tick(idleSeconds: 0).shouldSendReminder)
    }

    private func makeEngine() -> ReminderEngine {
        ReminderEngine(
            reminderInterval: 20,
            repeatReminderInterval: 5,
            idleThreshold: 60,
            tickInterval: 1
        )
    }
}
