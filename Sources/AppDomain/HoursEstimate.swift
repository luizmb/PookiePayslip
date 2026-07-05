import Foundation

public struct EstimateResult: Sendable, Equatable {
    public var actualHours: Double
    public var projectedHours: Double
    public var projectedDays: Int
    public var incompleteDays: Int
    public var weekdayAvgHours: Double
    public var weekendAvgHours: Double
    public var noWeekdayDataWarning: Bool

    public var totalHours: Double { actualHours + projectedHours }
}

// Pure function — no IO, no side effects.
// today's record is classified as "past" if it has an endTime, otherwise as "future".
public func buildEstimate(
    records: [WorkDayRecord],
    periodStart: Date,
    periodEnd: Date,
    today: Date,
    calendar: Calendar
) -> EstimateResult {
    // Key on the day-normalized date: every lookup below uses `startOfDay` keys (cursor / pastDates),
    // so the stored key must be normalized too. A record whose `date` carries a time component (or was
    // written in a different offset) otherwise passes the range filter yet contributes 0 minutes here.
    let recordsByDate = Dictionary(records.map { (calendar.startOfDay(for: $0.date), $0) }, uniquingKeysWith: { _, last in last })
    let todayNorm = calendar.startOfDay(for: today)

    // Classify each day in the period
    var pastDates: [Date] = []
    var futureDates: [Date] = []
    var incompleteDays = 0

    var cursor = calendar.startOfDay(for: periodStart)
    let end = calendar.startOfDay(for: periodEnd)
    while cursor <= end {
        let rec = recordsByDate[cursor]
        let isTodayOrPast = cursor <= todayNorm
        let isTodayComplete = (cursor == todayNorm) && (rec?.endTime != nil)

        if cursor < todayNorm || isTodayComplete {
            pastDates.append(cursor)
            if let r = rec, r.isStarted && !r.isComplete { incompleteDays += 1 }
        } else {
            futureDates.append(cursor)
        }
        cursor = calendar.date(byAdding: .day, value: 1, to: cursor)!
    }

    // Tally worked hours in past range by weekday/weekend
    var weekdayMinutes = 0
    var weekendMinutes = 0
    var pastWeekdayCount = 0
    var pastWeekendCount = 0

    for date in pastDates {
        let isWE = AppDomain.isWeekend(date, calendar: calendar)
        if isWE { pastWeekendCount += 1 } else { pastWeekdayCount += 1 }
        if let mins = recordsByDate[date]?.workedMinutes {
            if isWE { weekendMinutes += mins } else { weekdayMinutes += mins }
        }
    }

    let weekdayAvg = pastWeekdayCount > 0 ? Double(weekdayMinutes) / Double(pastWeekdayCount) / 60.0 : 0
    let weekendAvg = pastWeekendCount > 0 ? Double(weekendMinutes) / Double(pastWeekendCount) / 60.0 : 0

    // Tally actual worked hours in past range
    let actualHours = pastDates.compactMap { recordsByDate[$0]?.workedMinutes }.reduce(0, +)

    // Project future days
    var futureWeekdayCount = 0
    var futureWeekendCount = 0
    for date in futureDates {
        if AppDomain.isWeekend(date, calendar: calendar) { futureWeekendCount += 1 } else { futureWeekdayCount += 1 }
    }
    let projectedHours = weekdayAvg * Double(futureWeekdayCount) + weekendAvg * Double(futureWeekendCount)

    return EstimateResult(
        actualHours: Double(actualHours) / 60.0,
        projectedHours: projectedHours,
        projectedDays: futureDates.count,
        incompleteDays: incompleteDays,
        weekdayAvgHours: weekdayAvg,
        weekendAvgHours: weekendAvg,
        noWeekdayDataWarning: pastWeekdayCount == 0
    )
}

