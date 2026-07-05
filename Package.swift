// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "PookiePayslip",
    platforms: [.iOS(.v26), .macOS(.v14)],
    products: [
        .library(name: "PookieStyle",          targets: ["PookieStyle"]),
        .library(name: "AppDomain",            targets: ["AppDomain"]),
        .library(name: "NavigationFeature",    targets: ["NavigationFeature"]),
        .library(name: "CalendarFeature",      targets: ["CalendarFeature"]),
        .library(name: "DayDetailFeature",     targets: ["DayDetailFeature"]),
        .library(name: "ReportInputFeature",   targets: ["ReportInputFeature"]),
        .library(name: "ReportResultFeature",  targets: ["ReportResultFeature"]),
        .library(name: "SalaryEditorFeature",  targets: ["SalaryEditorFeature"]),
        .library(name: "SettingsFeature",      targets: ["SettingsFeature"]),
        .library(name: "AppCore",              targets: ["AppCore"]),
    ],
    dependencies: [
        .package(url: "https://github.com/SwiftRex/SwiftRex.git",     branch: "main", traits: ["ReactiveConcurrency"]),
        .package(url: "https://github.com/luizmb/ReactiveConcurrency.git", from: "0.3.0"),
        .package(url: "https://github.com/luizmb/FP.git",            from: "1.13.0"),
        .package(url: "https://github.com/luizmb/NetworkTools.git",  from: "0.6.0"),
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing.git", from: "1.17.0"),
    ],
    targets: [

        // MARK: - Design tokens

        .target(
            name: "PookieStyle",
            dependencies: [],
            path: "Sources/PookieStyle"
        ),

        // MARK: - Shared domain types

        .target(
            name: "AppDomain",
            dependencies: [
                .product(name: "CoreFP",         package: "FP"),
                .product(name: "CoreFPOperators", package: "FP"),
                .product(name: "FPMacros",        package: "FP"),
            ],
            path: "Sources/AppDomain"
        ),

        // MARK: - Features

        .target(
            name: "NavigationFeature",
            dependencies: [
                "AppDomain",
                .product(name: "SwiftRex",              package: "SwiftRex"),
                .product(name: "SwiftRex.SwiftUI",      package: "SwiftRex"),
                .product(name: "SwiftRex.Architecture", package: "SwiftRex"),
                .product(name: "SwiftRex.Operators",    package: "SwiftRex"),
                .product(name: "CoreFP",                package: "FP"),
                .product(name: "CoreFPOperators",       package: "FP"),
                .product(name: "FPMacros",              package: "FP"),
                "PookieStyle",
            ],
            path: "Sources/NavigationFeature"
        ),

        .target(
            name: "CalendarFeature",
            dependencies: [
                "AppDomain",
                "PookieStyle",
                .product(name: "SwiftRex",              package: "SwiftRex"),
                .product(name: "SwiftRex.SwiftUI",      package: "SwiftRex"),
                .product(name: "SwiftRex.Architecture", package: "SwiftRex"),
                .product(name: "SwiftRex.Operators",    package: "SwiftRex"),
                .product(name: "SwiftRex.ReactiveConcurrency", package: "SwiftRex"),
                .product(name: "ReactiveConcurrency",   package: "ReactiveConcurrency"),
                .product(name: "CoreFP",                package: "FP"),
                .product(name: "CoreFPOperators",       package: "FP"),
                .product(name: "FPMacros",              package: "FP"),
                .product(name: "Core", package: "NetworkTools"),
            ],
            path: "Sources/CalendarFeature"
        ),

        .target(
            name: "DayDetailFeature",
            dependencies: [
                "AppDomain",
                "PookieStyle",
                .product(name: "SwiftRex",              package: "SwiftRex"),
                .product(name: "SwiftRex.SwiftUI",      package: "SwiftRex"),
                .product(name: "SwiftRex.Architecture", package: "SwiftRex"),
                .product(name: "SwiftRex.Operators",    package: "SwiftRex"),
                .product(name: "SwiftRex.ReactiveConcurrency", package: "SwiftRex"),
                .product(name: "ReactiveConcurrency",   package: "ReactiveConcurrency"),
                .product(name: "CoreFP",                package: "FP"),
                .product(name: "CoreFPOperators",       package: "FP"),
                .product(name: "FPMacros",              package: "FP"),
                .product(name: "Core", package: "NetworkTools"),
            ],
            path: "Sources/DayDetailFeature"
        ),

        .target(
            name: "ReportInputFeature",
            dependencies: [
                "AppDomain",
                "PookieStyle",
                .product(name: "SwiftRex",              package: "SwiftRex"),
                .product(name: "SwiftRex.SwiftUI",      package: "SwiftRex"),
                .product(name: "SwiftRex.Architecture", package: "SwiftRex"),
                .product(name: "SwiftRex.Operators",    package: "SwiftRex"),
                .product(name: "SwiftRex.ReactiveConcurrency", package: "SwiftRex"),
                .product(name: "ReactiveConcurrency",   package: "ReactiveConcurrency"),
                .product(name: "CoreFP",                package: "FP"),
                .product(name: "CoreFPOperators",       package: "FP"),
                .product(name: "FPMacros",              package: "FP"),
                .product(name: "Core", package: "NetworkTools"),
            ],
            path: "Sources/ReportInputFeature"
        ),

        .target(
            name: "ReportResultFeature",
            dependencies: [
                "AppDomain",
                "PookieStyle",
                .product(name: "SwiftRex",              package: "SwiftRex"),
                .product(name: "SwiftRex.SwiftUI",      package: "SwiftRex"),
                .product(name: "SwiftRex.Architecture", package: "SwiftRex"),
                .product(name: "SwiftRex.Operators",    package: "SwiftRex"),
                .product(name: "SwiftRex.ReactiveConcurrency", package: "SwiftRex"),
                .product(name: "ReactiveConcurrency",   package: "ReactiveConcurrency"),
                .product(name: "CoreFP",                package: "FP"),
                .product(name: "CoreFPOperators",       package: "FP"),
                .product(name: "FPMacros",              package: "FP"),
                .product(name: "Core", package: "NetworkTools"),
            ],
            path: "Sources/ReportResultFeature"
        ),

        .target(
            name: "SalaryEditorFeature",
            dependencies: [
                "AppDomain",
                "PookieStyle",
                .product(name: "SwiftRex",              package: "SwiftRex"),
                .product(name: "SwiftRex.SwiftUI",      package: "SwiftRex"),
                .product(name: "SwiftRex.Architecture", package: "SwiftRex"),
                .product(name: "SwiftRex.Operators",    package: "SwiftRex"),
                .product(name: "SwiftRex.ReactiveConcurrency", package: "SwiftRex"),
                .product(name: "ReactiveConcurrency",   package: "ReactiveConcurrency"),
                .product(name: "CoreFP",                package: "FP"),
                .product(name: "CoreFPOperators",       package: "FP"),
                .product(name: "FPMacros",              package: "FP"),
                .product(name: "Core",                  package: "NetworkTools"),
            ],
            path: "Sources/SalaryEditorFeature"
        ),

        .target(
            name: "SettingsFeature",
            dependencies: [
                "AppDomain",
                "PookieStyle",
                .product(name: "SwiftRex",              package: "SwiftRex"),
                .product(name: "SwiftRex.SwiftUI",      package: "SwiftRex"),
                .product(name: "SwiftRex.Architecture", package: "SwiftRex"),
                .product(name: "SwiftRex.Operators",    package: "SwiftRex"),
                .product(name: "SwiftRex.ReactiveConcurrency", package: "SwiftRex"),
                .product(name: "ReactiveConcurrency",   package: "ReactiveConcurrency"),
                .product(name: "CoreFP",                package: "FP"),
                .product(name: "CoreFPOperators",       package: "FP"),
                .product(name: "FPMacros",              package: "FP"),
            ],
            path: "Sources/SettingsFeature"
        ),

        // MARK: - App wiring

        .target(
            name: "AppCore",
            dependencies: [
                "AppDomain",
                "NavigationFeature",
                "CalendarFeature",
                "DayDetailFeature",
                "ReportInputFeature",
                "ReportResultFeature",
                "SalaryEditorFeature",
                "SettingsFeature",
                "PookieStyle",
                .product(name: "SwiftRex",              package: "SwiftRex"),
                .product(name: "SwiftRex.SwiftUI",      package: "SwiftRex"),
                .product(name: "SwiftRex.Architecture", package: "SwiftRex"),
                .product(name: "SwiftRex.Operators",    package: "SwiftRex"),
                .product(name: "SwiftRex.ReactiveConcurrency", package: "SwiftRex"),
                .product(name: "ReactiveConcurrency",   package: "ReactiveConcurrency"),
                .product(name: "CoreFP",                package: "FP"),
                .product(name: "CoreFPOperators",       package: "FP"),
                .product(name: "FPMacros",              package: "FP"),
                .product(name: "Core",                  package: "NetworkTools"),
            ],
            path: "Sources/AppCore"
        ),

        // MARK: - Tests

        .testTarget(
            name: "PookieTests",
            dependencies: [
                "AppDomain",
                "AppCore",
                "CalendarFeature",
                "DayDetailFeature",
                "ReportInputFeature",
                "ReportResultFeature",
                .product(name: "SwiftRex",              package: "SwiftRex"),
                .product(name: "SwiftRex.Architecture", package: "SwiftRex"),
                .product(name: "SwiftRex.ReactiveConcurrency", package: "SwiftRex"),
                .product(name: "ReactiveConcurrency",   package: "ReactiveConcurrency"),
                .product(name: "SwiftRex.Testing",      package: "SwiftRex"),
                .product(name: "CoreFP",                package: "FP"),
                .product(name: "CoreFPOperators",       package: "FP"),
                .product(name: "FPMacros",              package: "FP"),
                .product(name: "Core",                  package: "NetworkTools"),
                .product(name: "SnapshotTesting",       package: "swift-snapshot-testing"),
            ],
            path: "Tests/PookieTests",
            exclude: ["Features/__Snapshots__"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
