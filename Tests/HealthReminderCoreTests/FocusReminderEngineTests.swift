import XCTest
@testable import HealthReminderCore

final class FocusReminderEngineTests: XCTestCase {
    func testEmptyCurrentTaskDoesNotAccumulateOrRemind() {
        var engine = makeEngine()

        for _ in 0..<4 {
            XCTAssertFalse(engine.tick(idleSeconds: 0).shouldRemind)
        }

        XCTAssertNil(engine.currentTask)
        XCTAssertEqual(engine.elapsedActiveTime, 0)
        XCTAssertEqual(engine.state, .tracking)
    }

    func testCurrentTaskTriggersAfterConfiguredActiveIntervalAndResets() {
        var engine = makeEngine()
        engine.setTask(FocusTask(title: "写 HealthReminder MVP"))

        XCTAssertFalse(engine.tick(idleSeconds: 0).shouldRemind)
        XCTAssertFalse(engine.tick(idleSeconds: 0).shouldRemind)

        let result = engine.tick(idleSeconds: 0)

        XCTAssertEqual(result.taskToRemind, FocusTask(title: "写 HealthReminder MVP"))
        XCTAssertEqual(engine.elapsedActiveTime, 0)
        XCTAssertEqual(engine.state, .tracking)
    }

    func testIdlePausesWithoutIncreasingActiveTime() {
        var engine = makeEngine()
        engine.setTask(FocusTask(title: "整理菜单栏"))

        _ = engine.tick(idleSeconds: 0)
        let result = engine.tick(idleSeconds: 60)

        XCTAssertFalse(result.shouldRemind)
        XCTAssertEqual(engine.elapsedActiveTime, 1)
        XCTAssertEqual(engine.state, .pausedByIdle)
    }

    func testTriggerResetsForNextReminderRound() {
        var engine = makeEngine()
        engine.setTask(FocusTask(title: "补测试"))

        for _ in 0..<3 {
            _ = engine.tick(idleSeconds: 0)
        }

        XCTAssertEqual(engine.elapsedActiveTime, 0)
        XCTAssertFalse(engine.tick(idleSeconds: 0).shouldRemind)
        XCTAssertFalse(engine.tick(idleSeconds: 0).shouldRemind)
        XCTAssertTrue(engine.tick(idleSeconds: 0).shouldRemind)
    }

    func testChangingOrClearingTaskResetsActiveTime() {
        var engine = makeEngine()
        engine.setTask(FocusTask(title: "旧任务"))
        _ = engine.tick(idleSeconds: 0)
        _ = engine.tick(idleSeconds: 0)

        engine.setTask(FocusTask(title: "新任务"))

        XCTAssertEqual(engine.currentTask, FocusTask(title: "新任务"))
        XCTAssertEqual(engine.elapsedActiveTime, 0)
        XCTAssertFalse(engine.tick(idleSeconds: 0).shouldRemind)

        engine.setTask(nil)

        XCTAssertNil(engine.currentTask)
        XCTAssertEqual(engine.elapsedActiveTime, 0)
        XCTAssertFalse(engine.tick(idleSeconds: 0).shouldRemind)
    }

    private func makeEngine() -> FocusReminderEngine {
        FocusReminderEngine(
            interval: 3,
            idleThreshold: 60,
            tickInterval: 1
        )
    }
}
