import AppDomain
import PookieStyle
import SwiftUI

public struct CalendarContent: View {
    let monthTitle: String
    let monthHoursText: String
    let monthHoursSuffix: String
    let monthTotalLine1: String
    let monthTotalLine2: String
    let weekdayLabels: [String]
    let reportButtonLabel: String
    let salaryChipLabel: String
    let expectedEarningsText: String?
    let days: [CalendarFeature.DayCellModel]
    let onPrevMonth: () -> Void
    let onNextMonth: () -> Void
    let onDayTap: (Date) -> Void
    let onReport: () -> Void
    let onSalaryTap: () -> Void
    let onSettings: () -> Void

    public var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                MonthHeader(
                    title: monthTitle,
                    hoursText: monthHoursText,
                    hoursSuffix: monthHoursSuffix,
                    totalLine1: monthTotalLine1,
                    totalLine2: monthTotalLine2,
                    reportButtonLabel: reportButtonLabel,
                    salaryChipLabel: salaryChipLabel,
                    expectedEarningsText: expectedEarningsText,
                    onPrev: onPrevMonth,
                    onNext: onNextMonth,
                    onReport: onReport,
                    onSalaryTap: onSalaryTap,
                    onSettings: onSettings
                )
                CalendarGrid(days: days, weekdayLabels: weekdayLabels, onDayTap: onDayTap)
            }
            .padding(.bottom, 34)
        }
        .background(Color.pookieBg.ignoresSafeArea())
    }
}

// MARK: - MonthHeader

private struct MonthHeader: View {
    let title: String
    let hoursText: String
    let hoursSuffix: String
    let totalLine1: String
    let totalLine2: String
    let reportButtonLabel: String
    let salaryChipLabel: String
    let expectedEarningsText: String?
    let onPrev: () -> Void
    let onNext: () -> Void
    let onReport: () -> Void
    let onSalaryTap: () -> Void
    let onSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Nav row
            HStack(spacing: 4) {
                Button(action: onPrev) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(width: 34, height: 34)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.pookieText)

                Text(title)
                    .font(.pookie(17, weight: .semibold))
                    .frame(minWidth: 132, alignment: .center)
                    .foregroundStyle(Color.pookieText)

                Button(action: onNext) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(width: 34, height: 34)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.pookieText)

                Spacer()

                Button(action: onSettings) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(width: 34, height: 34)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.pookieTextMuted)

                Button(action: onReport) {
                    Text(reportButtonLabel)
                        .font(.pookie(14, weight: .semibold))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 9)
                        .background(Color.pookieAccentSoft)
                        .foregroundStyle(Color.pookieAccentInk)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 18)

            // Hours + salary row
            HStack(alignment: .lastTextBaseline, spacing: 0) {
                Text(hoursText)
                    .font(.pookie(52, weight: .bold))
                    .foregroundStyle(Color.pookieText)
                    .monospacedDigit()
                Text(hoursSuffix)
                    .font(.pookie(24, weight: .semibold))
                    .foregroundStyle(Color.pookieTextMuted)
                    .padding(.leading, 2)
                    .padding(.bottom, 7)
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(totalLine1)
                        Text(totalLine2)
                    }
                    .font(.pookie(13))
                    .foregroundStyle(Color.pookieTextMuted)

                    // Salary chip
                    Button(action: onSalaryTap) {
                        Text(salaryChipLabel)
                            .font(.pookie(12, weight: .semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.pookieAccentSoft)
                            .foregroundStyle(Color.pookieAccentInk)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.bottom, 7)
            }
            .padding(.horizontal, 20)

            // Expected earnings
            if let earnings = expectedEarningsText {
                Text(earnings)
                    .font(.pookie(13, weight: .medium))
                    .foregroundStyle(Color.pookieAccentInk)
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 22)
    }
}

// MARK: - CalendarGrid

private struct CalendarGrid: View {
    let days: [CalendarFeature.DayCellModel]
    let weekdayLabels: [String]
    let onDayTap: (Date) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 5), count: 7)

    var body: some View {
        VStack(spacing: 0) {
            // Weekday header
            HStack(spacing: 0) {
                ForEach(weekdayLabels.indices, id: \.self) { i in
                    Text(weekdayLabels[i])
                        .font(.pookie(11, weight: .semibold))
                        .foregroundStyle(i >= 5 ? Color.pookieAccent.opacity(0.8) : Color.pookieTextFaint)
                        .frame(maxWidth: .infinity)
                        .textCase(.uppercase)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 6)

            LazyVGrid(columns: columns, spacing: 5) {
                ForEach(days) { day in
                    DayCell(model: day, onTap: { onDayTap(day.id) })
                }
            }
            .padding(.horizontal, 16)
        }
    }
}

// MARK: - DayCell

private struct DayCell: View {
    let model: CalendarFeature.DayCellModel
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            GeometryReader { geo in
                let size = geo.size.width
                ZStack(alignment: .top) {
                    // Background
                    RoundedRectangle(cornerRadius: PookieRadius.sm)
                        .fill(cellBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: PookieRadius.sm)
                                .strokeBorder(model.isToday ? Color.pookieAccent : Color.clear, lineWidth: 2)
                        )
                        .pookieShadow()

                    VStack(spacing: 0) {
                        // Day number
                        Text(model.dayNumber)
                            .font(.pookie(13, weight: .semibold))
                            .foregroundStyle(model.hoursText != nil ? Color.pookieAccentInk : Color.pookieTextMuted)
                            .padding(.top, 7)

                        Spacer(minLength: 0)

                        // Hours or dot
                        if let hours = model.hoursText {
                            Text(hours)
                                .font(.pookie(15, weight: .bold))
                                .foregroundStyle(Color.pookieAccentInk)
                                .monospacedDigit()
                                .padding(.bottom, 7)
                        } else if model.isInProgress {
                            Circle()
                                .fill(Color.pookieAccent.opacity(0.55))
                                .frame(width: 7, height: 7)
                                .padding(.bottom, 12)
                        }
                    }
                    .frame(width: size, height: size * 1.12)
                }
                .frame(width: size, height: size * 1.12)
            }
            .aspectRatio(1 / 1.12, contentMode: .fit)
        }
        .buttonStyle(.plain)
        .opacity(model.isInMonth ? 1 : 0.32)
        .disabled(!model.isInMonth)
    }

    private var cellBackground: Color {
        if model.hoursText != nil { return Color.pookieAccentSoft }      // worked day
        if model.isWeekend && model.isInMonth { return Color.pookieWeekend }  // empty weekend
        return Color.pookieSurface                                        // empty weekday
    }
}
