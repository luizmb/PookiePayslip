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
public enum SalaryEditorFeature {

    // MARK: - State

    public struct State: Sendable, Equatable {
        public var amount: Decimal
        public var periodicity: SalaryPeriodicity
        public var niClass: NIClass
        public var studentLoan: StudentLoanPlan
        public var pensionRate: Decimal      // 0 = no pension (opt-in, default off)
        public var monthDate: Date?          // nil until the bridge seeds it from the calendar month
    }

    // Default employee contribution applied when pension is switched on (UK auto-enrolment).
    static let defaultPensionRate = Decimal(string: "0.05")!

    // MARK: - Action

    public enum Action: Sendable {
        case setAmount(Decimal)
        case setPeriodicity(SalaryPeriodicity)
        case setNIClass(NIClass)
        case setStudentLoan(StudentLoanPlan)
        case setPensionEnabled(Bool)
        case save
        case saved(SalaryRecord)   // dispatched after file write; bridgeBehavior routes to calendar
        case saveFailed
        case back
    }

    // MARK: - Environment

    public struct Environment: Sendable {
        let decode:      DataDecoder<MonthData>
        let encode:      DataEncoder<MonthData>
        let readFile:    @Sendable (String) -> Publisher<Data, ReadingError>
        let saveFile:    @Sendable (Data, String) -> Publisher<Void, SavingError>
        let calendar:    @Sendable () -> Calendar

        public init(
            decoder:  any DataDecoderFactory,
            encoder:  any DataEncoderFactory,
            readFile: @Sendable @escaping (String) -> Publisher<Data, ReadingError>,
            saveFile: @Sendable @escaping (Data, String) -> Publisher<Void, SavingError>,
            calendar: @Sendable @escaping () -> Calendar
        ) {
            decode       = decoder.dataDecoder(for: MonthData.self)
            encode       = encoder.dataEncoder(for: MonthData.self)
            self.readFile = readFile
            self.saveFile = saveFile
            self.calendar = calendar
        }
    }

    // MARK: - ViewModel

        public struct ViewState: Sendable, Equatable {
            public var amount: Decimal
            public var amountText: String
            public var periodicity: SalaryPeriodicity
            public var niClass: NIClass
            public var studentLoan: StudentLoanPlan
            public var pensionEnabled: Bool
            public var pensionLabel: String
            public var displayPreview: String
            // Labels
            public var titleLabel: String
            public var amountLabel: String
            public var currencySymbol: String
            public var saveButtonLabel: String
            public var canSave: Bool
        }

        @Prisms
        public enum ViewAction: Sendable {
            case setAmountText(String)
            case setPeriodicity(SalaryPeriodicity)
            case setNIClass(NIClass)
            case setStudentLoan(StudentLoanPlan)
            case setPensionEnabled(Bool)
            case save
            case back
        }

    // MARK: - Mappings

    public static let mapState = Reader<Environment, @MainActor @Sendable (State) -> ViewState> { _ in { state in
        let record = SalaryRecord(amount: state.amount, periodicity: state.periodicity)
        let preview: String = state.amount > 0
            ? "You earn \(record.displayString)"
            : "Enter an amount"
        // amountText: show integer if whole, otherwise decimal without trailing zeros
        let amountText: String = {
            if state.amount == 0 { return "" }
            let n = state.amount as NSDecimalNumber
            let d = n.doubleValue
            if d.truncatingRemainder(dividingBy: 1) == 0 { return "\(Int(d))" }
            let s = String(format: "%.2f", d)
            return s.hasSuffix("0") ? String(s.dropLast()) : s
        }()
        let pensionEnabled = state.pensionRate > 0
        let pensionPct = (state.pensionRate * 100 as NSDecimalNumber).doubleValue
        let pensionLabel = pensionEnabled
            ? "Workplace pension (\(pensionPct.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(pensionPct))" : "\(pensionPct)")%)"
            : "Workplace pension"
        return .init(
            amount: state.amount,
            amountText: amountText,
            periodicity: state.periodicity,
            niClass: state.niClass,
            studentLoan: state.studentLoan,
            pensionEnabled: pensionEnabled,
            pensionLabel: pensionLabel,
            displayPreview: preview,
            titleLabel: "Salary",
            amountLabel: "Amount",
            currencySymbol: "£",
            saveButtonLabel: "Save",
            canSave: state.amount > 0
        )
    } }

    public static let mapAction = Reader<Environment, @Sendable (ViewAction) -> Action> { _ in { va in
        switch va {
        case .setAmountText(let s):
            let cleaned = s.replacingOccurrences(of: ",", with: ".")
            return .setAmount(Decimal(string: cleaned) ?? 0)
        case .setPeriodicity(let p):  return .setPeriodicity(p)
        case .setNIClass(let c):      return .setNIClass(c)
        case .setStudentLoan(let l):  return .setStudentLoan(l)
        case .setPensionEnabled(let b): return .setPensionEnabled(b)
        case .save:                   return .save
        case .back:                   return .back
        }
    } }

    // MARK: - Lifecycle

    public static func initialState(with _: Void) -> State {
        .init(amount: 0, periodicity: .hourly, niClass: .employed, studentLoan: .none, pensionRate: 0, monthDate: nil)
    }

    // MARK: - Behavior

    public static func behavior() -> Behavior<Action, State, Environment> {
        .handle { action, context in
            guard let stateBefore = context.stateBefore else { return .doNothing }

            switch action {
            case .setAmount(let a):      return .reduce { $0.amount = a }
            case .setPeriodicity(let p): return .reduce { $0.periodicity = p }
            case .setNIClass(let c):     return .reduce { $0.niClass = c }
            case .setStudentLoan(let l): return .reduce { $0.studentLoan = l }
            case .setPensionEnabled(let on):
                return .reduce { $0.pensionRate = on ? SalaryEditorFeature.defaultPensionRate : 0 }

            case .save:
                let salary = SalaryRecord(
                    amount: stateBefore.amount,
                    periodicity: stateBefore.periodicity,
                    niClass: stateBefore.niClass,
                    studentLoan: stateBefore.studentLoan,
                    pensionRate: stateBefore.pensionRate
                )
                guard salary.amount > 0, let monthDate = stateBefore.monthDate else { return .doNothing }
                return .produce { ctx in
                    let cal = ctx.environment.calendar()
                    let filename = monthFilename(for: monthDate, calendar: cal)
                    return ctx.environment.readFile(filename)
                        .map { data -> MonthData in
                            if case .success(let md) = ctx.environment.decode(data) { md } else { MonthData() }
                        }
                        .replaceError(with: MonthData())   // missing/unreadable month → start a fresh one
                        .setFailureType(to: SavingError.self)
                        .flatMap { monthData -> Publisher<Void, SavingError> in
                            var updated = monthData
                            updated.salary = salary
                            switch ctx.environment.encode(updated) {
                            case .failure:
                                return .fail(.ioError(filename: filename, underlying: EncodingError.invalidValue(salary, .init(codingPath: [], debugDescription: ""))))
                            case .success(let data):
                                return ctx.environment.saveFile(data, filename)
                            }
                        }
                        .asEffect { result in
                            if case .failure = result { .saveFailed } else { .saved(salary) }
                        }
                }

            case .saved, .saveFailed, .back:
                return .doNothing   // bridgeBehavior handles navigation + calendar update
            }
        }
    }

    public typealias Content = SalaryEditorView
}
