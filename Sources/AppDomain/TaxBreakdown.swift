import Foundation

/// The result of a UK tax computation — NI, Pension, Income Tax, Student Loan, and net pay.
public struct TaxBreakdown: Sendable {
    public var ni:           Decimal
    public var pension:      Decimal
    public var incomeTax:    Decimal
    public var studentLoan:  Decimal
    public var net:          Decimal

    public init(ni: Decimal, pension: Decimal, incomeTax: Decimal, studentLoan: Decimal, net: Decimal) {
        self.ni = ni
        self.pension = pension
        self.incomeTax = incomeTax
        self.studentLoan = studentLoan
        self.net = net
    }
}
