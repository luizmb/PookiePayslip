import AppDomain
import Foundation
import Testing

@Suite("TimeOfDay")
struct TimeOfDayTests {

    @Test func totalMinutes() {
        #expect(TimeOfDay(hour: 0, minute: 0).totalMinutes  == 0)
        #expect(TimeOfDay(hour: 9, minute: 0).totalMinutes  == 540)
        #expect(TimeOfDay(hour: 17, minute: 30).totalMinutes == 1050)
        #expect(TimeOfDay(hour: 23, minute: 59).totalMinutes == 1439)
    }

    @Test func comparableOrdering() {
        let early = TimeOfDay(hour: 9, minute: 0)
        let late  = TimeOfDay(hour: 17, minute: 30)
        #expect(early < late)
        #expect(!(late < early))
        #expect(early == early)
    }

    @Test func hashableAndEquatable() {
        let a = TimeOfDay(hour: 12, minute: 0)
        let b = TimeOfDay(hour: 12, minute: 0)
        let c = TimeOfDay(hour: 12, minute: 1)
        #expect(a == b)
        #expect(a != c)
        var set: Set<TimeOfDay> = [a, b, c]
        #expect(set.count == 2)
    }

    @Test func codableRoundTrip() throws {
        let original = TimeOfDay(hour: 14, minute: 45)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TimeOfDay.self, from: data)
        #expect(decoded == original)
    }
}
