import AppDomain
import Foundation
import ReportInputFeature
import SwiftRex
import SwiftRexArchitecture
import SwiftRexTesting
import Testing

@MainActor
private func store(
    initial: ReportInputFeature.State = ReportInputFeature.initialState(with: ()),
    env: ReportInputFeature.Environment = .mock(),
    exhaustive: Bool = true
) -> TestStore<ReportInputFeature.Action, ReportInputFeature.State, ReportInputFeature.Environment> {
    TestStore(initial: initial, behavior: ReportInputFeature.behavior(), environment: env, exhaustive: exhaustive)
}

// MARK: - Behavior tests

@Suite("ReportInputFeature Behavior")
@MainActor
struct ReportInputFeatureBehaviorTests {

    // MARK: - .start

    @Test func startProducesStartedActionWithTodayAndDefaultDates() async {
        let s = store(env: .mock(currentDate: { Fixture.today }))

        s.dispatch(.start) { _ in }
        await s.runEffects()

        s.receive(ReportInputFeature.Action.prism.started) { args, state in
            let (today, monthStart, _, warning) = args
            state.today = today
            state.range = ReportInputFeature.DateRange(from: monthStart, to: today)
            state.noSalaryWarning = warning
        }

        #expect(s.state.today == Fixture.today)
    }

    @Test func startDoesNotOverrideAlreadySetDates() async {
        var initial = ReportInputFeature.initialState(with: ())
        initial.range = ReportInputFeature.DateRange(from: Fixture.twoDaysAgo, to: Fixture.today)
        let s = store(initial: initial, env: .mock(currentDate: { Fixture.today }))

        s.dispatch(.start) { _ in }
        await s.runEffects()
        s.receive(ReportInputFeature.Action.prism.started) { args, state in
            let (today, _, _, warning) = args
            state.today = today
            state.noSalaryWarning = warning
            // fromDate/toDate already set → remain unchanged
        }

        #expect(s.state.range?.from == Fixture.twoDaysAgo)
        #expect(s.state.range?.to == Fixture.today)
    }

    // Regression: on re-entry, salary must load from the report's START month (the kept fromDate),
    // NOT today's month — otherwise a June report re-opened in July shows "no salary" (real bug).
    @Test func startLoadsSalaryFromReportStartMonthNotToday() async {
        let june1  = Fixture.calendar.date(from: DateComponents(year: 2026, month: 6, day: 1))!
        let june30 = Fixture.calendar.date(from: DateComponents(year: 2026, month: 6, day: 30))!
        let july1  = Fixture.calendar.date(from: DateComponents(year: 2026, month: 7, day: 1))!
        let juneSalary = SalaryRecord(amount: 12, periodicity: .hourly)
        let juneData  = (try? JSONEncoder().encode(MonthData(records: [], salary: juneSalary))) ?? Data()
        let emptyData = (try? JSONEncoder().encode(MonthData(records: [], salary: nil))) ?? Data()
        let env = ReportInputFeature.Environment(
            decoder: JSONDecoder(),
            readFile: { $0.contains("06-2026") ? .just(juneData) : .just(emptyData) },
            currentDate: { july1 },
            calendar: { Fixture.calendar },
            calcTax: { gross, _, _ in TaxBreakdown(ni: 0, pension: 0, incomeTax: 0, studentLoan: 0, net: gross) }
        )
        var initial = ReportInputFeature.initialState(with: ())
        initial.range = ReportInputFeature.DateRange(from: june1, to: june30)

        let s = store(initial: initial, env: env)
        s.dispatch(.start) { _ in }
        await s.runEffects()
        s.receive(ReportInputFeature.Action.prism.started) { args, state in
            let (today, _, salary, warning) = args
            state.today = today
            state.salary = salary
            state.noSalaryWarning = warning
        }
        #expect(s.state.salary == juneSalary)     // June's salary, not empty July
        #expect(s.state.noSalaryWarning == nil)   // found → no warning
    }

    // Regression (real user bug): salary set in June, hours logged in July. A July report's start
    // month (07-2026.json) has records but NO salary, so before carry-forward the Generate button was
    // disabled with a "no salary" warning. Salary must fall back to the most recent earlier month.
    @Test func startCarriesSalaryForwardWhenStartMonthHasNone() async {
        let july5 = Fixture.calendar.date(from: DateComponents(year: 2026, month: 7, day: 5, hour: 9))!
        let juneSalary = SalaryRecord(amount: 12, periodicity: .hourly)
        let july1Record = WorkDayRecord(
            id: Fixture.idA,
            date: Fixture.calendar.date(from: DateComponents(year: 2026, month: 7, day: 1))!,
            startTime: TimeOfDay(hour: 9, minute: 0),
            endTime: TimeOfDay(hour: 17, minute: 0),
            breaks: []
        )
        let env = ReportInputFeature.Environment.mock(
            monthFiles: [
                "07-2026.json": MonthData(records: [july1Record], salary: nil),   // hours, no salary
                "06-2026.json": MonthData(records: [], salary: juneSalary)         // salary lives here
            ],
            currentDate: { july5 }
        )
        let s = store(env: env)
        s.dispatch(.start) { _ in }
        await s.runEffects()
        s.receive(ReportInputFeature.Action.prism.started) { args, state in
            let (today, monthStart, salary, warning) = args
            state.today = today
            state.range = ReportInputFeature.DateRange(from: monthStart, to: today)
            state.salary = salary
            state.noSalaryWarning = warning
        }
        #expect(s.state.salary == juneSalary)     // carried forward from June
        #expect(s.state.noSalaryWarning == nil)   // found → Generate no longer blocked
    }

    // MARK: - setFrom / setTo

    @Test func setFromUpdateFromDate() async {
        var initial = ReportInputFeature.initialState(with: ())
        initial.range = ReportInputFeature.DateRange(from: Fixture.today, to: Fixture.today)  // the picker only edits a resolved range
        let s = store(initial: initial)
        s.dispatch(.setFrom(Fixture.twoDaysAgo)) { state in
            state.range?.from = Fixture.twoDaysAgo
        }
        // setFrom fires a salary-only reload — it must NOT touch `today` (bug 2 regression guard).
        await s.runEffects()
        s.receive(ReportInputFeature.Action.prism.salaryReloaded) { args, state in
            state.salary = args.0; state.noSalaryWarning = args.1
        }
        #expect(s.state.today == nil)   // unchanged by the reload
    }

    @Test func setToUpdateToDate() {
        var initial = ReportInputFeature.initialState(with: ())
        initial.range = ReportInputFeature.DateRange(from: Fixture.today, to: Fixture.today)
        let s = store(initial: initial)
        s.dispatch(.setTo(Fixture.yesterday)) { state in
            state.range?.to = Fixture.yesterday
        }
    }

    @Test func setToFutureDateClearsEstimateToggle() {
        var initial = ReportInputFeature.initialState(with: ())
        initial.range = ReportInputFeature.DateRange(from: Fixture.today, to: Fixture.today)
        initial.today = Fixture.today
        initial.estimateFuture = true
        let s = store(initial: initial)
        s.dispatch(.setTo(Fixture.yesterday)) { state in
            state.range?.to = Fixture.yesterday
            state.estimateFuture = false
        }
    }

    // MARK: - toggleEstimate

    @Test func toggleEstimateFlipsFlag() {
        var initial = ReportInputFeature.initialState(with: ())
        initial.today = Fixture.today
        initial.range = ReportInputFeature.DateRange(from: Fixture.today, to: Fixture.tomorrow)   // future → toggle is visible
        let s = store(initial: initial)
        s.dispatch(.toggleEstimate) { state in
            state.estimateFuture = true
        }
        s.dispatch(.toggleEstimate) { state in
            state.estimateFuture = false
        }
    }

    // MARK: - generate

    @Test func generateWithPastRecordsProducesReport() async {
        let record = Fixture.completedDay
        var initial = ReportInputFeature.initialState(with: ())
        initial.range = ReportInputFeature.DateRange(from: Fixture.todayMidnight, to: Fixture.todayMidnight)
        initial.salary = SalaryRecord(amount: 11, periodicity: .hourly)
        initial.today = Fixture.today

        let s = store(
            initial: initial,
            env: .mock(currentDate: { Fixture.today }, records: [record])
        )

        s.dispatch(.generate) { _ in }
        await s.runEffects()
        s.receive(ReportInputFeature.Action.prism.reportGenerated) { args, state in
            let (report, _, _, _) = args
            state.weekdayAvgHours = report.weekdayAvgHours
            state.weekendAvgHours = report.weekendAvgHours
            #expect(report.totalHours == 8.0)
            #expect(report.grossPay == 88)   // 8h × £11
        }
    }

    @Test func generateWithNoRecordsProducesZeroHoursReport() async {
        var initial = ReportInputFeature.initialState(with: ())
        initial.range = ReportInputFeature.DateRange(from: Fixture.twoDaysAgo, to: Fixture.yesterday)
        initial.salary = SalaryRecord(amount: 11, periodicity: .hourly)
        initial.today = Fixture.today

        let s = store(initial: initial, env: .mock())

        s.dispatch(.generate) { _ in }
        await s.runEffects()
        s.receive(ReportInputFeature.Action.prism.reportGenerated) { args, state in
            let (report, _, _, _) = args
            state.weekdayAvgHours = report.weekdayAvgHours
            state.weekendAvgHours = report.weekendAvgHours
            #expect(report.totalHours == 0)
        }
    }
}

// MARK: - mapState tests

@Suite("ReportInputFeature mapState")
@MainActor
struct ReportInputFeatureMapStateTests {

    @Test func canGenerateIsFalseWithoutDates() {
        let vs = ReportInputFeature.mapState(.mock())(ReportInputFeature.initialState(with: ()))
        #expect(!vs.canGenerate)
    }

    @Test func canGenerateTrueWhenValidInputs() {
        var state = ReportInputFeature.initialState(with: ())
        state.range = ReportInputFeature.DateRange(from: Fixture.twoDaysAgo, to: Fixture.today)
        state.salary = SalaryRecord(amount: 11, periodicity: .hourly)
        state.today = Fixture.today
        let vs = ReportInputFeature.mapState(.mock())(state)
        #expect(vs.canGenerate)
    }

    @Test func showEstimateToggleWhenToDateIsFuture() {
        var state = ReportInputFeature.initialState(with: ())
        state.today = Fixture.today
        state.range = ReportInputFeature.DateRange(from: Fixture.tomorrow, to: Fixture.tomorrow)
        let vs = ReportInputFeature.mapState(.mock())(state)
        #expect(vs.showEstimateToggle)
    }

    @Test func hideEstimateToggleForPastPeriods() {
        var state = ReportInputFeature.initialState(with: ())
        state.today = Fixture.today
        state.range = ReportInputFeature.DateRange(from: Fixture.yesterday, to: Fixture.yesterday)
        let vs = ReportInputFeature.mapState(.mock())(state)
        #expect(!vs.showEstimateToggle)
    }

    @Test func staticLabelsNeverEmpty() {
        let vs = ReportInputFeature.mapState(.mock())(ReportInputFeature.initialState(with: ()))
        #expect(!vs.titleLabel.isEmpty)
        #expect(!vs.subtitleLabel.isEmpty)
        #expect(!vs.fromLabel.isEmpty)
        #expect(!vs.toLabel.isEmpty)
        #expect(!vs.generateButtonLabel.isEmpty)
    }

    @Test func estimateDescriptionIncludesAverages() {
        var state = ReportInputFeature.initialState(with: ())
        state.weekdayAvgHours = 8.0
        state.weekendAvgHours = 6.0
        state.today = Fixture.today
        state.range = ReportInputFeature.DateRange(from: Fixture.tomorrow, to: Fixture.tomorrow)
        let vs = ReportInputFeature.mapState(.mock())(state)
        #expect(vs.estimateDescriptionLabel.contains("8"))
        #expect(vs.estimateDescriptionLabel.contains("6"))
    }
}

// MARK: - mapAction tests

@Suite("ReportInputFeature mapAction")
struct ReportInputFeatureMapActionTests {

    @Test func onAppearMapsToStart() {
        let action = ReportInputFeature.mapAction(.mock())(.onAppear)
        #expect(ReportInputFeature.Action.prism.start.preview(action) != nil)
    }

    @Test func generateMapsToGenerate() {
        let action = ReportInputFeature.mapAction(.mock())(.generate)
        #expect(ReportInputFeature.Action.prism.generate.preview(action) != nil)
    }

    @Test func setFromMapsThrough() {
        let action = ReportInputFeature.mapAction(.mock())(.setFrom(Fixture.today))
        #expect(ReportInputFeature.Action.prism.setFrom.preview(action) == Fixture.today)
    }
}

// MARK: - Snapshot tests

#if os(iOS) || os(tvOS)
import SnapshotTesting
import SwiftUI

@Suite("ReportInputFeature Snapshots", .snapshots)
@MainActor
struct ReportInputFeatureSnapshotTests {

    private func feature(state: ReportInputFeature.State) -> TestFeature<ReportInputFeature> {
        TestFeature<ReportInputFeature>(initial: state, environment: .mock())
    }

    private func baseState() -> ReportInputFeature.State {
        var s = ReportInputFeature.initialState(with: ())
        s.range = ReportInputFeature.DateRange(from: Fixture.calendar.date(from: DateComponents(year: 2026, month: 5, day: 1))!, to: Fixture.todayMidnight)
        s.salary = SalaryRecord(amount: 11, periodicity: .hourly)
        s.today = Fixture.today
        return s
    }

    @Test func snapshotDefaultState() async {
        await snap(feature(state: baseState()), named: "reportinput-default")
    }

    @Test func snapshotEstimateToggleVisible() async {
        var s = baseState()
        s.range?.to = Fixture.tomorrow
        await snap(feature(state: s), named: "reportinput-estimate-toggle-visible")
    }

    @Test func snapshotEstimateToggleChecked() async {
        var s = baseState()
        s.range?.to = Fixture.tomorrow
        s.estimateFuture = true
        s.weekdayAvgHours = 8.0
        s.weekendAvgHours = 4.0
        await snap(feature(state: s), named: "reportinput-estimate-checked")
    }

    @Test func snapshotWithMonthlySalary() async {
        var s = baseState()
        s.salary = SalaryRecord(amount: 2500, periodicity: .monthly)
        await snap(feature(state: s), named: "reportinput-monthly-salary")
    }
}
#endif
