// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "HealthReminder",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .target(
            name: "HealthReminderCore",
            path: "Sources/HealthReminderCore"
        ),
        .executableTarget(
            name: "HealthReminder",
            dependencies: ["HealthReminderCore"],
            path: "Sources/HealthReminder"
        ),
        .testTarget(
            name: "HealthReminderCoreTests",
            dependencies: ["HealthReminderCore"],
            path: "Tests/HealthReminderCoreTests"
        )
    ],
    swiftLanguageModes: [.v5]
)
