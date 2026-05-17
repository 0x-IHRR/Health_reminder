import XCTest
@testable import HealthReminderCore

final class AppConfigurationTests: XCTestCase {
    func testUsesDefaultsWhenOverridesAreEmpty() {
        let configuration = AppConfiguration.load(overrides: [:])

        XCTAssertEqual(configuration, .defaults)
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
            OVERLAY_DISPLAY_SECONDS=3
            OVERLAY_FADE_IN_SECONDS=0.2
            OVERLAY_FADE_OUT_SECONDS=0.4
            OVERLAY_WIDTH=500
            OVERLAY_HEIGHT=150
            OVERLAY_THEME=dark_neon
            OVERLAY_TEXT_ALIGNMENT=center
            OVERLAY_PARTICLE_STYLE=reconstruct
            OVERLAY_PARTICLE_BIRTH_RATE=12
            OVERLAY_PARTICLE_LIFETIME_SECONDS=0.7
            OVERLAY_PARTICLE_DURATION_SECONDS=0.5
            OVERLAY_PARTICLE_VELOCITY=24
            OVERLAY_PARTICLE_SCALE=0.02
            """
        )

        XCTAssertEqual(configuration.movementInterval, 1200)
        XCTAssertEqual(configuration.waterInterval, 2400)
        XCTAssertEqual(configuration.postureInterval, 3600)
        XCTAssertEqual(configuration.focusReminderInterval, 90)
        XCTAssertEqual(configuration.idleThreshold, 45)
        XCTAssertEqual(configuration.tickInterval, 2)
        XCTAssertEqual(configuration.kanbanPath, "/tmp/Kanban.md")
        XCTAssertEqual(configuration.kanbanInboxSection, "Inbox")
        XCTAssertEqual(configuration.overlay.displaySeconds, 3)
        XCTAssertEqual(configuration.overlay.fadeInSeconds, 0.2)
        XCTAssertEqual(configuration.overlay.fadeOutSeconds, 0.4)
        XCTAssertEqual(configuration.overlay.width, 500)
        XCTAssertEqual(configuration.overlay.height, 150)
        XCTAssertEqual(configuration.overlay.theme, "dark_neon")
        XCTAssertEqual(configuration.overlay.textAlignment, "center")
        XCTAssertEqual(configuration.overlay.particleStyle, "reconstruct")
        XCTAssertEqual(configuration.overlay.particleBirthRate, 12)
        XCTAssertEqual(configuration.overlay.particleLifetimeSeconds, 0.7)
        XCTAssertEqual(configuration.overlay.particleDurationSeconds, 0.5)
        XCTAssertEqual(configuration.overlay.particleVelocity, 24)
        XCTAssertEqual(configuration.overlay.particleScale, 0.02)
    }

    func testInvalidValuesFallBackToDefaults() {
        let configuration = AppConfiguration.load(
            envContents: """
            FOCUS_REMINDER_INTERVAL_SECONDS=-1
            IDLE_THRESHOLD_SECONDS=abc
            TICK_INTERVAL_SECONDS=0
            KANBAN_PATH=
            KANBAN_INBOX_SECTION=
            OVERLAY_WIDTH=-20
            OVERLAY_FADE_IN_SECONDS=-0.2
            OVERLAY_THEME=white
            OVERLAY_TEXT_ALIGNMENT=left
            OVERLAY_PARTICLE_STYLE=heavy
            OVERLAY_PARTICLE_BIRTH_RATE=-3
            OVERLAY_PARTICLE_SCALE=0
            """
        )

        XCTAssertEqual(configuration.focusReminderInterval, AppConfiguration.defaults.focusReminderInterval)
        XCTAssertEqual(configuration.idleThreshold, AppConfiguration.defaults.idleThreshold)
        XCTAssertEqual(configuration.tickInterval, AppConfiguration.defaults.tickInterval)
        XCTAssertEqual(configuration.kanbanPath, AppConfiguration.defaults.kanbanPath)
        XCTAssertEqual(configuration.kanbanInboxSection, AppConfiguration.defaults.kanbanInboxSection)
        XCTAssertEqual(configuration.overlay.width, AppConfiguration.defaults.overlay.width)
        XCTAssertEqual(configuration.overlay.fadeInSeconds, AppConfiguration.defaults.overlay.fadeInSeconds)
        XCTAssertEqual(configuration.overlay.theme, AppConfiguration.defaults.overlay.theme)
        XCTAssertEqual(configuration.overlay.textAlignment, AppConfiguration.defaults.overlay.textAlignment)
        XCTAssertEqual(configuration.overlay.particleStyle, AppConfiguration.defaults.overlay.particleStyle)
        XCTAssertEqual(configuration.overlay.particleBirthRate, AppConfiguration.defaults.overlay.particleBirthRate)
        XCTAssertEqual(configuration.overlay.particleScale, AppConfiguration.defaults.overlay.particleScale)
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
}
