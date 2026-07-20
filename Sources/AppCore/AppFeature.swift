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
        .on(.action(AppAction.prism.calendar >>> CalendarFeature.Action.prism.openSalaryEditor),
            dispatch: .action(review: const(.navigation(.push(.salaryEditor)))),
            reduce: { _, state in
                state.salaryEditor.amount      = state.calendar.salary?.amount      ?? 0
                state.salaryEditor.periodicity = state.calendar.salary?.periodicity ?? .hourly
                state.salaryEditor.niClass     = state.calendar.salary?.niClass     ?? .employed
                state.salaryEditor.studentLoan = state.calendar.salary?.studentLoan ?? .none
                state.salaryEditor.pensionRate = state.calendar.salary?.pensionRate ?? 0
                state.salaryEditor.monthDate   = state.calendar.currentMonth
            })

    // Salary saved → update calendar + pop
        .on(.action(AppAction.prism.salaryEditor >>> SalaryEditorFeature.Action.prism.saved),
            dispatch: .action(review: { salary in .calendar(.salaryUpdated(salary)) }))
        .on(.action(AppAction.prism.salaryEditor >>> SalaryEditorFeature.Action.prism.saved),
            dispatch: .action(review: const(.navigation(.pop))))

    // Salary back → pop
        .on(.action(AppAction.prism.salaryEditor >>> SalaryEditorFeature.Action.prism.back),
            dispatch: .action(review: const(.navigation(.pop))))

    // Settings gear tapped → push settings
        .on(.action(AppAction.prism.calendar >>> CalendarFeature.Action.prism.openSettings),
            dispatch: .action(review: const(.navigation(.push(.settings)))))

    // Settings saved / back → pop
        .on(.action(AppAction.prism.settings >>> SettingsFeature.Action.prism.saved),
            dispatch: .action(review: const(.navigation(.pop))))
        .on(.action(AppAction.prism.settings >>> SettingsFeature.Action.prism.back),
            dispatch: .action(review: const(.navigation(.pop))))

    // selectDay: push nav to dayDetail, seed dayDetail.date for the onAppear load
        .on(.action(AppAction.prism.calendar >>> CalendarFeature.Action.prism.selectDay),
            dispatch: .action(review: { date in .navigation(.push(.dayDetail(date))) }),
            reduce:   { date, state in state.dayDetail.date = date })

    // openReport: push nav to reportInput
        .on(.action(AppAction.prism.calendar >>> CalendarFeature.Action.prism.openReport),
            dispatch: .action(review: const(.navigation(.push(.reportInput)))))

    // dayLoaded: keep navigation path in sync (covers prevDay, nextDay, and initial load)
        .on(.action(AppAction.prism.dayDetail >>> DayDetailFeature.Action.prism.dayLoaded),
            dispatch: .action(review: { args in .navigation(.replaceLast(.dayDetail(args.0.date))) }))

    // saveCompleted: route saved record to CalendarFeature cache
        .on(.action(AppAction.prism.dayDetail >>> DayDetailFeature.Action.prism.saveCompleted),
            dispatch: .action(review: { record in .calendar(.recordUpdated(record)) }))

    // done: pop navigation
        .on(.action(AppAction.prism.dayDetail >>> DayDetailFeature.Action.prism.done),
            dispatch: .action(review: const(.navigation(.pop))))

    // reportGenerated: push nav to reportResult
        .on(.action(AppAction.prism.reportInput >>> ReportInputFeature.Action.prism.reportGenerated),
            dispatch: .action(review: const(.navigation(.push(.reportResult)))))

    // reportGenerated: route to ReportResultFeature so it seeds its own state (including records for PDF)
        .on(.action(AppAction.prism.reportInput >>> ReportInputFeature.Action.prism.reportGenerated),
            dispatch: .action(review: { args in
                let (report, records, from, to) = args
                return .reportResult(.loaded(report, records, from: from, to: to))
            }))

    // back: pop nav
        .on(.action(AppAction.prism.reportInput  >>> ReportInputFeature.Action.prism.back),
            dispatch: .action(review: const(.navigation(.pop))))
        .on(.action(AppAction.prism.reportResult >>> ReportResultFeature.Action.prism.back),
            dispatch: .action(review: const(.navigation(.pop))))
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

public enum AppScopes {
    public static let calendar = Relay.Empty
        .action(AppAction.prism.calendar).state(\AppState.calendar)
        .environment { (world: World) in
            CalendarFeature.Environment(
                decoder:     world.decoder,
                readFile:    world.readFile,
                currentDate: world.currentDate,
                calendar:    world.calendar,
                formatDate:  world.formatDate,
                formatMoney: world.formatMoney
            )
        }

    public static let dayDetail = Relay.Empty
        .action(AppAction.prism.dayDetail).state(\AppState.dayDetail)
        .environment { (world: World) in
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

    public static let reportInput = Relay.Empty
        .action(AppAction.prism.reportInput).state(\AppState.reportInput)
        .environment { (world: World) in
            ReportInputFeature.Environment(
                decoder:     world.decoder,
                readFile:    world.readFile,
                currentDate: world.currentDate,
                calendar:    world.calendar,
                calcTax:     world.calcTax
            )
        }

    public static let reportResult = Relay.Empty
        .action(AppAction.prism.reportResult).state(\AppState.reportResult)
        .environment { (world: World) in
            ReportResultFeature.Environment(
                renderPDF: { r, recs in world.renderPDF(r, recs) },
                formatDate: world.formatDate,
                formatMoney: world.formatMoney
            )
        }

    public static let salaryEditor = Relay.Empty
        .action(AppAction.prism.salaryEditor).state(\AppState.salaryEditor)
        .environment { (world: World) in
            SalaryEditorFeature.Environment(
                decoder:  world.decoder,
                encoder:  world.encoder,
                readFile: world.readFile,
                saveFile: world.saveFile,
                calendar: world.calendar
            )
        }

    public static let settings = Relay.Empty
        .action(AppAction.prism.settings).state(\AppState.settings)
        .environment { (world: World) in
            SettingsFeature.Environment(
                loadSettings: world.loadSettings,
                saveSettings: world.saveSettings,
                exportDatabase: world.exportDatabase
            )
        }
}
