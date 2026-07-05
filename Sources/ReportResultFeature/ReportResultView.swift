import AppDomain
import PookieStyle
import SwiftRexArchitecture
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
            pdfShareable:          viewStore.state.pdfShareable
        )
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
        .sheet(
            isPresented: Binding(
                get: { viewStore.state.isPreviewPresented },
                set: { if !$0 { viewStore.dispatch(.dismissPreview) } }
            )
        ) {
            if let pdf = viewStore.state.pdfShareable {
                PayslipPDFPreview(
                    shareable: pdf,
                    title: "Payslip Preview",
                    shareLabel: viewStore.state.periodLabel.isEmpty ? "Payslip Estimate" : viewStore.state.periodLabel,
                    onClose: { viewStore.dispatch(.dismissPreview) }
                )
            }
        }
    }
}
