import AppDomain
import Foundation
import Testing

@Suite("WorkDayRecord — hours calculation")
struct WorkDayRecordTests {

    // MARK: - workedMinutes

    @Test func noStartTimeGivesNilWorkedMinutes() {
        let rec = WorkDayRecord(id: Fixture.idA, date: Fixture.todayMidnight)
        #expect(rec.workedMinutes == nil)
    }

    @Test func noEndTimeGivesNilWorkedMinutes() {
        var rec = WorkDayRecord(id: Fixture.idA, date: Fixture.todayMidnight)
        rec.startTime = TimeOfDay(hour: 9, minute: 0)
        #expect(rec.workedMinutes == nil)
    }

    @Test func eightHourDayNoBreaks() {
        var rec = WorkDayRecord(id: Fixture.idA, date: Fixture.todayMidnight)
        rec.startTime = TimeOfDay(hour: 9, minute: 0)
        rec.endTime   = TimeOfDay(hour: 17, minute: 0)
        #expect(rec.workedMinutes == 480)  // 8 × 60
    }

    @Test func thirtyMinuteBreakSubtracted() {
        let rec = Fixture.completedDay   // 9:00–17:30 with 30-min break → 8h = 480 min
        #expect(rec.workedMinutes == 480)
    }

    @Test func breakWithMissingEndIgnored() {
        var rec = WorkDayRecord(id: Fixture.idA, date: Fixture.todayMidnight)
        rec.startTime = TimeOfDay(hour: 9, minute: 0)
        rec.endTime   = TimeOfDay(hour: 17, minute: 0)
        rec.breaks    = [WorkBreakRecord(startTime: TimeOfDay(hour: 12, minute: 0), endTime: nil)]
        // Incomplete break is not subtracted
        #expect(rec.workedMinutes == 480)
    }

    @Test func multipleBreaksAllSubtracted() {
        var rec = WorkDayRecord(id: Fixture.idA, date: Fixture.todayMidnight)
        rec.startTime = TimeOfDay(hour: 9, minute: 0)
        rec.endTime   = TimeOfDay(hour: 17, minute: 0)
        rec.breaks    = [
            WorkBreakRecord(startTime: TimeOfDay(hour: 11, minute: 0), endTime: TimeOfDay(hour: 11, minute: 15)),
            WorkBreakRecord(startTime: TimeOfDay(hour: 12, minute: 30), endTime: TimeOfDay(hour: 13, minute: 0)),
        ]
        // 480 - 15 - 30 = 435 minutes
        #expect(rec.workedMinutes == 435)
    }

    @Test func workedMinutesNeverNegative() {
        var rec = WorkDayRecord(id: Fixture.idA, date: Fixture.todayMidnight)
        rec.startTime = TimeOfDay(hour: 9, minute: 0)
        rec.endTime   = TimeOfDay(hour: 9, minute: 30)
        rec.breaks    = [WorkBreakRecord(startTime: TimeOfDay(hour: 9, minute: 0), endTime: TimeOfDay(hour: 10, minute: 0))]
        // Break longer than shift → clamped to 0
        #expect(rec.workedMinutes == 0)
    }

    // MARK: - isComplete / isStarted / hasOpenBreak

    @Test func isComplete() {
        #expect(!Fixture.inProgressDay.isComplete)
        #expect(Fixture.completedDay.isComplete)
    }

    @Test func isStarted() {
        let empty = WorkDayRecord(id: Fixture.idA, date: Fixture.todayMidnight)
        #expect(!empty.isStarted)
        #expect(Fixture.inProgressDay.isStarted)
        #expect(Fixture.completedDay.isStarted)
    }

    @Test func hasOpenBreak() {
        var rec = Fixture.completedDay
        #expect(!rec.hasOpenBreak)
        rec.breaks.append(WorkBreakRecord(startTime: TimeOfDay(hour: 15, minute: 0), endTime: nil))
        #expect(rec.hasOpenBreak)
    }

    // MARK: - Codable round-trip

    @Test func codableRoundTrip() throws {
        let original = Fixture.completedDay
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(WorkDayRecord.self, from: data)
        #expect(decoded == original)
    }
}
