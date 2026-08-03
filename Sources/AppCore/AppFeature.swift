import AppDomain
import CalendarFeature
import Core
import CoreFP
import CoreFPOperators
import DayDetailFeature
import FPMacros
import Foundation
import ReactiveConcurrency
import ReportInputFeature
import ReportResultFeature
import SalaryEditorFeature
import SettingsFeature
import SwiftRex
import SwiftRexArchitecture
import SwiftRexOperators
import SwiftRexReactiveConcurrency
import SwiftUI

// MARK: - AppFeature

/// The app is a `Feature` like any other: it owns state, actions and a behavior, and it builds its own
/// view. Nothing about the root is special-cased — which is the point. The root used to hand a bare
/// `Store` to a view, and because `Store` is not `@Observable`, the stack silently never re-rendered.
/// Going through the standard `Feature` machinery means the view store is built exactly the way every
/// other screen's is, so that failure is no longer expressible here.
///
/// It is also the app's coordinator: it holds the `World`, constructs the ``AppRouter``, and injects it
/// into the root view. Child features are created by that router on demand and never cached.
@Feature(strategy: .observationSimple)
public enum AppFeature {

    // MARK: - State

    public struct State: Sendable, Equatable {
        /// The root screen — always on screen, so never optional.
        public var calendar: CalendarFeature.State

        /// The pushed screens, each carrying its own state. One source of truth: there is no parallel
        /// table to keep in step, so a route and its data cannot disagree.
        public var path: [StackEntry]

        public init() {
            calendar = CalendarFeature.initialState(with: ())
            path = []
        }
    }

    // MARK: - Action

    public enum Action: Sendable {
        case appLaunch
        case navigation(NavigationAction)
        case calendar(CalendarFeature.Action)
        case dayDetail(DayDetailFeature.Action)
        case reportInput(ReportInputFeature.Action)
        case reportResult(ReportResultFeature.Action)
        case salaryEditor(SalaryEditorFeature.Action)
        case settings(SettingsFeature.Action)
    }

    // MARK: - Environment

    public typealias Environment = World

    // No `ViewState`/`ViewAction`: the macro aliases them to `State`/`Action`, so the root view's store
    // is `ViewStore<State, Action>` — the whole app, which is what a router needs to project children.

    // MARK: - Lifecycle

    public static func initialState(with _: Void) -> State { .init() }

    // MARK: - View
    //
    // Hand-written rather than `typealias Content`: the generated `view()` passes only the view store,
    // and the root view also needs its router. This is the one place holding the `World`, so it is the
    // one place that can build a router — and the `World` goes no further.

    @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
    @MainActor
    public static func view(store: any StoreType<Action, State>, environment: World) -> some View {
        AppRootView(
            viewStore: ViewStore(store),
            router: AppRouter(store: store, world: environment)
        )
    }

    // MARK: - Behavior

    public static func behavior() -> Behavior<Action, State, World> {
        // Each feature's own wiring sits with it: the lift, then the actions it sends onward. Reading a
        // feature's row tells you everything it participates in, without a separate bridge to cross-check.
        navigationBehavior()

        <> AppScopes.calendar.behavior(of: CalendarFeature.self)
            .on(.action(\.calendar.selectDay),        dispatch: .action(\.navigation.push.dayDetail))
            .on(.action(\.calendar.openReport),       dispatch: .action(\.navigation.push.reportInput))
            .on(.action(\.calendar.openSalaryEditor), dispatch: .action(\.navigation.push.salaryEditor))
            .on(.action(\.calendar.openSettings),     dispatch: .action(\.navigation.push.settings))

        <> AppScopes.dayDetail.behavior(of: DayDetailFeature.self)
            .on(.action(\.dayDetail.saveCompleted), dispatch: .action(\.calendar.recordUpdated))

        <> AppScopes.reportInput.behavior(of: ReportInputFeature.self)
            .on(.action(\.reportInput.reportGenerated), dispatch: .action(\.navigation.push.reportResult))

        <> AppScopes.reportResult.behavior(of: ReportResultFeature.self)

        <> AppScopes.salaryEditor.behavior(of: SalaryEditorFeature.self)
            .on(.action(\.salaryEditor.saved), dispatch: .action(\.calendar.salaryUpdated))
            .on(.action(\.salaryEditor.saved), dispatch: .action(review: const(.navigation(.pop))))

        <> AppScopes.settings.behavior(of: SettingsFeature.self)
            .on(.action(\.settings.saved), dispatch: .action(review: const(.navigation(.pop))))
    }
}

// Familiar spellings for the app triad — `AppFeature.State` everywhere would only add noise.
public typealias AppState = AppFeature.State
public typealias AppAction = AppFeature.Action
public typealias MainStoreType = any StoreType<AppAction, AppState>
public typealias MainStore = Store<AppAction, AppState, World>

// MARK: - The path, as SwiftUI sees it

public extension AppState {
    /// The `Hashable` identities SwiftUI navigates by. Read-only — the path is the truth, this is a view
    /// of it. A screen's data can change all it likes without changing which screen it is.
    var routes: [AppRoute] { path.map(\.route) }
}

// MARK: - Store factory

public extension MainStore {
    @MainActor
    static func app(world: World) -> MainStoreType {
        Store(
            initial: AppState(),
            behavior: AppFeature.behavior(),
            environment: world
        )
        .dispatching(.appLaunch)
    }
}

private extension Store<AppAction, AppState, World> {
    func dispatching(
        _ action: AppAction,
        file: String = #file,
        function: String = #function,
        line: UInt = #line
    ) -> Self {
        dispatch(action, source: .init(file: file, function: function, line: line))
        return self
    }
}

// MARK: - Feature scopes
//
// One declaration per feature carrying all three axes — action, state, environment — so the same value
// drives the behavior fold and the router. A pushed screen's state axis is **affine**: it focuses the
// `path` element the screen lives in, reading and writing through the same prism, so there is no derived
// copy and nothing to keep in step.

public enum AppScopes: Rig {
    public typealias Action = AppAction
    public typealias State = AppState
    public typealias Environment = World

    public static let calendar = ScopeOf<AppScopes>
        .action(\.calendar)
        .state(\.calendar)
        .environment(fanout(
            \.decoder, \.readFile, \.currentDate, \.calendar,
            \.formatDate, \.formatMoney
        ) >>> CalendarFeature.Environment.init)

    public static let dayDetail = ScopeOf<AppScopes>
        .action(\.dayDetail)
        .state(preview: topmost(StackEntry.prism.dayDetail), set: replacing(StackEntry.prism.dayDetail))
        .environment(fanout(
            \.decoder, \.encoder, \.readFile, \.saveFile,
            \.currentDate, \.newID, \.calendar, \.dayBefore,
            \.dayAfter, \.loadSettings, \.formatDate
        ) >>> DayDetailFeature.Environment.init)

    public static let reportInput = ScopeOf<AppScopes>
        .action(\.reportInput)
        .state(preview: topmost(StackEntry.prism.reportInput), set: replacing(StackEntry.prism.reportInput))
        .environment(fanout(
            \.decoder, \.readFile, \.currentDate, \.calendar,
            \.calcTax
        ) >>> ReportInputFeature.Environment.init)

    public static let reportResult = ScopeOf<AppScopes>
        .action(\.reportResult)
        .state(preview: topmost(StackEntry.prism.reportResult), set: replacing(StackEntry.prism.reportResult))
        .environment(fanout(
            \.renderPDF, \.formatDate, \.formatMoney
        ) >>> ReportResultFeature.Environment.init)

    public static let salaryEditor = ScopeOf<AppScopes>
        .action(\.salaryEditor)
        .state(preview: topmost(StackEntry.prism.salaryEditor), set: replacing(StackEntry.prism.salaryEditor))
        .environment(fanout(
            \.decoder, \.encoder, \.readFile, \.saveFile,
            \.calendar
        ) >>> SalaryEditorFeature.Environment.init)

    public static let settings = ScopeOf<AppScopes>
        .action(\.settings)
        .state(preview: topmost(StackEntry.prism.settings), set: replacing(StackEntry.prism.settings))
        .environment(fanout(
            \.loadSettings, \.saveSettings, \.exportDatabase
        ) >>> SettingsFeature.Environment.init)
}

// MARK: - The affine focus a pushed screen lives behind
//
// Both halves go through the same prism, so a read and a write can never disagree about which element
// they mean. `replacing` only ever overwrites an element that is already there — it cannot append, so a
// child behavior can never conjure a screen navigation did not push.

private func topmost<S>(_ prism: Prism<StackEntry, S>) -> @Sendable (AppState) -> S? {
    { $0.path.compactMap(prism.preview).last }
}

private func replacing<S>(_ prism: Prism<StackEntry, S>) -> @Sendable (AppState, S) -> AppState {
    { state, screen in
        guard let index = state.path.lastIndex(where: { prism.preview($0) != nil }) else { return state }
        var updated = state
        updated.path[index] = prism.review(screen)
        return updated
    }
}
