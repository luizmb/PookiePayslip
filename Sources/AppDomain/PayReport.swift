import Foundation

public struct PayReport: Sendable, Equatable, Codable {
    public var totalHours: Double
    public var isEstimated: Bool
    public var weekdayAvgHours: Double
    public var weekendAvgHours: Double
    public var projectedHours: Double      // hours projected onto future days (0 when not estimated)
    public var projectedDays: Int
    public var incompleteDays: Int
    public var grossPay: Decimal
    public var niDeduction: Decimal
    public var pensionDeduction: Decimal
    public var incomeTaxDeduction: Decimal
    public var studentLoanDeduction: Decimal
    public var netPay: Decimal
    public var noWeekdayDataWarning: Bool
    public var periodDays: Int
    public var salary: SalaryRecord

    public init(
        totalHours: Double,
        isEstimated: Bool,
        weekdayAvgHours: Double,
        weekendAvgHours: Double,
        projectedHours: Double = 0,
        projectedDays: Int,
        incompleteDays: Int,
        grossPay: Decimal,
        niDeduction: Decimal,
        pensionDeduction: Decimal,
        incomeTaxDeduction: Decimal,
        studentLoanDeduction: Decimal,
        netPay: Decimal,
        noWeekdayDataWarning: Bool,
        periodDays: Int,
        salary: SalaryRecord
    ) {
        self.totalHours = totalHours
        self.isEstimated = isEstimated
        self.weekdayAvgHours = weekdayAvgHours
        self.weekendAvgHours = weekendAvgHours
        self.projectedHours = projectedHours
        self.projectedDays = projectedDays
        self.incompleteDays = incompleteDays
        self.grossPay = grossPay
        self.niDeduction = niDeduction
        self.pensionDeduction = pensionDeduction
        self.incomeTaxDeduction = incomeTaxDeduction
        self.studentLoanDeduction = studentLoanDeduction
        self.netPay = netPay
        self.noWeekdayDataWarning = noWeekdayDataWarning
        self.periodDays = periodDays
        self.salary = salary
    }
}
