import Foundation

public struct AppConfiguration: Equatable {
    public struct HealthReminderConfiguration: Equatable {
        public let id: String
        public let title: String
        public let body: String
        public let interval: TimeInterval
        public let isEnabled: Bool

        public init(
            id: String,
            title: String,
            body: String,
            interval: TimeInterval,
            isEnabled: Bool
        ) {
            self.id = id
            self.title = title
            self.body = body
            self.interval = interval
            self.isEnabled = isEnabled
        }
    }

    public struct Overlay: Equatable {
        public let displaySeconds: TimeInterval
        public let fadeInSeconds: TimeInterval
        public let fadeOutSeconds: TimeInterval
        public let backdropStyle: String
        public let backdropOpacity: Double
        public let width: Double
        public let height: Double
        public let theme: String
        public let textAlignment: String
        public let textStyle: String
        public let textSize: String
        public let position: String
        public let verticalOffsetRatio: Double
        public let particleStyle: String
        public let particleCount: Int
        public let particleCanvasPadding: Double
        public let particleBirthRate: Double
        public let particleLifetimeSeconds: TimeInterval
        public let particleDurationSeconds: TimeInterval
        public let particleVelocity: Double
        public let particleScale: Double

        public init(
            displaySeconds: TimeInterval,
            fadeInSeconds: TimeInterval,
            fadeOutSeconds: TimeInterval,
            backdropStyle: String,
            backdropOpacity: Double,
            width: Double,
            height: Double,
            theme: String,
            textAlignment: String,
            textStyle: String,
            textSize: String,
            position: String,
            verticalOffsetRatio: Double,
            particleStyle: String,
            particleCount: Int,
            particleCanvasPadding: Double,
            particleBirthRate: Double,
            particleLifetimeSeconds: TimeInterval,
            particleDurationSeconds: TimeInterval,
            particleVelocity: Double,
            particleScale: Double
        ) {
            self.displaySeconds = displaySeconds
            self.fadeInSeconds = fadeInSeconds
            self.fadeOutSeconds = fadeOutSeconds
            self.backdropStyle = backdropStyle
            self.backdropOpacity = backdropOpacity
            self.width = width
            self.height = height
            self.theme = theme
            self.textAlignment = textAlignment
            self.textStyle = textStyle
            self.textSize = textSize
            self.position = position
            self.verticalOffsetRatio = verticalOffsetRatio
            self.particleStyle = particleStyle
            self.particleCount = particleCount
            self.particleCanvasPadding = particleCanvasPadding
            self.particleBirthRate = particleBirthRate
            self.particleLifetimeSeconds = particleLifetimeSeconds
            self.particleDurationSeconds = particleDurationSeconds
            self.particleVelocity = particleVelocity
            self.particleScale = particleScale
        }
    }

    public struct About: Equatable {
        public let developerName: String
        public let websiteURL: String
        public let email: String
        public let githubURL: String
        public let communityURL: String
        public let feedbackURL: String

        public init(
            developerName: String,
            websiteURL: String,
            email: String,
            githubURL: String,
            communityURL: String,
            feedbackURL: String
        ) {
            self.developerName = developerName
            self.websiteURL = websiteURL
            self.email = email
            self.githubURL = githubURL
            self.communityURL = communityURL
            self.feedbackURL = feedbackURL
        }

        public static let defaults = About(
            developerName: "",
            websiteURL: "",
            email: "",
            githubURL: "",
            communityURL: "",
            feedbackURL: ""
        )
    }

    public let movementInterval: TimeInterval
    public let waterInterval: TimeInterval
    public let postureInterval: TimeInterval
    public let focusReminderInterval: TimeInterval
    public let idleThreshold: TimeInterval
    public let tickInterval: TimeInterval
    public let kanbanPath: String
    public let kanbanInboxSection: String
    public let healthRemindersEnabled: Bool
    public let healthReminderIDs: [String]
    public let healthReminders: [HealthReminderConfiguration]
    public let overlay: Overlay
    public let about: About

    public init(
        movementInterval: TimeInterval,
        waterInterval: TimeInterval,
        postureInterval: TimeInterval,
        focusReminderInterval: TimeInterval,
        idleThreshold: TimeInterval,
        tickInterval: TimeInterval,
        kanbanPath: String,
        kanbanInboxSection: String,
        overlay: Overlay,
        about: About = .defaults,
        healthRemindersEnabled: Bool = true,
        healthReminderIDs: [String]? = nil,
        healthReminders: [HealthReminderConfiguration]? = nil
    ) {
        self.movementInterval = movementInterval
        self.waterInterval = waterInterval
        self.postureInterval = postureInterval
        self.focusReminderInterval = focusReminderInterval
        self.idleThreshold = idleThreshold
        self.tickInterval = tickInterval
        self.kanbanPath = kanbanPath
        self.kanbanInboxSection = kanbanInboxSection
        self.healthRemindersEnabled = healthRemindersEnabled
        let resolvedHealthReminders = healthReminders ?? Self.defaultHealthReminders(
            movementInterval: movementInterval,
            waterInterval: waterInterval,
            postureInterval: postureInterval
        )
        self.healthReminders = resolvedHealthReminders
        self.healthReminderIDs = healthReminderIDs ?? resolvedHealthReminders.map(\.id)
        self.overlay = overlay
        self.about = about
    }

    public static let defaultKanbanPath = "/Users/ihrr/Library/Mobile Documents/iCloud~md~obsidian/Documents/起源之地/0x.Start/_Meta/Kanban.md"

    public static func defaultHealthReminders(
        movementInterval: TimeInterval = 30 * 60,
        waterInterval: TimeInterval = 60 * 60,
        postureInterval: TimeInterval = 90 * 60
    ) -> [HealthReminderConfiguration] {
        [
            HealthReminderConfiguration(
                id: "rest",
                title: "放松眼睛，活动一下",
                body: "看一下远处，站起来动一动。",
                interval: movementInterval,
                isEnabled: true
            ),
            HealthReminderConfiguration(
                id: "water",
                title: "喝水",
                body: "喝几口水，别等口渴了再喝。",
                interval: waterInterval,
                isEnabled: true
            ),
            HealthReminderConfiguration(
                id: "posture",
                title: "调整坐姿，放松肩颈",
                body: "坐直一点，转转脖子，活动一下肩膀。",
                interval: postureInterval,
                isEnabled: true
            ),
            HealthReminderConfiguration(
                id: "medicine",
                title: "吃药",
                body: "按计划吃药，别漏掉。",
                interval: 4 * 60 * 60,
                isEnabled: false
            )
        ]
    }

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
            backdropStyle: "off",
            backdropOpacity: 0.72,
            width: 420,
            height: 132,
            theme: "dark_particle",
            textAlignment: "center",
            textStyle: "classic",
            textSize: "medium",
            position: "upper_center",
            verticalOffsetRatio: 0.18,
            particleStyle: "reconstruct",
            particleCount: 140,
            particleCanvasPadding: 220,
            particleBirthRate: 72,
            particleLifetimeSeconds: 1.1,
            particleDurationSeconds: 0.85,
            particleVelocity: 52,
            particleScale: 0.03
        ),
        about: .defaults
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
        let defaultHealthReminders = Dictionary(
            uniqueKeysWithValues: defaults.healthReminders.map { ($0.id, $0) }
        )
        let healthReminderIDs = healthReminderIDs(
            overrides["HEALTH_REMINDER_IDS"],
            defaultValue: defaults.healthReminderIDs
        )
        let healthReminders = healthReminderIDs.map { id in
            healthReminderConfiguration(
                id: id,
                overrides: overrides,
                defaultValue: defaultHealthReminders[id] ?? defaultCustomHealthReminder(id: id)
            )
        }
        let healthReminderByID = Dictionary(uniqueKeysWithValues: healthReminders.map { ($0.id, $0) })

        return AppConfiguration(
            movementInterval: healthReminderByID["rest"]?.interval ?? defaults.movementInterval,
            waterInterval: healthReminderByID["water"]?.interval ?? defaults.waterInterval,
            postureInterval: healthReminderByID["posture"]?.interval ?? defaults.postureInterval,
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
            kanbanInboxSection: overrides.keys.contains("KANBAN_INBOX_SECTION")
                ? trimmedString(overrides["KANBAN_INBOX_SECTION"])
                : defaults.kanbanInboxSection,
            overlay: Overlay(
                displaySeconds: boundedDouble(
                    overrides["OVERLAY_DISPLAY_SECONDS"],
                    defaultValue: overlayDefaults.displaySeconds,
                    minimum: 2,
                    maximum: 12
                ),
                fadeInSeconds: nonNegativeTimeInterval(
                    overrides["OVERLAY_FADE_IN_SECONDS"],
                    defaultValue: overlayDefaults.fadeInSeconds
                ),
                fadeOutSeconds: nonNegativeTimeInterval(
                    overrides["OVERLAY_FADE_OUT_SECONDS"],
                    defaultValue: overlayDefaults.fadeOutSeconds
                ),
                backdropStyle: backdropStyle(
                    overrides["OVERLAY_BACKDROP_STYLE"],
                    defaultValue: overlayDefaults.backdropStyle
                ),
                backdropOpacity: boundedDouble(
                    overrides["OVERLAY_BACKDROP_OPACITY"],
                    defaultValue: overlayDefaults.backdropOpacity,
                    minimum: 0.2,
                    maximum: 0.9
                ),
                width: positiveDouble(overrides["OVERLAY_WIDTH"], defaultValue: overlayDefaults.width),
                height: positiveDouble(overrides["OVERLAY_HEIGHT"], defaultValue: overlayDefaults.height),
                theme: overlayTheme(overrides["OVERLAY_THEME"], defaultValue: overlayDefaults.theme),
                textAlignment: textAlignment(
                    overrides["OVERLAY_TEXT_ALIGNMENT"],
                    defaultValue: overlayDefaults.textAlignment
                ),
                textStyle: textStyle(
                    overrides["OVERLAY_TEXT_STYLE"],
                    defaultValue: overlayDefaults.textStyle
                ),
                textSize: textSize(
                    overrides["OVERLAY_TEXT_SIZE"],
                    defaultValue: overlayDefaults.textSize
                ),
                position: overlayPosition(
                    overrides["OVERLAY_POSITION"],
                    defaultValue: overlayDefaults.position
                ),
                verticalOffsetRatio: boundedDouble(
                    overrides["OVERLAY_VERTICAL_OFFSET_RATIO"],
                    defaultValue: overlayDefaults.verticalOffsetRatio,
                    minimum: 0,
                    maximum: 0.32
                ),
                particleStyle: particleStyle(
                    overrides["OVERLAY_PARTICLE_STYLE"],
                    defaultValue: overlayDefaults.particleStyle
                ),
                particleCount: boundedInt(
                    overrides["OVERLAY_PARTICLE_COUNT"],
                    defaultValue: overlayDefaults.particleCount,
                    minimum: 40,
                    maximum: 260
                ),
                particleCanvasPadding: boundedDouble(
                    overrides["OVERLAY_PARTICLE_CANVAS_PADDING"],
                    defaultValue: overlayDefaults.particleCanvasPadding,
                    minimum: 40,
                    maximum: 280
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
            ),
            about: About(
                developerName: trimmedString(overrides["ABOUT_DEVELOPER_NAME"]),
                websiteURL: trimmedString(overrides["ABOUT_WEBSITE_URL"]),
                email: trimmedString(overrides["ABOUT_EMAIL"]),
                githubURL: trimmedString(overrides["ABOUT_GITHUB_URL"]),
                communityURL: trimmedString(overrides["ABOUT_COMMUNITY_URL"]),
                feedbackURL: trimmedString(overrides["ABOUT_FEEDBACK_URL"])
            ),
            healthRemindersEnabled: boolean(
                overrides["HEALTH_REMINDERS_ENABLED"],
                defaultValue: defaults.healthRemindersEnabled
            ),
            healthReminderIDs: healthReminderIDs,
            healthReminders: healthReminders
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

    private static func firstPositiveTimeInterval(
        _ values: [String?],
        defaultValue: TimeInterval
    ) -> TimeInterval {
        for value in values {
            guard let value, let parsedValue = Double(value), parsedValue > 0 else {
                continue
            }

            return parsedValue
        }

        return defaultValue
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

    private static func boundedDouble(
        _ value: String?,
        defaultValue: Double,
        minimum: Double,
        maximum: Double
    ) -> Double {
        guard let value, let parsedValue = Double(value), parsedValue >= minimum, parsedValue <= maximum else {
            return defaultValue
        }

        return parsedValue
    }

    private static func boundedInt(
        _ value: String?,
        defaultValue: Int,
        minimum: Int,
        maximum: Int
    ) -> Int {
        guard let value, let parsedValue = Int(value), parsedValue >= minimum, parsedValue <= maximum else {
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

    private static func trimmedString(_ value: String?) -> String {
        value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private static func boolean(_ value: String?, defaultValue: Bool) -> Bool {
        guard let value else {
            return defaultValue
        }

        switch value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "true", "1", "yes", "y", "on":
            return true
        case "false", "0", "no", "n", "off":
            return false
        default:
            return defaultValue
        }
    }

    private static func healthReminderConfiguration(
        id: String,
        overrides: [String: String],
        defaultValue: HealthReminderConfiguration
    ) -> HealthReminderConfiguration {
        let keyPrefix = "HEALTH_REMINDER_\(id.uppercased())"
        let intervalValues = [
            overrides["\(keyPrefix)_INTERVAL_SECONDS"],
            legacyHealthReminderIntervalValue(for: id, overrides: overrides)
        ]

        return HealthReminderConfiguration(
            id: id,
            title: nonEmptyString(overrides["\(keyPrefix)_TITLE"], defaultValue: defaultValue.title),
            body: nonEmptyString(overrides["\(keyPrefix)_BODY"], defaultValue: defaultValue.body),
            interval: firstPositiveTimeInterval(intervalValues, defaultValue: defaultValue.interval),
            isEnabled: boolean(overrides["\(keyPrefix)_ENABLED"], defaultValue: defaultValue.isEnabled)
        )
    }

    private static func healthReminderIDs(_ value: String?, defaultValue: [String]) -> [String] {
        guard let value else {
            return defaultValue
        }

        var seenIDs = Set<String>()
        let parsedIDs = value
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty && isSupportedHealthReminderID($0) }
            .filter { seenIDs.insert($0).inserted }

        return parsedIDs.isEmpty ? defaultValue : parsedIDs
    }

    private static func isSupportedHealthReminderID(_ id: String) -> Bool {
        id.range(of: #"^[a-z][a-z0-9_]*$"#, options: .regularExpression) != nil
    }

    private static func legacyHealthReminderIntervalValue(
        for id: String,
        overrides: [String: String]
    ) -> String? {
        switch id {
        case "rest":
            return overrides["HEALTH_MOVEMENT_INTERVAL_SECONDS"]
        case "water":
            return overrides["HEALTH_WATER_INTERVAL_SECONDS"]
        case "posture":
            return overrides["HEALTH_POSTURE_INTERVAL_SECONDS"]
        default:
            return nil
        }
    }

    private static func defaultCustomHealthReminder(id: String) -> HealthReminderConfiguration {
        HealthReminderConfiguration(
            id: id,
            title: "自定义提醒",
            body: "写下你想提醒自己的事。",
            interval: 60 * 60,
            isEnabled: true
        )
    }

    private static func particleStyle(_ value: String?, defaultValue: String) -> String {
        let normalizedValue = nonEmptyString(value, defaultValue: defaultValue).lowercased()
        return ["reconstruct", "light", "off"].contains(normalizedValue) ? normalizedValue : defaultValue
    }

    private static func backdropStyle(_ value: String?, defaultValue: String) -> String {
        let normalizedValue = nonEmptyString(value, defaultValue: defaultValue).lowercased()
        return ["off", "dim", "dim_glow"].contains(normalizedValue) ? normalizedValue : defaultValue
    }

    private static func overlayTheme(_ value: String?, defaultValue: String) -> String {
        let normalizedValue = nonEmptyString(value, defaultValue: defaultValue).lowercased()

        if normalizedValue == "dark_neon" {
            return "dark_particle"
        }

        return ["dark_particle", "light_particle"].contains(normalizedValue) ? normalizedValue : defaultValue
    }

    private static func textAlignment(_ value: String?, defaultValue: String) -> String {
        let normalizedValue = nonEmptyString(value, defaultValue: defaultValue).lowercased()
        return ["center"].contains(normalizedValue) ? normalizedValue : defaultValue
    }

    private static func textStyle(_ value: String?, defaultValue: String) -> String {
        let normalizedValue = nonEmptyString(value, defaultValue: defaultValue).lowercased()
        return ["classic", "prism", "aurora", "warm"].contains(normalizedValue) ? normalizedValue : defaultValue
    }

    private static func textSize(_ value: String?, defaultValue: String) -> String {
        let normalizedValue = nonEmptyString(value, defaultValue: defaultValue).lowercased()
        return ["small", "medium", "large"].contains(normalizedValue) ? normalizedValue : defaultValue
    }

    private static func overlayPosition(_ value: String?, defaultValue: String) -> String {
        let normalizedValue = nonEmptyString(value, defaultValue: defaultValue).lowercased()
        return ["upper_center", "center"].contains(normalizedValue) ? normalizedValue : defaultValue
    }
}
