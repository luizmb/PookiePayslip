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
            if let from = viewStore.state.fromDate, let to = viewStore.state.toDate {
                ReportInputContent(
                    from:                   Binding(get: { from }, set: { viewStore.dispatch(.setFrom($0)) }),
                    to:                     Binding(get: { to },   set: { viewStore.dispatch(.setTo($0)) }),
                    estimate:               Binding(get: { viewStore.state.estimateFuture }, set: { _ in viewStore.dispatch(.toggleEstimate) }),
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
