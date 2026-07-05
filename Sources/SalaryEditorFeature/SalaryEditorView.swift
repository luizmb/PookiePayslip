import AppDomain
import PookieStyle
import SwiftRexArchitecture
import SwiftUI

@BoundTo(SalaryEditorFeature.self, strategy: .observationSimple)
public struct SalaryEditorView: View {
    public var body: some View {
        SalaryEditorContent(
            amountText:      Binding(get: { viewStore.state.amountText },   set: { viewStore.dispatch(.setAmountText($0)) }),
            periodicity:     Binding(get: { viewStore.state.periodicity },   set: { viewStore.dispatch(.setPeriodicity($0)) }),
            niClass:         Binding(get: { viewStore.state.niClass },       set: { viewStore.dispatch(.setNIClass($0)) }),
            studentLoan:     Binding(get: { viewStore.state.studentLoan },   set: { viewStore.dispatch(.setStudentLoan($0)) }),
            pensionEnabled:  Binding(get: { viewStore.state.pensionEnabled }, set: { viewStore.dispatch(.setPensionEnabled($0)) }),
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
