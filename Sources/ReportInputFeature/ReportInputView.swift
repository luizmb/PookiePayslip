import AppDomain
import PookieStyle
import SwiftRexArchitecture
import SwiftUI

@BoundTo(ReportInputFeature.self, strategy: .observationSimple)
public struct ReportInputView: View {
    public var body: some View {
        Group {
            // The period is resolved from World before the store exists, so both are non-nil once
            // running; the placeholder only guards the pre-resolution instant.
            // The period is one optional group: while `range` is present, transpose to a child store over
            // the UNWRAPPED `DateRange`, so `from`/`to` are non-optional `Date` and their bindings are clean.
            if let rangeStore = viewStore.projection(.action(review: { $0 }).state(\.range)).transpose() {
                ReportInputContent(
                    from:                   rangeStore.binding(.state(\.from), dispatch: .action(\.setFrom)),
                    to:                     rangeStore.binding(.state(\.to),   dispatch: .action(\.setTo)),
                    estimate:               viewStore.binding(.state(\.estimateFuture), dispatch: .action(review: const(ReportInputFeature.ViewAction.toggleEstimate))),
                    showEstimateToggle:     viewStore.state.showEstimateToggle,
                    canGenerate:            viewStore.state.canGenerate,
                    noSalaryWarning:        viewStore.state.noSalaryWarning,
                    titleLabel:             viewStore.state.titleLabel,
                    subtitleLabel:          viewStore.state.subtitleLabel,
                    fromLabel:              viewStore.state.fromLabel,
                    toLabel:                viewStore.state.toLabel,
                    estimateTitleLabel:     viewStore.state.estimateTitleLabel,
                    estimateDescriptionLabel: viewStore.state.estimateDescriptionLabel,
                    generateButtonLabel:    viewStore.state.generateButtonLabel,
                    onGenerate:             { viewStore.dispatch(.generate) }
                )
            } else {
                Color.pookieBg.ignoresSafeArea()
            }
        }
        .onAppear { viewStore.dispatch(.onAppear) }
    }
}
