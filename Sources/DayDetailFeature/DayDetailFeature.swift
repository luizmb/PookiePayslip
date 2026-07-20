import AppDomain
import Core
import CoreFP
import Foundation
import SwiftRex
import SwiftUI
import SwiftRexArchitecture
import ReactiveConcurrency
import SwiftRexReactiveConcurrency

// Default break added by "Add break": a 30-minute lunch slot the user can adjust or re-length.
// (These will move to injected user defaults once the Settings screen lands.)
let defaultBreakStart = TimeOfDay(hour: 12, minute: 30)
let defaultBreakMinutes = 30

@Feature(strategy: .observationSimple)
public enum DayDetailFeature {

    // MARK: - State

    public struct State: Sendable, Equatable, Codable {
        public var date: Date?              // nil until a day is selected/loaded
        public var today: Date?             // set on dayLoaded; used to decide "future" display
        public var record: WorkDayRecord?   // nil until a day is loaded — no placeholder sentinel
        public var defaults: AppSettings    // tap/add-break defaults, loaded from settings.json
        public var dateTitle: String        // derived cache of the formatted "EEEE, d MMMM" header
    }

    // MARK: - Action

    public enum Action: Sendable {
        case start                             // dispatched by view onAppear; loads state.date
        case loadDay(Date)                     // explicit load for a specific date
        case dayLoaded(WorkDayRecord, today: Date, dateTitle: String)
        case settingsLoaded(AppSettings)
        case setStart(TimeOfDay?)
        case setEnd(TimeOfDay?)
        case setStartNow                   // behavior resolves "now" via env.currentDate()
        case setEndNow
        case addBreak
        case removeBreak(Int)
        case setBreakLength(Int, Int)          // break index, length in minutes (sets end = start + length)
        case setBreakStart(Int, TimeOfDay?)
        case setBreakEnd(Int, TimeOfDay?)
        case setBreakStartNow(Int)
        case setBreakEndNow(Int)
        case saveCompleted(WorkDayRecord)   // auto-save finished — carries saved record for calendar sync
        case saveFailed(PersistError)
        case prevDay
        case nextDay
        case done            // user explicitly pressed back → bridgeBehavior pops
    }

    // MARK: - Environment

    public struct Environment: Sendable {
        let decode: DataDecoder<MonthData>
        let encode: DataEncoder<MonthData>
        let readFile: @Sendable (String) -> Publisher<Data, ReadingError>
        let saveFile: @Sendable (Data, String) -> Publisher<Void, SavingError>
        let currentDate: @Sendable () -> Date
        let newID: @Sendable () -> UUID
        let calendar: @Sendable () -> Calendar
        let dayBefore: @Sendable (Date) -> Date
        let dayAfter:  @Sendable (Date) -> Date
        let loadSettings: @Sendable () -> Publisher<AppSettings, Never>
        let formatDate: @Sendable (Date, String) -> String

        public init(
            decoder: any DataDecoderFactory,
            encoder: any DataEncoderFactory,
            readFile: @Sendable @escaping (String) -> Publisher<Data, ReadingError>,
            saveFile: @Sendable @escaping (Data, String) -> Publisher<Void, SavingError>,
            currentDate: @Sendable @escaping () -> Date,
            newID: @Sendable @escaping () -> UUID,
            calendar: @Sendable @escaping () -> Calendar,
            dayBefore: @Sendable @escaping (Date) -> Date,
            dayAfter:  @Sendable @escaping (Date) -> Date,
            loadSettings: @Sendable @escaping () -> Publisher<AppSettings, Never>,
            formatDate: @Sendable @escaping (Date, String) -> String
        ) {
            decode = decoder.dataDecoder(for: MonthData.self)
            encode = encoder.dataEncoder(for: MonthData.self)
            self.readFile = readFile
            self.saveFile = saveFile
            self.currentDate = currentDate
            self.newID = newID
            self.calendar = calendar
            self.dayBefore = dayBefore
            self.dayAfter  = dayAfter
            self.loadSettings = loadSettings
            self.formatDate = formatDate
        }
    }

    // MARK: - View state & actions

    public struct ViewState: Sendable, Equatable {
            public var dateTitle: String
            public var workedHoursText: String
            public var statusText: String
            public var startFieldLabel: String
            public var endFieldLabel: String
            public var addBreakLabel: String
            public var nowButtonLabel: String
            public var timePlaceholder: String
            public var doneButtonLabel: String
            public var startTime: TimeOfDay?
            public var endTime: TimeOfDay?
            public var breaks: [BreakRowModel]
            public var isFuture: Bool
            public var totalBreakText: String?
            // Defaults committed when a --:-- field is tapped (from Settings)
            public var defaultStart: TimeOfDay
            public var defaultEnd: TimeOfDay
        }

        public struct BreakRowModel: Sendable, Equatable, Identifiable {
            public var id: Int
            public var label: String                // "Break 1" / "Break 1 · ongoing"
            public var startTime: TimeOfDay?
            public var endTime: TimeOfDay?
            public var durationMinutes: Int?        // nil while a break is open (no end yet)
        }

        public enum ViewAction: Sendable {
            case setStart(TimeOfDay?)
            case setEnd(TimeOfDay?)
            case setStartNow
            case setEndNow
            case addBreak
            case removeBreak(Int)
            case setBreakLength(Int, Int)
            case setBreakStart(Int, TimeOfDay?)
            case setBreakEnd(Int, TimeOfDay?)
            case setBreakStartNow(Int)
            case setBreakEndNow(Int)
            case prevDay
            case nextDay
            case done
            case onAppear
        }

    // MARK: - Mappings

    public static let mapState = Reader<Environment, @MainActor @Sendable (State) -> ViewState> { _ in buildViewState }
    public static let mapAction = Reader<Environment, @Sendable (ViewAction) -> Action> { _ in { $0.asAction } }

    // MARK: - Lifecycle

    public static func initialState(with _: Void) -> State {
        .init(date: nil, today: nil, record: nil, defaults: .default, dateTitle: "")
    }

    // MARK: - Behavior

    public static func behavior() -> Behavior<Action, State, Environment> {
        .handle { action, context in
            guard let stateBefore = context.stateBefore else { return .doNothing }
            let currentRecord = stateBefore.record

            switch action {
            case .loadDay(let date):
                return .produce { ctx in
                    let today = ctx.environment.currentDate()
                    let newID = ctx.environment.newID()
                    return loadRecordTask(date: date, env: ctx.environment, newID: newID)
                        .asEffect { result -> Action in
                            switch result {
                            case .success(let r): return .dayLoaded(r, today: today, dateTitle: ctx.environment.formatDate(r.date, "EEEE, d MMMM"))
                            case .failure: return .dayLoaded(WorkDayRecord(id: newID, date: date), today: today, dateTitle: ctx.environment.formatDate(date, "EEEE, d MMMM"))
                            }
                        }
                }

            case .dayLoaded(let record, let today, let dateTitle):
                return .reduce { state in
                    state.date = record.date
                    state.today = today
                    state.record = record
                    state.dateTitle = dateTitle
                }

            case .settingsLoaded(let settings):
                return .reduce { $0.defaults = settings }

            case .setStart(let t):
                guard var updated = currentRecord else { return .doNothing }
                updated.startTime = t
                return .reduce { $0.record?.startTime = t }
                    .produce(saveEffect(updated))

            case .setEnd(let t):
                guard var updated = currentRecord else { return .doNothing }
                updated.endTime = t
                return .reduce { $0.record?.endTime = t }
                    .produce(saveEffect(updated))

            case .setStartNow:
                return .produce { ctx in
                    let tod = timeOfDay(from: ctx.environment.currentDate(), calendar: ctx.environment.calendar())
                    return Publisher<Action, Never>.just(.setStart(tod)).asEffect()
                }

            case .setEndNow:
                return .produce { ctx in
                    let tod = timeOfDay(from: ctx.environment.currentDate(), calendar: ctx.environment.calendar())
                    return Publisher<Action, Never>.just(.setEnd(tod)).asEffect()
                }

            case .addBreak:
                let newBreak = WorkBreakRecord(
                    startTime: defaultBreakStart,
                    endTime: defaultBreakStart.adding(minutes: stateBefore.defaults.defaultBreakMinutes)
                )
                guard var updated = currentRecord else { return .doNothing }
                updated.breaks.append(newBreak)
                return .reduce { $0.record?.breaks.append(newBreak) }
                    .produce(saveEffect(updated))

            case .setBreakLength(let i, let minutes):
                // Re-length a break from a single value: keep the start (default it if unset) and
                // move the end to start + minutes. Lets the user log "30 min" without touching times.
                let relength: @Sendable (inout WorkBreakRecord) -> Void = { b in
                    let start = b.startTime ?? defaultBreakStart
                    b.startTime = start
                    b.endTime = start.adding(minutes: minutes)
                }
                guard var updated = currentRecord else { return .doNothing }
                [WorkBreakRecord].ix(i).tryModifyMut(&updated.breaks, relength)
                return .reduce { state in
                    guard var record = state.record else { return }
                    [WorkBreakRecord].ix(i).tryModifyMut(&record.breaks, relength)
                    state.record = record
                }
                .produce(saveEffect(updated))

            case .removeBreak(let i):
                // ix is a no-op when i is out of bounds — no explicit contains check needed
                guard var updated = currentRecord else { return .doNothing }
                if updated.breaks.indices.contains(i) { updated.breaks.remove(at: i) }
                return .reduce { state in
                    guard var record = state.record, record.breaks.indices.contains(i) else { return }
                    record.breaks.remove(at: i)
                    state.record = record
                }
                .produce(saveEffect(updated))

            case .setBreakStart(let i, let t):
                guard var updated = currentRecord else { return .doNothing }
                [WorkBreakRecord].ix(i).tryModifyMut(&updated.breaks) { $0.startTime = t }
                return .reduce { state in
                    guard var record = state.record else { return }
                    [WorkBreakRecord].ix(i).tryModifyMut(&record.breaks) { $0.startTime = t }
                    state.record = record
                }
                .produce(saveEffect(updated))

            case .setBreakEnd(let i, let t):
                guard var updated = currentRecord else { return .doNothing }
                [WorkBreakRecord].ix(i).tryModifyMut(&updated.breaks) { $0.endTime = t }
                return .reduce { state in
                    guard var record = state.record else { return }
                    [WorkBreakRecord].ix(i).tryModifyMut(&record.breaks) { $0.endTime = t }
                    state.record = record
                }
                .produce(saveEffect(updated))

            case .setBreakStartNow(let i):
                return .produce { ctx in
                    let tod = timeOfDay(from: ctx.environment.currentDate(), calendar: ctx.environment.calendar())
                    return Publisher<Action, Never>.just(.setBreakStart(i, tod)).asEffect()
                }

            case .setBreakEndNow(let i):
                return .produce { ctx in
                    let tod = timeOfDay(from: ctx.environment.currentDate(), calendar: ctx.environment.calendar())
                    return Publisher<Action, Never>.just(.setBreakEnd(i, tod)).asEffect()
                }

            case .start:
                guard let date = stateBefore.date else { return .doNothing }
                return .produce { ctx in
                    let today = ctx.environment.currentDate()
                    let newID = ctx.environment.newID()
                    let dayLoad = loadRecordTask(date: date, env: ctx.environment, newID: newID)
                        .asEffect { result -> Action in
                            switch result {
                            case .success(let r): return .dayLoaded(r, today: today, dateTitle: ctx.environment.formatDate(r.date, "EEEE, d MMMM"))
                            case .failure: return .dayLoaded(WorkDayRecord(id: newID, date: date), today: today, dateTitle: ctx.environment.formatDate(date, "EEEE, d MMMM"))
                            }
                        }
                    // Also refresh the tap/add-break defaults from Settings on every appearance.
                    let settingsLoad = ctx.environment.loadSettings()
                        .asEffect { result -> Action in
                            if case .success(let s) = result { .settingsLoaded(s) } else { .settingsLoaded(.default) }
                        }
                    return .combine(dayLoad, settingsLoad)
                }

            case .prevDay:
                guard let current = stateBefore.date else { return .doNothing }
                return .produce { ctx in
                    let prevDate = ctx.environment.dayBefore(current)
                    let today = ctx.environment.currentDate()
                    let newID = ctx.environment.newID()
                    return loadRecordTask(date: prevDate, env: ctx.environment, newID: newID)
                        .asEffect { result -> Action in
                            switch result {
                            case .success(let r): return .dayLoaded(r, today: today, dateTitle: ctx.environment.formatDate(r.date, "EEEE, d MMMM"))
                            case .failure: return .dayLoaded(WorkDayRecord(id: newID, date: prevDate), today: today, dateTitle: ctx.environment.formatDate(prevDate, "EEEE, d MMMM"))
                            }
                        }
                }

            case .nextDay:
                guard let current = stateBefore.date else { return .doNothing }
                return .produce { ctx in
                    let nextDate = ctx.environment.dayAfter(current)
                    let today = ctx.environment.currentDate()
                    let newID = ctx.environment.newID()
                    return loadRecordTask(date: nextDate, env: ctx.environment, newID: newID)
                        .asEffect { result -> Action in
                            switch result {
                            case .success(let r): return .dayLoaded(r, today: today, dateTitle: ctx.environment.formatDate(r.date, "EEEE, d MMMM"))
                            case .failure: return .dayLoaded(WorkDayRecord(id: newID, date: nextDate), today: today, dateTitle: ctx.environment.formatDate(nextDate, "EEEE, d MMMM"))
                            }
                        }
                }

            case .saveCompleted, .saveFailed, .done:
                return .doNothing  // bridgeBehavior routes .saveCompleted to calendar; .done + nav handled there
            }
        }
    }

    public typealias Content = DayDetailView
}

// MARK: - Private helpers

private func timeOfDay(from date: Date, calendar: Calendar) -> TimeOfDay {
    TimeOfDay(hour: calendar.component(.hour, from: date), minute: calendar.component(.minute, from: date))
}

private func loadRecordTask(
    date: Date,
    env: DayDetailFeature.Environment,
    newID: UUID
) -> Publisher<WorkDayRecord, LoadError> {
    let cal = env.calendar()
    let filename = monthFilename(for: date, calendar: cal)
    return env.readFile(filename)
        .mapError(LoadError.reading)
        .flatMap { data -> Publisher<WorkDayRecord, LoadError> in
            env.decode(data)
                .mapError(LoadError.decoding)
                .flatMap { monthData in
                    monthData.records.first { cal.isDate($0.date, inSameDayAs: date) }
                        .map(Result.success)
                        ?? .failure(LoadError.reading(.fileNotFound(filename: filename)))
                }
                .publisher
        }
}

// Produces a save effect for the given record. `record` is captured from pre-mutation state
// with the mutation already applied, so we don't need to read post-mutation state asynchronously.
private func saveEffect(
    _ record: WorkDayRecord?
) -> @Sendable (PostReducerContext<DayDetailFeature.State, DayDetailFeature.Environment>) -> Effect<DayDetailFeature.Action> {
    { ctx in
        guard let record else { return .empty }
        let cal = ctx.environment.calendar()
        let filename = monthFilename(for: record.date, calendar: cal)
        return ctx.environment.readFile(filename)
            .map { data -> MonthData in
                if case .success(let monthData) = ctx.environment.decode(data) { monthData } else { MonthData() }
            }
            .replaceError(with: MonthData())   // unreadable month → rebuild from this record alone
            .setFailureType(to: SavingError.self)
            .flatMap { monthData -> Publisher<Void, SavingError> in
                var updated = monthData.records.filter { !cal.isDate($0.date, inSameDayAs: record.date) }
                if record.isStarted { updated.append(record) }
                let toSave = MonthData(records: updated, salary: monthData.salary)
                switch ctx.environment.encode(toSave) {
                case .failure(let e):
                    return .fail(.ioError(filename: filename, underlying: e))
                case .success(let data):
                    return ctx.environment.saveFile(data, filename)
                }
            }
            .asEffect { result in
                if case .failure(let e) = result { .saveFailed(.saving(e)) } else { .saveCompleted(record) }
            }
    }
}

private let buildViewState: @MainActor @Sendable (DayDetailFeature.State) -> DayDetailFeature.ViewState = { state in
    let title = state.dateTitle   // formatted in the behavior; "" until a day is loaded
    let isFuture: Bool = { if let t = state.today, let d = state.date { d > t } else { false } }()

    let breaks = state.record?.breaks ?? []
    let workedText: String
    let statusText: String
    if let mins = state.record?.workedMinutes {
        let h = mins / 60
        let m = mins % 60
        workedText = m == 0 ? "\(h)h" : "\(h)h \(m)m"
        statusText = "worked"
    } else if state.record?.isStarted == true {
        workedText = ""
        statusText = isFuture
            ? "Planned — add a finish time"
            : "In progress — add a finish time"
    } else {
        workedText = ""
        statusText = "Nothing logged yet"
    }

    let totalBreakMinutes = breaks.compactMap { b -> Int? in
        guard let s = b.startTime, let e = b.endTime else { return nil }
        var d = e.totalMinutes - s.totalMinutes
        if d < 0 { d += 24 * 60 }
        return d
    }.reduce(0, +)
    let breakText: String? = totalBreakMinutes > 0
        ? { let h = totalBreakMinutes / 60; let m = totalBreakMinutes % 60; return m == 0 ? "\(h)h" : "\(h)h \(m)m" }()
        : nil

    let breakModels = breaks.enumerated().map { i, b in
        let ongoing = b.startTime != nil && b.endTime == nil
        let label = ongoing ? "Break \(i + 1) · ongoing" : "Break \(i + 1)"
        let duration: Int? = {
            guard let s = b.startTime, let e = b.endTime else { return nil }
            var d = e.totalMinutes - s.totalMinutes
            if d < 0 { d += 24 * 60 }
            return d
        }()
        return DayDetailFeature.BreakRowModel(
            id: i, label: label, startTime: b.startTime, endTime: b.endTime, durationMinutes: duration
        )
    }

    let fullBreakText = breakText.map { "\($0) of breaks (unpaid)" }

    return .init(
        dateTitle: title,
        workedHoursText: workedText,
        statusText: statusText,
        startFieldLabel: "Started work",
        endFieldLabel: "Finished work",
        addBreakLabel: "Add a break",
        nowButtonLabel: "Now",
        timePlaceholder: "--:--",
        doneButtonLabel: "Done",
        startTime: state.record?.startTime ?? nil,
        endTime: state.record?.endTime ?? nil,
        breaks: breakModels,
        isFuture: isFuture,
        totalBreakText: fullBreakText,
        defaultStart: state.defaults.defaultStartTime,
        defaultEnd: state.defaults.defaultEndTime
    )
}

private extension DayDetailFeature.ViewAction {
    var asAction: DayDetailFeature.Action {
        switch self {
        case .setStart(let t):              .setStart(t)
        case .setEnd(let t):                .setEnd(t)
        case .setStartNow:                  .setStartNow
        case .setEndNow:                    .setEndNow
        case .addBreak:                     .addBreak
        case .removeBreak(let i):           .removeBreak(i)
        case .setBreakLength(let i, let m): .setBreakLength(i, m)
        case .setBreakStart(let i, let t):  .setBreakStart(i, t)
        case .setBreakEnd(let i, let t):    .setBreakEnd(i, t)
        case .setBreakStartNow(let i):      .setBreakStartNow(i)
        case .setBreakEndNow(let i):        .setBreakEndNow(i)
        case .prevDay:                      .prevDay
        case .nextDay:                      .nextDay
        case .done:                         .done
        case .onAppear:                     .start
        }
    }
}
