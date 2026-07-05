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
        let store = Store(initial: initial, behavior: .identity, environment: environment)
        view = F.view(store: store, environment: environment)
    }

    func ignoringActions(_ body: () async -> Void) async { await body() }
}

/// Captures one iPhone-sized snapshot of the feature's frozen initial state.
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
            of: feature.view,
            as: .image(layout: iPhoneLayout),
            named: baseName,
            file: file,
            testName: testName,
            line: line
        )
    }
}
#endif
