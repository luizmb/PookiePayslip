import AppDomain
import DayDetailFeature
import Foundation
import SwiftRex
import SwiftRexArchitecture
import SwiftRexTesting
import Testing

@MainActor
private func store(
    initial: DayDetailFeature.State = DayDetailFeature.initialState(with: ()),
    env: DayDetailFeature.Environment = .mock(),
    exhaustive: Bool = true
) -> TestStore<DayDetailFeature.Action, DayDetailFeature.State, DayDetailFeature.Environment> {
    TestStore(initial: initial, behavior: DayDetailFeature.behavior(), environment: env, exhaustive: exhaustive)
}

// MARK: - Behavior tests

@Suite("DayDetailFeature Behavior")
@MainActor
struct DayDetailFeatureBehaviorTests {

    // MARK: - loadDay

    @Test func loadDayForNewDateCreatesEmptyRecord() async {
        let s = store(env: .mock(newID: { Fixture.idA }))
        let date = Fixture.todayMidnight

        s.dispatch(.loadDay(date), assert: { _ in })  // produce-only
        await s.runEffects()

        s.receive(DayDetailFeature.Action.prism.dayLoaded) { args, state in
            let (record, today, dateTitle) = args
            state.dateTitle = dateTitle
            state.date = date
            state.record = record
            state.today = today
        }
    }

    @Test func loadDayFindsExistingRecord() async {
        let existingRecord = Fixture.completedDay
        let s = store(env: .mock(existingRecord: existingRecord))

        s.dispatch(.loadDay(Fixture.todayMidnight), assert: { _ in })
        await s.runEffects()
        s.receive(DayDetailFeature.Action.prism.dayLoaded) { args, state in
            let (record, today, dateTitle) = args
            state.dateTitle = dateTitle
            state.date = record.date
            state.record = record
            state.today = today
        }

        #expect(s.state.record?.startTime == Fixture.completedDay.startTime)
    }

    // MARK: - setStart / setEnd

    @Test func setStartUpdatesRecordAndSaves() async {
        var initial = DayDetailFeature.initialState(with: ())
        initial.date = Fixture.todayMidnight
        initial.record = WorkDayRecord(id: Fixture.idA, date: Fixture.todayMidnight)
        let s = store(initial: initial, env: .mock())
        let tod = TimeOfDay(hour: 9, minute: 0)

        s.dispatch(.setStart(tod)) { state in
            state.record?.startTime = tod
        }
        await s.runEffects()
        s.receive(DayDetailFeature.Action.prism.saveCompleted) { _, _ in }
    }

    @Test func setEndUpdatesRecord() async {
        var initial = DayDetailFeature.initialState(with: ())
        initial.date = Fixture.todayMidnight
        initial.record = WorkDayRecord(
            id: Fixture.idA, date: Fixture.todayMidnight,
            startTime: TimeOfDay(hour: 9, minute: 0), endTime: nil, breaks: []
        )
        let s = store(initial: initial, env: .mock())
        let tod = TimeOfDay(hour: 17, minute: 0)

        s.dispatch(.setEnd(tod)) { state in
            state.record?.endTime = tod
        }
        await s.runEffects()
        s.receive(DayDetailFeature.Action.prism.saveCompleted) { _, _ in }
    }

    @Test func clearStartSetsNil() async {
        var initial = DayDetailFeature.initialState(with: ())
        initial.date = Fixture.todayMidnight
        initial.record = WorkDayRecord(
            id: Fixture.idA, date: Fixture.todayMidnight,
            startTime: TimeOfDay(hour: 9, minute: 0), endTime: nil, breaks: []
        )
        let s = store(initial: initial, env: .mock())

        s.dispatch(.setStart(nil)) { state in
            state.record?.startTime = nil
        }
        await s.runEffects()
        s.receive(DayDetailFeature.Action.prism.saveCompleted) { _, _ in }
    }

    // MARK: - addBreak / removeBreak

    @Test func addBreakAppendsDefaultBreak() async {
        var initial = DayDetailFeature.initialState(with: ())
        initial.date = Fixture.todayMidnight
        initial.record = WorkDayRecord(id: Fixture.idA, date: Fixture.todayMidnight,
            startTime: TimeOfDay(hour: 9, minute: 0), endTime: nil, breaks: [])
        let s = store(initial: initial, env: .mock())

        // "Add break" now seeds a 30-minute default (12:30–13:00), editable afterwards.
        s.dispatch(.addBreak) { state in
            state.record?.breaks.append(WorkBreakRecord(
                startTime: TimeOfDay(hour: 12, minute: 30),
                endTime: TimeOfDay(hour: 13, minute: 0)
            ))
        }
        await s.runEffects()
        s.receive(DayDetailFeature.Action.prism.saveCompleted) { _, _ in }
    }

    @Test func removeBreakDeletesByIndex() async {
        var initial = DayDetailFeature.initialState(with: ())
        initial.date = Fixture.todayMidnight
        initial.record = WorkDayRecord(
            id: Fixture.idA, date: Fixture.todayMidnight,
            startTime: TimeOfDay(hour: 9, minute: 0), endTime: nil,
            breaks: [WorkBreakRecord(startTime: TimeOfDay(hour: 11, minute: 0), endTime: TimeOfDay(hour: 11, minute: 15))]
        )
        let s = store(initial: initial, env: .mock())

        s.dispatch(.removeBreak(0)) { state in
            state.record?.breaks.remove(at: 0)
        }
        await s.runEffects()
        s.receive(DayDetailFeature.Action.prism.saveCompleted) { _, _ in }
    }

    @Test func removeBreakOutOfBoundsIsNoOp() {
        let s = store(exhaustive: false)
        s.dispatch(.removeBreak(99), assert: { _ in })
    }

    // MARK: - setStartNow — resolves time through environment

    @Test func setStartNowProducesSetStartAction() async {
        let expectedHour = Fixture.calendar.component(.hour, from: Fixture.today)
        let expectedMinute = Fixture.calendar.component(.minute, from: Fixture.today)
        var initial = DayDetailFeature.initialState(with: ())
        initial.date = Fixture.todayMidnight
        initial.record = WorkDayRecord(id: Fixture.idA, date: Fixture.todayMidnight)  // a day must be loaded first

        let s = store(initial: initial, env: .mock(currentDate: { Fixture.today }))
        s.dispatch(.setStartNow, assert: { _ in })
        await s.runEffects()   // runs the "resolve now" DeferredTask → dispatches .setStart(tod)
        s.receive(DayDetailFeature.Action.prism.setStart) { tod, state in
            if let tod {
                state.record?.startTime = tod
                #expect(tod.hour == expectedHour)
                #expect(tod.minute == expectedMinute)
            }
        }
        // .setStart triggers save effect — drain it too
        await s.runEffects()
        s.receive(DayDetailFeature.Action.prism.saveCompleted) { _, _ in }
    }

    // MARK: - passthrough actions (handled by bridgeBehavior)

    @Test func doneIsPassthrough() {
        let s = store(exhaustive: false)
        s.dispatch(.done, assert: { _ in })
    }

    @Test func prevDayLoadsRecord() async {
        var initial = DayDetailFeature.initialState(with: ())
        initial.date = Fixture.todayMidnight
        let s = store(initial: initial, env: .mock(newID: { Fixture.idB }))

        // prevDay is now produce-only: feature delegates date change to dayLoaded
        s.dispatch(.prevDay, assert: { _ in })
        await s.runEffects()
        s.receive(DayDetailFeature.Action.prism.dayLoaded) { args, state in
            let (record, today, dateTitle) = args
            state.dateTitle = dateTitle
            state.date = record.date
            state.record = record
            state.today = today
        }
        let expected = Fixture.calendar.date(byAdding: .day, value: -1, to: Fixture.todayMidnight)!
        #expect(s.state.date == expected)
    }
}

// MARK: - mapState tests

@Suite("DayDetailFeature mapState")
@MainActor
struct DayDetailFeatureMapStateTests {

    @Test func emptyStateGivesEmptyTitle() {
        let vs = DayDetailFeature.mapState(.mock())(DayDetailFeature.initialState(with: ()))
        #expect(vs.dateTitle == "")
    }

    @Test func dateTitleSurfacedFromState() {
        // The title is formatted in the behavior (see loadDay tests) and cached in State;
        // mapState just surfaces it.
        var state = DayDetailFeature.initialState(with: ())
        state.date = Fixture.todayMidnight
        state.today = Fixture.today
        state.dateTitle = "Friday, 29 May"
        let vs = DayDetailFeature.mapState(.mock())(state)
        #expect(vs.dateTitle.contains("29"))
        #expect(vs.dateTitle.contains("May"))
    }

    @Test func completedRecordShowsWorkedHours() {
        var state = DayDetailFeature.initialState(with: ())
        state.date = Fixture.todayMidnight
        state.record = Fixture.completedDay
        state.today = Fixture.today
        let vs = DayDetailFeature.mapState(.mock())(state)
        #expect(vs.workedHoursText == "8h")   // 480 min = 8h
        #expect(vs.statusText == "worked")
    }

    @Test func inProgressRecordShowsStatusText() {
        var state = DayDetailFeature.initialState(with: ())
        state.date = Fixture.todayMidnight
        state.record = Fixture.inProgressDay
        state.today = Fixture.today
        let vs = DayDetailFeature.mapState(.mock())(state)
        #expect(vs.workedHoursText == "")
        #expect(vs.statusText.contains("In progress"))
    }

    @Test func futureDateShowsPlanningStatus() {
        var state = DayDetailFeature.initialState(with: ())
        state.date = Fixture.tomorrow
        state.record = WorkDayRecord(id: Fixture.idA, date: Fixture.tomorrow,
            startTime: TimeOfDay(hour: 9, minute: 0), endTime: nil, breaks: [])
        state.today = Fixture.todayMidnight
        let vs = DayDetailFeature.mapState(.mock())(state)
        #expect(vs.isFuture)
        #expect(vs.statusText.contains("Planned"))
    }

    @Test func breakLabelIncludesIndexAndOngoingSuffix() {
        var state = DayDetailFeature.initialState(with: ())
        state.record = WorkDayRecord(id: Fixture.idA, date: Fixture.todayMidnight,
            startTime: TimeOfDay(hour: 9, minute: 0), endTime: nil,
            breaks: [WorkBreakRecord(startTime: TimeOfDay(hour: 11, minute: 0), endTime: nil)])
        state.today = Fixture.today
        let vs = DayDetailFeature.mapState(.mock())(state)
        #expect(vs.breaks[0].label.contains("1"))
        #expect(vs.breaks[0].label.contains("ongoing"))
    }

    @Test func completedBreakLabelHasNoOngoingSuffix() {
        var state = DayDetailFeature.initialState(with: ())
        state.record = Fixture.completedDay   // has a completed break
        state.today = Fixture.today
        let vs = DayDetailFeature.mapState(.mock())(state)
        #expect(!vs.breaks[0].label.contains("ongoing"))
    }

    @Test func totalBreakTextIncludesUnpaidSuffix() {
        var state = DayDetailFeature.initialState(with: ())
        state.record = Fixture.completedDay   // 30-min break
        state.today = Fixture.today
        let vs = DayDetailFeature.mapState(.mock())(state)
        #expect(vs.totalBreakText?.contains("unpaid") == true)
    }

    @Test func staticLabelsNeverEmpty() {
        let vs = DayDetailFeature.mapState(.mock())(DayDetailFeature.initialState(with: ()))
        #expect(!vs.startFieldLabel.isEmpty)
        #expect(!vs.endFieldLabel.isEmpty)
        #expect(!vs.addBreakLabel.isEmpty)
        #expect(!vs.nowButtonLabel.isEmpty)
        #expect(!vs.timePlaceholder.isEmpty)
        #expect(!vs.doneButtonLabel.isEmpty)
    }
}

// MARK: - mapAction tests

@Suite("DayDetailFeature mapAction")
struct DayDetailFeatureMapActionTests {

    @Test func setStartMapsThrough() {
        let tod = TimeOfDay(hour: 9, minute: 0)
        let action = DayDetailFeature.mapAction(.mock())(.setStart(tod))
        #expect(DayDetailFeature.Action.prism.setStart.preview(action) == tod)
    }

    @Test func setStartNowMapsToSetStartNow() {
        let action = DayDetailFeature.mapAction(.mock())(.setStartNow)
        #expect(DayDetailFeature.Action.prism.setStartNow.preview(action) != nil)
    }

    @Test func addBreakMapsThrough() {
        let action = DayDetailFeature.mapAction(.mock())(.addBreak)
        #expect(DayDetailFeature.Action.prism.addBreak.preview(action) != nil)
    }

    @Test func doneMapsThrough() {
        let action = DayDetailFeature.mapAction(.mock())(.done)
        #expect(DayDetailFeature.Action.prism.done.preview(action) != nil)
    }

    @Test func prevDayMapsThrough() {
        let action = DayDetailFeature.mapAction(.mock())(.prevDay)
        #expect(DayDetailFeature.Action.prism.prevDay.preview(action) != nil)
    }
}

// MARK: - Snapshot tests

#if os(iOS) || os(tvOS)
import SnapshotTesting
import SwiftUI

@Suite("DayDetailFeature Snapshots", .snapshots)
@MainActor
struct DayDetailFeatureSnapshotTests {

    private func feature(state: DayDetailFeature.State) -> TestFeature<DayDetailFeature> {
        TestFeature<DayDetailFeature>(initial: state, environment: .mock())
    }

    private func baseState(date: Date = Fixture.todayMidnight) -> DayDetailFeature.State {
        var s = DayDetailFeature.initialState(with: ())
        s.date = date
        s.today = Fixture.today
        s.record = WorkDayRecord(id: Fixture.idA, date: date)
        // dateTitle is behavior-computed; replicate the mock formatter for snapshots.
        s.dateTitle = Formatting.dateFormatter(locale: Locale(identifier: "en_GB"), calendar: Fixture.calendar)(date, "EEEE, d MMMM")
        return s
    }

    @Test func snapshotNothingLogged() async {
        await snap(feature(state: baseState()), named: "daydetail-empty")
    }

    @Test func snapshotInProgress() async {
        var s = baseState()
        s.record?.startTime = TimeOfDay(hour: 9, minute: 0)
        await snap(feature(state: s), named: "daydetail-in-progress")
    }

    @Test func snapshotWithBreakOngoing() async {
        var s = baseState()
        s.record?.startTime = TimeOfDay(hour: 9, minute: 0)
        s.record?.breaks = [WorkBreakRecord(startTime: TimeOfDay(hour: 12, minute: 30), endTime: nil)]
        await snap(feature(state: s), named: "daydetail-break-ongoing")
    }

    @Test func snapshotCompleted() async {
        var s = baseState()
        s.record = Fixture.completedDay
        await snap(feature(state: s), named: "daydetail-completed")
    }

    @Test func snapshotWithMultipleBreaks() async {
        var s = baseState()
        s.record?.startTime = TimeOfDay(hour: 9, minute: 0)
        s.record?.endTime   = TimeOfDay(hour: 18, minute: 0)
        s.record?.breaks = [
            WorkBreakRecord(startTime: TimeOfDay(hour: 11, minute: 0), endTime: TimeOfDay(hour: 11, minute: 15)),
            WorkBreakRecord(startTime: TimeOfDay(hour: 13, minute: 0), endTime: TimeOfDay(hour: 13, minute: 30)),
        ]
        await snap(feature(state: s), named: "daydetail-multiple-breaks")
    }

    @Test func snapshotFutureDay() async {
        var s = baseState(date: Fixture.tomorrow)
        s.record?.startTime = TimeOfDay(hour: 9, minute: 0)
        await snap(feature(state: s), named: "daydetail-future")
    }
}
#endif
