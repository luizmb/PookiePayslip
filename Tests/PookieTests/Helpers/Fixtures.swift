import AppDomain
import CoreFP
import Foundation

// MARK: - Fixed dates (no Date() calls — all computed once at compile/load time)

enum Fixture {
    static let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/London")!
        return c
    }()

    // 2026-05-29 09:00 BST — a fixed "today" used across all tests
    static let today: Date = calendar.date(
        from: DateComponents(year: 2026, month: 5, day: 29, hour: 9, minute: 0)
    )!

    static let todayMidnight: Date = calendar.startOfDay(for: today)

    // A few other dates for testing
    static let yesterday: Date = calendar.date(byAdding: .day, value: -1, to: todayMidnight)!
    static let twoDaysAgo: Date = calendar.date(byAdding: .day, value: -2, to: todayMidnight)!
    static let tomorrow: Date = calendar.date(byAdding: .day, value: 1, to: todayMidnight)!

    // Fixed UUIDs
    static let idA = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
    static let idB = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!
    static let idC = UUID(uuidString: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC")!

    // A complete 8-hour workday (9:00–17:30, 30-min lunch break = 8h)
    static var completedDay: WorkDayRecord {
        WorkDayRecord(
            id: idA,
            date: todayMidnight,
            startTime: TimeOfDay(hour: 9, minute: 0),
            endTime: TimeOfDay(hour: 17, minute: 30),
            breaks: [WorkBreakRecord(startTime: TimeOfDay(hour: 12, minute: 30), endTime: TimeOfDay(hour: 13, minute: 0))]
        )
    }

    // A 6-hour weekend day
    static var weekendDay: WorkDayRecord {
        WorkDayRecord(
            id: idB,
            date: calendar.date(from: DateComponents(year: 2026, month: 5, day: 23))!,  // Saturday
            startTime: TimeOfDay(hour: 10, minute: 0),
            endTime: TimeOfDay(hour: 16, minute: 0),
            breaks: []
        )
    }

    // An in-progress day (no endTime)
    static var inProgressDay: WorkDayRecord {
        WorkDayRecord(
            id: idC,
            date: todayMidnight,
            startTime: TimeOfDay(hour: 9, minute: 0),
            endTime: nil,
            breaks: []
        )
    }
}
