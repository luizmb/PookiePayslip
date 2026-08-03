import AppDomain
import Core
import CoreFP
import Foundation
import SwiftRex
import SwiftUI
import SwiftRexArchitecture
import FPMacros
import ReactiveConcurrency
import SwiftRexReactiveConcurrency

@Feature(strategy: .observationSimple)
public enum ReportInputFeature {

    // MARK: - State

    /// The report period — the two dates travel together (both resolved at once in `.started`, both edited
    /// only while the screen is shown), so they're one optional group, not two parallel optionals. `nil`
    /// until "now" resolves; present ⇒ the screen operates on the **unwrapped** range.
    public struct DateRange: Sendable, Equatable {
        public var from: Date
        public var to: Date
        public init(from: Date, to: Date) { self.from = from; self.to = to }
    }

    public struct State: Sendable, Equatable {
        public var range: DateRange?       // resolved in `.started`; nil only in the no-arg test default
        public var salary: SalaryRecord?   // loaded from the start month; nil if not configured
        public var estimateFuture: Bool
        public var today: Date?            // nil until the period is first resolved
        public var noSalaryWarning: String?  // derived cache; behavior formats it from World's calendar
        public var weekdayAvgHours: Double
        public var weekendAvgHours: Double
    }

    // MARK: - Action

    public enum Action: Sendable {
        case start
        case started(today: Date, monthStart: Date, salary: SalaryRecord?, noSalaryWarning: String?)
        case salaryReloaded(SalaryRecord?, noSalaryWarning: String?)
        case setFrom(Date)
        case setTo(Date)
        case toggleEstimate
        case generate
        case reportGenerated(PayReport, [WorkDayRecord], from: Date, to: Date)
        case generationFailed
    }

    // MARK: - Environment

    public struct Environment: Sendable {
        let decode: DataDecoder<MonthData>
        let readFile: @Sendable (String) -> Publisher<Data, ReadingError>
        let currentDate: @Sendable () -> Date
        let calendar: @Sendable () -> Calendar
        let calcTax: @Sendable (Decimal, Int, SalaryRecord) -> TaxBreakdown

        public init(
            decoder: any DataDecoderFactory & Sendable,
            readFile: @Sendable @escaping (String) -> Publisher<Data, ReadingError>,
            currentDate: @Sendable @escaping () -> Date,
            calendar: @Sendable @escaping () -> Calendar,
            calcTax: @Sendable @escaping (Decimal, Int, SalaryRecord) -> TaxBreakdown
        ) {
            decode = decoder.dataDecoder(for: MonthData.self)
            self.readFile = readFile
            self.currentDate = currentDate
            self.calendar = calendar
            self.calcTax = calcTax
        }
    }

    // MARK: - ViewModel

        public struct ViewState: Sendable, Equatable {
            public var range: DateRange?   // nil only before "now" is resolved; present ⇒ transposes to the editor
            public var estimateFuture: Bool
            public var showEstimateToggle: Bool
            public var weekdayAvgText: String
            public var weekendAvgText: String
            public var canGenerate: Bool
            // Salary info (loaded from start month)
            public var salaryLabel: String       // "11£/h" or "Not set"
            public var hasSalary: Bool
            // Labels
            public var titleLabel: String
            public var subtitleLabel: String
            public var fromLabel: String
            public var toLabel: String
            public var estimateTitleLabel: String
            public var estimateDescriptionLabel: String
            public var generateButtonLabel: String
            public var noSalaryWarning: String?  // shown if salary not configured
        }

        @Prisms
        public enum ViewAction: Sendable {
            case setFrom(Date)
            case setTo(Date)
            case toggleEstimate
            case generate
            case onAppear
        }

    // MARK: - Mappings

    public static let mapState = Reader<Environment, @MainActor @Sendable (State) -> ViewState> { _ in { state in
        let avgDesc = "Project the remaining days from your averages (\(fmtHours(state.weekdayAvgHours))h / weekday, \(fmtHours(state.weekendAvgHours))h / weekend day)."
        let salaryLabel = state.salary?.displayString ?? "Not set"
        let showEstimate: Bool = { if let today = state.today, let r = state.range { r.to > today } else { false } }()
        let canGenerate: Bool = { if let r = state.range { r.from <= r.to && state.salary != nil } else { false } }()
        return .init(
            range: state.range,
            estimateFuture: state.estimateFuture,
            showEstimateToggle: showEstimate,
            weekdayAvgText: fmtHours(state.weekdayAvgHours),
            weekendAvgText: fmtHours(state.weekendAvgHours),
            canGenerate: canGenerate,
            salaryLabel: salaryLabel,
            hasSalary: state.salary != nil,
            titleLabel: "New report",
            subtitleLabel: "Choose a period. The salary is loaded from the month you start in.",
            fromLabel: "From",
            toLabel: "To",
            estimateTitleLabel: "Estimate future hours",
            estimateDescriptionLabel: "This period runs into the future. \(avgDesc)",
            generateButtonLabel: "Generate report",
            noSalaryWarning: state.noSalaryWarning
        )
    } }

    public static let mapAction = Reader<Environment, @Sendable (ViewAction) -> Action> { _ in { va in
        switch va {
        case .setFrom(let d):  .setFrom(d)
        case .setTo(let d):    .setTo(d)
        case .toggleEstimate:  .toggleEstimate
        case .generate:        .generate
        case .onAppear:        .start
        }
    } }

    // MARK: - Lifecycle

    public static func initialState(with _: Void) -> State {
        .init(
            range: nil,
            salary: nil,
            estimateFuture: false,
            today: nil,
            noSalaryWarning: nil,
            weekdayAvgHours: 0,
            weekendAvgHours: 0
        )
    }

    // MARK: - Behavior

    public static func behavior() -> Behavior<Action, State, Environment> {
        .handle { action, context in
            guard let stateBefore = context.stateBefore else { return .doNothing }
            switch action {
            case .start:
                let priorFrom = stateBefore.range?.from
                return .produce { ctx in
                    let today = ctx.environment.currentDate()
                    let cal = ctx.environment.calendar()
                    let monthStart = startOfMonth(for: today, calendar: cal)
                    // Load the salary for the month the report STARTS in ("loaded from the month you
                    // start in") — on re-entry that's the kept `fromDate`, not today's month. Salary
                    // carries forward: if the start month has none, use the most recent earlier month
                    // that does (a salary set in June still applies to a July period).
                    let salaryMonth = priorFrom ?? monthStart
                    return loadSalaryTask(startMonth: salaryMonth, calendar: cal, env: ctx.environment)
                        .asEffect { result -> Action in
                            let salary: SalaryRecord? = { if case .success(let s) = result { s } else { nil } }()
                            let warning = noSalaryWarning(salary: salary, from: salaryMonth, calendar: cal)
                            return .started(today: today, monthStart: monthStart, salary: salary, noSalaryWarning: warning)
                        }
                }

            case .started(let today, let monthStart, let salary, let warning):
                return .reduce { state in
                    state.today = today
                    state.salary = salary
                    state.noSalaryWarning = warning
                    if state.range == nil { state.range = DateRange(from: monthStart, to: today) }
                    // The estimate toggle is only shown when the period runs into the future.
                    // Clamp the flag so a stale "on" can't leave projection silently active
                    // with the checkbox hidden (e.g. on re-entry once `today` has advanced).
                    if let r = state.range, r.to <= today { state.estimateFuture = false }
                }

            case .salaryReloaded(let salary, let warning):
                // Salary-only refresh after the start month changes — must NOT touch `today`.
                return .reduce { state in
                    state.salary = salary
                    state.noSalaryWarning = warning
                }

            case .setFrom(let d):
                return .reduce { state in
                    state.range?.from = d
                    if state.estimateFuture, let today = state.today, d > today { state.estimateFuture = false }
                }
                .produce { ctx in
                    // Reload salary from the new start month — salary only, leaving `today` intact.
                    // Same carry-forward rule as `.start`: fall back to the most recent earlier month.
                    let cal = ctx.environment.calendar()
                    return loadSalaryTask(startMonth: startOfMonth(for: d, calendar: cal), calendar: cal, env: ctx.environment)
                        .asEffect { result -> Action in
                            let salary: SalaryRecord? = { if case .success(let s) = result { s } else { nil } }()
                            return .salaryReloaded(salary, noSalaryWarning: noSalaryWarning(salary: salary, from: d, calendar: cal))
                        }
                }

            case .setTo(let d):
                return .reduce { state in
                    state.range?.to = d
                    if let today = state.today, d <= today { state.estimateFuture = false }
                }

            case .toggleEstimate:
                return .reduce { $0.estimateFuture.toggle() }

            case .generate:
                guard let range = stateBefore.range else { return .doNothing }
                let from = range.from
                let to = range.to
                let today    = stateBefore.today
                // Only project when the period actually runs into the future — i.e. exactly when
                // the toggle is shown. Guards against a stale `estimateFuture` flag (see bug 1).
                let estimate = stateBefore.estimateFuture && (today.map { to > $0 } ?? false)
                guard let resolvedSalary = stateBefore.salary else { return .doNothing }
                return .produce { ctx in
                    let cal = ctx.environment.calendar()
                    return loadAllRecordsTask(from: from, to: to, calendar: cal, env: ctx.environment)
                        .asEffect { result -> Action in
                            let allRecords: [WorkDayRecord]
                            if case .success(let r) = result { allRecords = r } else { allRecords = [] }
                            // The PDF day-by-day page lists `records` verbatim, so restrict them
                            // to the report's [from, to] range — otherwise other months loaded
                            // from the same files leak onto page 2 (bug 3 / 4).
                            let lo = cal.startOfDay(for: from)
                            let hi = cal.startOfDay(for: to)
                            let records = allRecords.filter {
                                let day = cal.startOfDay(for: $0.date)
                                return day >= lo && day <= hi
                            }
                            return .reportGenerated(
                                buildReport(records: records, from: from, to: to, today: today ?? to,
                                            calendar: cal, salary: resolvedSalary, estimate: estimate,
                                            calcTax: ctx.environment.calcTax),
                                records,
                                from: from, to: to
                            )
                        }
                }

            case .reportGenerated(let report, _, _, _):
                // ReportInputFeature handles only its own state (averages)
                // AppFeature's fold pushes the result screen, carrying this report with it
                return .reduce { state in
                    state.weekdayAvgHours = report.weekdayAvgHours
                    state.weekendAvgHours = report.weekendAvgHours
                }

            case .generationFailed:
                return .doNothing
            }
        }
    }

    public typealias Content = ReportInputView
}

// MARK: - Private helpers

private func loadAllRecordsTask(
    from: Date,
    to: Date,
    calendar cal: Calendar,
    env: ReportInputFeature.Environment
) -> Publisher<[WorkDayRecord], Never> {
    var months: Set<String> = []
    var cursor = startOfMonth(for: from, calendar: cal)
    let end = startOfMonth(for: to, calendar: cal)
    while cursor <= end {
        months.insert(monthFilename(for: cursor, calendar: cal))
        cursor = cal.date(byAdding: .month, value: 1, to: cursor) ?? cursor
    }
    let tasks: [Publisher<[WorkDayRecord], Never>] = months.map { filename in
        env.readFile(filename)
            .map { data -> [WorkDayRecord] in
                if case .success(let md) = env.decode(data) { md.records } else { [] }
            }
            .replaceError(with: [])   // missing month file → no records
    }
    // Run every month read, gather each month's array, then flatten into one list.
    return Publisher<[WorkDayRecord], Never>.merge(tasks)
        .collect()
        .map { $0.flatMap { $0 } }
}

// Resolves the salary for a period by carrying it forward: the start month's salary, or —
// if that month has none — the salary of the most recent earlier month that has one. Bounds the
// look-back to 2 years so an unconfigured app doesn't read unbounded files. Never looks into the
// future (a salary set for a later month must not apply to an earlier period).
private func loadSalaryTask(
    startMonth: Date,
    calendar cal: Calendar,
    env: ReportInputFeature.Environment
) -> Publisher<SalaryRecord?, Never> {
    var months: [Date] = []
    var cursor = startOfMonth(for: startMonth, calendar: cal)
    for _ in 0..<24 {
        months.append(cursor)
        cursor = cal.date(byAdding: .month, value: -1, to: cursor) ?? cursor
    }
    let tasks: [Publisher<MonthSalary, Never>] = months.map { month in
        env.readFile(monthFilename(for: month, calendar: cal))
            .map { data -> MonthSalary in
                if case .success(let md) = env.decode(data) { MonthSalary(month: month, salary: md.salary) }
                else { MonthSalary(month: month, salary: nil) }
            }
            .replaceError(with: MonthSalary(month: month, salary: nil))
    }
    // Gather every month's salary, then pick the most recent month that actually has one.
    return Publisher<MonthSalary, Never>.merge(tasks)
        .collect()
        .map { found in found.filter { $0.salary != nil }.max { $0.month < $1.month }?.salary ?? nil }
}

private struct MonthSalary: Sendable {
    let month: Date
    let salary: SalaryRecord?
}

private func buildReport(
    records: [WorkDayRecord],
    from: Date,
    to: Date,
    today: Date,
    calendar cal: Calendar,
    salary: SalaryRecord,
    estimate: Bool,
    calcTax: @Sendable (Decimal, Int, SalaryRecord) -> TaxBreakdown
) -> PayReport {
    // Estimate OFF must never project and must not depend on `today` at all: anchor the boundary the
    // day AFTER `to` so every day in the selected period counts as actual (past). Only estimate ON
    // uses the real `today` — the boundary that separates recorded past days from projected future ones.
    let boundary = estimate ? today : (cal.date(byAdding: .day, value: 1, to: to) ?? to)
    let est = buildEstimate(records: records, periodStart: from, periodEnd: to, today: boundary, calendar: cal)

    let totalHours = est.totalHours
    let periodDays = max(1, cal.dateComponents([.day], from: from, to: to).day ?? 1) + 1
    let gross = salary.grossPay(hoursWorked: totalHours, periodDays: periodDays)
    let tax = calcTax(gross, periodDays, salary)

    return PayReport(
        totalHours: totalHours,
        isEstimated: estimate && est.projectedHours > 0,
        weekdayAvgHours: est.weekdayAvgHours,
        weekendAvgHours: est.weekendAvgHours,
        projectedHours: est.projectedHours,
        projectedDays: est.projectedDays,
        incompleteDays: est.incompleteDays,
        grossPay: gross,
        niDeduction: tax.ni,
        pensionDeduction: tax.pension,
        incomeTaxDeduction: tax.incomeTax,
        studentLoanDeduction: tax.studentLoan,
        netPay: tax.net,
        noWeekdayDataWarning: est.noWeekdayDataWarning,
        periodDays: periodDays,
        salary: salary
    )
}

// Formats the "no salary set" warning from World's calendar (behavior-side; kept out of mapState).
private func noSalaryWarning(salary: SalaryRecord?, from: Date, calendar: Calendar) -> String? {
    guard salary == nil else { return nil }
    // "MM/yyyy" is numeric → month/year of `from` via the calendar; no DateFormatter/locale.
    let m = calendar.component(.month, from: from)
    let y = calendar.component(.year, from: from)
    return "Month \(String(format: "%02d/%04d", m, y)) doesn't have a salary set."
}

private func fmtHours(_ h: Double) -> String {
    let rounded = (h * 10).rounded() / 10
    if rounded.truncatingRemainder(dividingBy: 1) == 0 { return "\(Int(rounded))" }
    return "\(rounded)"
}
