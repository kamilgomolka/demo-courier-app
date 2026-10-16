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

enum Layer: String {
    case core = "Core"
    case features = "Features"
    case app = "App"
}

func target(
    _ name: String,
    layer: Layer,
    dependencies: [Target.Dependency] = [],
    resources: [Resource] = [],
    isolatedToMainActor: Bool = false
) -> Target {
    .target(
        name: name,
        dependencies: dependencies,
        path: "Sources/\(layer.rawValue)/\(name)",
        resources: resources,
        swiftSettings: isolatedToMainActor ? mainActorSettings : strictSettings
    )
}

func testTarget(
    _ name: String,
    layer: Layer,
    dependencies: [Target.Dependency],
    resources: [Resource] = [],
    isolatedToMainActor: Bool = false
) -> Target {
    .testTarget(
        name: name,
        dependencies: dependencies,
        path: "Tests/\(layer.rawValue)/\(name)",
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
        target("Domain", layer: .core),
        target("DomainTestSupport", layer: .core, dependencies: ["Domain"]),
        target("DesignSystem", layer: .core, resources: [.process("Resources")], isolatedToMainActor: true),
        target("LocalStorage", layer: .core, dependencies: ["Domain"]),
        target("SyncEngine", layer: .core, dependencies: ["Domain"], resources: [.process("Resources")]),
        target(
            "FeatureDashboard",
            layer: .features,
            dependencies: [
                "Domain", "DesignSystem", "DomainTestSupport",
            ],
            resources: [.process("Resources")],
            isolatedToMainActor: true
        ),
        target(
            "FeatureDelivery",
            layer: .features,
            dependencies: [
                "Domain", "DesignSystem", "DomainTestSupport",
            ],
            resources: [.process("Resources")],
            isolatedToMainActor: true
        ),
        target(
            "FeatureHistory",
            layer: .features,
            dependencies: [
                "Domain", "DesignSystem", "DomainTestSupport",
            ],
            resources: [.process("Resources")],
            isolatedToMainActor: true
        ),
        target(
            "FeatureSettings",
            layer: .features,
            dependencies: [
                "Domain", "DesignSystem", "DomainTestSupport",
            ],
            resources: [.process("Resources")],
            isolatedToMainActor: true
        ),
        target(
            "AppNavigation",
            layer: .app,
            dependencies: [
                "Domain", "DesignSystem", "LocalStorage", "SyncEngine",
                "FeatureDashboard", "FeatureDelivery", "FeatureHistory", "FeatureSettings",
            ],
            resources: [.process("Resources")],
            isolatedToMainActor: true
        ),
        testTarget("DomainTests", layer: .core, dependencies: ["Domain", "DomainTestSupport"]),
        testTarget("DesignSystemTests", layer: .core, dependencies: ["DesignSystem"], isolatedToMainActor: true),
        testTarget(
            "LocalStorageTests",
            layer: .core,
            dependencies: ["LocalStorage", "Domain", "DomainTestSupport"]
        ),
        testTarget(
            "SyncEngineTests",
            layer: .core,
            dependencies: ["SyncEngine", "LocalStorage", "Domain", "DomainTestSupport"]
        ),
        testTarget(
            "FeatureDashboardTests",
            layer: .features,
            dependencies: ["FeatureDashboard", "Domain", "DomainTestSupport"],
            isolatedToMainActor: true
        ),
        testTarget(
            "FeatureDeliveryTests",
            layer: .features,
            dependencies: ["FeatureDelivery", "Domain", "DomainTestSupport"],
            isolatedToMainActor: true
        ),
        testTarget(
            "FeatureHistoryTests",
            layer: .features,
            dependencies: ["FeatureHistory", "Domain", "DomainTestSupport"],
            isolatedToMainActor: true
        ),
        testTarget(
            "FeatureSettingsTests",
            layer: .features,
            dependencies: ["FeatureSettings", "Domain", "DomainTestSupport"],
            isolatedToMainActor: true
        ),
    ]
)
