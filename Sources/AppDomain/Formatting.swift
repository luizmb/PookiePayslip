import Foundation

/// Pure view-formatting closures. The ambient `Locale`/`Calendar`/`TimeZone` are captured **once**
/// (in `World.live`), so the returned closures are deterministic and side-effect-free from a
/// feature's perspective — a feature never constructs a formatter or reads `.current`.
public enum Formatting {
    /// `(date, dateFormat pattern) -> localized string`, e.g. `format(date, "MMMM yyyy")`.
    public static func dateFormatter(
        locale: Locale,
        calendar: Calendar
    ) -> @Sendable (Date, String) -> String {
        { date, pattern in
            let f = DateFormatter()
            f.locale = locale
            f.calendar = calendar
            f.timeZone = calendar.timeZone
            f.dateFormat = pattern
            return f.string(from: date)
        }
    }

    /// `(amount, fractionDigits) -> "£1,234.56"` (2 digits) or `"£350"` (0 digits).
    public static func moneyFormatter(
        locale: Locale
    ) -> @Sendable (Decimal, Int) -> String {
        { amount, fractionDigits in
            let f = NumberFormatter()
            f.locale = locale
            f.numberStyle = .currency
            f.currencySymbol = "£"
            f.minimumFractionDigits = fractionDigits
            f.maximumFractionDigits = fractionDigits
            return f.string(from: amount as NSDecimalNumber) ?? (fractionDigits == 0 ? "£0" : "£0.00")
        }
    }
}
