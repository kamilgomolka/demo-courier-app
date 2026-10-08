// swift-tools-version: 6.2
import PackageDescription

let strictSettings: [SwiftSetting] = [
    .strictMemorySafety(),
    .enableUpcomingFeature("ExistentialAny"),
    .enableUpcomingFeature("InternalImportsByDefault"),
    .enableUpcomingFeature("MemberImportVisibility"),
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
    .enableUpcomingFeature("InferIsolatedConformances"),
]

let mainActorSettings = strictSettings + [.defaultIsolation(MainActor.self)]

func target(
    _ name: String,
    dependencies: [Target.Dependency] = [],
    resources: [Resource] = [],
    isolatedToMainActor: Bool = false
) -> Target {
    .target(
        name: name,
        dependencies: dependencies,
        resources: resources,
        swiftSettings: isolatedToMainActor ? mainActorSettings : strictSettings
    )
}

func testTarget(
    _ name: String,
    dependencies: [Target.Dependency],
    resources: [Resource] = [],
    isolatedToMainActor: Bool = false
) -> Target {
    .testTarget(
        name: name,
        dependencies: dependencies,
        resources: resources,
        swiftSettings: isolatedToMainActor ? mainActorSettings : strictSettings
    )
}

let package = Package(
    name: "CourierModules",
    defaultLocalization: "en",
    platforms: [.iOS(.v26)],
    products: [
        .library(name: "AppNavigation", targets: ["AppNavigation"])
    ],
    targets: [
        target("Domain"),
        target("DomainTestSupport", dependencies: ["Domain"]),
        target("DesignSystem", resources: [.process("Resources")], isolatedToMainActor: true),
        target("LocalStorage", dependencies: ["Domain"]),
        target("SyncEngine", dependencies: ["Domain"], resources: [.process("Resources")]),
        target(
            "FeatureDashboard",
            dependencies: ["Domain", "DesignSystem"],
            resources: [.process("Resources")],
            isolatedToMainActor: true
        ),
        target(
            "FeatureDelivery",
            dependencies: ["Domain", "DesignSystem"],
            resources: [.process("Resources")],
            isolatedToMainActor: true
        ),
        target(
            "FeatureHistory",
            dependencies: ["Domain", "DesignSystem"],
            resources: [.process("Resources")],
            isolatedToMainActor: true
        ),
        target(
            "FeatureSettings",
            dependencies: ["Domain", "DesignSystem"],
            resources: [.process("Resources")],
            isolatedToMainActor: true
        ),
        target(
            "AppNavigation",
            dependencies: [
                "Domain", "DesignSystem", "LocalStorage", "SyncEngine",
                "FeatureDashboard", "FeatureDelivery", "FeatureHistory", "FeatureSettings",
            ],
            resources: [.process("Resources")],
            isolatedToMainActor: true
        ),
        testTarget("DomainTests", dependencies: ["Domain", "DomainTestSupport"]),
        testTarget("DesignSystemTests", dependencies: ["DesignSystem"], isolatedToMainActor: true),
        testTarget(
            "FeatureDashboardTests",
            dependencies: ["FeatureDashboard", "Domain", "DomainTestSupport"],
            isolatedToMainActor: true
        ),
        testTarget(
            "FeatureDeliveryTests",
            dependencies: ["FeatureDelivery", "Domain", "DomainTestSupport"],
            isolatedToMainActor: true
        ),
        testTarget(
            "FeatureHistoryTests",
            dependencies: ["FeatureHistory", "Domain", "DomainTestSupport"],
            isolatedToMainActor: true
        ),
        testTarget(
            "FeatureSettingsTests",
            dependencies: ["FeatureSettings", "Domain", "DomainTestSupport"],
            isolatedToMainActor: true
        ),
        testTarget("LocalStorageTests", dependencies: ["LocalStorage", "Domain", "DomainTestSupport"]),
        testTarget("SyncEngineTests", dependencies: ["SyncEngine", "LocalStorage", "Domain", "DomainTestSupport"]),
    ]
)
