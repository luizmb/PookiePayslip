import Foundation

public extension WorkDayRecord {
    var workedMinutes: Int? {
        guard let start = startTime, let end = endTime else { return nil }
        let gross = span(from: start, to: end)
        let breakTotal = breaks.compactMap { b -> Int? in
            guard let bs = b.startTime, let be = b.endTime else { return nil }
            return span(from: bs, to: be)
        }.reduce(0, +)
        return max(0, gross - breakTotal)
    }

    var isComplete: Bool { startTime != nil && endTime != nil }
    var isStarted: Bool { startTime != nil }
    var hasOpenBreak: Bool { breaks.contains { $0.startTime != nil && $0.endTime == nil } }
}

private func span(from start: TimeOfDay, to end: TimeOfDay) -> Int {
    var diff = end.totalMinutes - start.totalMinutes
    if diff < 0 { diff += 24 * 60 }
    return diff
}
