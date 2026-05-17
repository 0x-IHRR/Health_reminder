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
        let normalizedSectionTitle = inboxSectionTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        var isInsideInbox = normalizedSectionTitle.isEmpty
        var inboxHeadingLevel: Int?
        var tasks: [String] = []

        for rawLine in contents.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)

            if let heading = markdownHeading(from: line) {
                if isInsideInbox,
                   let inboxHeadingLevel,
                   heading.level <= inboxHeadingLevel {
                    break
                }

                if heading.title == normalizedSectionTitle {
                    isInsideInbox = true
                    inboxHeadingLevel = heading.level
                }
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
        let prefixes = ["- [ ] ", "* [ ] ", "+ [ ] "]

        guard let prefix = prefixes.first(where: { line.hasPrefix($0) }) else {
            return nil
        }

        let title = line.dropFirst(prefix.count).trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty ? nil : String(title)
    }

    private func markdownHeading(from line: String) -> (level: Int, title: String)? {
        var level = 0

        for character in line {
            if character == "#" {
                level += 1
            } else {
                break
            }
        }

        guard level > 0,
              level <= 6,
              line.dropFirst(level).first == " " else {
            return nil
        }

        let title = line
            .dropFirst(level + 1)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "#"))
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return title.isEmpty ? nil : (level, title)
    }
}
