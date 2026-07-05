import AppDomain
import CalendarFeature
import CoreFP
import CoreFPOperators
import DayDetailFeature
import FPMacros
import Foundation
import NavigationFeature
import ReportInputFeature
import ReportResultFeature
import SalaryEditorFeature
import SettingsFeature
import SwiftRex
import SwiftRexArchitecture
import ReactiveConcurrency
import SwiftRexReactiveConcurrency
import SwiftRexOperators

// MARK: - AppState

@Lenses
public struct AppState: Sendable, Codable {
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
        NavigationFeature.behavior().lift(action: \.navigation, state: \.navigation, environment: { _ in () })
        <> calendarScope.behavior
        <> dayDetailScope.behavior
        <> reportInputScope.behavior
        <> reportResultScope.behavior
        <> salaryEditorScope.behavior
        <> settingsScope.behavior
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
        .on(AppAction.prism.calendar >>> CalendarFeature.Action.prism.openSalaryEditor,
            dispatch: const(.navigation(.push(.salaryEditor))),
            reduce: { _, state in
                state.salaryEditor.amount      = state.calendar.salary?.amount      ?? 0
                state.salaryEditor.periodicity = state.calendar.salary?.periodicity ?? .hourly
                state.salaryEditor.niClass     = state.calendar.salary?.niClass     ?? .employed
                state.salaryEditor.studentLoan = state.calendar.salary?.studentLoan ?? .none
                state.salaryEditor.pensionRate = state.calendar.salary?.pensionRate ?? 0
                state.salaryEditor.monthDate   = state.calendar.currentMonth
            })

    // Salary saved → update calendar + pop
        .on(AppAction.prism.salaryEditor >>> SalaryEditorFeature.Action.prism.saved,
            dispatch: { salary in .calendar(.salaryUpdated(salary)) })
        .on(AppAction.prism.salaryEditor >>> SalaryEditorFeature.Action.prism.saved,
            dispatch: const(.navigation(.pop)))

    // Salary back → pop
        .on(AppAction.prism.salaryEditor >>> SalaryEditorFeature.Action.prism.back,
            dispatch: const(.navigation(.pop)))

    // Settings gear tapped → push settings
        .on(AppAction.prism.calendar >>> CalendarFeature.Action.prism.openSettings,
            dispatch: const(.navigation(.push(.settings))))

    // Settings saved / back → pop
        .on(AppAction.prism.settings >>> SettingsFeature.Action.prism.saved,
            dispatch: const(.navigation(.pop)))
        .on(AppAction.prism.settings >>> SettingsFeature.Action.prism.back,
            dispatch: const(.navigation(.pop)))

    // selectDay: push nav to dayDetail, seed dayDetail.date for the onAppear load
        .on(AppAction.prism.calendar >>> CalendarFeature.Action.prism.selectDay,
            dispatch: { date in .navigation(.push(.dayDetail(date))) },
            reduce:   { date, state in state.dayDetail.date = date })

    // openReport: push nav to reportInput
        .on(AppAction.prism.calendar >>> CalendarFeature.Action.prism.openReport,
            dispatch: const(.navigation(.push(.reportInput))))

    // dayLoaded: keep navigation path in sync (covers prevDay, nextDay, and initial load)
        .on(AppAction.prism.dayDetail >>> DayDetailFeature.Action.prism.dayLoaded,
            dispatch: { args in .navigation(.replaceLast(.dayDetail(args.0.date))) })

    // saveCompleted: route saved record to CalendarFeature cache
        .on(AppAction.prism.dayDetail >>> DayDetailFeature.Action.prism.saveCompleted,
            dispatch: { record in .calendar(.recordUpdated(record)) })

    // done: pop navigation
        .on(AppAction.prism.dayDetail >>> DayDetailFeature.Action.prism.done,
            dispatch: const(.navigation(.pop)))

    // reportGenerated: push nav to reportResult
        .on(AppAction.prism.reportInput >>> ReportInputFeature.Action.prism.reportGenerated,
            dispatch: const(.navigation(.push(.reportResult))))

    // reportGenerated: route to ReportResultFeature so it seeds its own state (including records for PDF)
        .on(AppAction.prism.reportInput >>> ReportInputFeature.Action.prism.reportGenerated,
            dispatch: { args in
                let (report, records, from, to) = args
                return .reportResult(.loaded(report, records, from: from, to: to))
            })

    // back: pop nav
        .on(AppAction.prism.reportInput  >>> ReportInputFeature.Action.prism.back,
            dispatch: const(.navigation(.pop)))
        .on(AppAction.prism.reportResult >>> ReportResultFeature.Action.prism.back,
            dispatch: const(.navigation(.pop)))
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
