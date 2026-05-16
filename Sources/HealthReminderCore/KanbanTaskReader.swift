import Foundation

public struct KanbanTaskReader {
    public init() {}

    public func readInboxTasks(
        from url: URL,
        inboxSectionTitle: String = AppConfiguration.defaults.kanbanInboxSection
    ) throws -> [String] {
        let contents = try String(contentsOf: url, encoding: .utf8)
        return parseInboxTasks(from: contents, inboxSectionTitle: inboxSectionTitle)
    }

    public func parseInboxTasks(
        from contents: String,
        inboxSectionTitle: String = AppConfiguration.defaults.kanbanInboxSection
    ) -> [String] {
        var isInsideInbox = false
        var tasks: [String] = []
        let sectionHeading = "## \(inboxSectionTitle)"

        for rawLine in contents.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)

            if line.hasPrefix("## ") {
                if isInsideInbox {
                    break
                }
                isInsideInbox = line == sectionHeading
                continue
            }

            guard isInsideInbox else {
                continue
            }

            if let task = uncheckedTaskTitle(from: line) {
                tasks.append(task)
            }
        }

        return tasks
    }

    private func uncheckedTaskTitle(from line: String) -> String? {
        let prefixes = ["- [ ] ", "* [ ] "]

        guard let prefix = prefixes.first(where: { line.hasPrefix($0) }) else {
            return nil
        }

        let title = line.dropFirst(prefix.count).trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty ? nil : String(title)
    }
}
