import PookieStyle
import SwiftRexArchitecture
import SwiftUI

@BoundTo(CalendarFeature.self, strategy: .observationSimple)
public struct CalendarView: View {
    public var body: some View {
        CalendarContent(
            monthTitle:           viewStore.state.monthTitle,
            monthHoursText:       viewStore.state.monthHoursText,
            monthHoursSuffix:     viewStore.state.monthHoursSuffix,
            monthTotalLine1:      viewStore.state.monthTotalLine1,
            monthTotalLine2:      viewStore.state.monthTotalLine2,
            weekdayLabels:        viewStore.state.weekdayLabels,
            reportButtonLabel:    viewStore.state.reportButtonLabel,
            salaryChipLabel:      viewStore.state.salaryChipLabel,
            expectedEarningsText: viewStore.state.expectedEarningsText,
            days:                 viewStore.state.days,
            onPrevMonth:          { viewStore.dispatch(.prevMonth) },
            onNextMonth:          { viewStore.dispatch(.nextMonth) },
            onDayTap:             { viewStore.dispatch(.dayTapped($0)) },
            onReport:             { viewStore.dispatch(.reportTapped) },
            onSalaryTap:          { viewStore.dispatch(.salaryTapped) },
            onSettings:           { viewStore.dispatch(.settingsTapped) }
        )
        .onAppear { viewStore.dispatch(.onAppear) }
    }
}
