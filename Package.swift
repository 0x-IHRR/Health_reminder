// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "HealthReminder",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        .package(path: "Vendor/Vortex")
    ],
    targets: [
        .target(
            name: "HealthReminderCore",
            path: "Sources/HealthReminderCore"
        ),
        .executableTarget(
            name: "HealthReminder",
            dependencies: [
                "HealthReminderCore",
                .product(name: "Vortex", package: "Vortex")
            ],
            path: "Sources/HealthReminder",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "HealthReminderCoreTests",
            dependencies: ["HealthReminderCore"],
            path: "Tests/HealthReminderCoreTests"
        )
    ],
    swiftLanguageModes: [.v5]
)
