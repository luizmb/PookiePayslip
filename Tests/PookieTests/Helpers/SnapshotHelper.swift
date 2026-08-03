#if os(iOS) || os(tvOS)
import SnapshotTesting
import SwiftRex
import SwiftRexArchitecture
import SwiftUI
import Testing

// iPhone 17 Pro Max viewport — matches the simulator used in CI
nonisolated(unsafe) let iPhoneLayout = SwiftUISnapshotLayout.fixed(width: 393, height: 852)

/// Local snapshot harness for a `Feature`'s view — replaces the retired `SwiftRexTesting.TestFeature`.
/// Builds the feature's view over a store whose behavior is `.identity`, so the initial state is
/// frozen (dispatched actions — onAppear, taps — are ignored) for a deterministic snapshot.
@available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
@MainActor
struct TestFeature<F: Feature> {
    let view: F.Body

    init(initial: F.State, environment: F.Environment) {
        // Spelled out rather than `.identity`: a bare leading dot leaves `Action` unconstrained here,
        // since nothing else in the expression mentions it.
        let store = Store(
            initial: initial,
            behavior: Behavior<F.Action, F.State, F.Environment>.identity,
            environment: environment
        )
        view = F.view(store: store, environment: environment)
    }

    func ignoringActions(_ body: () async -> Void) async { await body() }
}

/// Captures one iPhone-sized snapshot of the feature's frozen initial state.
///
/// The view is pinned to a fixed locale, calendar and time zone. The app's own strings are formatted by
/// injected `World` formatters and so are already deterministic, but **system controls are not**:
/// `DatePicker` reads the ambient `Locale`/`Calendar` from the SwiftUI environment, and its rendering —
/// including its intrinsic width, which then resizes the card around it — changes with the host's region
/// settings. Without this, references only reproduce on a machine configured like the one that recorded
/// them. Same rule as everywhere else in this codebase: no `Locale.current`, inject it.
@available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
@MainActor
func snap<F: Feature>(
    _ feature: TestFeature<F>,
    named baseName: String,
    testName: String = #function,
    file: StaticString = #filePath,
    line: UInt = #line
) async {
    await feature.ignoringActions {
        assertSnapshot(
            of: feature.view
                .environment(\.locale, Fixture.locale)
                .environment(\.calendar, Fixture.calendar)
                .environment(\.timeZone, Fixture.timeZone),
            as: .image(layout: iPhoneLayout),
            named: baseName,
            file: file,
            testName: testName,
            line: line
        )
    }
}
#endif
