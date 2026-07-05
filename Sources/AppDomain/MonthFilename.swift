import Foundation

public func monthFilename(for date: Date, calendar: Calendar) -> String {
    let m = calendar.component(.month, from: date)
    let y = calendar.component(.year, from: date)
    return String(format: "%02d-%04d.json", m, y)
}

public func startOfMonth(for date: Date, calendar: Calendar) -> Date {
    let components = calendar.dateComponents([.year, .month], from: date)
    return calendar.date(from: components)!
}

public func isWeekend(_ date: Date, calendar: Calendar) -> Bool {
    let wd = calendar.component(.weekday, from: date)
    return wd == 1 || wd == 7
}
