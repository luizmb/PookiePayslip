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
public typealias LiftedScope<F: Feature> = Scope<AppAction, AppState, World, F>

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
        <> LiftedScope<CalendarFeature>.calendar.behavior
        <> LiftedScope<DayDetailFeature>.dayDetail.behavior
        <> LiftedScope<ReportInputFeature>.reportInput.behavior
        <> LiftedScope<ReportResultFeature>.reportResult.behavior
        <> LiftedScope<SalaryEditorFeature>.salaryEditor.behavior
        <> LiftedScope<SettingsFeature>.settings.behavior
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

// MARK: - Feature scopes

public extension LiftedScope<CalendarFeature> {
    static var calendar: Self {
        Scope(
            CalendarFeature.self,
            action: \.calendar,
            state: \.calendar,
            environment: { world in
                        CalendarFeature.Environment(
                            decoder:     world.decoder,
                            readFile:    world.readFile,
                            currentDate: world.currentDate,
                            calendar:    world.calendar,
                            formatDate:  world.formatDate,
                            formatMoney: world.formatMoney
                        )
                    }
        )
    }
}

public extension LiftedScope<DayDetailFeature> {
    static var dayDetail: Self {
        Scope(
            DayDetailFeature.self,
            action: \.dayDetail,
            state: \.dayDetail,
            environment: { world in
                        DayDetailFeature.Environment(
                            decoder:     world.decoder,
                            encoder:     world.encoder,
                            readFile:    world.readFile,
                            saveFile:    world.saveFile,
                            currentDate: world.currentDate,
                            newID:       world.newID,
                            calendar:    world.calendar,
                            dayBefore:   world.dayBefore,
                            dayAfter:    world.dayAfter,
                            loadSettings: world.loadSettings,
                            formatDate:  world.formatDate
                        )
                    }
        )
    }
}

public extension LiftedScope<ReportInputFeature> {
    static var reportInput: Self {
        Scope(
            ReportInputFeature.self,
            action: \.reportInput,
            state: \.reportInput,
            environment: { world in
                        ReportInputFeature.Environment(
                            decoder:     world.decoder,
                            readFile:    world.readFile,
                            currentDate: world.currentDate,
                            calendar:    world.calendar,
                            calcTax:     world.calcTax
                        )
                    }
        )
    }
}

public extension LiftedScope<ReportResultFeature> {
    static var reportResult: Self {
        Scope(
            ReportResultFeature.self,
            action: \.reportResult,
            state: \.reportResult,
            environment: { world in
                        ReportResultFeature.Environment(
                            renderPDF: { r, recs in world.renderPDF(r, recs) },
                            formatDate: world.formatDate,
                            formatMoney: world.formatMoney
                        )
                    }
        )
    }
}

public extension LiftedScope<SalaryEditorFeature> {
    static var salaryEditor: Self {
        Scope(
            SalaryEditorFeature.self,
            action: \.salaryEditor,
            state: \.salaryEditor,
            environment: { world in
                        SalaryEditorFeature.Environment(
                            decoder:  world.decoder,
                            encoder:  world.encoder,
                            readFile: world.readFile,
                            saveFile: world.saveFile,
                            calendar: world.calendar
                        )
                    }
        )
    }
}

public extension LiftedScope<SettingsFeature> {
    static var settings: Self {
        Scope(
            SettingsFeature.self,
            action: \.settings,
            state: \.settings,
            environment: { world in
                        SettingsFeature.Environment(
                            loadSettings: world.loadSettings,
                            saveSettings: world.saveSettings,
                            exportDatabase: world.exportDatabase
                        )
                    }
        )
    }
}
