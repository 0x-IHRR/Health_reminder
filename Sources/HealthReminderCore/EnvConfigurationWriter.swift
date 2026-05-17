import Foundation

public enum EnvConfigurationWriter {
    public static func mergedContents(existingContents: String, updates: [String: String]) -> String {
        var remainingUpdates = updates
        var lines: [String] = []

        for rawLine in existingContents.components(separatedBy: .newlines) {
            guard !rawLine.isEmpty else {
                lines.append(rawLine)
                continue
            }

            let trimmedLine = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedLine.hasPrefix("#"),
                  let separatorIndex = rawLine.firstIndex(of: "=") else {
                lines.append(rawLine)
                continue
            }

            let key = rawLine[..<separatorIndex].trimmingCharacters(in: .whitespacesAndNewlines)
            if let updatedValue = remainingUpdates.removeValue(forKey: String(key)) {
                lines.append("\(key)=\(updatedValue)")
            } else {
                lines.append(rawLine)
            }
        }

        let sortedRemainingKeys = remainingUpdates.keys.sorted()
        if !sortedRemainingKeys.isEmpty, !lines.isEmpty, lines.last != "" {
            lines.append("")
        }

        for key in sortedRemainingKeys {
            if let value = remainingUpdates[key] {
                lines.append("\(key)=\(value)")
            }
        }

        return lines.joined(separator: "\n").trimmingCharacters(in: .newlines) + "\n"
    }
}
