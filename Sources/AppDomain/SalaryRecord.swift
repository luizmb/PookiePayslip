import Foundation

// MARK: - Periodicity

public enum SalaryPeriodicity: String, Codable, Sendable, CaseIterable, Equatable {
    case hourly
    case monthly
    case yearly
}

// MARK: - National Insurance class

public enum NIClass: String, Codable, Sendable, CaseIterable, Equatable {
    /// Standard PAYE employee — Class 1 (8%/2% employee contribution)
    case employed
    /// Self-employed — Class 2 (£3.45/week) + Class 4 (9%/2%)
    case selfEmployed

    public var displayLabel: String {
        switch self {
        case .employed:     "Employed (PAYE)"
        case .selfEmployed: "Self-employed"
        }
    }
}

// MARK: - Student Loan plan

public enum StudentLoanPlan: String, Codable, Sendable, CaseIterable, Equatable {
    case none       // no student loan
    case plan1      // pre-2012 starters: 9% above £24,990
    case plan2      // 2012–2023 starters: 9% above £27,295 (most common)
    case plan5      // post-Aug 2023 starters: 9% above £25,000
    case postgrad   // Postgraduate Loan: 6% above £21,000

    public var displayLabel: String {
        switch self {
        case .none:    "None"
        case .plan1:   "Plan 1 (pre-2012)"
        case .plan2:   "Plan 2 (2012–2023)"
        case .plan5:   "Plan 5 (2023+)"
        case .postgrad: "Postgraduate Loan"
        }
    }

    /// Annual repayment threshold (England 2025/26)
    public var annualThreshold: Decimal {
        switch self {
        case .none:    0
        case .plan1:   24_990
        case .plan2:   27_295
        case .plan5:   25_000
        case .postgrad: 21_000
        }
    }

    /// Repayment rate
    public var rate: Decimal {
        switch self {
        case .postgrad: 0.06
        default:        0.09
        }
    }
}

// MARK: - SalaryRecord

public struct SalaryRecord: Codable, Sendable, Equatable {
    public var amount: Decimal
    public var periodicity: SalaryPeriodicity
    public var niClass: NIClass
    public var studentLoan: StudentLoanPlan
    /// Workplace-pension contribution rate (employee). `0` = no pension (opt-in, default off).
    public var pensionRate: Decimal

    public init(
        amount: Decimal,
        periodicity: SalaryPeriodicity,
        niClass: NIClass = .employed,
        studentLoan: StudentLoanPlan = .none,
        pensionRate: Decimal = 0
    ) {
        self.amount = amount
        self.periodicity = periodicity
        self.niClass = niClass
        self.studentLoan = studentLoan
        self.pensionRate = pensionRate
    }

    private enum CodingKeys: String, CodingKey {
        case amount, periodicity, niClass, studentLoan, pensionRate
    }

    // Migration-safe decode: salary files written before pension was configurable simply
    // omit `pensionRate`, which decodes as `0` (off) — never a decode failure.
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        amount = try c.decode(Decimal.self, forKey: .amount)
        periodicity = try c.decode(SalaryPeriodicity.self, forKey: .periodicity)
        niClass = try c.decodeIfPresent(NIClass.self, forKey: .niClass) ?? .employed
        studentLoan = try c.decodeIfPresent(StudentLoanPlan.self, forKey: .studentLoan) ?? .none
        pensionRate = try c.decodeIfPresent(Decimal.self, forKey: .pensionRate) ?? 0
    }

    // Effective monthly gross (for calendar display and monthly/yearly report)
    public var monthlyAmount: Decimal {
        switch periodicity {
        case .hourly:  return 0   // not a fixed monthly amount
        case .monthly: return amount
        case .yearly:  return amount / 12
        }
    }

    // Hourly rate (only meaningful for .hourly; others return nil)
    public var hourlyRate: Decimal? {
        periodicity == .hourly ? amount : nil
    }

    // Compact display string: "11£/h", "2,500£/mo", "45k£/y"
    public var displayString: String {
        let suffix: String
        switch periodicity {
        case .hourly:  suffix = "£/h"
        case .monthly: suffix = "£/mo"
        case .yearly:  suffix = "£/y"
        }
        return "\(formatCompact(amount))\(suffix)"
    }

    // Compute gross for a report period
    // For hourly: hours × rate; for monthly: month amount; for yearly: year/12
    public func grossPay(hoursWorked: Double, periodDays: Int) -> Decimal {
        switch periodicity {
        case .hourly:
            return Decimal(hoursWorked) * amount
        case .monthly:
            // Pro-rate: amount × (periodDays / 30.44 average days per month)
            let months = Decimal(periodDays) / Decimal(string: "30.4375")!
            return amount * months
        case .yearly:
            let months = Decimal(periodDays) / Decimal(string: "30.4375")!
            return (amount / 12) * months
        }
    }
}

private func formatCompact(_ value: Decimal) -> String {
    if value >= 1000 {
        let k = value / 1000
        let rounded = (k * 10).rounding(accordingToBehavior: nil) / 10
        if rounded.truncatingRemainder == 0 {
            return "\(Int(truncating: rounded as NSDecimalNumber))k"
        }
        return "\(rounded)k"
    }
    // Show up to 2 decimal places, dropping trailing zeros
    let n = value as NSDecimalNumber
    let d = n.doubleValue
    if d.truncatingRemainder(dividingBy: 1) == 0 { return "\(Int(d))" }
    let s = String(format: "%.2f", d)
    return s.hasSuffix("0") ? String(s.dropLast()) : s
}

private extension Decimal {
    var truncatingRemainder: Decimal {
        self - Decimal(Int(truncating: self as NSDecimalNumber))
    }
    func rounding(accordingToBehavior behaviour: NSDecimalNumberBehaviors?) -> Decimal {
        (self as NSDecimalNumber).rounding(accordingToBehavior: behaviour) as Decimal
    }
}
