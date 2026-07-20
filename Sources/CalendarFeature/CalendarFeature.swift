import AppDomain
import CoreFP
import Foundation
import Core
import SwiftRex
import SwiftUI
import SwiftRexArchitecture
import ReactiveConcurrency
import SwiftRexReactiveConcurrency

@Feature(strategy: .observationSimple)
public enum CalendarFeature {

    // MARK: - State

    public struct State: Sendable, Equatable, Codable {
        // Source of truth — only these change via Actions:
        public var currentMonth: Date?      // nil until first load; the viewed month
        public var today: Date?             // nil until loaded; drives the "today" highlight
        public var workDays: [Date: WorkDayRecord]
        public var salary: SalaryRecord?        // current month's salary (nil = not set)
        // Derived view-data, computed by the behavior from World's calendar (which can change
        // without an Action). nil until the first `.start` rerender.
        public var rendered: Rendered?
    }

    /// Everything the calendar view needs that depends on the (Action-invisible) system calendar —
    /// grid, weekday labels, month title/earnings. Re-derived by the behavior; a discardable cache.
    public struct Rendered: Sendable, Equatable, Codable {
        public var monthTitle: String
        public var expectedEarningsText: String?
        public var weekdayLabels: [String]
        public var monthMinutes: Int
        public var days: [DayCell]
    }

    public struct DayCell: Sendable, Equatable, Codable {
        public var date: Date
        public var dayNumber: String
        public var hoursText: String?
        public var isInProgress: Bool
        public var isToday: Bool
        public var isWeekend: Bool
        public var isInMonth: Bool
    }

    // MARK: - Action

    public enum Action: Sendable {
        case start
        case prevMonth
        case nextMonth
        case selectDay(Date)
        case openReport
        case startLoaded(today: Date, month: Date, result: Result<MonthData, LoadError>)
        case monthChanged(Date)             // prev/next resolved the new month via World's calendar
        case monthLoaded(Result<MonthData, LoadError>)
        case openSalaryEditor
        case openSettings
        case salaryUpdated(SalaryRecord)
        case recordUpdated(WorkDayRecord)   // pushed by bridgeBehavior after DayDetail saves
        case setRendered(Rendered)          // behavior-computed grid/labels/title/earnings
    }

    // MARK: - Environment

    public struct Environment: Sendable {
        let decode: DataDecoder<MonthData>
        let readFile: @Sendable (String) -> Publisher<Data, ReadingError>
        let currentDate: @Sendable () -> Date
        let calendar: @Sendable () -> Calendar  // lazy thunk — evaluated inside Effect
        let formatDate: @Sendable (Date, String) -> String
        let formatMoney: @Sendable (Decimal, Int) -> String

        public init(
            decoder: any DataDecoderFactory,
            readFile: @Sendable @escaping (String) -> Publisher<Data, ReadingError>,
            currentDate: @Sendable @escaping () -> Date,
            calendar: @Sendable @escaping () -> Calendar,
            formatDate: @Sendable @escaping (Date, String) -> String,
            formatMoney: @Sendable @escaping (Decimal, Int) -> String
        ) {
            decode = decoder.dataDecoder(for: MonthData.self)
            self.readFile = readFile
            self.currentDate = currentDate
            self.calendar = calendar
            self.formatDate = formatDate
            self.formatMoney = formatMoney
        }
    }

    // MARK: - ViewModel

        public struct ViewState: Sendable, Equatable {
            public var monthTitle: String
            public var monthHoursText: String
            public var monthHoursSuffix: String
            public var monthTotalLine1: String
            public var monthTotalLine2: String
            public var weekdayLabels: [String]
            public var reportButtonLabel: String
            public var salaryChipLabel: String       // "11£/h" / "2,500£/mo" / nil→"Set salary"
            public var expectedEarningsText: String? // "~£350 earned" — nil when no salary set
            public var days: [DayCellModel]
        }

        public struct DayCellModel: Sendable, Equatable, Identifiable {
            public var id: Date
            public var dayNumber: String
            public var hoursText: String?
            public var isInProgress: Bool
            public var isToday: Bool
            public var isWeekend: Bool
            public var isInMonth: Bool
        }

        public enum ViewAction: Sendable {
            case prevMonth
            case nextMonth
            case dayTapped(Date)
            case reportTapped
            case salaryTapped
            case settingsTapped
            case onAppear
        }

    // MARK: - Mappings

    public static let mapState = Reader<Environment, @MainActor @Sendable (State) -> ViewState> { _ in buildViewState }
    public static let mapAction = Reader<Environment, @Sendable (ViewAction) -> Action> { _ in mapViewAction }

    // MARK: - Lifecycle

    public static func initialState(with _: Void) -> State {
        .init(currentMonth: nil, today: nil, workDays: [:], salary: nil, rendered: nil)
    }

    // MARK: - Behavior

    public static func behavior() -> Behavior<Action, State, Environment> {
        .handle { action, context in
            guard let stateBefore = context.stateBefore else { return .doNothing }
            switch action {
            case .start:
                // `start` re-fires every time the calendar re-appears (e.g. popping back from a
                // day). Keep the month the user is viewing; only default to today's month on the
                // very first load. Otherwise editing a day in another month snaps back to today.
                let viewing = stateBefore.currentMonth
                return .produce { ctx in
                    let today = ctx.environment.currentDate()
                    let cal = ctx.environment.calendar()
                    let month = viewing ?? startOfMonth(for: today, calendar: cal)
                    return loadMonthTask(filename: monthFilename(for: month, calendar: cal), env: ctx.environment)
                        .asEffect { result in .startLoaded(today: today, month: month, result: result) }
                }

            case .startLoaded(let today, let month, let result):
                return .reduce { state in
                    state.today = today
                    state.currentMonth = month
                    if case .success(let data) = result {
                        for r in data.records { state.workDays[r.date] = r }
                        state.salary = data.salary
                    }
                }
                .produce(rerenderEffect)

            case .prevMonth:
                guard let current = stateBefore.currentMonth else { return .doNothing }
                return .produce { ctx in
                    let newMonth = ctx.environment.calendar().date(byAdding: .month, value: -1, to: current) ?? current
                    return Publisher<Action, Never>.just(.monthChanged(newMonth)).asEffect()
                }

            case .nextMonth:
                guard let current = stateBefore.currentMonth else { return .doNothing }
                return .produce { ctx in
                    let newMonth = ctx.environment.calendar().date(byAdding: .month, value: 1, to: current) ?? current
                    return Publisher<Action, Never>.just(.monthChanged(newMonth)).asEffect()
                }

            case .monthChanged(let newMonth):
                return .reduce { $0.currentMonth = newMonth }
                    .produce { ctx in
                        loadMonthTask(filename: monthFilename(for: newMonth, calendar: ctx.environment.calendar()), env: ctx.environment)
                            .asEffect(Action.monthLoaded)   // monthLoaded re-renders the grid
                    }

            case .monthLoaded(.success(let data)):
                return .reduce { state in
                    for r in data.records { state.workDays[r.date] = r }
                    state.salary = data.salary
                }
                .produce(rerenderEffect)

            case .monthLoaded(.failure):
                return .produce(rerenderEffect)   // month didn't load, but the title still needs the new month

            case .recordUpdated(let record):
                return .reduce { $0.workDays[record.date] = record }
                    .produce(rerenderEffect)

            case .salaryUpdated(let salary):
                return .reduce { $0.salary = salary }
                    .produce(rerenderEffect)

            case .setRendered(let rendered):
                return .reduce { $0.rendered = rendered }

            case .selectDay, .openReport, .openSalaryEditor, .openSettings:
                return .doNothing  // handled by bridgeBehavior in AppCore
            }
        }
    }

    public typealias Content = CalendarView
}

// MARK: - Private helpers

private func loadMonthTask(
    filename: String,
    env: CalendarFeature.Environment
) -> Publisher<MonthData, LoadError> {
    env.readFile(filename)
        .mapError(LoadError.reading)
        .flatMap { data in
            env.decode(data).mapError(LoadError.decoding).publisher
        }
        .catch { error -> Publisher<MonthData, LoadError> in
            // A missing month file is normal — treat it as an empty month, not an error.
            if case .reading(.fileNotFound) = error { .just(MonthData()) } else { .fail(error) }
        }
}

// Re-derives ALL calendar-dependent view-data from the *post-mutation* state (read on the main
// actor) + World's current calendar, then stores it via `.setRendered`. Fired after any action that
// changes the month, work days, or salary — and on `.start`, which picks up any external calendar
// change since a settings change never dispatches an Action.
private func rerenderEffect(
    _ ctx: PostReducerContext<CalendarFeature.State, CalendarFeature.Environment>
) -> Effect<CalendarFeature.Action> {
    Publisher<CalendarFeature.Action, Never>.future { () async -> Result<CalendarFeature.Action, Never> in
        let state = await MainActor.run(body: { ctx.liveState })
        return .success(.setRendered(computeRendered(state: state, env: ctx.environment)))
    }
    .asEffect()
}

// The old `buildViewState` body — moved into the behavior because it needs World's calendar.
// `internal` so tests can exercise the pure grid computation directly.
func computeRendered(
    state: CalendarFeature.State?,
    env: CalendarFeature.Environment
) -> CalendarFeature.Rendered {
    let cal = env.calendar()
    let symbols = cal.shortWeekdaySymbols  // Sun … Sat
    let weekdayLabels = Array(symbols[1...]) + [symbols[0]]   // Mon-first

    guard let state, let currentMonth = state.currentMonth else {
        return .init(monthTitle: "", expectedEarningsText: nil, weekdayLabels: weekdayLabels, monthMinutes: 0, days: [])
    }

    let year = cal.component(.year, from: currentMonth)
    let monthIdx = cal.component(.month, from: currentMonth)
    let monthMinutes = state.workDays.values
        .filter { cal.component(.year, from: $0.date) == year && cal.component(.month, from: $0.date) == monthIdx }
        .compactMap(\.workedMinutes)
        .reduce(0, +)

    let mondayOffset = (cal.component(.weekday, from: currentMonth) + 5) % 7
    let gridStart = cal.date(byAdding: .day, value: -mondayOffset, to: currentMonth) ?? currentMonth
    var days: [CalendarFeature.DayCell] = []
    for i in 0 ..< 42 {
        guard let date = cal.date(byAdding: .day, value: i, to: gridStart) else { break }
        let inMonth = cal.component(.month, from: date) == monthIdx
        if i >= 35 && !inMonth { break }
        let rec = state.workDays[cal.startOfDay(for: date)]
        days.append(.init(
            date: date,
            dayNumber: "\(cal.component(.day, from: date))",
            hoursText: rec.flatMap(\.workedMinutes).map(formatHoursDecimal),
            isInProgress: rec?.isStarted == true && rec?.isComplete == false,
            isToday: state.today.map { cal.isDate(date, inSameDayAs: $0) } ?? false,
            isWeekend: AppDomain.isWeekend(date, calendar: cal),
            isInMonth: inMonth
        ))
    }

    return .init(
        monthTitle: env.formatDate(currentMonth, "MMMM yyyy"),
        expectedEarningsText: expectedEarnings(salary: state.salary, monthMinutes: monthMinutes, formatMoney: env.formatMoney),
        weekdayLabels: weekdayLabels,
        monthMinutes: monthMinutes,
        days: days
    )
}

// Pure aggregate: this month's worked hours × the salary → "~£350 expected" (nil when no salary).
private func expectedEarnings(
    salary: SalaryRecord?,
    monthMinutes: Int,
    formatMoney: @Sendable (Decimal, Int) -> String
) -> String? {
    guard let salary else { return nil }
    let gross: Decimal
    switch salary.periodicity {
    case .hourly:  gross = Decimal(Double(monthMinutes) / 60.0) * salary.amount
    case .monthly: gross = salary.amount
    case .yearly:  gross = salary.amount / 12
    }
    return "~\(formatMoney(gross, 0)) expected"
}

// Pure presentation: reads the behavior-computed `rendered` cache; touches no calendar.
private let buildViewState: @MainActor @Sendable (CalendarFeature.State) -> CalendarFeature.ViewState = { state in
    let r = state.rendered
    let days = (r?.days ?? []).map {
        CalendarFeature.DayCellModel(
            id: $0.date, dayNumber: $0.dayNumber, hoursText: $0.hoursText,
            isInProgress: $0.isInProgress, isToday: $0.isToday, isWeekend: $0.isWeekend, isInMonth: $0.isInMonth
        )
    }
    return .init(
        monthTitle: r?.monthTitle ?? "",
        monthHoursText: formatHoursDecimal(r?.monthMinutes ?? 0),
        monthHoursSuffix: "h",
        monthTotalLine1: "worked",
        monthTotalLine2: "this month",
        weekdayLabels: r?.weekdayLabels ?? [],
        reportButtonLabel: "Report",
        salaryChipLabel: state.salary?.displayString ?? "Set salary",
        expectedEarningsText: r?.expectedEarningsText,
        days: days
    )
}

private let mapViewAction: @Sendable (CalendarFeature.ViewAction) -> CalendarFeature.Action = { va in
    switch va {
    case .prevMonth:        .prevMonth
    case .nextMonth:        .nextMonth
    case .dayTapped(let d): .selectDay(d)
    case .reportTapped:     .openReport
    case .salaryTapped:     .openSalaryEditor
    case .settingsTapped:   .openSettings
    case .onAppear:         .start
    }
}

private func formatHoursDecimal(_ minutes: Int) -> String {
    let h = Double(minutes) / 60.0
    let rounded = (h * 10).rounded() / 10
    if rounded.truncatingRemainder(dividingBy: 1) == 0 { return "\(Int(rounded))" }
    return "\(rounded)"
}
