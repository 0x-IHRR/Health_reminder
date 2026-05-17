import XCTest
@testable import HealthReminderCore

final class KanbanTaskReaderTests: XCTestCase {
    func testReadsOnlyUncheckedTasksFromInboxSection() {
        let markdown = """
        # Kanban

        ## 收件箱
        - [ ] 写 HealthReminder 主线任务
        - [x] 已完成的旧任务
        - [ ] 复盘提醒体验

        ## 进行中
        - [ ] 不应该读到这一条
        """

        let tasks = KanbanTaskReader().parseInboxTasks(from: markdown)

        XCTAssertEqual(tasks, [
            "写 HealthReminder 主线任务",
            "复盘提醒体验"
        ])
    }

    func testIgnoresOtherSectionsBeforeInbox() {
        let markdown = """
        ## 进行中
        - [ ] 进行中的任务

        ## 收件箱
        - [ ] 收件箱任务

        ## 完成
        - [ ] 完成区任务
        """

        XCTAssertEqual(KanbanTaskReader().parseInboxTasks(from: markdown), ["收件箱任务"])
    }

    func testReturnsEmptyArrayWhenInboxIsMissingOrEmpty() {
        XCTAssertEqual(
            KanbanTaskReader().parseInboxTasks(from: "## 进行中\n- [ ] A"),
            []
        )

        XCTAssertEqual(
            KanbanTaskReader().parseInboxTasks(from: "## 收件箱\n- [x] A"),
            []
        )
    }

    func testReadInboxTasksDoesNotModifySourceFile() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("health-reminder-kanban-\(UUID().uuidString).md")
        let markdown = "## 收件箱\n- [ ] 只读任务\n"
        try markdown.write(to: url, atomically: true, encoding: .utf8)
        defer {
            try? FileManager.default.removeItem(at: url)
        }

        let before = try Data(contentsOf: url)
        let tasks = try KanbanTaskReader().readInboxTasks(from: url)
        let after = try Data(contentsOf: url)

        XCTAssertEqual(tasks, ["只读任务"])
        XCTAssertEqual(after, before)
    }

    func testReadsCustomInboxSectionTitle() {
        let markdown = """
        ## 收件箱
        - [ ] 默认收件箱任务

        ## Inbox
        - [ ] Custom task

        ## Done
        - [ ] Ignored task
        """

        let tasks = KanbanTaskReader().parseInboxTasks(
            from: markdown,
            inboxSectionTitle: "Inbox"
        )

        XCTAssertEqual(tasks, ["Custom task"])
    }

    func testReadsSectionAtAnyHeadingLevelAndStopsAtSameOrHigherHeading() {
        let markdown = """
        # Project
        ### Inbox
          + [ ] 缩进加号任务
          * [ ] 缩进星号任务

        #### Nested
        - [ ] 子标题下任务

        ### Next
        - [ ] 不应该读到
        """

        let tasks = KanbanTaskReader().parseInboxTasks(from: markdown, inboxSectionTitle: "Inbox")

        XCTAssertEqual(tasks, ["缩进加号任务", "缩进星号任务", "子标题下任务"])
    }

    func testEmptySectionTitleReadsAllUncheckedTasks() {
        let markdown = """
        ## Backlog
        - [ ] A
        - [x] B

        ## Today
          + [ ] C
        """

        let tasks = KanbanTaskReader().parseInboxTasks(from: markdown, inboxSectionTitle: "")

        XCTAssertEqual(tasks, ["A", "C"])
    }
}
