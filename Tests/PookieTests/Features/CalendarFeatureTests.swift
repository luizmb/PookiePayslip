import AppDomain
@testable import CalendarFeature
import Foundation
import SwiftRex
import SwiftRexArchitecture
import SwiftRexTesting
import Testing

// MARK: - Helpers

@MainActor
private func store(
    initial: CalendarFeature.State = CalendarFeature.initialState(with: ()),
    env: CalendarFeature.Environment = .mock(),
    exhaustive: Bool = true
) -> TestStore<CalendarFeature.Action, CalendarFeature.State, CalendarFeature.Environment> {
    TestStore(initial: initial, behavior: CalendarFeature.behavior(), environment: env, exhaustive: exhaustive)
}

// MARK: - Behavior tests

@Suite("CalendarFeature Behavior")
@MainActor
struct CalendarFeatureBehaviorTests {

    // MARK: - .start

    @Test func startProducesEffectAndSetsStateFromStartLoaded() async {
        let s = store(env: .mock(currentDate: { Fixture.today }))

        s.dispatch(.start) { _ in }  // no synchronous state change — all in produce

        await s.runEffects()

        s.receive(CalendarFeature.Action.prism.startLoaded) { args, state in
            let (today, month, _) = args
            state.today = today
            state.currentMonth = month
        }
        // startLoaded re-renders the grid/labels/title cache
        await s.runEffects()
        s.receive(CalendarFeature.Action.prism.setRendered) { rendered, state in state.rendered = rendered }
    }

    @Test func startWithRecordsPopulatesWorkDays() async {
        let record = Fixture.completedDay
        let s = store(env: .mock(records: [record]))

        s.dispatch(.start) { _ in }
        await s.runEffects()
        s.receive(CalendarFeature.Action.prism.startLoaded) { args, state in
            let (today, month, result) = args
            state.today = today
            state.currentMonth = month
            if case .success(let records) = result {
                for r in records.records { state.workDays[r.date] = r }
            }
        }
        await s.runEffects()
        s.receive(CalendarFeature.Action.prism.setRendered) { rendered, state in state.rendered = rendered }

        #expect(s.state.workDays[Fixture.todayMidnight] != nil)
    }

    // MARK: - prev/next month

    @Test func prevMonthDecrementsCurrentMonth() async {
        var initial = CalendarFeature.initialState(with: ())
        initial.currentMonth = Fixture.calendar.date(from: DateComponents(year: 2026, month: 5, day: 1))!
        initial.today = Fixture.today
        let expectedPrev = Fixture.calendar.date(from: DateComponents(year: 2026, month: 4, day: 1))!

        let s = store(initial: initial, env: .mock())

        s.dispatch(.prevMonth) { _ in }   // produce-only: resolves the new month via World's calendar
        await s.runEffects()
        s.receive(CalendarFeature.Action.prism.monthChanged) { newMonth, state in
            state.currentMonth = newMonth
            #expect(newMonth == expectedPrev)
        }
        await s.runEffects()
        s.receive(CalendarFeature.Action.prism.monthLoaded) { _, _ in }  // empty month
        await s.runEffects()
        s.receive(CalendarFeature.Action.prism.setRendered) { rendered, state in state.rendered = rendered }
    }

    @Test func nextMonthIncrementsCurrentMonth() async {
        var initial = CalendarFeature.initialState(with: ())
        initial.currentMonth = Fixture.calendar.date(from: DateComponents(year: 2026, month: 5, day: 1))!
        initial.today = Fixture.today
        let expectedNext = Fixture.calendar.date(from: DateComponents(year: 2026, month: 6, day: 1))!

        let s = store(initial: initial, env: .mock())

        s.dispatch(.nextMonth) { _ in }   // produce-only
        await s.runEffects()
        s.receive(CalendarFeature.Action.prism.monthChanged) { newMonth, state in
            state.currentMonth = newMonth
            #expect(newMonth == expectedNext)
        }
        await s.runEffects()
        s.receive(CalendarFeature.Action.prism.monthLoaded) { _, _ in }
        await s.runEffects()
        s.receive(CalendarFeature.Action.prism.setRendered) { rendered, state in state.rendered = rendered }
    }

    // MARK: - recordUpdated

    @Test func recordUpdatedWritesIntoWorkDays() async {
        let s = store()
        let record = Fixture.completedDay
        s.dispatch(.recordUpdated(record)) { state in
            state.workDays[record.date] = record
        }
        await s.runEffects()
        s.receive(CalendarFeature.Action.prism.setRendered) { rendered, state in state.rendered = rendered }
    }

    // MARK: - passthrough actions (handled by bridgeBehavior)

    @Test func selectDayProducesNoLocalStateChange() {
        let s = store(exhaustive: false)
        s.dispatch(.selectDay(Fixture.todayMidnight), assert: { _ in })
    }

    @Test func openReportProducesNoLocalStateChange() {
        let s = store(exhaustive: false)
        s.dispatch(.openReport, assert: { _ in })
    }
}

// MARK: - mapState tests

@Suite("CalendarFeature mapState")
@MainActor
struct CalendarFeatureMapStateTests {

    @Test func distantPastStateProducesEmptyViewState() {
        let vs = CalendarFeature.mapState(.mock())(CalendarFeature.initialState(with: ()))
        #expect(vs.monthTitle == "")
        #expect(vs.days.isEmpty)
    }

    @Test func monthTitleSurfacedFromState() {
        // The grid/title are computed by the behavior and cached in `rendered`; mapState surfaces it.
        var state = CalendarFeature.initialState(with: ())
        state.rendered = .init(monthTitle: "May 2026", expectedEarningsText: nil, weekdayLabels: [], monthMinutes: 0, days: [])
        #expect(CalendarFeature.mapState(.mock())(state).monthTitle == "May 2026")
    }
}

// MARK: - computeRendered (grid built in the behavior from World's calendar)

@Suite("CalendarFeature computeRendered")
@MainActor
struct CalendarFeatureComputeRenderedTests {
    private func may2026State() -> CalendarFeature.State {
        var s = CalendarFeature.initialState(with: ())
        s.currentMonth = Fixture.calendar.date(from: DateComponents(year: 2026, month: 5, day: 1))!
        s.today = Fixture.today
        return s
    }

    @Test func todayMarkedIsToday() {
        let r = computeRendered(state: may2026State(), env: .mock())
        #expect(r.days.first { $0.isToday }?.dayNumber == "29")
    }

    @Test func completedDayShowsHoursText() {
        var state = may2026State()
        state.workDays[Fixture.todayMidnight] = Fixture.completedDay
        let r = computeRendered(state: state, env: .mock())
        #expect(r.days.first { $0.isToday }?.hoursText == "8")   // 480 min = 8h
    }

    @Test func inProgressDayShowsDot() {
        var state = may2026State()
        state.workDays[Fixture.todayMidnight] = Fixture.inProgressDay
        let r = computeRendered(state: state, env: .mock())
        let cell = r.days.first { $0.isToday }
        #expect(cell?.hoursText == nil)
        #expect(cell?.isInProgress == true)
    }

    @Test func weekdayLabelsAreMondayFirst() {
        let r = computeRendered(state: may2026State(), env: .mock())
        #expect(r.weekdayLabels.count == 7)
        #expect(r.weekdayLabels[0] == Fixture.calendar.shortWeekdaySymbols[1])  // Monday
    }

    @Test func monthMinutesReflectsCompletedDays() {
        var state = may2026State()
        state.workDays[Fixture.todayMidnight] = Fixture.completedDay
        let yesterday = Fixture.calendar.date(byAdding: .day, value: -1, to: Fixture.todayMidnight)!
        var yRecord = Fixture.completedDay; yRecord.id = Fixture.idB; yRecord.date = yesterday
        state.workDays[yesterday] = yRecord
        #expect(computeRendered(state: state, env: .mock()).monthMinutes == 960)  // 2 × 8h
    }
}

// MARK: - mapAction tests

@Suite("CalendarFeature mapAction")
struct CalendarFeatureMapActionTests {

    @Test func onAppearMapsToStart() {
        let action = CalendarFeature.mapAction(.mock())(.onAppear)
        #expect(CalendarFeature.Action.prism.start.preview(action) != nil)
    }

    @Test func prevMonthMapsToPrevMonth() {
        let action = CalendarFeature.mapAction(.mock())(.prevMonth)
        #expect(CalendarFeature.Action.prism.prevMonth.preview(action) != nil)
    }

    @Test func nextMonthMapsToNextMonth() {
        let action = CalendarFeature.mapAction(.mock())(.nextMonth)
        #expect(CalendarFeature.Action.prism.nextMonth.preview(action) != nil)
    }

    @Test func dayTappedMapsToSelectDay() {
        let action = CalendarFeature.mapAction(.mock())(.dayTapped(Fixture.todayMidnight))
        #expect(CalendarFeature.Action.prism.selectDay.preview(action) == Fixture.todayMidnight)
    }

    @Test func reportTappedMapsToOpenReport() {
        let action = CalendarFeature.mapAction(.mock())(.reportTapped)
        #expect(CalendarFeature.Action.prism.openReport.preview(action) != nil)
    }
}

// MARK: - Snapshot tests

#if os(iOS) || os(tvOS)
import SnapshotTesting
import SwiftUI

@Suite("CalendarFeature Snapshots", .snapshots)
@MainActor
struct CalendarFeatureSnapshotTests {

    private func feature(state: CalendarFeature.State) -> TestFeature<CalendarFeature> {
        TestFeature<CalendarFeature>(initial: state, environment: .mock())
    }

    // The grid is behavior-computed, so snapshot states must populate `rendered` up front.
    private func rendered(_ s: CalendarFeature.State) -> CalendarFeature.State {
        var out = s
        out.rendered = computeRendered(state: s, env: .mock())
        return out
    }

    private func may2026() -> CalendarFeature.State {
        var s = CalendarFeature.initialState(with: ())
        s.currentMonth = Fixture.calendar.date(from: DateComponents(year: 2026, month: 5, day: 1))!
        s.today = Fixture.today
        return rendered(s)
    }

    @Test func snapshotEmptyMonth() async {
        await snap(feature(state: may2026()), named: "calendar-empty")
    }

    @Test func snapshotWithCompletedDays() async {
        var s = may2026()
        // Several completed weekdays
        for day in [25, 26, 27, 28] {
            let date = Fixture.calendar.date(from: DateComponents(year: 2026, month: 5, day: day))!
            s.workDays[date] = WorkDayRecord(
                id: UUID(), date: date,
                startTime: TimeOfDay(hour: 9, minute: 0),
                endTime: TimeOfDay(hour: 17, minute: 30),
                breaks: [WorkBreakRecord(startTime: TimeOfDay(hour: 12, minute: 30), endTime: TimeOfDay(hour: 13, minute: 0))]
            )
        }
        await snap(feature(state: rendered(s)), named: "calendar-completed-days")
    }

    @Test func snapshotWithInProgressToday() async {
        var s = may2026()
        s.workDays[Fixture.todayMidnight] = Fixture.inProgressDay
        await snap(feature(state: rendered(s)), named: "calendar-today-in-progress")
    }

    @Test func snapshotWithMixedStates() async {
        var s = may2026()
        // Past completed
        let may27 = Fixture.calendar.date(from: DateComponents(year: 2026, month: 5, day: 27))!
        let may28 = Fixture.calendar.date(from: DateComponents(year: 2026, month: 5, day: 28))!
        s.workDays[may27] = WorkDayRecord(id: UUID(), date: may27,
            startTime: TimeOfDay(hour: 9, minute: 0), endTime: TimeOfDay(hour: 17, minute: 0), breaks: [])
        s.workDays[may28] = WorkDayRecord(id: UUID(), date: may28,
            startTime: TimeOfDay(hour: 9, minute: 0), endTime: TimeOfDay(hour: 16, minute: 30), breaks: [])
        // Today in-progress
        s.workDays[Fixture.todayMidnight] = Fixture.inProgressDay
        await snap(feature(state: rendered(s)), named: "calendar-mixed-states")
    }

    @Test func snapshotPreviousMonth() async {
        var s = CalendarFeature.initialState(with: ())
        s.currentMonth = Fixture.calendar.date(from: DateComponents(year: 2026, month: 4, day: 1))!
        s.today = Fixture.today
        await snap(feature(state: rendered(s)), named: "calendar-april-2026")
    }
}
#endif
