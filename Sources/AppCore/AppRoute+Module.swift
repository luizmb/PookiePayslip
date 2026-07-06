import AppDomain
import CalendarFeature
import DayDetailFeature
import NavigationFeature
import ReportInputFeature
import ReportResultFeature
import SalaryEditorFeature
import SettingsFeature
import SwiftRex
import SwiftRexArchitecture
import SwiftUI

// MARK: - AppRoute → View (the router)
//
// The router resolves a route to a feature view via that feature's `Scope`, supplying the child's
// environment from `world` — the env-free view body never builds a child itself. `@ViewBuilder`
// unifies the concrete per-route view types without `AnyView` erasure.

public extension AppRoute {

    @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
    @MainActor
    static func scene(store: MainStoreType, world: World) -> some Scene {
        WindowGroup {
            root(store: store, world: world, entry: .calendar)
        }
    }

    @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
    @MainActor
    private static func root(store: MainStoreType, world: World, entry: AppRoute) -> some View {
        AppRootView(path: store.path(\.navigation.path, set: { AppAction.navigation(.setPath($0)) })) {
            entry.view(in: store, world: world)
                .navigationDestination(for: AppRoute.self) { route in
                    route.view(in: store, world: world)
                }
        }
    }

    /// The view for this route, built with its environment supplied from `world`.
    @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
    @MainActor @ViewBuilder
    func view(in store: MainStoreType, world: World) -> some View {
        switch self {
        case .calendar:     LiftedScope<CalendarFeature>.calendar.view(from: store, world: world)
        case .dayDetail:    LiftedScope<DayDetailFeature>.dayDetail.view(from: store, world: world)
        case .reportInput:  LiftedScope<ReportInputFeature>.reportInput.view(from: store, world: world)
        case .reportResult: LiftedScope<ReportResultFeature>.reportResult.view(from: store, world: world)
        case .salaryEditor: LiftedScope<SalaryEditorFeature>.salaryEditor.view(from: store, world: world)
        case .settings:     LiftedScope<SettingsFeature>.settings.view(from: store, world: world)
        }
    }
}
