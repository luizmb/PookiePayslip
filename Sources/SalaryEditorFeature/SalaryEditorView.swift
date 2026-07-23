import AppDomain
import PookieStyle
import SwiftRexArchitecture
import SwiftUI

@BoundTo(SalaryEditorFeature.self, strategy: .observationSimple)
public struct SalaryEditorView: View {
    public var body: some View {
        SalaryEditorContent(
            amountText:      viewStore.binding(.state(\.amountText), dispatch: .action(\.setAmountText)),
            periodicity:     viewStore.binding(.state(\.periodicity), dispatch: .action(\.setPeriodicity)),
            niClass:         viewStore.binding(.state(\.niClass), dispatch: .action(\.setNIClass)),
            studentLoan:     viewStore.binding(.state(\.studentLoan), dispatch: .action(\.setStudentLoan)),
            pensionEnabled:  viewStore.binding(.state(\.pensionEnabled), dispatch: .action(\.setPensionEnabled)),
            pensionLabel:    viewStore.state.pensionLabel,
            displayPreview:  viewStore.state.displayPreview,
            canSave:         viewStore.state.canSave,
            titleLabel:      viewStore.state.titleLabel,
            amountLabel:     viewStore.state.amountLabel,
            currencySymbol:  viewStore.state.currencySymbol,
            saveButtonLabel: viewStore.state.saveButtonLabel,
            onSave:          { viewStore.dispatch(.save) }
        )
    }
}
