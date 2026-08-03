import AppDomain
import Foundation
import ReportResultFeature
import SwiftRexSwiftUI
import SwiftRex
import SwiftRexArchitecture
import SwiftRexTesting
import Testing

@MainActor
private func store(
    initial: ReportResultFeature.State = ReportResultFeature.initialState(with: ()),
    env: ReportResultFeature.Environment = .mock,
    exhaustive: Bool = true
) -> TestStore<ReportResultFeature.Action, ReportResultFeature.State, ReportResultFeature.Environment> {
    TestStore(initial: initial, behavior: ReportResultFeature.behavior(), environment: env, exhaustive: exhaustive)
}

private func mockReport(totalHours: Double = 8, grossPay: Decimal = 88, pension: Decimal = 0) -> PayReport {
    PayReport(
        totalHours: totalHours,
        isEstimated: false,
        weekdayAvgHours: 8,
        weekendAvgHours: 0,
        projectedDays: 0,
        incompleteDays: 0,
        grossPay: grossPay,
        niDeduction: 0,
        pensionDeduction: pension,
        incomeTaxDeduction: 0,
        studentLoanDeduction: 0,
        netPay: grossPay,
        noWeekdayDataWarning: false,
        periodDays: 1,
        salary: SalaryRecord(amount: 11, periodicity: .hourly, pensionRate: pension > 0 ? Decimal(string: "0.05")! : 0)
    )
}

private func rendered88() -> ReportResultFeature.Rendered {
    .init(periodLabel: "27 May – 29 May", yearLabel: "2026", netPay: "£88.00", gross: "£88.00",
          incomeTax: "£0.00", ni: "£0.00", pension: "£0.00", studentLoan: "£0.00")
}

// MARK: - Behavior tests

@Suite("ReportResultFeature Behavior")
@MainActor
struct ReportResultFeatureBehaviorTests {

    @Test func startFormatsTheSeededReport() async {
        // The navigation push seeds report/records/dates; `.start` only formats them.
        var initial = ReportResultFeature.initialState(with: ())
        initial.report = mockReport()
        initial.fromDate = Fixture.twoDaysAgo
        initial.toDate = Fixture.today
        let s = store(initial: initial)

        s.dispatch(.start) { _ in }   // produce-only
        await s.runEffects()
        s.receive(ReportResultFeature.Action.prism.rendered) { rendered, state in
            state.rendered = rendered
            #expect(rendered.periodLabel.contains("May"))
            #expect(rendered.gross.contains("88"))
        }
    }

    @Test func startWithoutASeededReportDoesNothing() {
        // Unreachable in the app — the push always seeds — but the guard should hold regardless.
        let s = store(exhaustive: false)
        s.dispatch(.start, assert: { _ in })
    }

    @Test func exportPDFWithReportProducesPDFReadyAction() async {
        var initial = ReportResultFeature.initialState(with: ())
        initial.report = mockReport()
        let s = store(initial: initial, env: .mock)

        s.dispatch(.exportPDF) { _ in }  // produce-only
        await s.runEffects()
        s.receive(ReportResultFeature.Action.prism.pdfReady) { data, state in
            state.preview = .presented(PDFShareable(data: data, filename: "payslip.pdf"))
            #expect(!data.isEmpty)
        }
    }

    @Test func exportPDFWithNoReportDoesNothing() {
        let s = store(exhaustive: false)
        s.dispatch(.exportPDF, assert: { _ in })
    }

    @Test func exportPDFRenderFailureDispatchesPDFFailed() async {
        var initial = ReportResultFeature.initialState(with: ())
        initial.report = mockReport()
        let s = store(initial: initial, env: .failingRender)

        s.dispatch(.exportPDF) { _ in }
        await s.runEffects()
        s.receive(ReportResultFeature.Action.prism.pdfFailed) { _, _ in }
    }

    @Test func pdfReadyPresentsTheDocument() {
        let s = store()
        let data = Data("pdf-content".utf8)
        s.dispatch(.pdfReady(data)) { state in
            state.preview = .presented(PDFShareable(data: data, filename: "payslip.pdf"))
        }
    }

    /// Two dispatches, one stage each: the binding's `set(false)` starts the out-animation and
    /// `onDismiss` completes it. The document stays readable through `dismissing`, so the sheet does not
    /// blank mid-animation.
    @Test func dismissPreviewWalksThePresentationOneStageAtATime() {
        let pdf = PDFShareable(data: Data("pdf-content".utf8), filename: "payslip.pdf")
        var initial = ReportResultFeature.initialState(with: ())
        initial.preview = .presented(pdf)
        let s = store(initial: initial)

        s.dispatch(.dismissPreview) { state in
            state.preview = .dismissing(last: pdf)
        }
        #expect(s.state.preview.wrapped == pdf)

        s.dispatch(.dismissPreview) { state in
            state.preview = .dismissed
        }
        #expect(s.state.preview.wrapped == nil)
    }
}

// MARK: - mapState tests

@Suite("ReportResultFeature mapState")
@MainActor
struct ReportResultFeatureMapStateTests {

    @Test func notLoadedProducesEmptyState() {
        let vs = ReportResultFeature.mapState(.mock)(ReportResultFeature.initialState(with: ()))
        #expect(!vs.isLoaded)
        #expect(vs.netPayText.isEmpty)
    }

    @Test func loadedStatePopulatesAllFields() {
        var state = ReportResultFeature.initialState(with: ())
        state.report = mockReport(totalHours: 8, grossPay: 88)
        state.fromDate = Fixture.twoDaysAgo
        state.toDate = Fixture.today
        state.rendered = rendered88()

        let vs = ReportResultFeature.mapState(.mock)(state)
        #expect(vs.isLoaded)
        #expect(!vs.kickerLabel.isEmpty)
        #expect(!vs.periodLabel.isEmpty)
        #expect(!vs.heroTitleLabel.isEmpty)
        let grossRow = vs.breakdownRows.first { $0.label.contains("Gross") }
        #expect(grossRow?.value.contains("88") == true)
        #expect(vs.netPayText.contains("88"))   // no deductions in mock
    }

    @Test func periodLabelFormatsFromAndTo() {
        var state = ReportResultFeature.initialState(with: ())
        state.report = mockReport()
        // May 27 to May 29
        state.fromDate = Fixture.twoDaysAgo
        state.toDate = Fixture.todayMidnight
        state.rendered = rendered88()

        let vs = ReportResultFeature.mapState(.mock)(state)
        #expect(vs.periodLabel.contains("27"))
        #expect(vs.periodLabel.contains("29"))
        #expect(vs.periodLabel.contains("May"))
        #expect(vs.yearLabel.contains("2026"))
    }

    @Test func estimateNoteOnlyWhenEstimated() {
        var state = ReportResultFeature.initialState(with: ())
        var report = mockReport()
        report.isEstimated = false
        state.report = report; state.records = []
        #expect(ReportResultFeature.mapState(.mock)(state).estimateNoteText == nil)

        report.isEstimated = true
        report.projectedDays = 3
        state.report = report; state.records = []
        #expect(ReportResultFeature.mapState(.mock)(state).estimateNoteText != nil)
    }

    // Regression: the note must show the real projected hours, not the old `totalHours - weekdayAvg`
    // bug (which made "52.4h total" claim "51h estimated" — see the report-hours report).
    @Test func estimateNoteShowsProjectedHoursNotTotalMinusAvg() {
        var state = ReportResultFeature.initialState(with: ())
        var report = mockReport()
        report.isEstimated = true
        report.projectedDays = 22
        report.projectedHours = 21     // the real projected figure
        report.weekdayAvgHours = 1.4   // diluted per-weekday average — must NOT leak into the note
        report.totalHours = 52.4
        state.report = report; state.records = []

        let note = ReportResultFeature.mapState(.mock)(state).estimateNoteText
        #expect(note?.contains("21") == true)    // projectedHours
        #expect(note?.contains("51") == false)   // NOT totalHours(52.4) - weekdayAvg(1.4)
    }

    @Test func incompleteWarningOnlyWhenIncompleteDaysExist() {
        var state = ReportResultFeature.initialState(with: ())
        var report = mockReport()
        report.incompleteDays = 0
        state.report = report; state.records = []
        #expect(ReportResultFeature.mapState(.mock)(state).incompleteWarningText == nil)

        report.incompleteDays = 2
        state.report = report; state.records = []
        #expect(ReportResultFeature.mapState(.mock)(state).incompleteWarningText != nil)
        #expect(ReportResultFeature.mapState(.mock)(state).incompleteWarningText!.contains("2"))
    }

    @Test func breakdownRowsHaveCorrectCount() {
        var state = ReportResultFeature.initialState(with: ())
        state.report = mockReport(pension: 5)   // pension opted in → row shown

        let vs = ReportResultFeature.mapState(.mock)(state)
        // 5 rows: hours worked, gross pay, income tax, NI, pension
        #expect(vs.breakdownRows.count == 5)
    }

    @Test func niAndPensionRowsAreNegative() {
        var state = ReportResultFeature.initialState(with: ())
        state.report = mockReport(pension: 5)

        let vs = ReportResultFeature.mapState(.mock)(state)
        let niRow = vs.breakdownRows.first { $0.label.contains("National Insurance") }
        let pensionRow = vs.breakdownRows.first { $0.label.contains("Pension") }
        #expect(niRow?.isNegative == true)
        #expect(pensionRow?.isNegative == true)
    }

    @Test func staticLabelsNeverEmpty() {
        var state = ReportResultFeature.initialState(with: ())
        state.report = mockReport()
        let vs = ReportResultFeature.mapState(.mock)(state)
        #expect(!vs.kickerLabel.isEmpty)
        #expect(!vs.finePrintHeading.isEmpty)
        #expect(!vs.finePrintBody.isEmpty)
        #expect(!vs.printButtonLabel.isEmpty)
    }

    @Test func previewPassedThrough() {
        var state = ReportResultFeature.initialState(with: ())
        state.report = mockReport()
        #expect(!ReportResultFeature.mapState(.mock)(state).preview.isPresented)

        state.preview = .presented(PDFShareable(data: Data("pdf".utf8), filename: "payslip.pdf"))
        let vs = ReportResultFeature.mapState(.mock)(state)
        #expect(vs.preview.isPresented)
        #expect(vs.preview.wrapped != nil)
    }
}

// MARK: - mapAction tests

@Suite("ReportResultFeature mapAction")
struct ReportResultFeatureMapActionTests {

    @Test func exportPDFMapsThrough() {
        let action = ReportResultFeature.mapAction(.mock)(.exportPDF)
        #expect(ReportResultFeature.Action.prism.exportPDF.preview(action) != nil)
    }

    @Test func onAppearMapsToStart() {
        let action = ReportResultFeature.mapAction(.mock)(.onAppear)
        #expect(ReportResultFeature.Action.prism.start.preview(action) != nil)
    }

    @Test func dismissPreviewMapsThrough() {
        let action = ReportResultFeature.mapAction(.mock)(.dismissPreview)
        #expect(ReportResultFeature.Action.prism.dismissPreview.preview(action) != nil)
    }
}

// MARK: - Snapshot tests

#if os(iOS) || os(tvOS)
import SnapshotTesting
import SwiftUI

@Suite("ReportResultFeature Snapshots", .snapshots)
@MainActor
struct ReportResultFeatureSnapshotTests {

    private func feature(state: ReportResultFeature.State) -> TestFeature<ReportResultFeature> {
        TestFeature<ReportResultFeature>(initial: state, environment: .mock)
    }

    private func baseReport(
        totalHours: Double = 8,
        grossPay: Decimal = 88,
        isEstimated: Bool = false,
        incompleteDays: Int = 0
    ) -> PayReport {
        PayReport(
            totalHours: totalHours,
            isEstimated: isEstimated,
            weekdayAvgHours: 8,
            weekendAvgHours: 0,
            projectedHours: isEstimated ? 4 : 0,
            projectedDays: isEstimated ? 3 : 0,
            incompleteDays: incompleteDays,
            grossPay: grossPay,
            niDeduction: isEstimated ? 10 : 0,
            pensionDeduction: isEstimated ? 5 : 0,
            incomeTaxDeduction: 0,
            studentLoanDeduction: 0,
            netPay: grossPay - (isEstimated ? 15 : 0),
            noWeekdayDataWarning: false,
            periodDays: 7,
            salary: SalaryRecord(amount: 11, periodicity: .hourly)
        )
    }

    private func loadedState(report: PayReport) -> ReportResultFeature.State {
        var s = ReportResultFeature.initialState(with: ())
        let from = Fixture.calendar.date(from: DateComponents(year: 2026, month: 5, day: 1))!
        let to = Fixture.todayMidnight
        s.report = report
        s.fromDate = from
        s.toDate = to
        // rendered is behavior-computed; replicate the mock formatters for snapshots.
        let m = Formatting.moneyFormatter(locale: Locale(identifier: "en_GB"))
        let d = Formatting.dateFormatter(locale: Locale(identifier: "en_GB"), calendar: Fixture.calendar)
        s.rendered = .init(
            periodLabel: "\(d(from, "d MMM")) – \(d(to, "d MMM"))",
            yearLabel: d(to, "yyyy"),
            netPay: m(report.netPay, 2), gross: m(report.grossPay, 2),
            incomeTax: m(report.incomeTaxDeduction, 2), ni: m(report.niDeduction, 2),
            pension: m(report.pensionDeduction, 2), studentLoan: m(report.studentLoanDeduction, 2)
        )
        return s
    }

    @Test func snapshotBasicReport() async {
        let s = loadedState(report: baseReport())
        await snap(feature(state: s), named: "reportresult-basic")
    }

    @Test func snapshotWithNIAndPension() async {
        let report = PayReport(
            totalHours: 80,
            isEstimated: false,
            weekdayAvgHours: 8,
            weekendAvgHours: 0,
            projectedDays: 0,
            incompleteDays: 0,
            grossPay: 880,
            niDeduction: 45.12,
            pensionDeduction: 33.70,
            incomeTaxDeduction: 0,
            studentLoanDeduction: 0,
            netPay: 801.18,
            noWeekdayDataWarning: false,
            periodDays: 30,
            salary: SalaryRecord(amount: 11, periodicity: .hourly)
        )
        let s = loadedState(report: report)
        await snap(feature(state: s), named: "reportresult-with-deductions")
    }

    @Test func snapshotWithEstimateNote() async {
        let s = loadedState(report: baseReport(totalHours: 40, grossPay: 440, isEstimated: true))
        await snap(feature(state: s), named: "reportresult-estimated")
    }

    @Test func snapshotWithIncompleteWarning() async {
        let s = loadedState(report: baseReport(incompleteDays: 2))
        await snap(feature(state: s), named: "reportresult-incomplete-warning")
    }

    @Test func snapshotWithPDFReady() async {
        var s = loadedState(report: baseReport())
        s.preview = .presented(PDFShareable(data: Data("fake-pdf".utf8), filename: "payslip.pdf"))
        await snap(feature(state: s), named: "reportresult-pdf-ready")
    }
}
#endif
