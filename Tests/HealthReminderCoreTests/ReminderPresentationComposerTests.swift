import XCTest
@testable import HealthReminderCore

final class ReminderPresentationComposerTests: XCTestCase {
    func testEmptyInputReturnsNil() {
        let message = ReminderPresentationComposer.compose(
            healthReminders: [],
            focusTask: nil
        )

        XCTAssertNil(message)
    }

    func testSingleHealthReminderKeepsOriginalCopy() {
        let message = ReminderPresentationComposer.compose(
            healthReminders: [movementReminder],
            focusTask: nil
        )

        XCTAssertEqual(
            message,
            ReminderPresentationMessage(
                title: "放松眼睛，活动一下",
                body: "看一下远处，站起来动一动。"
            )
        )
    }

    func testMultipleHealthRemindersAreCompressedIntoOneMessage() {
        let message = ReminderPresentationComposer.compose(
            healthReminders: [movementReminder, waterReminder, postureReminder],
            focusTask: nil
        )

        XCTAssertEqual(
            message,
            ReminderPresentationMessage(
                title: "休息一下",
                body: "放松眼睛，活动一下 · 喝水 · 调整坐姿，放松肩颈"
            )
        )
    }

    func testSingleFocusReminderKeepsFocusCopy() {
        let message = ReminderPresentationComposer.compose(
            healthReminders: [],
            focusTask: FocusTask(title: "写 HealthReminder MVP")
        )

        XCTAssertEqual(
            message,
            ReminderPresentationMessage(
                title: "回到主线任务",
                body: "写 HealthReminder MVP"
            )
        )
    }

    func testFocusReminderTakesPriorityAndIncludesHealthReminders() {
        let message = ReminderPresentationComposer.compose(
            healthReminders: [movementReminder, waterReminder],
            focusTask: FocusTask(title: "整理召回逻辑")
        )

        XCTAssertEqual(
            message,
            ReminderPresentationMessage(
                title: "回到主线任务",
                body: "整理召回逻辑\n顺手：放松眼睛，活动一下 · 喝水"
            )
        )
    }

    private var movementReminder: ReminderDefinition {
        ReminderDefinition(
            id: "movement-break",
            title: "放松眼睛，活动一下",
            body: "看一下远处，站起来动一动。",
            interval: 30 * 60
        )
    }

    private var waterReminder: ReminderDefinition {
        ReminderDefinition(
            id: "water",
            title: "喝水",
            body: "喝几口水，别等口渴了再喝。",
            interval: 60 * 60
        )
    }

    private var postureReminder: ReminderDefinition {
        ReminderDefinition(
            id: "posture-relax",
            title: "调整坐姿，放松肩颈",
            body: "坐直一点，转转脖子，活动一下肩膀。",
            interval: 90 * 60
        )
    }
}
