import Foundation
import FPMacros

/// The identity of a screen on the navigation stack — **payload-free on purpose**.
///
/// `NavigationStack` keys its destinations by the path element's *value*, so a payload here would make
/// "the same screen showing different data" a different destination: SwiftUI tears the screen down and
/// re-pushes it whenever that data changes. What a screen currently shows belongs to its own feature
/// state; a route only says *which* screen. The root (the calendar) is deliberately absent — it is not a
/// destination, so it can never be pushed on top of itself.
@Prisms
public enum AppRoute: Hashable, Sendable, Codable {
    case dayDetail
    case reportInput
    case reportResult
    case salaryEditor
    case settings
}

/// An ask to navigate — carrying whatever the destination needs in order to be built.
///
/// It is a transient action payload, never stored: the navigation reducer turns it into the `StackEntry`
/// that goes on the stack. Keeping intent separate from the screen is what lets a feature dispatch
/// `push(.dayDetail(date))` tacitly while a screen like the salary editor is still built from state the
/// app already holds, which no action payload could supply.
@Prisms
public enum NavigationRequest: Sendable, Equatable {
    case dayDetail(Date)
    case reportInput
    case reportResult(PayReport, [WorkDayRecord], from: Date, to: Date)
    case salaryEditor
    case settings
}
