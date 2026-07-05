import AppDomain
import PookieStyle
import SwiftRexArchitecture
import SwiftUI

@BoundTo(SettingsFeature.self, strategy: .observationSimple)
public struct SettingsView: View {
    public var body: some View {
        SettingsContent(
            startTime:         Binding(get: { viewStore.state.startTime }, set: { viewStore.dispatch(.setStart($0)) }),
            endTime:           Binding(get: { viewStore.state.endTime },   set: { viewStore.dispatch(.setEnd($0)) }),
            breakMinutes:      viewStore.state.breakMinutes,
            breakLabel:        viewStore.state.breakLabel,
            breakOptions:      viewStore.state.breakOptions,
            titleLabel:        viewStore.state.titleLabel,
            subtitleLabel:     viewStore.state.subtitleLabel,
            startLabel:        viewStore.state.startLabel,
            endLabel:          viewStore.state.endLabel,
            breakSectionLabel: viewStore.state.breakSectionLabel,
            saveButtonLabel:   viewStore.state.saveButtonLabel,
            exportSectionLabel: viewStore.state.exportSectionLabel,
            exportButtonLabel: viewStore.state.exportButtonLabel,
            exportShareable:   viewStore.state.exportShareable,
            onSetBreak:        { viewStore.dispatch(.setBreakMinutes($0)) },
            onSave:            { viewStore.dispatch(.save) },
            onExport:          { viewStore.dispatch(.exportDatabase) }
        )
        .onAppear { viewStore.dispatch(.onAppear) }
    }
}
