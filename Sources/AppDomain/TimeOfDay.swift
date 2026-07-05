import Foundation

public struct TimeOfDay: Codable, Sendable, Comparable, Equatable, Hashable {
    public var hour: Int
    public var minute: Int

    public init(hour: Int, minute: Int) {
        self.hour = hour
        self.minute = minute
    }

    public var totalMinutes: Int { hour * 60 + minute }

    /// Returns the time `minutes` later, wrapping within a 24-hour day.
    public func adding(minutes: Int) -> TimeOfDay {
        let day = 24 * 60
        let total = ((totalMinutes + minutes) % day + day) % day
        return TimeOfDay(hour: total / 60, minute: total % 60)
    }

    public static func < (lhs: TimeOfDay, rhs: TimeOfDay) -> Bool {
        lhs.totalMinutes < rhs.totalMinutes
    }

    /// A start/finish time is wall-clock and timezone-independent, so the `TimeOfDay`↔`Date` bridge
    /// a `.hourAndMinute` `DatePicker` needs uses a **fixed UTC** calendar — no injected calendar
    /// required. The bound `Date` carries only h:m on a fixed reference day; pair with
    /// `.environment(\.timeZone, .gmt)` on the picker so it displays the same h:m.
    private static let pickerCalendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = .gmt
        c.locale = Locale(identifier: "en_US_POSIX")
        return c
    }()
    private static let pickerAnchor = Date(timeIntervalSinceReferenceDate: 0)

    /// This time as a `Date` for a `.hourAndMinute` picker binding (fixed UTC reference day).
    public var pickerDate: Date {
        let cal = TimeOfDay.pickerCalendar
        let day = cal.startOfDay(for: TimeOfDay.pickerAnchor)
        return cal.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
    }

    /// Reads h:m back from a picker `Date` (inverse of `pickerDate`).
    public init(pickerDate: Date) {
        let cal = TimeOfDay.pickerCalendar
        self.init(hour: cal.component(.hour, from: pickerDate), minute: cal.component(.minute, from: pickerDate))
    }
}
