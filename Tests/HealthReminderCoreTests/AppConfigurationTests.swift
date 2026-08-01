import XCTest
@testable import HealthReminderCore

final class AppConfigurationTests: XCTestCase {
    func testUsesDefaultsWhenOverridesAreEmpty() {
        let configuration = AppConfiguration.load(overrides: [:])

        XCTAssertEqual(configuration, .defaults)
    }

    func testNewInstallationOverlayDefaultsFavorHighAttentionPresentation() {
        let overlay = AppConfiguration.defaults.overlay

        XCTAssertEqual(overlay.displaySeconds, 4)
        XCTAssertEqual(overlay.backdropStyle, "dim_glow")
        XCTAssertEqual(overlay.backdropOpacity, 0.8)
        XCTAssertEqual(overlay.width, 640)
        XCTAssertEqual(overlay.height, 200)
        XCTAssertEqual(overlay.theme, "alert_yellow")
        XCTAssertEqual(overlay.textSize, "large")
        XCTAssertEqual(overlay.position, "upper_center")
        XCTAssertEqual(overlay.verticalOffsetRatio, 0.24)
    }

    func testLoadsSupportedOverridesFromEnvContents() {
        let configuration = AppConfiguration.load(
            envContents: """
            # Local HealthReminder config
            HEALTH_MOVEMENT_INTERVAL_SECONDS=1200
            HEALTH_WATER_INTERVAL_SECONDS=2400
            HEALTH_POSTURE_INTERVAL_SECONDS=3600
            FOCUS_REMINDER_INTERVAL_SECONDS=90
            IDLE_THRESHOLD_SECONDS=45
            TICK_INTERVAL_SECONDS=2
            KANBAN_PATH=/tmp/Kanban.md
            KANBAN_INBOX_SECTION=Inbox
            HEALTH_REMINDER_COUNTING_MODE=input_active
            OVERLAY_DISPLAY_SECONDS=3
            OVERLAY_FADE_IN_SECONDS=0.2
            OVERLAY_FADE_OUT_SECONDS=0.4
            OVERLAY_BACKDROP_STYLE=dim_glow
            OVERLAY_BACKDROP_OPACITY=0.8
            OVERLAY_WIDTH=500
            OVERLAY_HEIGHT=150
            OVERLAY_THEME=light_particle
            OVERLAY_TEXT_ALIGNMENT=center
            OVERLAY_TEXT_STYLE=warm
            OVERLAY_TEXT_SIZE=large
            OVERLAY_POSITION=upper_center
            OVERLAY_VERTICAL_OFFSET_RATIO=0.2
            OVERLAY_PARTICLE_STYLE=reconstruct
            OVERLAY_PARTICLE_COUNT=144
            OVERLAY_PARTICLE_CANVAS_PADDING=160
            OVERLAY_PARTICLE_BIRTH_RATE=12
            OVERLAY_PARTICLE_LIFETIME_SECONDS=0.7
            OVERLAY_PARTICLE_DURATION_SECONDS=0.5
            OVERLAY_PARTICLE_VELOCITY=24
            OVERLAY_PARTICLE_SCALE=0.02
            ABOUT_DEVELOPER_NAME=Jane
            ABOUT_WEBSITE_URL=https://example.com
            ABOUT_EMAIL=hi@example.com
            ABOUT_GITHUB_URL=https://github.com/example
            ABOUT_COMMUNITY_URL=https://example.com/community
            ABOUT_FEEDBACK_URL=mailto:hi@example.com
            """
        )

        XCTAssertEqual(configuration.movementInterval, 1200)
        XCTAssertEqual(configuration.waterInterval, 2400)
        XCTAssertEqual(configuration.postureInterval, 3600)
        XCTAssertEqual(configuration.healthRemindersEnabled, true)
        XCTAssertEqual(configuration.healthReminderCountingMode, "input_active")
        XCTAssertEqual(configuration.healthReminderIDs, ["rest", "water", "posture", "medicine"])
        XCTAssertEqual(configuration.healthReminders.first { $0.id == "rest" }?.interval, 1200)
        XCTAssertEqual(configuration.healthReminders.first { $0.id == "water" }?.interval, 2400)
        XCTAssertEqual(configuration.healthReminders.first { $0.id == "posture" }?.interval, 3600)
        XCTAssertEqual(configuration.focusReminderInterval, 90)
        XCTAssertEqual(configuration.idleThreshold, 45)
        XCTAssertEqual(configuration.tickInterval, 2)
        XCTAssertEqual(configuration.kanbanPath, "/tmp/Kanban.md")
        XCTAssertEqual(configuration.kanbanInboxSection, "Inbox")
        XCTAssertEqual(configuration.overlay.displaySeconds, 3)
        XCTAssertEqual(configuration.overlay.fadeInSeconds, 0.2)
        XCTAssertEqual(configuration.overlay.fadeOutSeconds, 0.4)
        XCTAssertEqual(configuration.overlay.backdropStyle, "dim_glow")
        XCTAssertEqual(configuration.overlay.backdropOpacity, 0.8)
        XCTAssertEqual(configuration.overlay.width, 500)
        XCTAssertEqual(configuration.overlay.height, 150)
        XCTAssertEqual(configuration.overlay.theme, "light_particle")
        XCTAssertEqual(configuration.overlay.textAlignment, "center")
        XCTAssertEqual(configuration.overlay.textStyle, "warm")
        XCTAssertEqual(configuration.overlay.textSize, "large")
        XCTAssertEqual(configuration.overlay.position, "upper_center")
        XCTAssertEqual(configuration.overlay.verticalOffsetRatio, 0.2)
        XCTAssertEqual(configuration.overlay.particleStyle, "reconstruct")
        XCTAssertEqual(configuration.overlay.particleCount, 144)
        XCTAssertEqual(configuration.overlay.particleCanvasPadding, 160)
        XCTAssertEqual(configuration.overlay.particleBirthRate, 12)
        XCTAssertEqual(configuration.overlay.particleLifetimeSeconds, 0.7)
        XCTAssertEqual(configuration.overlay.particleDurationSeconds, 0.5)
        XCTAssertEqual(configuration.overlay.particleVelocity, 24)
        XCTAssertEqual(configuration.overlay.particleScale, 0.02)
        XCTAssertEqual(configuration.about.developerName, "Jane")
        XCTAssertEqual(configuration.about.websiteURL, "https://example.com")
        XCTAssertEqual(configuration.about.email, "hi@example.com")
        XCTAssertEqual(configuration.about.githubURL, "https://github.com/example")
        XCTAssertEqual(configuration.about.communityURL, "https://example.com/community")
        XCTAssertEqual(configuration.about.feedbackURL, "mailto:hi@example.com")
    }

    func testLoadsCustomHealthReminderSlotsFromNewEnvKeys() {
        let configuration = AppConfiguration.load(
            envContents: """
            HEALTH_REMINDER_REST_ENABLED=false
            HEALTH_REMINDER_REST_TITLE=休息一会
            HEALTH_REMINDER_REST_BODY=离开屏幕走两步。
            HEALTH_REMINDER_REST_INTERVAL_SECONDS=600
            HEALTH_REMINDER_WATER_ENABLED=true
            HEALTH_REMINDER_WATER_TITLE=补水
            HEALTH_REMINDER_WATER_BODY=喝半杯水。
            HEALTH_REMINDER_WATER_INTERVAL_SECONDS=1200
            HEALTH_REMINDER_POSTURE_ENABLED=false
            HEALTH_REMINDER_POSTURE_TITLE=坐姿检查
            HEALTH_REMINDER_POSTURE_BODY=放松肩颈。
            HEALTH_REMINDER_POSTURE_INTERVAL_SECONDS=1800
            HEALTH_REMINDER_MEDICINE_ENABLED=true
            HEALTH_REMINDER_MEDICINE_TITLE=吃药
            HEALTH_REMINDER_MEDICINE_BODY=按计划吃药。
            HEALTH_REMINDER_MEDICINE_INTERVAL_SECONDS=14400
            """
        )

        let remindersByID = Dictionary(uniqueKeysWithValues: configuration.healthReminders.map { ($0.id, $0) })

        XCTAssertEqual(remindersByID["rest"]?.isEnabled, false)
        XCTAssertEqual(remindersByID["rest"]?.title, "休息一会")
        XCTAssertEqual(remindersByID["rest"]?.body, "离开屏幕走两步。")
        XCTAssertEqual(remindersByID["rest"]?.interval, 600)
        XCTAssertEqual(configuration.movementInterval, 600)

        XCTAssertEqual(remindersByID["water"]?.isEnabled, true)
        XCTAssertEqual(remindersByID["water"]?.title, "补水")
        XCTAssertEqual(remindersByID["water"]?.body, "喝半杯水。")
        XCTAssertEqual(remindersByID["water"]?.interval, 1200)
        XCTAssertEqual(configuration.waterInterval, 1200)

        XCTAssertEqual(remindersByID["posture"]?.isEnabled, false)
        XCTAssertEqual(remindersByID["posture"]?.title, "坐姿检查")
        XCTAssertEqual(remindersByID["posture"]?.body, "放松肩颈。")
        XCTAssertEqual(remindersByID["posture"]?.interval, 1800)
        XCTAssertEqual(configuration.postureInterval, 1800)

        XCTAssertEqual(remindersByID["medicine"]?.isEnabled, true)
        XCTAssertEqual(remindersByID["medicine"]?.interval, 14400)
    }

    func testLoadsOrderedCustomHealthReminderListFromIDs() {
        let configuration = AppConfiguration.load(
            envContents: """
            HEALTH_REMINDERS_ENABLED=false
            HEALTH_REMINDER_IDS=water,custom_1,rest
            HEALTH_REMINDER_CUSTOM_1_ENABLED=true
            HEALTH_REMINDER_CUSTOM_1_TITLE=滴眼药水
            HEALTH_REMINDER_CUSTOM_1_BODY=按计划滴眼药水。
            HEALTH_REMINDER_CUSTOM_1_INTERVAL_SECONDS=2700
            """
        )

        XCTAssertEqual(configuration.healthRemindersEnabled, false)
        XCTAssertEqual(configuration.healthReminderIDs, ["water", "custom_1", "rest"])
        XCTAssertEqual(configuration.healthReminders.map(\.id), ["water", "custom_1", "rest"])

        let customReminder = configuration.healthReminders.first { $0.id == "custom_1" }
        XCTAssertEqual(customReminder?.title, "滴眼药水")
        XCTAssertEqual(customReminder?.body, "按计划滴眼药水。")
        XCTAssertEqual(customReminder?.interval, 2700)
        XCTAssertEqual(customReminder?.isEnabled, true)
    }

    func testInvalidHealthReminderIDsFallBackToDefaultList() {
        let configuration = AppConfiguration.load(envContents: "HEALTH_REMINDER_IDS=,???")

        XCTAssertEqual(configuration.healthReminderIDs, AppConfiguration.defaults.healthReminderIDs)
        XCTAssertEqual(configuration.healthReminders, AppConfiguration.defaults.healthReminders)
    }

    func testMedicineHealthReminderIsDisabledByDefault() {
        let configuration = AppConfiguration.load(overrides: [:])
        let medicine = configuration.healthReminders.first { $0.id == "medicine" }

        XCTAssertEqual(medicine?.isEnabled, false)
        XCTAssertEqual(medicine?.title, "吃药")
    }

    func testHealthReminderCountingModeDefaultsToScreenAwake() {
        let configuration = AppConfiguration.load(overrides: [:])

        XCTAssertEqual(configuration.healthReminderCountingMode, "screen_awake")
    }

    func testSupportedHealthReminderCountingModesAreAccepted() {
        for mode in ["screen_awake", "input_active"] {
            let configuration = AppConfiguration.load(envContents: "HEALTH_REMINDER_COUNTING_MODE=\(mode)")

            XCTAssertEqual(configuration.healthReminderCountingMode, mode)
        }
    }

    func testInvalidValuesFallBackToDefaults() {
        let configuration = AppConfiguration.load(
            envContents: """
            FOCUS_REMINDER_INTERVAL_SECONDS=-1
            IDLE_THRESHOLD_SECONDS=abc
            TICK_INTERVAL_SECONDS=0
            KANBAN_PATH=
            KANBAN_INBOX_SECTION=
            HEALTH_REMINDER_COUNTING_MODE=wall_clock
            OVERLAY_WIDTH=-20
            OVERLAY_DISPLAY_SECONDS=1
            OVERLAY_FADE_IN_SECONDS=-0.2
            OVERLAY_BACKDROP_STYLE=blackout
            OVERLAY_BACKDROP_OPACITY=1.2
            OVERLAY_THEME=white
            OVERLAY_TEXT_ALIGNMENT=left
            OVERLAY_TEXT_STYLE=rainbow
            OVERLAY_TEXT_SIZE=huge
            OVERLAY_POSITION=bottom
            OVERLAY_VERTICAL_OFFSET_RATIO=2
            OVERLAY_PARTICLE_STYLE=heavy
            OVERLAY_PARTICLE_COUNT=999
            OVERLAY_PARTICLE_CANVAS_PADDING=8
            OVERLAY_PARTICLE_BIRTH_RATE=-3
            OVERLAY_PARTICLE_SCALE=0
            """
        )

        XCTAssertEqual(configuration.focusReminderInterval, AppConfiguration.defaults.focusReminderInterval)
        XCTAssertEqual(configuration.idleThreshold, AppConfiguration.defaults.idleThreshold)
        XCTAssertEqual(configuration.tickInterval, AppConfiguration.defaults.tickInterval)
        XCTAssertEqual(configuration.kanbanPath, AppConfiguration.defaults.kanbanPath)
        XCTAssertEqual(configuration.kanbanInboxSection, "")
        XCTAssertEqual(configuration.healthReminderCountingMode, AppConfiguration.defaults.healthReminderCountingMode)
        XCTAssertEqual(configuration.overlay.width, AppConfiguration.defaults.overlay.width)
        XCTAssertEqual(configuration.overlay.displaySeconds, AppConfiguration.defaults.overlay.displaySeconds)
        XCTAssertEqual(configuration.overlay.fadeInSeconds, AppConfiguration.defaults.overlay.fadeInSeconds)
        XCTAssertEqual(configuration.overlay.backdropStyle, AppConfiguration.defaults.overlay.backdropStyle)
        XCTAssertEqual(configuration.overlay.backdropOpacity, AppConfiguration.defaults.overlay.backdropOpacity)
        XCTAssertEqual(configuration.overlay.theme, AppConfiguration.defaults.overlay.theme)
        XCTAssertEqual(configuration.overlay.textAlignment, AppConfiguration.defaults.overlay.textAlignment)
        XCTAssertEqual(configuration.overlay.textStyle, AppConfiguration.defaults.overlay.textStyle)
        XCTAssertEqual(configuration.overlay.textSize, AppConfiguration.defaults.overlay.textSize)
        XCTAssertEqual(configuration.overlay.position, AppConfiguration.defaults.overlay.position)
        XCTAssertEqual(configuration.overlay.verticalOffsetRatio, AppConfiguration.defaults.overlay.verticalOffsetRatio)
        XCTAssertEqual(configuration.overlay.particleStyle, AppConfiguration.defaults.overlay.particleStyle)
        XCTAssertEqual(configuration.overlay.particleCount, AppConfiguration.defaults.overlay.particleCount)
        XCTAssertEqual(configuration.overlay.particleCanvasPadding, AppConfiguration.defaults.overlay.particleCanvasPadding)
        XCTAssertEqual(configuration.overlay.particleBirthRate, AppConfiguration.defaults.overlay.particleBirthRate)
        XCTAssertEqual(configuration.overlay.particleScale, AppConfiguration.defaults.overlay.particleScale)
        XCTAssertEqual(configuration.healthReminders, AppConfiguration.defaults.healthReminders)
    }

    func testMissingKanbanSectionUsesDefaultButExplicitEmptySectionIsKept() {
        XCTAssertEqual(
            AppConfiguration.load(overrides: [:]).kanbanInboxSection,
            AppConfiguration.defaults.kanbanInboxSection
        )
        XCTAssertEqual(
            AppConfiguration.load(envContents: "KANBAN_INBOX_SECTION=").kanbanInboxSection,
            ""
        )
    }

    func testInvalidHealthReminderValuesFallBackToDefaults() {
        let configuration = AppConfiguration.load(
            envContents: """
            HEALTH_REMINDER_WATER_ENABLED=maybe
            HEALTH_REMINDER_WATER_TITLE=
            HEALTH_REMINDER_WATER_BODY=
            HEALTH_REMINDER_WATER_INTERVAL_SECONDS=-20
            HEALTH_REMINDER_MEDICINE_ENABLED=maybe
            HEALTH_REMINDER_MEDICINE_INTERVAL_SECONDS=abc
            """
        )
        let remindersByID = Dictionary(uniqueKeysWithValues: configuration.healthReminders.map { ($0.id, $0) })

        XCTAssertEqual(remindersByID["water"], AppConfiguration.defaults.healthReminders.first { $0.id == "water" })
        XCTAssertEqual(remindersByID["medicine"], AppConfiguration.defaults.healthReminders.first { $0.id == "medicine" })
    }

    func testCustomHealthReminderInvalidIntervalFallsBackToOneHour() {
        let configuration = AppConfiguration.load(
            envContents: """
            HEALTH_REMINDER_IDS=custom_1
            HEALTH_REMINDER_CUSTOM_1_TITLE=拉伸
            HEALTH_REMINDER_CUSTOM_1_BODY=做一次拉伸。
            HEALTH_REMINDER_CUSTOM_1_INTERVAL_SECONDS=abc
            """
        )

        XCTAssertEqual(configuration.healthReminders.first?.id, "custom_1")
        XCTAssertEqual(configuration.healthReminders.first?.interval, 3600)
    }

    func testLegacyDarkNeonThemeMapsToDarkParticle() {
        let configuration = AppConfiguration.load(envContents: "OVERLAY_THEME=dark_neon")

        XCTAssertEqual(configuration.overlay.theme, "dark_particle")
    }

    func testSupportedOverlayThemesAreAccepted() {
        for theme in ["dark_particle", "light_particle", "alert_yellow"] {
            let configuration = AppConfiguration.load(envContents: "OVERLAY_THEME=\(theme)")

            XCTAssertEqual(configuration.overlay.theme, theme)
        }
    }

    func testSupportedOverlayTextStylesAreAccepted() {
        for style in ["classic", "prism", "aurora", "warm"] {
            let configuration = AppConfiguration.load(envContents: "OVERLAY_TEXT_STYLE=\(style)")

            XCTAssertEqual(configuration.overlay.textStyle, style)
        }
    }

    func testSupportedOverlayTextSizesAreAccepted() {
        for size in ["small", "medium", "large"] {
            let configuration = AppConfiguration.load(envContents: "OVERLAY_TEXT_SIZE=\(size)")

            XCTAssertEqual(configuration.overlay.textSize, size)
        }
    }

    func testSupportedOverlayBackdropStylesAreAccepted() {
        for style in ["off", "dim", "dim_glow"] {
            let configuration = AppConfiguration.load(envContents: "OVERLAY_BACKDROP_STYLE=\(style)")

            XCTAssertEqual(configuration.overlay.backdropStyle, style)
        }
    }

    func testParseEnvIgnoresCommentsEmptyLinesAndUnknownKeys() {
        let values = AppConfiguration.parseEnv(
            """
            # Comment

            FOCUS_REMINDER_INTERVAL_SECONDS = 20
            UNKNOWN_KEY=value
            QUOTED_VALUE="abc"
            """
        )

        XCTAssertEqual(values["FOCUS_REMINDER_INTERVAL_SECONDS"], "20")
        XCTAssertEqual(values["UNKNOWN_KEY"], "value")
        XCTAssertEqual(values["QUOTED_VALUE"], "abc")
    }

    func testEnvConfigurationWriterUpdatesOverlayKeysAndPreservesOtherValues() {
        let contents = EnvConfigurationWriter.mergedContents(
            existingContents: """
            # Local config
            FOCUS_REMINDER_INTERVAL_SECONDS=600
            OVERLAY_THEME=dark_particle
            UNKNOWN_KEY=keep-me
            """,
            updates: [
                "OVERLAY_THEME": "light_particle",
                "OVERLAY_TEXT_STYLE": "warm",
                "OVERLAY_TEXT_SIZE": "medium",
                "OVERLAY_DISPLAY_SECONDS": "6",
                "OVERLAY_BACKDROP_STYLE": "dim_glow",
                "OVERLAY_PARTICLE_STYLE": "off"
            ]
        )

        XCTAssertTrue(contents.contains("# Local config"))
        XCTAssertTrue(contents.contains("FOCUS_REMINDER_INTERVAL_SECONDS=600"))
        XCTAssertTrue(contents.contains("UNKNOWN_KEY=keep-me"))
        XCTAssertTrue(contents.contains("OVERLAY_THEME=light_particle"))
        XCTAssertTrue(contents.contains("OVERLAY_TEXT_STYLE=warm"))
        XCTAssertTrue(contents.contains("OVERLAY_TEXT_SIZE=medium"))
        XCTAssertTrue(contents.contains("OVERLAY_DISPLAY_SECONDS=6"))
        XCTAssertTrue(contents.contains("OVERLAY_BACKDROP_STYLE=dim_glow"))
        XCTAssertTrue(contents.contains("OVERLAY_PARTICLE_STYLE=off"))
        XCTAssertFalse(contents.contains("OVERLAY_THEME=dark_particle"))
    }

    func testEnvConfigurationWriterUpdatesHealthReminderKeysAndPreservesOtherValues() {
        let contents = EnvConfigurationWriter.mergedContents(
            existingContents: """
            # Local config
            FOCUS_REMINDER_INTERVAL_SECONDS=900
            HEALTH_REMINDER_WATER_TITLE=喝水
            HEALTH_REMINDER_WATER_INTERVAL_SECONDS=3600
            UNKNOWN_KEY=keep-me
            """,
            updates: [
                "HEALTH_REMINDER_WATER_ENABLED": "true",
                "HEALTH_REMINDER_IDS": "water,custom_1",
                "HEALTH_REMINDERS_ENABLED": "true",
                "HEALTH_REMINDER_COUNTING_MODE": "screen_awake",
                "HEALTH_REMINDER_WATER_TITLE": "补水",
                "HEALTH_REMINDER_WATER_BODY": "喝几口水。",
                "HEALTH_REMINDER_WATER_INTERVAL_SECONDS": "1200",
                "HEALTH_REMINDER_CUSTOM_1_ENABLED": "true",
                "HEALTH_REMINDER_CUSTOM_1_TITLE": "拉伸",
                "HEALTH_REMINDER_CUSTOM_1_BODY": "做一次拉伸。",
                "HEALTH_REMINDER_CUSTOM_1_INTERVAL_SECONDS": "1800"
            ]
        )

        XCTAssertTrue(contents.contains("# Local config"))
        XCTAssertTrue(contents.contains("FOCUS_REMINDER_INTERVAL_SECONDS=900"))
        XCTAssertTrue(contents.contains("UNKNOWN_KEY=keep-me"))
        XCTAssertTrue(contents.contains("HEALTH_REMINDERS_ENABLED=true"))
        XCTAssertTrue(contents.contains("HEALTH_REMINDER_COUNTING_MODE=screen_awake"))
        XCTAssertTrue(contents.contains("HEALTH_REMINDER_IDS=water,custom_1"))
        XCTAssertTrue(contents.contains("HEALTH_REMINDER_WATER_ENABLED=true"))
        XCTAssertTrue(contents.contains("HEALTH_REMINDER_WATER_TITLE=补水"))
        XCTAssertTrue(contents.contains("HEALTH_REMINDER_WATER_BODY=喝几口水。"))
        XCTAssertTrue(contents.contains("HEALTH_REMINDER_WATER_INTERVAL_SECONDS=1200"))
        XCTAssertTrue(contents.contains("HEALTH_REMINDER_CUSTOM_1_TITLE=拉伸"))
        XCTAssertTrue(contents.contains("HEALTH_REMINDER_CUSTOM_1_INTERVAL_SECONDS=1800"))
        XCTAssertFalse(contents.contains("HEALTH_REMINDER_WATER_TITLE=喝水"))
        XCTAssertFalse(contents.contains("HEALTH_REMINDER_WATER_INTERVAL_SECONDS=3600"))
    }

    func testEnvConfigurationWriterUpdatesKanbanAndAboutKeysAndPreservesOtherValues() {
        let contents = EnvConfigurationWriter.mergedContents(
            existingContents: """
            # Local config
            FOCUS_REMINDER_INTERVAL_SECONDS=900
            KANBAN_PATH=/old/Kanban.md
            ABOUT_DEVELOPER_NAME=Old
            UNKNOWN_KEY=keep-me
            """,
            updates: [
                "KANBAN_PATH": "/new/Kanban.md",
                "KANBAN_INBOX_SECTION": "",
                "ABOUT_DEVELOPER_NAME": "New",
                "ABOUT_WEBSITE_URL": "https://example.com",
                "ABOUT_EMAIL": "hi@example.com",
                "ABOUT_GITHUB_URL": "https://github.com/example",
                "ABOUT_COMMUNITY_URL": "",
                "ABOUT_FEEDBACK_URL": ""
            ]
        )

        XCTAssertTrue(contents.contains("# Local config"))
        XCTAssertTrue(contents.contains("FOCUS_REMINDER_INTERVAL_SECONDS=900"))
        XCTAssertTrue(contents.contains("UNKNOWN_KEY=keep-me"))
        XCTAssertTrue(contents.contains("KANBAN_PATH=/new/Kanban.md"))
        XCTAssertTrue(contents.contains("KANBAN_INBOX_SECTION="))
        XCTAssertTrue(contents.contains("ABOUT_DEVELOPER_NAME=New"))
        XCTAssertTrue(contents.contains("ABOUT_WEBSITE_URL=https://example.com"))
        XCTAssertTrue(contents.contains("ABOUT_EMAIL=hi@example.com"))
        XCTAssertFalse(contents.contains("KANBAN_PATH=/old/Kanban.md"))
        XCTAssertFalse(contents.contains("ABOUT_DEVELOPER_NAME=Old"))
    }
}
