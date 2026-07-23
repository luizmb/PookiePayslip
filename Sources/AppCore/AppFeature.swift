import AppDomain
import CalendarFeature
import Core
import CoreFP
import CoreFPOperators
import DayDetailFeature
import FPMacros
import Foundation
import NavigationFeature
import ReactiveConcurrency
import ReportInputFeature
import ReportResultFeature
import SalaryEditorFeature
import SettingsFeature
import SwiftRex
import SwiftRexArchitecture
import SwiftRexOperators
import SwiftRexReactiveConcurrency

// MARK: - AppState

@Lenses
public struct AppState: Sendable {
    public var navigation:   NavigationFeature.State
    public var calendar:     CalendarFeature.State
    public var dayDetail:    DayDetailFeature.State
    public var reportInput:  ReportInputFeature.State
    public var reportResult: ReportResultFeature.State
    public var salaryEditor: SalaryEditorFeature.State
    public var settings:     SettingsFeature.State

    // Pure: no World. Every feature starts empty; the behaviors fill calendar-derived values from
    // World on `.start`/onAppear — nothing that can change without an Action lives in State.
    public init() {
        navigation    = NavigationFeature.State()
        self.calendar = CalendarFeature.initialState(with: ())
        dayDetail     = DayDetailFeature.initialState(with: ())
        reportInput   = ReportInputFeature.initialState(with: ())
        reportResult  = ReportResultFeature.initialState(with: ())
        salaryEditor  = SalaryEditorFeature.initialState(with: ())
        settings      = SettingsFeature.initialState(with: ())
    }
}

// MARK: - AppAction

@Prisms
public enum AppAction: Sendable {
    case appLaunch
    case navigation(NavigationFeature.Action)
    case calendar(CalendarFeature.Action)
    case dayDetail(DayDetailFeature.Action)
    case reportInput(ReportInputFeature.Action)
    case reportResult(ReportResultFeature.Action)
    case salaryEditor(SalaryEditorFeature.Action)
    case settings(SettingsFeature.Action)
}

public typealias MainStoreType = any StoreType<AppAction, AppState>
public typealias MainStore = Store<AppAction, AppState, World>

// MARK: - Store factory

public extension MainStore {
    @MainActor
    static func app(world: World) -> MainStoreType {
        Store(
            initial: AppState(),
            behavior: behavior(),
            environment: world
        )
        .dispatching(.appLaunch)
    }
}

private extension MainStore {
    static func behavior() -> Behavior<AppAction, AppState, World> {
        NavigationFeature.behavior().lift(.action(\.navigation).state(\.navigation).environment(ignore))
        <> AppScopes.calendar.behavior(of: CalendarFeature.self)
        <> AppScopes.dayDetail.behavior(of: DayDetailFeature.self)
        <> AppScopes.reportInput.behavior(of: ReportInputFeature.self)
        <> AppScopes.reportResult.behavior(of: ReportResultFeature.self)
        <> AppScopes.salaryEditor.behavior(of: SalaryEditorFeature.self)
        <> AppScopes.settings.behavior(of: SettingsFeature.self)
        <> bridgeBehavior()
    }
}

// MARK: - Bridge behavior
//
// Responsible ONLY for cross-feature coordination:
//   - Navigation path updates
//   - Sharing state between features (e.g. propagating a saved record to calendar)
//   - Dispatching actions to trigger other features
//
// IO side-effects (file reads for the day, etc.) live in the target feature's own behavior.

private func bridgeBehavior() -> Behavior<AppAction, AppState, World> {
    Behavior<AppAction, AppState, World>.identity

    // Calendar salary chip tapped → seed month date in editor + push nav
        .on(
            .action(\.calendar.openSalaryEditor),
            dispatch: .action(\.navigation.push.salaryEditor),
            reduce: { _, state in
                state.salaryEditor.amount      = state.calendar.salary?.amount      ?? 0
                state.salaryEditor.periodicity = state.calendar.salary?.periodicity ?? .hourly
                state.salaryEditor.niClass     = state.calendar.salary?.niClass     ?? .employed
                state.salaryEditor.studentLoan = state.calendar.salary?.studentLoan ?? .none
                state.salaryEditor.pensionRate = state.calendar.salary?.pensionRate ?? 0
                state.salaryEditor.monthDate   = state.calendar.currentMonth
            }
        )

    // Salary saved → update calendar + pop
        .on(.action(\.salaryEditor.saved), dispatch: .action(\.calendar.salaryUpdated))
        .on(.action(\.salaryEditor.saved), dispatch: .action(review: const(.navigation(.pop))))

    // Salary back → pop
        .on(.action(\.salaryEditor.back), dispatch: .action(\.navigation.pop))

    // Settings gear tapped → push settings
        .on(.action(\.calendar.openSettings), dispatch: .action(\.navigation.push.settings))

    // Settings saved / back → pop
        .on(.action(\.settings.saved), dispatch: .action(review: const(.navigation(.pop))))
        .on(.action(\.settings.back), dispatch: .action(\.navigation.pop))

    // selectDay: push nav to dayDetail, seed dayDetail.date for the onAppear load
        .on(
            .action(\.calendar.selectDay),
            dispatch: .action(\.navigation.push.dayDetail),
            reduce: { date, state in state.dayDetail.date = date }
        )

    // openReport: push nav to reportInput
        .on(.action(\.calendar.openReport), dispatch: .action(\.navigation.push.reportInput))

    // dayLoaded: keep navigation path in sync (covers prevDay, nextDay, and initial load)
        .on(
            .action(\.dayDetail.dayLoaded),
            dispatch: .action(review: { args in .navigation(.replaceLast(.dayDetail(args.0.date))) })
        )

    // saveCompleted: route saved record to CalendarFeature cache
        .on(.action(\.dayDetail.saveCompleted), dispatch: .action(\.calendar.recordUpdated))

    // done: pop navigation
        .on(.action(\.dayDetail.done), dispatch: .action(\.navigation.pop))

    // reportGenerated: push nav to reportResult
        .on(.action(\.reportInput.reportGenerated), dispatch: .action(review: const(.navigation(.push(.reportResult)))))

    // reportGenerated: route to ReportResultFeature so it seeds its own state (including records for PDF)
        .on(
            .action(\.reportInput.reportGenerated),
            dispatch: .action(review: { args in
                let (report, records, from, to) = args
                return .reportResult(.loaded(report, records, from: from, to: to))
            })
        )

    // back: pop nav
        .on(.action(\.reportInput.back), dispatch: .action(\.navigation.pop))
        .on(.action(\.reportResult.back), dispatch: .action(\.navigation.pop))
}

private extension Store<AppAction, AppState, World> {
    func dispatching(
        _ action: AppAction,
        file: String = #file,
        function: String = #function,
        line: UInt = #line
    ) -> Self {
        dispatch(
            action,
            source: .init(
                file: file,
                function: function,
                line: line
            )
        )
        return self
    }
}

// MARK: - Feature scopes

public enum AppScopes: Rig {
    public typealias Action = AppAction
    public typealias State = AppState
    public typealias Environment = World

    // Total-state scope shape pinned to the app triad (duplex `Prism` / total `ReadsWrites` / `Narrows`).
    // Annotating a scope `Global<_,_,_>` roots the bare optics, so each declares as
    // `.action(\.x).state(\.x).environment(…)` with no explicit witnesses.
    //
    // Multi-property environments narrow point-free via `fanout(keypaths: …, into: Env.init)`. The feature
    // `Environment` inits take `& Sendable` decoders (matching `World`'s storage) so the key-path value
    // type equals the init param type — a plain `any …` param would force a variance conversion inside the
    // variadic pack, which currently crashes the Swift compiler (emit-module SIGSEGV).
    public typealias Global<A, S, E> = Relay.Scope<
        Relay.ActionAxis.Prism<Action, A>,
        Relay.StateAxis.ReadsWrites<State, S>,
        Relay.EnvironmentAxis.Narrows<Environment, E>
    >

    public static let calendar: Global<_, _, _> =
        .action(\.calendar).state(\.calendar)
        .environment(fanout(
            keypaths: \.decoder, \.readFile, \.currentDate, \.calendar, \.formatDate, \.formatMoney,
            into: CalendarFeature.Environment.init
        ))

    public static let dayDetail: Global<_, _, _> =
        .action(\.dayDetail).state(\.dayDetail)
        .environment(fanout(
            keypaths: \.decoder, \.encoder, \.readFile, \.saveFile, \.currentDate, \.newID,
                      \.calendar, \.dayBefore, \.dayAfter, \.loadSettings, \.formatDate,
            into: DayDetailFeature.Environment.init
        ))

    public static let reportInput: Global<_, _, _> =
        .action(\.reportInput).state(\.reportInput)
        .environment(fanout(
            keypaths: \.decoder, \.readFile, \.currentDate, \.calendar, \.calcTax,
            into: ReportInputFeature.Environment.init
        ))

    public static let reportResult: Global<_, _, _> =
        .action(\.reportResult).state(\.reportResult)
        .environment(fanout(
            keypaths: \.renderPDF, \.formatDate, \.formatMoney,
            into: ReportResultFeature.Environment.init
        ))

    public static let salaryEditor: Global<_, _, _> =
        .action(\.salaryEditor).state(\.salaryEditor)
        .environment(fanout(
            keypaths: \.decoder, \.encoder, \.readFile, \.saveFile, \.calendar,
            into: SalaryEditorFeature.Environment.init
        ))

    public static let settings: Global<_, _, _> =
        .action(\.settings).state(\.settings)
        .environment(fanout(
            keypaths: \.loadSettings, \.saveSettings, \.exportDatabase,
            into: SettingsFeature.Environment.init
        ))
}
