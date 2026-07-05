import AppDomain
import Foundation

// UK 2025/26 thresholds (England) — all annual, scaled to the number of *tax months* the
// period covers (Month-1 / non-cumulative PAYE). A single monthly pay run gets one full
// month's allowances (annual ÷ 12) regardless of whether the month is 28 or 31 days long,
// matching how HMRC operates a `1257L M1` code on a monthly payslip.

private enum UK {
    // National Insurance — Class 1 (employee) & Class 4 (self-employed)
    static let niPrimaryThreshold:   Decimal = 12_570  // PT
    static let niUpperEarningsLimit: Decimal = 50_270  // UEL

    // Class 1 employee rates
    static let niClass1Main:  Decimal = 0.08
    static let niClass1Upper: Decimal = 0.02

    // Class 4 self-employed rates
    static let niClass4Main:  Decimal = 0.09
    static let niClass4Upper: Decimal = 0.02

    // Class 2 self-employed flat rate (annual equivalent: £3.45 × 52)
    static let niClass2Annual: Decimal = 179.40

    // Workplace pension (employee auto-enrolment)
    static let pensionLower: Decimal = 6_240
    static let pensionUpper: Decimal = 50_270
    static let pensionRate:  Decimal = 0.05

    // Income Tax (England)
    static let personalAllowance: Decimal = 12_570
    static let basicRateLimit:    Decimal = 50_270
    static let higherRateLimit:   Decimal = 125_140
    static let paTaperStart:      Decimal = 100_000   // PA starts reducing above this
    static let basicRate:         Decimal = 0.20
    static let higherRate:        Decimal = 0.40
    static let additionalRate:    Decimal = 0.45
}

func calcDeductions(gross: Decimal, periodDays: Int, salary: SalaryRecord) -> TaxBreakdown {
    // Whole tax months in the period: a 28–31 day pay run is one month (annual ÷ 12); longer
    // ranges scale up (≈365 days → 12 months → full annual). Never below one month.
    let taxMonths = max(1, Int((Double(max(periodDays, 1)) / 30.4375).rounded()))
    let f = Decimal(taxMonths) / 12

    // MARK: - National Insurance

    let niPT  = UK.niPrimaryThreshold   * f
    let niUEL = UK.niUpperEarningsLimit  * f

    let ni: Decimal
    switch salary.niClass {
    case .employed:
        var n: Decimal = 0
        if gross > niPT  { n += (min(gross, niUEL) - niPT)  * UK.niClass1Main }
        if gross > niUEL { n += (gross - niUEL)              * UK.niClass1Upper }
        ni = max(0, n)

    case .selfEmployed:
        // Class 2 (flat, pro-rated) — only if above PT
        let class2 = gross > niPT ? UK.niClass2Annual * f : 0
        // Class 4 (profit-based)
        var n: Decimal = 0
        if gross > niPT  { n += (min(gross, niUEL) - niPT)  * UK.niClass4Main }
        if gross > niUEL { n += (gross - niUEL)              * UK.niClass4Upper }
        ni = max(0, n) + class2
    }

    // MARK: - Pension (opt-in — only when the salary carries a contribution rate)

    let pension: Decimal
    if salary.pensionRate > 0 {
        let qLow  = UK.pensionLower * f
        let qHigh = UK.pensionUpper * f
        pension = max(0, min(gross, qHigh) - qLow) * salary.pensionRate
    } else {
        pension = 0
    }

    // MARK: - Income Tax (England, with Personal Allowance tapering)

    let paFull = UK.personalAllowance * f
    let paBase = UK.paTaperStart      * f

    // PA reduces by £1 for every £2 over £100k — minimum 0
    let paReduction = gross > paBase ? max(0, (gross - paBase) / 2) : 0
    let pa          = max(0, paFull - paReduction)

    let basicTop  = UK.basicRateLimit  * f
    let higherTop = UK.higherRateLimit * f

    var incomeTax: Decimal = 0
    if gross > pa       { incomeTax += (min(gross, basicTop)  - pa)       * UK.basicRate }
    if gross > basicTop { incomeTax += (min(gross, higherTop) - basicTop) * UK.higherRate }
    if gross > higherTop { incomeTax += (gross - higherTop)               * UK.additionalRate }
    incomeTax = max(0, incomeTax)

    // MARK: - Student Loan

    let studentLoan: Decimal
    if salary.studentLoan == .none {
        studentLoan = 0
    } else {
        let threshold = salary.studentLoan.annualThreshold * f
        studentLoan = gross > threshold
            ? (gross - threshold) * salary.studentLoan.rate
            : 0
    }

    // MARK: - Net

    // Round every figure to whole pennies. The ÷12 month factor is non-terminating in Decimal,
    // so the raw products carry a 1e-34 tail; money is penny-precise, so collapse it here.
    let niR = penny(ni)
    let pensionR = penny(pension)
    let taxR = penny(incomeTax)
    let loanR = penny(studentLoan)
    let net = penny(max(0, gross - niR - pensionR - taxR - loanR))
    return TaxBreakdown(ni: niR, pension: pensionR, incomeTax: taxR, studentLoan: loanR, net: net)
}

private func penny(_ value: Decimal) -> Decimal {
    var result = Decimal()
    var input = value
    NSDecimalRound(&result, &input, 2, .plain)
    return result
}
