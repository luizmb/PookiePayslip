@testable import AppCore
import AppDomain
import Foundation
import Testing

@Suite("TaxCalculator — UK 2025/26 rates")
struct TaxCalculatorTests {

    // MARK: - Helpers

    private func deductions(gross: Decimal, days: Int,
                             niClass: NIClass = .employed,
                             studentLoan: StudentLoanPlan = .none,
                             pensionRate: Decimal = 0) -> TaxBreakdown {
        let salary = SalaryRecord(amount: gross, periodicity: .hourly, niClass: niClass, studentLoan: studentLoan, pensionRate: pensionRate)
        return calcDeductions(gross: gross, periodDays: days, salary: salary)
    }

    // MARK: - Below primary threshold → no NI, minimal pension

    @Test func belowPTProducesNoNI() {
        // Pro-rate PT for 365 days: £12,570 / 1 = £12,570
        // Gross £10,000 < £12,570 → NI = 0
        let result = deductions(gross: 10_000, days: 365)
        #expect(result.ni == 0)
    }

    @Test func belowPensionLowerBoundProducesNoPension() {
        // Lower QE for 365 days: £6,240
        // Gross £5,000 < £6,240 → pension = 0
        let result = deductions(gross: 5_000, days: 365)
        #expect(result.pension == 0)
    }

    // MARK: - Between PT and UEL

    @Test func between_PT_and_UEL_calculatesMainNIRate() {
        // 365-day period → full annual thresholds apply
        // Gross: £20,000. PT: £12,570. UEL: £50,270
        // NI = (20,000 - 12,570) × 8% = 7,430 × 0.08 = 594.40
        let result = deductions(gross: 20_000, days: 365)
        #expect(result.ni == Decimal(string: "594.4")!)
    }

    @Test func above_UEL_addsUpperRateSurcharge() {
        // Gross £60,000 > UEL £50,270
        // NI (main): (50,270 - 12,570) × 8% = 37,700 × 0.08 = 3,016
        // NI (upper): (60,000 - 50,270) × 2% = 9,730 × 0.02 = 194.6
        // Total NI = 3,016 + 194.6 = 3,210.6
        let result = deductions(gross: 60_000, days: 365)
        #expect(result.ni == Decimal(string: "3210.6")!)
    }

    // MARK: - Pension

    @Test func noPensionWhenRateIsZero() {
        // Pension is opt-in: the default salary carries no rate → no deduction, ever.
        let result = deductions(gross: 20_000, days: 365)
        #expect(result.pension == 0)
    }

    @Test func pensionOnQualifyingEarningsBand() {
        // Gross £20,000, 5% opted in. Lower QE: £6,240. Upper QE: £50,270.
        // Qualifying earnings: 20,000 - 6,240 = 13,760
        // Pension = 13,760 × 5% = 688
        let result = deductions(gross: 20_000, days: 365, pensionRate: Decimal(string: "0.05")!)
        #expect(result.pension == 688)
    }

    @Test func pensionCappedAtUpperQE() {
        // Gross £100,000 > upper QE £50,270 → capped at 50,270
        // Qualifying earnings: 50,270 - 6,240 = 44,030
        // Pension = 44,030 × 5% = 2,201.5
        let result = deductions(gross: 100_000, days: 365, pensionRate: Decimal(string: "0.05")!)
        #expect(result.pension == Decimal(string: "2201.5")!)
    }

    // MARK: - Income Tax

    @Test func belowPersonalAllowanceNoIncomeTax() {
        // Gross £10,000 < PA £12,570 → no income tax
        let result = deductions(gross: 10_000, days: 365)
        #expect(result.incomeTax == 0)
    }

    @Test func basicRateIncomeTax() {
        // Gross £20,000. Taxable = 20,000 - 12,570 = 7,430 × 20% = 1,486
        let result = deductions(gross: 20_000, days: 365)
        #expect(result.incomeTax == Decimal(string: "1486")!)
    }

    @Test func higherRateIncomeTax() {
        // Gross £60,000. Basic-rate on (50,270-12,570)=37,700 × 20% = 7,540
        // Higher-rate on (60,000-50,270)=9,730 × 40% = 3,892
        // Total = 11,432
        let result = deductions(gross: 60_000, days: 365)
        #expect(result.incomeTax == 11_432)
    }

    // MARK: - Net pay

    @Test func netPayIsGrossMinusAllDeductions() {
        let result = deductions(gross: 20_000, days: 365)
        #expect(result.net == 20_000 - result.ni - result.pension - result.incomeTax)
    }

    // MARK: - Tax-month scaling (Month-1 basis)

    @Test func halfYearCountsAsSixTaxMonths() {
        // 182 days → 6 tax months → PT = 12,570 × 6/12 = 6,285
        // Gross £6,000 < £6,285 → no NI
        let result = deductions(gross: 6_000, days: 182)
        #expect(result.ni == 0)
    }

    @Test func shortPeriodCountsAsOneTaxMonth() {
        // M1: any sub-month run gets one full month's allowances (not pro-rated by day).
        // Monthly PT = 12,570 / 12 = £1,047.50. Gross £50 « PT → no NI.
        let result = deductions(gross: 50, days: 1)
        #expect(result.ni == 0)
    }

    @Test func zeroDaysUsesMinimumOfOneMonth() {
        let result = deductions(gross: 1_000, days: 0)
        // Should not crash, and net = gross − all deductions
        #expect(result.net == 1_000 - result.ni - result.pension - result.incomeTax)
    }

    // MARK: - Real monthly payslip (1257L M1, no pension)

    @Test func monthlyPayslipMatchesWithinPennies() {
        // June payslip: gross £1,496 over a ~31-day pay month.
        // Monthly allowance £1,047.50 → NI 8%×(1496−1047.5)=£35.88, PAYE 20%×448.5=£89.70.
        let result = deductions(gross: 1_496, days: 31)
        #expect(result.ni == Decimal(string: "35.88")!)
        #expect(result.incomeTax == Decimal(string: "89.7")!)
        #expect(result.pension == 0)
    }
}
