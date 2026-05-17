import Foundation

public struct AppConfiguration: Equatable {
    public struct Overlay: Equatable {
        public let displaySeconds: TimeInterval
        public let fadeInSeconds: TimeInterval
        public let fadeOutSeconds: TimeInterval
        public let width: Double
        public let height: Double
        public let theme: String
        public let textAlignment: String
        public let particleStyle: String
        public let particleBirthRate: Double
        public let particleLifetimeSeconds: TimeInterval
        public let particleDurationSeconds: TimeInterval
        public let particleVelocity: Double
        public let particleScale: Double

        public init(
            displaySeconds: TimeInterval,
            fadeInSeconds: TimeInterval,
            fadeOutSeconds: TimeInterval,
            width: Double,
            height: Double,
            theme: String,
            textAlignment: String,
            particleStyle: String,
            particleBirthRate: Double,
            particleLifetimeSeconds: TimeInterval,
            particleDurationSeconds: TimeInterval,
            particleVelocity: Double,
            particleScale: Double
        ) {
            self.displaySeconds = displaySeconds
            self.fadeInSeconds = fadeInSeconds
            self.fadeOutSeconds = fadeOutSeconds
            self.width = width
            self.height = height
            self.theme = theme
            self.textAlignment = textAlignment
            self.particleStyle = particleStyle
            self.particleBirthRate = particleBirthRate
            self.particleLifetimeSeconds = particleLifetimeSeconds
            self.particleDurationSeconds = particleDurationSeconds
            self.particleVelocity = particleVelocity
            self.particleScale = particleScale
        }
    }

    public let movementInterval: TimeInterval
    public let waterInterval: TimeInterval
    public let postureInterval: TimeInterval
    public let focusReminderInterval: TimeInterval
    public let idleThreshold: TimeInterval
    public let tickInterval: TimeInterval
    public let kanbanPath: String
    public let kanbanInboxSection: String
    public let overlay: Overlay

    public init(
        movementInterval: TimeInterval,
        waterInterval: TimeInterval,
        postureInterval: TimeInterval,
        focusReminderInterval: TimeInterval,
        idleThreshold: TimeInterval,
        tickInterval: TimeInterval,
        kanbanPath: String,
        kanbanInboxSection: String,
        overlay: Overlay
    ) {
        self.movementInterval = movementInterval
        self.waterInterval = waterInterval
        self.postureInterval = postureInterval
        self.focusReminderInterval = focusReminderInterval
        self.idleThreshold = idleThreshold
        self.tickInterval = tickInterval
        self.kanbanPath = kanbanPath
        self.kanbanInboxSection = kanbanInboxSection
        self.overlay = overlay
    }

    public static let defaultKanbanPath = "/Users/ihrr/Library/Mobile Documents/iCloud~md~obsidian/Documents/起源之地/0x.Start/_Meta/Kanban.md"

    public static let defaults = AppConfiguration(
        movementInterval: 30 * 60,
        waterInterval: 60 * 60,
        postureInterval: 90 * 60,
        focusReminderInterval: 15 * 60,
        idleThreshold: 60,
        tickInterval: 1,
        kanbanPath: defaultKanbanPath,
        kanbanInboxSection: "收件箱",
        overlay: Overlay(
            displaySeconds: 4,
            fadeInSeconds: 0.35,
            fadeOutSeconds: 0.5,
            width: 420,
            height: 132,
            theme: "dark_neon",
            textAlignment: "center",
            particleStyle: "reconstruct",
            particleBirthRate: 72,
            particleLifetimeSeconds: 1.1,
            particleDurationSeconds: 0.85,
            particleVelocity: 52,
            particleScale: 0.03
        )
    )

    public static func load(from url: URL) -> AppConfiguration {
        guard let contents = try? String(contentsOf: url, encoding: .utf8) else {
            return defaults
        }

        return load(envContents: contents)
    }

    public static func load(envContents: String) -> AppConfiguration {
        load(overrides: parseEnv(envContents))
    }

    public static func load(overrides: [String: String]) -> AppConfiguration {
        let defaults = AppConfiguration.defaults
        let overlayDefaults = defaults.overlay

        return AppConfiguration(
            movementInterval: positiveTimeInterval(
                overrides["HEALTH_MOVEMENT_INTERVAL_SECONDS"],
                defaultValue: defaults.movementInterval
            ),
            waterInterval: positiveTimeInterval(
                overrides["HEALTH_WATER_INTERVAL_SECONDS"],
                defaultValue: defaults.waterInterval
            ),
            postureInterval: positiveTimeInterval(
                overrides["HEALTH_POSTURE_INTERVAL_SECONDS"],
                defaultValue: defaults.postureInterval
            ),
            focusReminderInterval: positiveTimeInterval(
                overrides["FOCUS_REMINDER_INTERVAL_SECONDS"],
                defaultValue: defaults.focusReminderInterval
            ),
            idleThreshold: positiveTimeInterval(
                overrides["IDLE_THRESHOLD_SECONDS"],
                defaultValue: defaults.idleThreshold
            ),
            tickInterval: positiveTimeInterval(
                overrides["TICK_INTERVAL_SECONDS"],
                defaultValue: defaults.tickInterval
            ),
            kanbanPath: nonEmptyString(overrides["KANBAN_PATH"], defaultValue: defaults.kanbanPath),
            kanbanInboxSection: nonEmptyString(
                overrides["KANBAN_INBOX_SECTION"],
                defaultValue: defaults.kanbanInboxSection
            ),
            overlay: Overlay(
                displaySeconds: positiveTimeInterval(
                    overrides["OVERLAY_DISPLAY_SECONDS"],
                    defaultValue: overlayDefaults.displaySeconds
                ),
                fadeInSeconds: nonNegativeTimeInterval(
                    overrides["OVERLAY_FADE_IN_SECONDS"],
                    defaultValue: overlayDefaults.fadeInSeconds
                ),
                fadeOutSeconds: nonNegativeTimeInterval(
                    overrides["OVERLAY_FADE_OUT_SECONDS"],
                    defaultValue: overlayDefaults.fadeOutSeconds
                ),
                width: positiveDouble(overrides["OVERLAY_WIDTH"], defaultValue: overlayDefaults.width),
                height: positiveDouble(overrides["OVERLAY_HEIGHT"], defaultValue: overlayDefaults.height),
                theme: overlayTheme(overrides["OVERLAY_THEME"], defaultValue: overlayDefaults.theme),
                textAlignment: textAlignment(
                    overrides["OVERLAY_TEXT_ALIGNMENT"],
                    defaultValue: overlayDefaults.textAlignment
                ),
                particleStyle: particleStyle(
                    overrides["OVERLAY_PARTICLE_STYLE"],
                    defaultValue: overlayDefaults.particleStyle
                ),
                particleBirthRate: nonNegativeDouble(
                    overrides["OVERLAY_PARTICLE_BIRTH_RATE"],
                    defaultValue: overlayDefaults.particleBirthRate
                ),
                particleLifetimeSeconds: positiveTimeInterval(
                    overrides["OVERLAY_PARTICLE_LIFETIME_SECONDS"],
                    defaultValue: overlayDefaults.particleLifetimeSeconds
                ),
                particleDurationSeconds: positiveTimeInterval(
                    overrides["OVERLAY_PARTICLE_DURATION_SECONDS"],
                    defaultValue: overlayDefaults.particleDurationSeconds
                ),
                particleVelocity: nonNegativeDouble(
                    overrides["OVERLAY_PARTICLE_VELOCITY"],
                    defaultValue: overlayDefaults.particleVelocity
                ),
                particleScale: positiveDouble(
                    overrides["OVERLAY_PARTICLE_SCALE"],
                    defaultValue: overlayDefaults.particleScale
                )
            )
        )
    }

    public static func parseEnv(_ contents: String) -> [String: String] {
        var values: [String: String] = [:]

        for rawLine in contents.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)

            guard !line.isEmpty, !line.hasPrefix("#"), let separatorIndex = line.firstIndex(of: "=") else {
                continue
            }

            let key = line[..<separatorIndex].trimmingCharacters(in: .whitespacesAndNewlines)
            let value = line[line.index(after: separatorIndex)...]
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))

            if !key.isEmpty {
                values[String(key)] = String(value)
            }
        }

        return values
    }

    private static func positiveTimeInterval(_ value: String?, defaultValue: TimeInterval) -> TimeInterval {
        positiveDouble(value, defaultValue: defaultValue)
    }

    private static func nonNegativeTimeInterval(_ value: String?, defaultValue: TimeInterval) -> TimeInterval {
        nonNegativeDouble(value, defaultValue: defaultValue)
    }

    private static func positiveDouble(_ value: String?, defaultValue: Double) -> Double {
        guard let value, let parsedValue = Double(value), parsedValue > 0 else {
            return defaultValue
        }

        return parsedValue
    }

    private static func nonNegativeDouble(_ value: String?, defaultValue: Double) -> Double {
        guard let value, let parsedValue = Double(value), parsedValue >= 0 else {
            return defaultValue
        }

        return parsedValue
    }

    private static func nonEmptyString(_ value: String?, defaultValue: String) -> String {
        guard let value else {
            return defaultValue
        }

        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue.isEmpty ? defaultValue : trimmedValue
    }

    private static func particleStyle(_ value: String?, defaultValue: String) -> String {
        let normalizedValue = nonEmptyString(value, defaultValue: defaultValue).lowercased()
        return ["reconstruct", "light", "off"].contains(normalizedValue) ? normalizedValue : defaultValue
    }

    private static func overlayTheme(_ value: String?, defaultValue: String) -> String {
        let normalizedValue = nonEmptyString(value, defaultValue: defaultValue).lowercased()
        return ["dark_neon"].contains(normalizedValue) ? normalizedValue : defaultValue
    }

    private static func textAlignment(_ value: String?, defaultValue: String) -> String {
        let normalizedValue = nonEmptyString(value, defaultValue: defaultValue).lowercased()
        return ["center"].contains(normalizedValue) ? normalizedValue : defaultValue
    }
}
