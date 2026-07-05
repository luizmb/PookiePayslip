import Foundation

/// Container stored in the monthly JSON file.
/// Backward-compatible: old files are plain `[WorkDayRecord]` arrays;
/// new files are `{ "records": [...], "salary": {...} }`.
public struct MonthData: Sendable, Equatable {
    public var records: [WorkDayRecord]
    public var salary: SalaryRecord?

    public init(records: [WorkDayRecord] = [], salary: SalaryRecord? = nil) {
        self.records = records
        self.salary = salary
    }
}

// MARK: - Codable with legacy fallback

extension MonthData: Codable {
    private enum CodingKeys: String, CodingKey {
        case records, salary
    }

    public init(from decoder: Decoder) throws {
        // Try new keyed format first
        if let keyed = try? decoder.container(keyedBy: CodingKeys.self) {
            records = try keyed.decode([WorkDayRecord].self, forKey: .records)
            salary  = try keyed.decodeIfPresent(SalaryRecord.self, forKey: .salary)
            return
        }
        // Fall back to legacy plain array
        var array = try decoder.unkeyedContainer()
        var list: [WorkDayRecord] = []
        while !array.isAtEnd {
            list.append(try array.decode(WorkDayRecord.self))
        }
        records = list
        salary  = nil
    }

    public func encode(to encoder: Encoder) throws {
        var keyed = encoder.container(keyedBy: CodingKeys.self)
        try keyed.encode(records, forKey: .records)
        try keyed.encodeIfPresent(salary, forKey: .salary)
    }
}
