import AppDomain
import CoreFP
import Foundation
import SwiftRex
import SwiftUI
import SwiftRexArchitecture
import ReactiveConcurrency
import SwiftRexReactiveConcurrency

@Feature(strategy: .observationSimple)
public enum ReportResultFeature {

    // MARK: - State

    public struct State: Sendable, Equatable, Codable {
        public var report: PayReport?           // source of truth for all figures below
        public var records: [WorkDayRecord]     // individual days for PDF breakdown page
        public var fromDate: Date?
        public var toDate: Date?
        public var pdfData: Data?
        public var rendered: Rendered?          // derived, locale-formatted cache (see Rendered)
    }

    /// Locale-formatted strings derived from `report`/`fromDate`/`toDate` by the behavior (which
    /// holds the `Environment`). A discardable cache — the raw figures in `report` are the truth.
    public struct Rendered: Sendable, Equatable, Codable {
        public var periodLabel: String
        public var yearLabel: String
        public var netPay: String
        public var gross: String
        public var incomeTax: String
        public var ni: String
        public var pension: String
        public var studentLoan: String

        public init(periodLabel: String, yearLabel: String, netPay: String, gross: String,
                    incomeTax: String, ni: String, pension: String, studentLoan: String) {
            self.periodLabel = periodLabel; self.yearLabel = yearLabel
            self.netPay = netPay; self.gross = gross; self.incomeTax = incomeTax
            self.ni = ni; self.pension = pension; self.studentLoan = studentLoan
        }
    }

    // MARK: - Action

    public enum Action: Sendable {
        case loaded(PayReport, [WorkDayRecord], from: Date, to: Date)
        case rendered(Rendered)   // behavior-formatted strings, stored into State
        case exportPDF
        case pdfReady(Data)
        case pdfFailed(RenderError)
        case dismissPreview
        case back
    }

    // MARK: - Environment

    public struct Environment: Sendable {
        let renderPDF: @Sendable (PayReport, [WorkDayRecord]) -> Publisher<Data, RenderError>
        let formatDate: @Sendable (Date, String) -> String
        let formatMoney: @Sendable (Decimal, Int) -> String

        public init(
            renderPDF: @Sendable @escaping (PayReport, [WorkDayRecord]) -> Publisher<Data, RenderError>,
            formatDate: @Sendable @escaping (Date, String) -> String,
            formatMoney: @Sendable @escaping (Decimal, Int) -> String
        ) {
            self.renderPDF = renderPDF
            self.formatDate = formatDate
            self.formatMoney = formatMoney
        }
    }

    // MARK: - ViewModel

        public struct ViewState: Sendable, Equatable {
            public var isLoaded: Bool
            // Header
            public var kickerLabel: String
            public var periodLabel: String
            public var yearLabel: String
            // Hero card
            public var heroTitleLabel: String
            public var netPayText: String
            public var heroMetaText: String
            // Notes
            public var estimateNoteText: String?
            public var incompleteWarningText: String?
            // Breakdown rows
            public var breakdownRows: [BreakdownRow]
            // Net card
            public var netCardLabel: String
            // Fine print
            public var finePrintHeading: String
            public var finePrintBody: String
            // Navigation
            public var printButtonLabel: String
            // PDF
            public var pdfShareable: PDFShareable?
            public var isPreviewPresented: Bool
        }

        public struct BreakdownRow: Sendable, Equatable {
            public var label: String
            public var sub: String?
            public var value: String
            public var isNegative: Bool
            public var isStrong: Bool
        }

        public enum ViewAction: Sendable {
            case exportPDF
            case dismissPreview
            case back
        }

    // MARK: - Mappings

    public static let mapState = Reader<Environment, @MainActor @Sendable (State) -> ViewState> { _ in buildViewState }
    public static let mapAction = Reader<Environment, @Sendable (ViewAction) -> Action> { _ in { va in
        switch va {
        case .exportPDF:      .exportPDF
        case .dismissPreview: .dismissPreview
        case .back:           .back
        }
    } }

    // MARK: - Lifecycle

    public static func initialState(with _: Void) -> State { .init(report: nil, records: [], fromDate: nil, toDate: nil, pdfData: nil, rendered: nil) }

    // MARK: - Behavior

    public static func behavior() -> Behavior<Action, State, Environment> {
        .handle { action, context in
            switch action {
            case .loaded(let report, let records, let from, let to):
                return .reduce { state in
                    state.report = report
                    state.records = records
                    state.fromDate = from
                    state.toDate = to
                    state.pdfData = nil
                }
                .produce { ctx in
                    // Format the locale-sensitive strings here (Environment is only reachable in an
                    // effect), then store them back into State via `.rendered`.
                    let m = ctx.environment.formatMoney
                    let d = ctx.environment.formatDate
                    let rendered = Rendered(
                        periodLabel: "\(d(from, "d MMM")) – \(d(to, "d MMM"))",
                        yearLabel: d(to, "yyyy"),
                        netPay: m(report.netPay, 2),
                        gross: m(report.grossPay, 2),
                        incomeTax: m(report.incomeTaxDeduction, 2),
                        ni: m(report.niDeduction, 2),
                        pension: m(report.pensionDeduction, 2),
                        studentLoan: m(report.studentLoanDeduction, 2)
                    )
                    return Publisher<Action, Never>.just(.rendered(rendered)).asEffect()
                }

            case .rendered(let rendered):
                return .reduce { $0.rendered = rendered }

            case .exportPDF:
                let report  = context.stateBefore?.report
                let records = context.stateBefore?.records ?? []
                return .produce { ctx in
                    guard let report else { return .empty }
                    return ctx.environment.renderPDF(report, records)
                        .asEffect { result in
                            switch result {
                            case .success(let data): .pdfReady(data)
                            case .failure(let e):    .pdfFailed(e)
                            }
                        }
                }

            case .pdfReady(let data):
                return .reduce { $0.pdfData = data }

            case .dismissPreview:
                return .reduce { $0.pdfData = nil }

            case .pdfFailed, .back:
                return .doNothing
            }
        }
    }

    public typealias Content = ReportResultView
}

// MARK: - Private helpers

private func fmtHours(_ h: Double) -> String {
    let rounded = (h * 10).rounded() / 10
    if rounded.truncatingRemainder(dividingBy: 1) == 0 { return "\(Int(rounded))" }
    return "\(rounded)"
}

// Renders a rate like 0.05 as "5%", 0.045 as "4.5%".
private func pctString(_ rate: Decimal) -> String {
    let pct = (rate * 100 as NSDecimalNumber).doubleValue
    if pct.truncatingRemainder(dividingBy: 1) == 0 { return "\(Int(pct))%" }
    return "\(pct)%"
}

private let buildViewState: @MainActor @Sendable (ReportResultFeature.State) -> ReportResultFeature.ViewState = { state in
    let emptyRow = ReportResultFeature.BreakdownRow(label: "", value: "", isNegative: false, isStrong: false)
    guard let r = state.report else {
        return .init(
            isLoaded: false,
            kickerLabel: "", periodLabel: "", yearLabel: "",
            heroTitleLabel: "", netPayText: "", heroMetaText: "",
            estimateNoteText: nil, incompleteWarningText: nil,
            breakdownRows: [], netCardLabel: "",
            finePrintHeading: "", finePrintBody: "",
            printButtonLabel: "Print / PDF",
            pdfShareable: nil,
            isPreviewPresented: false
        )
    }

    let rendered    = state.rendered
    let periodLabel = rendered?.periodLabel ?? ""
    let yearLabel   = rendered?.yearLabel ?? ""

    let totalH    = fmtHours(r.totalHours)
    let salaryStr = r.salary.displayString

    let grossSub: String
    switch r.salary.periodicity {
    case .hourly:  grossSub = "\(totalH)h × \(r.salary.displayString)"
    case .monthly: grossSub = "Monthly salary"
    case .yearly:  grossSub = "Annual ÷ 12"
    }

    let estimateNote: String? = r.isEstimated && r.projectedDays > 0
        ? "Includes \(fmtHours(r.projectedHours))h estimated across \(r.projectedDays) future day\(r.projectedDays != 1 ? "s" : "")."
        : nil

    let incompleteWarning: String? = r.incompleteDays > 0
        ? "\(r.incompleteDays) day\(r.incompleteDays != 1 ? "s" : "") in this period \(r.incompleteDays != 1 ? "are" : "is") missing a finish time and weren't counted."
        : nil

    let niSub: String = r.salary.niClass == .employed
        ? "Class 1, 8% above threshold"
        : "Class 4, 9% above threshold + Class 2"

    let pensionPct = pctString(r.salary.pensionRate)
    let pensionSub = "\(pensionPct) of qualifying earnings"

    var rows: [ReportResultFeature.BreakdownRow] = [
        .init(label: "Hours worked",       sub: nil,       value: "\(totalH)h",              isNegative: false, isStrong: false),
        .init(label: "Gross pay",          sub: grossSub,  value: rendered?.gross ?? "",      isNegative: false, isStrong: true),
        .init(label: "Income Tax",         sub: "PAYE bands (20%/40%/45%)", value: rendered?.incomeTax ?? "", isNegative: true, isStrong: false),
        .init(label: "National Insurance", sub: niSub,     value: rendered?.ni ?? "",         isNegative: true, isStrong: false),
    ]
    if r.pensionDeduction > 0 {
        rows.append(.init(label: "Pension", sub: pensionSub, value: rendered?.pension ?? "", isNegative: true, isStrong: false))
    }
    if r.salary.studentLoan != .none && r.studentLoanDeduction > 0 {
        rows.append(.init(label: "Student Loan", sub: r.salary.studentLoan.displayLabel, value: rendered?.studentLoan ?? "", isNegative: true, isStrong: false))
    }

    let niDesc = r.salary.niClass == .employed ? "Class 1 employee NI (8% main, 2% above UEL)" : "Class 2 + Class 4 self-employed NI"
    let loanDesc = r.salary.studentLoan == .none ? "" : " Student Loan \(r.salary.studentLoan.displayLabel)."
    let pensionDesc = r.pensionDeduction > 0 ? " Pension: \(pensionPct) of qualifying earnings." : ""
    let finePrint = "England 2025/26. Monthly (M1) basis, allowances ÷ 12. Salary: \(salaryStr). PAYE Income Tax (20%/40%/45%) with Personal Allowance taper above £100k. \(niDesc).\(pensionDesc)\(loanDesc) All figures are estimates, not formal tax advice."

    return .init(
        isLoaded: true,
        kickerLabel: "PAYSLIP ESTIMATE",
        periodLabel: periodLabel,
        yearLabel: yearLabel,
        heroTitleLabel: "Take-home pay",
        netPayText: rendered?.netPay ?? "",
        heroMetaText: "\(totalH)h worked · \(salaryStr)",
        estimateNoteText: estimateNote,
        incompleteWarningText: incompleteWarning,
        breakdownRows: rows,
        netCardLabel: "Take-home pay",
        finePrintHeading: "HOW THIS IS WORKED OUT",
        finePrintBody: finePrint,
        printButtonLabel: "Print / PDF",
        pdfShareable: state.pdfData.map { data in
            let name = periodLabel.isEmpty ? "payslip.pdf" : "payslip-\(periodLabel).pdf"
                .replacingOccurrences(of: " ", with: "-")
                .replacingOccurrences(of: "/", with: "-")
            return PDFShareable(data: data, filename: name)
        },
        isPreviewPresented: state.pdfData != nil
    )
}
