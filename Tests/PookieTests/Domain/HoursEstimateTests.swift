import AppDomain
import Foundation
import Testing

@Suite("buildEstimate — future hours projection")
struct HoursEstimateTests {

    private let cal = Fixture.calendar

    // Build a date in 2026 May
    private func may(_ day: Int) -> Date {
        cal.date(from: DateComponents(year: 2026, month: 5, day: day))!
    }

    // 8-hour weekday record on a given day
    private func weekdayRecord(on day: Int, id: UUID = Fixture.idA) -> WorkDayRecord {
        WorkDayRecord(
            id: id,
            date: may(day),
            startTime: TimeOfDay(hour: 9, minute: 0),
            endTime: TimeOfDay(hour: 17, minute: 0),
            breaks: []
        )
    }

    // 6-hour weekend record on a given day
    private func weekendRecord(on day: Int, id: UUID = Fixture.idB) -> WorkDayRecord {
        WorkDayRecord(
            id: id,
            date: may(day),
            startTime: TimeOfDay(hour: 10, minute: 0),
            endTime: TimeOfDay(hour: 16, minute: 0),
            breaks: []
        )
    }

    // MARK: - No future days

    @Test func noPastRecords_noProjection() {
        let result = buildEstimate(
            records: [],
            periodStart: may(1),
            periodEnd: may(22),  // all past
            today: may(29),
            calendar: cal
        )
        #expect(result.actualHours == 0)
        #expect(result.projectedHours == 0)
        #expect(result.projectedDays == 0)
    }

    // Regression (report-hours bug): estimate-OFF passes today = periodEnd + 1, so the last day
    // counts as past even when it's a future weekday with no record — nothing gets projected.
    @Test func boundaryAfterPeriodEnd_endDayIsPastNotProjected() {
        let result = buildEstimate(
            records: [weekdayRecord(on: 4)],   // one 8h day
            periodStart: may(1),
            periodEnd: may(20),                // May 20 2026 = Wed, no record
            today: may(21),                    // boundary = periodEnd + 1
            calendar: cal
        )
        #expect(result.projectedDays == 0)
        #expect(result.projectedHours == 0)
        #expect(result.totalHours == result.actualHours)   // pure actual, nothing invented
    }

    // Pins the OLD bug: boundary == periodEnd leaked a projection onto the end day.
    @Test func boundaryAtPeriodEnd_leaksProjectionOntoEndDay() {
        let result = buildEstimate(
            records: [weekdayRecord(on: 4)],
            periodStart: may(1),
            periodEnd: may(20),
            today: may(20),                    // buggy boundary == periodEnd
            calendar: cal
        )
        #expect(result.projectedDays == 1)     // May 20 wrongly classified as future
    }

    // Regression (report-hours bug): a record whose stored `date` isn't exactly local midnight
    // (a leftover time component, or written under a different UTC offset) must still be tallied.
    // It passes the [from,to] range filter, so if the hours lookup keys on the raw date it silently
    // contributes 0 → the report claims "no hours" for days that clearly have hours.
    @Test func recordDatedOffMidnightIsStillCounted() {
        let offMidnight = WorkDayRecord(
            id: Fixture.idA,
            date: cal.date(from: DateComponents(year: 2026, month: 5, day: 4, hour: 13, minute: 27))!,
            startTime: TimeOfDay(hour: 9, minute: 0),
            endTime: TimeOfDay(hour: 17, minute: 0),
            breaks: []
        )
        let result = buildEstimate(
            records: [offMidnight],
            periodStart: may(4),
            periodEnd: may(4),
            today: may(29),
            calendar: cal
        )
        #expect(result.actualHours == 8)   // was 0 before normalizing the lookup key
    }

    @Test func allPastWithRecords_computesActualHoursOnly() {
        let records = [weekdayRecord(on: 4), weekdayRecord(on: 5, id: Fixture.idB)]
        let result = buildEstimate(
            records: records,
            periodStart: may(4),
            periodEnd: may(5),
            today: may(29),
            calendar: cal
        )
        #expect(result.actualHours == 16)   // 2 × 8h
        #expect(result.projectedHours == 0)
    }

    // MARK: - With future days

    @Test func futureWeekdaysProjectedFromWeekdayAverage() {
        // Past: May 27 (Wed, 8h) and May 28 (Thu, 8h)
        // Today: May 29 (Fri, in-progress → future)
        // Future in period: May 29–31 (3 days: Fri, Sat, Sun)
        // Past range: May 27–28 (2 weekdays, 0 weekends)
        // weekdayAvg: 16h / 2 days = 8h
        // weekendAvg: 0 / 0 days = 0
        // Future: Fri=weekday→8h, Sat=weekend→0h, Sun=weekend→0h  => 8h projected
        let records = [
            weekdayRecord(on: 27),               // Wed
            WorkDayRecord(id: Fixture.idB, date: may(28),   // Thu
                startTime: TimeOfDay(hour: 9, minute: 0),
                endTime: TimeOfDay(hour: 17, minute: 0), breaks: [])
        ]
        let result = buildEstimate(
            records: records,
            periodStart: may(27),
            periodEnd: may(31),
            today: may(29),      // today has no endTime in records → future
            calendar: cal
        )
        #expect(result.actualHours == 16)
        #expect(result.projectedHours == 8)     // only Fri projects to 8h
        #expect(result.weekdayAvgHours == 8)
        #expect(result.weekendAvgHours == 0)
        #expect(!result.noWeekdayDataWarning)
    }

    @Test func todayWithEndTimeCountsAsPast() {
        // Today has an endTime → classified as past
        let todayRecord = WorkDayRecord(
            id: Fixture.idA,
            date: may(29),
            startTime: TimeOfDay(hour: 9, minute: 0),
            endTime: TimeOfDay(hour: 17, minute: 0),
            breaks: []
        )
        let result = buildEstimate(
            records: [todayRecord],
            periodStart: may(29),
            periodEnd: may(31),
            today: may(29),
            calendar: cal
        )
        // May 29 in past, May 30 (Sat) and 31 (Sun) in future
        #expect(result.actualHours == 8)
        #expect(result.projectedDays == 2)  // Sat + Sun
    }

    // MARK: - Warning for no weekday data

    @Test func noWeekdayDataProducesWarning() {
        // Past range must be entirely weekends: May 23 (Sat) and May 24 (Sun).
        // today = May 25 (Mon) → past = [23, 24], both weekend, pastWeekdayCount = 0 → warning fires.
        let records = [weekendRecord(on: 23)]
        let result = buildEstimate(
            records: records,
            periodStart: may(23),
            periodEnd: may(31),
            today: may(25),
            calendar: cal
        )
        #expect(result.noWeekdayDataWarning)
    }

    @Test func noWeekendDataDoesNotProduceWarning() {
        // All past days are weekdays — weekend avg = 0, no warning
        let records = [weekdayRecord(on: 27), weekdayRecord(on: 28, id: Fixture.idB)]
        let result = buildEstimate(
            records: records,
            periodStart: may(27),
            periodEnd: may(31),
            today: may(29),
            calendar: cal
        )
        #expect(!result.noWeekdayDataWarning)
        #expect(result.weekendAvgHours == 0)
    }

    // MARK: - Incomplete days

    @Test func incompleteDayIsCountedButNotInActualHours() {
        // In-progress day (started, no end) → not counted in actual hours, flagged as incomplete
        let inProgress = WorkDayRecord(
            id: Fixture.idA,
            date: may(28),
            startTime: TimeOfDay(hour: 9, minute: 0),
            endTime: nil,
            breaks: []
        )
        let result = buildEstimate(
            records: [inProgress],
            periodStart: may(28),
            periodEnd: may(28),
            today: may(29),
            calendar: cal
        )
        #expect(result.actualHours == 0)
        #expect(result.incompleteDays == 1)
    }

    // MARK: - totalHours

    @Test func totalHoursIsActualPlusProjected() {
        let records = [weekdayRecord(on: 27), weekdayRecord(on: 28, id: Fixture.idB)]
        let result = buildEstimate(
            records: records,
            periodStart: may(27),
            periodEnd: may(31),
            today: may(29),
            calendar: cal
        )
        #expect(result.totalHours == result.actualHours + result.projectedHours)
    }
}
