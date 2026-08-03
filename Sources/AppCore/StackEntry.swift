import AppDomain
import DayDetailFeature
import FPMacros
import Foundation
import ReportInputFeature
import ReportResultFeature
import SalaryEditorFeature
import SettingsFeature

// MARK: - StackEntry

/// One entry on the navigation stack: **its route identity and its state, inseparable**.
///
/// The stack is `[StackEntry]` — one source of truth. There is no parallel table of per-screen state to
/// keep in step, so "a route with no state" and "state for a screen that isn't on the stack" are not
/// merely avoided, they are unrepresentable. Pushing is appending a fully-formed screen; popping is
/// `removeLast`. Nothing to seed afterwards, nothing to prune.
///
/// It lives in AppCore rather than AppDomain because it carries feature states, and AppDomain cannot see
/// the feature modules. ``AppRoute`` — the payload-free identity SwiftUI navigates by — stays in the
/// domain, where it is a pure DTO.
@Prisms
public enum StackEntry: Sendable, Equatable {
    case dayDetail(DayDetailFeature.State)
    case reportInput(ReportInputFeature.State)
    case reportResult(ReportResultFeature.State)
    case salaryEditor(SalaryEditorFeature.State)
    case settings(SettingsFeature.State)
}

public extension StackEntry {
    /// The `Hashable` identity SwiftUI navigates by. Derived, never stored — a screen's data can change
    /// all it likes without changing which screen it is, so `NavigationStack` never re-pushes.
    var route: AppRoute {
        switch self {
        case .dayDetail:    .dayDetail
        case .reportInput:  .reportInput
        case .reportResult: .reportResult
        case .salaryEditor: .salaryEditor
        case .settings:     .settings
        }
    }
}
