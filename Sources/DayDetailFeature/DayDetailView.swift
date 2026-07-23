import AppDomain
import PookieStyle
import SwiftRexArchitecture
import SwiftUI

@BoundTo(DayDetailFeature.self, strategy: .observationSimple)
public struct DayDetailView: View {
    public var body: some View {
        DayDetailContent(
            dateTitle:        viewStore.state.dateTitle,
            workedHoursText:  viewStore.state.workedHoursText,
            statusText:       viewStore.state.statusText,
            startFieldLabel:  viewStore.state.startFieldLabel,
            endFieldLabel:    viewStore.state.endFieldLabel,
            addBreakLabel:    viewStore.state.addBreakLabel,
            nowButtonLabel:   viewStore.state.nowButtonLabel,
            timePlaceholder:  viewStore.state.timePlaceholder,
            startDefault:     viewStore.state.defaultStart,
            endDefault:       viewStore.state.defaultEnd,
            startTime:        viewStore.binding(.state(\.startTime), dispatch: .action(\.setStart)),
            endTime:          viewStore.binding(.state(\.endTime), dispatch: .action(\.setEnd)),
            breaks:           viewStore.state.breaks,
            isFuture:         viewStore.state.isFuture,
            totalBreakText:   viewStore.state.totalBreakText,
            onSetStartNow:    { viewStore.dispatch(.setStartNow) },
            onSetEndNow:      { viewStore.dispatch(.setEndNow) },
            onAddBreak:       { viewStore.dispatch(.addBreak) },
            onRemoveBreak:    { viewStore.dispatch(.removeBreak($0)) },
            onSetBreakLength: { i, m in viewStore.dispatch(.setBreakLength(i, m)) },
            onSetBreakStart:  { i, t in viewStore.dispatch(.setBreakStart(i, t)) },
            onSetBreakEnd:    { i, t in viewStore.dispatch(.setBreakEnd(i, t)) },
            onSetBreakStartNow: { viewStore.dispatch(.setBreakStartNow($0)) },
            onSetBreakEndNow:   { viewStore.dispatch(.setBreakEndNow($0)) }
        )
        .onAppear { viewStore.dispatch(.onAppear) }
        // Native back button + swipe gesture work correctly:
        // saveCompleted already syncs the calendar cache on every edit, so no custom back needed.
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                Button { viewStore.dispatch(.prevDay) } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .regular))
                }
                Button { viewStore.dispatch(.nextDay) } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 15, weight: .regular))
                }
            }
        }
        .tint(Color.pookieText)
    }
}
