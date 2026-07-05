import AppDomain
import Core
import CoreFP
import Foundation
import ReactiveConcurrency

public struct World: Sendable {
    // Codecs
    public let decoder:      any DataDecoderFactory & Sendable
    public let encoder:      any DataEncoderFactory & Sendable
    // IO — described as a lazy Publisher (typed failure channel); run only by Effect
    public let readFile:     @Sendable (String) -> Publisher<Data, ReadingError>
    public let saveFile:     @Sendable (Data, String) -> Publisher<Void, SavingError>
    // Time/ID — synchronous thunks; the only sources of Date() and UUID()
    public let currentDate:  @Sendable () -> Date
    public let newID:        @Sendable () -> UUID
    // Calendar — lazy thunk; side-effectful (.current reads locale/timezone), evaluated inside Effect
    public let calendar:     @Sendable () -> Calendar
    // Date arithmetic — all calendar-dependent date math comes from World
    public let dayBefore:    @Sendable (Date) -> Date
    public let dayAfter:     @Sendable (Date) -> Date
    // Tax: NI + Pension + Income Tax + Student Loan — injected for testability
    public let calcTax:      @Sendable (Decimal, Int, SalaryRecord) -> TaxBreakdown
    // PDF rendering — IO; UIGraphicsPDFRenderer lives only in live implementation
    public let renderPDF:    @Sendable (PayReport, [WorkDayRecord]) -> Publisher<Data, RenderError>
    // View formatting — Locale/Calendar/TimeZone captured in live; no formatter object escapes
    public let formatDate:   @Sendable (Date, String) -> String
    public let formatMoney:  @Sendable (Decimal, Int) -> String
    // User settings (settings.json) — load always resolves (defaults on missing/unreadable)
    public let loadSettings: @Sendable () -> Publisher<AppSettings, Never>
    public let saveSettings: @Sendable (AppSettings) -> Publisher<Void, SavingError>
    // Zips the entire data directory (settings.json + every MM-YYYY.json) for a full backup export
    public let exportDatabase: @Sendable () -> Publisher<Data, ExportError>
}
