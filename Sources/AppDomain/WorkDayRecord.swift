import Foundation

public struct WorkDayRecord: Codable, Sendable, Identifiable, Equatable {
    public var id: UUID
    public var date: Date
    public var startTime: TimeOfDay?
    public var endTime: TimeOfDay?
    public var breaks: [WorkBreakRecord]

    public init(id: UUID, date: Date, startTime: TimeOfDay? = nil, endTime: TimeOfDay? = nil, breaks: [WorkBreakRecord] = []) {
        self.id = id
        self.date = date
        self.startTime = startTime
        self.endTime = endTime
        self.breaks = breaks
    }
}

public struct WorkBreakRecord: Codable, Sendable, Equatable {
    public var startTime: TimeOfDay?
    public var endTime: TimeOfDay?

    public init(startTime: TimeOfDay? = nil, endTime: TimeOfDay? = nil) {
        self.startTime = startTime
        self.endTime = endTime
    }
}
