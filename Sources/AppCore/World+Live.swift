import AppDomain
import Core
import CoreFP
import Foundation
import ReactiveConcurrency
#if canImport(UIKit)
import UIKit

extension World {
    public static let real: World = .init(
        decoder:     JSONDecoder(),
        encoder:     JSONEncoder(),
        readFile:    FileIO.live.read,
        saveFile:    FileIO.live.write,
        currentDate: { Date() },
        newID:       { UUID() },
        calendar:    { .current },
        dayBefore:   { Calendar.current.date(byAdding: .day, value: -1, to: $0) ?? $0 },
        dayAfter:    { Calendar.current.date(byAdding: .day, value:  1, to: $0) ?? $0 },
        calcTax:     calcDeductions(gross:periodDays:salary:),
        renderPDF:   renderPayReportPDF,
        formatDate:  Formatting.dateFormatter(locale: .current, calendar: .current),
        formatMoney: Formatting.moneyFormatter(locale: Locale(identifier: "en_GB")),
        loadSettings: makeLoadSettings(FileIO.live.read),
        saveSettings: makeSaveSettings(FileIO.live.write),
        exportDatabase: FileIO.live.exportZip
    )
}

// MARK: - Entry point

private let renderPayReportPDF: @Sendable (PayReport, [WorkDayRecord]) -> Publisher<Data, RenderError> = { report, records in
    Publisher.future { () async -> Result<Data, RenderError> in
        let a4 = CGRect(x: 0, y: 0, width: 595, height: 842)
        let renderer = UIGraphicsPDFRenderer(bounds: a4)
        let data = renderer.pdfData { ctx in
            ctx.beginPage()
            drawPage1(report: report, records: records, bounds: a4)

            let completed = records.filter { $0.isComplete }.sorted { $0.date < $1.date }
            if report.salary.periodicity == .hourly && !completed.isEmpty {
                ctx.beginPage()
                drawPage2(records: completed, report: report, bounds: a4)
            }
        }
        return .success(data)
    }
}

// MARK: - Page 1 – Summary

private func drawPage1(report: PayReport, records: [WorkDayRecord], bounds: CGRect) {
    let margin: CGFloat = 48
    let col2: CGFloat = bounds.width - margin   // right-align column
    var y: CGFloat = 42

    // ── Kicker ──────────────────────────────────────────────────────────
    text("PAYSLIP ESTIMATE", x: margin, y: &y,
         font: .systemFont(ofSize: 8, weight: .bold), color: terracotta, kern: 2)
    y += 4

    // ── Period & earned ─────────────────────────────────────────────────
    let earned: String = {
        switch report.salary.periodicity {
        case .hourly:  return "\(fmtH(report.totalHours))h worked · \(report.salary.displayString)"
        case .monthly: return "Monthly salary · \(report.salary.displayString)"
        case .yearly:  return "Annual salary ÷ 12 · \(report.salary.displayString)"
        }
    }()
    text(earned, x: margin, y: &y,
         font: .systemFont(ofSize: 20, weight: .bold), color: .black)
    text("Period: \(report.periodDays) days", x: margin, y: &y,
         font: .systemFont(ofSize: 10), color: muted)
    y += 14

    // ── SALARY DETAILS ──────────────────────────────────────────────────
    sectionHeader("SALARY DETAILS", x: margin, y: &y)
    row("Amount",       value: report.salary.displayString,        lx: margin, rx: col2, y: &y)
    row("Pay period",   value: report.salary.periodicity.pdfLabel, lx: margin, rx: col2, y: &y)
    row("Employment",   value: report.salary.niClass.displayLabel, lx: margin, rx: col2, y: &y)
    if report.salary.studentLoan != .none {
        row("Student Loan", value: report.salary.studentLoan.displayLabel, lx: margin, rx: col2, y: &y)
    }
    y += 10

    // ── EARNINGS ────────────────────────────────────────────────────────
    sectionHeader("EARNINGS", x: margin, y: &y)
    switch report.salary.periodicity {
    case .hourly:
        row("Hours worked", value: "\(fmtH(report.totalHours))h", lx: margin, rx: col2, y: &y)
        row("Rate",         value: report.salary.displayString,   lx: margin, rx: col2, y: &y)
        rowBold("Gross pay", value: gbp(report.grossPay), lx: margin, rx: col2, y: &y)
    case .monthly:
        rowBold("Monthly salary (gross)", value: gbp(report.grossPay), lx: margin, rx: col2, y: &y)
    case .yearly:
        rowBold("Annual salary ÷ 12 (gross)", value: gbp(report.grossPay), lx: margin, rx: col2, y: &y)
    }
    y += 10

    // ── DEDUCTIONS ──────────────────────────────────────────────────────
    sectionHeader("DEDUCTIONS", x: margin, y: &y)
    rowWithSub("Income Tax",         sub: "PAYE bands 20%/40%/45%; PA taper above £100k",
               value: "− \(gbp(report.incomeTaxDeduction))", lx: margin, rx: col2, y: &y, neg: true)
    let niSub = report.salary.niClass == .employed
        ? "Class 1: 8% above PT, 2% above UEL"
        : "Class 4: 9% above PT, 2% above UEL + Class 2 flat"
    rowWithSub("National Insurance",  sub: niSub,
               value: "− \(gbp(report.niDeduction))",         lx: margin, rx: col2, y: &y, neg: true)
    if report.pensionDeduction > 0 {
        rowWithSub("Pension",         sub: "\(pctLabel(report.salary.pensionRate)) of qualifying earnings",
                   value: "− \(gbp(report.pensionDeduction))", lx: margin, rx: col2, y: &y, neg: true)
    }
    if report.studentLoanDeduction > 0 {
        rowWithSub("Student Loan",    sub: report.salary.studentLoan.displayLabel,
                   value: "− \(gbp(report.studentLoanDeduction))", lx: margin, rx: col2, y: &y, neg: true)
    }
    y += 14

    // ── TAKE-HOME PAY ───────────────────────────────────────────────────
    let boxH: CGFloat = 54
    let boxRect = CGRect(x: margin, y: y, width: bounds.width - margin * 2, height: boxH)
    UIColor(hex: "#d98a6a").setFill()
    UIBezierPath(roundedRect: boxRect, cornerRadius: 8).fill()

    let labelAttrs: [NSAttributedString.Key: Any] = [
        .font: UIFont.systemFont(ofSize: 11, weight: .semibold),
        .foregroundColor: UIColor.white
    ]
    "Take-home pay".draw(at: CGPoint(x: margin + 14, y: y + 12), withAttributes: labelAttrs)

    let netStr = gbp(report.netPay)
    let netFont = UIFont.systemFont(ofSize: 22, weight: .bold)
    let netSize = netStr.size(withAttributes: [.font: netFont])
    let netAttrs: [NSAttributedString.Key: Any] = [.font: netFont, .foregroundColor: UIColor.white]
    netStr.draw(at: CGPoint(x: bounds.width - margin - 14 - netSize.width, y: y + (boxH - netSize.height) / 2),
                withAttributes: netAttrs)
    y += boxH + 18

    // ── Fine print ──────────────────────────────────────────────────────
    let fine = "England 2025/26. Monthly (M1) basis — allowances ÷ 12. " +
               "Figures are estimates, not formal tax advice."
    textWrapped(fine, x: margin, y: &y, maxWidth: bounds.width - margin * 2,
                font: .systemFont(ofSize: 8), color: muted)
    if report.salary.periodicity == .hourly && records.contains(where: { $0.isComplete }) {
        y += 6
        text("→  Day-by-day breakdown on page 2.", x: margin, y: &y,
             font: .italicSystemFont(ofSize: 9), color: muted)
    }
}

// MARK: - Page 2 – Day breakdown

private func drawPage2(records: [WorkDayRecord], report: PayReport, bounds: CGRect) {
    let margin: CGFloat = 48
    var y: CGFloat = 42

    text("DAY-BY-DAY BREAKDOWN", x: margin, y: &y,
         font: .systemFont(ofSize: 8, weight: .bold), color: terracotta, kern: 2)
    y += 4
    text("Rate: \(report.salary.displayString)  ·  \(records.count) completed days",
         x: margin, y: &y, font: .systemFont(ofSize: 10), color: muted)
    y += 12

    // Column layout (x offsets from margin)
    let cols: [(header: String, x: CGFloat, w: CGFloat, align: NSTextAlignment)] = [
        ("Date",    0,   130, .left),
        ("Start",   130,  46, .center),
        ("End",     176,  46, .center),
        ("Breaks",  222,  58, .right),
        ("Worked",  280,  72, .right),
    ]

    // Header
    for col in cols {
        let r = CGRect(x: margin + col.x, y: y, width: col.w, height: 16)
        let para = NSMutableParagraphStyle(); para.alignment = col.align
        col.header.draw(in: r, withAttributes: [
            .font: UIFont.systemFont(ofSize: 9, weight: .bold),
            .foregroundColor: UIColor(hex: "#3b332e"),
            .paragraphStyle: para
        ])
    }
    y += 18

    // Divider
    drawHRule(x: margin, y: y, width: bounds.width - margin * 2, color: UIColor(hex: "#ece1d3"), thickness: 0.5)
    y += 6

    let dayFmt = DateFormatter(); dayFmt.dateFormat = "EEE d MMM"
    var totalMinutes = 0

    for rec in records {
        guard let start = rec.startTime, let end = rec.endTime else { continue }

        let breakMins = rec.breaks.compactMap { b -> Int? in
            guard let bs = b.startTime, let be = b.endTime else { return nil }
            var d = be.totalMinutes - bs.totalMinutes; if d < 0 { d += 24*60 }; return d
        }.reduce(0, +)

        var worked = end.totalMinutes - start.totalMinutes
        if worked < 0 { worked += 24 * 60 }
        worked = max(0, worked - breakMins)
        totalMinutes += worked

        let values: [String] = [
            dayFmt.string(from: rec.date),
            fmtTOD(start),
            fmtTOD(end),
            breakMins > 0 ? fmtMinutes(breakMins) : "—",
            fmtMinutes(worked)
        ]

        if y + 16 > bounds.height - 80 {
            text("… \(records.count - (records.firstIndex(where: { $0.id == rec.id }) ?? 0)) more days not shown",
                 x: margin, y: &y, font: .italicSystemFont(ofSize: 9), color: muted)
            break
        }

        for (i, col) in cols.enumerated() {
            let r = CGRect(x: margin + col.x, y: y, width: col.w, height: 14)
            let para = NSMutableParagraphStyle(); para.alignment = col.align
            values[i].draw(in: r, withAttributes: [
                .font: UIFont.systemFont(ofSize: 9.5),
                .foregroundColor: UIColor(hex: "#6b5e56"),
                .paragraphStyle: para
            ])
        }
        y += 15
    }

    // Footer
    y += 4
    drawHRule(x: margin, y: y, width: bounds.width - margin * 2, color: UIColor(hex: "#d98a6a"), thickness: 1)
    y += 8

    // Totals
    let totalWorked = fmtMinutes(totalMinutes)
    let totals: [String] = ["TOTAL", "", "", "", totalWorked]
    for (i, col) in cols.enumerated() {
        let r = CGRect(x: margin + col.x, y: y, width: col.w, height: 16)
        let para = NSMutableParagraphStyle(); para.alignment = col.align
        totals[i].draw(in: r, withAttributes: [
            .font: UIFont.systemFont(ofSize: 10, weight: .bold),
            .foregroundColor: UIColor(hex: "#3b332e"),
            .paragraphStyle: para
        ])
    }
    y += 20

    let hourlyGross  = Decimal(totalMinutes) / 60 * report.salary.amount
    text("Gross: \(gbp(hourlyGross))   Net (after all deductions): \(gbp(report.netPay))",
         x: margin, y: &y,
         font: .systemFont(ofSize: 10, weight: .semibold), color: UIColor(hex: "#3b332e"))
}

// MARK: - Low-level drawing helpers

private let muted    = UIColor(hex: "#9b8f84")
private let terracotta = UIColor(hex: "#d98a6a")

private func sectionHeader(_ title: String, x: CGFloat, y: inout CGFloat) {
    drawHRule(x: x, y: y, width: 499 - x, color: UIColor(hex: "#ece1d3"), thickness: 0.5)
    y += 6
    text(title, x: x, y: &y,
         font: .systemFont(ofSize: 8, weight: .bold), color: muted, kern: 1.5)
    y += 2
}

private func text(_ s: String, x: CGFloat, y: inout CGFloat,
                  font: UIFont, color: UIColor, kern: CGFloat = 0) {
    var attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
    if kern > 0 { attrs[.kern] = kern }
    let h = s.size(withAttributes: attrs).height + 2
    s.draw(at: CGPoint(x: x, y: y), withAttributes: attrs)
    y += h
}

private func textWrapped(_ s: String, x: CGFloat, y: inout CGFloat,
                          maxWidth: CGFloat, font: UIFont, color: UIColor) {
    let para = NSMutableParagraphStyle(); para.lineBreakMode = .byWordWrapping
    let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color, .paragraphStyle: para]
    let r = CGRect(x: x, y: y, width: maxWidth, height: 200)
    let used = NSAttributedString(string: s, attributes: attrs).boundingRect(with: r.size, options: .usesLineFragmentOrigin, context: nil)
    s.draw(with: r, options: .usesLineFragmentOrigin, attributes: attrs, context: nil)
    y += used.height + 2
}

private func row(_ label: String, value: String, lx: CGFloat, rx: CGFloat, y: inout CGFloat) {
    let font = UIFont.systemFont(ofSize: 10.5)
    let color = UIColor(hex: "#3b332e")
    label.draw(at: CGPoint(x: lx, y: y), withAttributes: [.font: font, .foregroundColor: color])
    let vw = value.size(withAttributes: [.font: font]).width
    value.draw(at: CGPoint(x: rx - vw, y: y), withAttributes: [.font: font, .foregroundColor: color])
    y += font.lineHeight + 3
}

private func rowBold(_ label: String, value: String, lx: CGFloat, rx: CGFloat, y: inout CGFloat) {
    let font = UIFont.systemFont(ofSize: 10.5, weight: .semibold)
    let color = UIColor(hex: "#3b332e")
    label.draw(at: CGPoint(x: lx, y: y), withAttributes: [.font: font, .foregroundColor: color])
    let vw = value.size(withAttributes: [.font: font]).width
    value.draw(at: CGPoint(x: rx - vw, y: y), withAttributes: [.font: font, .foregroundColor: color])
    y += font.lineHeight + 3
}

private func rowWithSub(_ label: String, sub: String, value: String,
                         lx: CGFloat, rx: CGFloat, y: inout CGFloat, neg: Bool = false) {
    let lFont = UIFont.systemFont(ofSize: 10.5)
    let sFont = UIFont.systemFont(ofSize: 8)
    let vFont = UIFont.systemFont(ofSize: 10.5, weight: neg ? .regular : .regular)
    let lColor = UIColor(hex: "#3b332e")
    let vColor = neg ? UIColor(hex: "#683c33") : lColor
    label.draw(at: CGPoint(x: lx, y: y), withAttributes: [.font: lFont, .foregroundColor: lColor])
    let vw = value.size(withAttributes: [.font: vFont]).width
    value.draw(at: CGPoint(x: rx - vw, y: y), withAttributes: [.font: vFont, .foregroundColor: vColor])
    y += lFont.lineHeight + 1
    sub.draw(at: CGPoint(x: lx, y: y), withAttributes: [.font: sFont, .foregroundColor: muted])
    y += sFont.lineHeight + 4
}

private func drawHRule(x: CGFloat, y: CGFloat, width: CGFloat, color: UIColor, thickness: CGFloat) {
    color.setStroke()
    let p = UIBezierPath()
    p.move(to: CGPoint(x: x, y: y))
    p.addLine(to: CGPoint(x: x + width, y: y))
    p.lineWidth = thickness
    p.stroke()
}

// MARK: - Formatters

private func gbp(_ d: Decimal) -> String {
    let f = NumberFormatter(); f.locale = Locale(identifier: "en_GB")
    f.numberStyle = .currency; f.currencySymbol = "£"
    f.minimumFractionDigits = 2; f.maximumFractionDigits = 2
    return f.string(from: d as NSDecimalNumber) ?? "£0.00"
}

private func fmtH(_ h: Double) -> String {
    let r = (h * 10).rounded() / 10
    return r.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(r))" : "\(r)"
}

private func fmtTOD(_ t: TimeOfDay) -> String {
    String(format: "%02d:%02d", t.hour, t.minute)
}

private func fmtMinutes(_ m: Int) -> String {
    let h = m / 60; let mn = m % 60
    return mn == 0 ? "\(h)h" : "\(h)h \(mn)m"
}

private func pctLabel(_ rate: Decimal) -> String {
    let pct = (rate * 100 as NSDecimalNumber).doubleValue
    return pct.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(pct))%" : "\(pct)%"
}

private extension UIColor {
    convenience init(hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0; Scanner(string: h).scanHexInt64(&int)
        self.init(red:   CGFloat((int >> 16) & 0xFF) / 255,
                  green: CGFloat((int >> 8)  & 0xFF) / 255,
                  blue:  CGFloat(int         & 0xFF) / 255, alpha: 1)
    }
}

private extension SalaryPeriodicity {
    var pdfLabel: String {
        switch self { case .hourly: "Hourly"; case .monthly: "Monthly"; case .yearly: "Annual" }
    }
}

#else

extension World {
    public static let real: World = .init(
        decoder:     JSONDecoder(),
        encoder:     JSONEncoder(),
        readFile:    FileIO.live.read,
        saveFile:    FileIO.live.write,
        currentDate: { Date() },
        newID:       { UUID() },
        calendar:    { .current },
        dayBefore:   { Calendar.current.date(byAdding: .day, value: -1, to: $0) ?? $0 },
        dayAfter:    { Calendar.current.date(byAdding: .day, value:  1, to: $0) ?? $0 },
        calcTax:     calcDeductions(gross:periodDays:salary:),
        renderPDF:   { _, _ in .fail(.renderingFailed("PDF requires UIKit")) },
        formatDate:  Formatting.dateFormatter(locale: .current, calendar: .current),
        formatMoney: Formatting.moneyFormatter(locale: Locale(identifier: "en_GB")),
        loadSettings: makeLoadSettings(FileIO.live.read),
        saveSettings: makeSaveSettings(FileIO.live.write),
        exportDatabase: FileIO.live.exportZip
    )
}

#endif

// MARK: - Settings IO (platform-independent — usable by both `real` variants above)

private func makeLoadSettings(
    _ read: @escaping @Sendable (String) -> Publisher<Data, ReadingError>
) -> @Sendable () -> Publisher<AppSettings, Never> {
    let decode: DataDecoder<AppSettings> = JSONDecoder().dataDecoder(for: AppSettings.self)
    return {
        read(settingsFilename)
            .map { data -> AppSettings in
                if case .success(let s) = decode(data) { s } else { .default }
            }
            .replaceError(with: .default)   // no file yet / unreadable → defaults
    }
}

private func makeSaveSettings(
    _ write: @escaping @Sendable (Data, String) -> Publisher<Void, SavingError>
) -> @Sendable (AppSettings) -> Publisher<Void, SavingError> {
    let encode: DataEncoder<AppSettings> = JSONEncoder().dataEncoder(for: AppSettings.self)
    return { settings in
        switch encode(settings) {
        case .success(let data): write(data, settingsFilename)
        case .failure(let e):    .fail(.ioError(filename: settingsFilename, underlying: e))
        }
    }
}
