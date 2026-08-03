import AppDomain
import PookieStyle
import SwiftRexArchitecture
import SwiftRexSwiftUI
import SwiftUI

@BoundTo(ReportResultFeature.self, strategy: .observationSimple)
public struct ReportResultView: View {
    public var body: some View {
        ReportResultContent(
            kickerLabel:           viewStore.state.kickerLabel,
            periodLabel:           viewStore.state.periodLabel,
            yearLabel:             viewStore.state.yearLabel,
            heroTitleLabel:        viewStore.state.heroTitleLabel,
            netPayText:            viewStore.state.netPayText,
            heroMetaText:          viewStore.state.heroMetaText,
            estimateNoteText:      viewStore.state.estimateNoteText,
            incompleteWarningText: viewStore.state.incompleteWarningText,
            breakdownRows:         viewStore.state.breakdownRows,
            netCardLabel:          viewStore.state.netCardLabel,
            finePrintHeading:      viewStore.state.finePrintHeading,
            finePrintBody:         viewStore.state.finePrintBody,
            pdfShareable:          viewStore.state.preview.wrapped
        )
        .onAppear { viewStore.dispatch(.onAppear) }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button { viewStore.dispatch(.exportPDF) } label: {
                    Text(viewStore.state.printButtonLabel)
                        .font(.pookie(14, weight: .semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Color.pookieAccentSoft)
                        .foregroundStyle(Color.pookieAccentInk)
                        .clipShape(Capsule())
                }
            }
        }
        // `presenting` wires BOTH dismiss edges — the binding's `set(false)` and `onDismiss` — so the
        // presentation can never stick mid-dismiss, and the sheet keeps rendering `dismissing(last:)`
        // while it animates out.
        .presenting(viewStore, \.preview, dismiss: .dismissPreview) { pdf in
            PayslipPDFPreview(
                shareable: pdf,
                title: "Payslip Preview",
                shareLabel: viewStore.state.periodLabel.isEmpty ? "Payslip Estimate" : viewStore.state.periodLabel,
                onClose: { viewStore.dispatch(.dismissPreview) }
            )
        }
    }
}
