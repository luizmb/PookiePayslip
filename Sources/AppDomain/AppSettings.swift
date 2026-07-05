import Foundation

/// App-global user preferences, persisted to `settings.json`. Currently the default times/length
/// used when tapping the `--:--` placeholders on the Day screen.
public struct AppSettings: Codable, Sendable, Equatable {
    public var defaultStartTime: TimeOfDay
    public var defaultEndTime: TimeOfDay
    public var defaultBreakMinutes: Int

    public init(
        defaultStartTime: TimeOfDay = TimeOfDay(hour: 10, minute: 0),
        defaultEndTime: TimeOfDay = TimeOfDay(hour: 18, minute: 0),
        defaultBreakMinutes: Int = 30
    ) {
        self.defaultStartTime = defaultStartTime
        self.defaultEndTime = defaultEndTime
        self.defaultBreakMinutes = defaultBreakMinutes
    }

    /// The values used before the user ever opens Settings (and the fallback if the file is
    /// missing or unreadable). 10:00 / 18:00 / 30-minute break.
    public static let `default` = AppSettings()

    private enum CodingKeys: String, CodingKey {
        case defaultStartTime, defaultEndTime, defaultBreakMinutes
    }

    // Migration-safe: any field absent in an older/partial settings.json falls back to the default.
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = AppSettings.default
        defaultStartTime = try c.decodeIfPresent(TimeOfDay.self, forKey: .defaultStartTime) ?? d.defaultStartTime
        defaultEndTime = try c.decodeIfPresent(TimeOfDay.self, forKey: .defaultEndTime) ?? d.defaultEndTime
        defaultBreakMinutes = try c.decodeIfPresent(Int.self, forKey: .defaultBreakMinutes) ?? d.defaultBreakMinutes
    }
}

/// Fixed filename for the persisted settings (in the app-support directory alongside month files).
public let settingsFilename = "settings.json"
