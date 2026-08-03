#if os(iOS) || os(tvOS)
import SnapshotTesting
import SwiftRex
import SwiftRexArchitecture
import SwiftUI
import Testing

// iPhone 17 Pro Max viewport — matches the simulator used in CI
nonisolated(unsafe) let iPhoneLayout = SwiftUISnapshotLayout.fixed(width: 393, height: 852)

// Tolerance for cross-machine rendering noise.
//
// The same view rendered on a dev Mac and on a CI runner is not bit-identical: GPU and rasteriser
// differences shift anti-aliased edges by a channel value or two. Measured across all 22 snapshots
// between a local run and a CI run, the worst channel delta was 6/255 (2.35%) with no size or content
// difference at all — the images are visually indistinguishable.
//
// `perceptualPrecision` compares colours the way an eye does rather than by exact bytes, so that noise
// passes while anything a human would notice — moved element, changed text, different colour — still
// fails by an enormous margin. Without it, references are only valid on the machine that recorded them,
// which is why this suite could never have run in CI.
// `precision` stays at 1 deliberately: every pixel must meet the bar. Relaxing it instead would let a
// share of pixels differ *completely* — at this resolution 1% is ~30k pixels, comfortably enough to hide
// a changed word — so the tolerance is spent entirely on colour, never on coverage.
private let pixelPrecision: Float = 1.0
private let perceptualPrecision: Float = 0.95   // ≈5% headroom against the 2.35% observed

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
            as: .image(
                precision: pixelPrecision,
                perceptualPrecision: perceptualPrecision,
                layout: iPhoneLayout
            ),
            named: baseName,
            file: file,
            testName: testName,
            line: line
        )
    }
}
#endif
