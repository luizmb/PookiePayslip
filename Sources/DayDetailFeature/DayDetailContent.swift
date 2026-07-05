import AppDomain
import PookieStyle
import SwiftUI

private func durationLabel(_ minutes: Int) -> String {
    let h = minutes / 60, m = minutes % 60
    if h == 0 { return "\(m) min" }
    return m == 0 ? "\(h)h" : "\(h)h \(m)m"
}

public struct DayDetailContent: View {
    let dateTitle: String
    let workedHoursText: String
    let statusText: String
    let startFieldLabel: String
    let endFieldLabel: String
    let addBreakLabel: String
    let nowButtonLabel: String
    let timePlaceholder: String
    let startDefault: TimeOfDay   // committed when the start --:-- is tapped (from Settings)
    let endDefault: TimeOfDay     // committed when the end --:-- is tapped (from Settings)
    let startTime: Binding<TimeOfDay?>
    let endTime: Binding<TimeOfDay?>
    let breaks: [DayDetailFeature.BreakRowModel]
    let isFuture: Bool
    let totalBreakText: String?
    let onSetStartNow: () -> Void
    let onSetEndNow: () -> Void
    let onAddBreak: () -> Void
    let onRemoveBreak: (Int) -> Void
    let onSetBreakLength: (Int, Int) -> Void
    let onSetBreakStart: (Int, TimeOfDay?) -> Void
    let onSetBreakEnd: (Int, TimeOfDay?) -> Void
    let onSetBreakStartNow: (Int) -> Void
    let onSetBreakEndNow: (Int) -> Void

    public var body: some View {
        ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    dayHeader
                    TimeFieldCard(
                        label: startFieldLabel,
                        defaultTime: startDefault,
                        nowLabel: nowButtonLabel,
                        placeholder: timePlaceholder,
                        time: startTime,
                        onNow: onSetStartNow
                    )
                    breaksSection
                    TimeFieldCard(
                        label: endFieldLabel,
                        defaultTime: endDefault,
                        nowLabel: nowButtonLabel,
                        placeholder: timePlaceholder,
                        time: endTime,
                        onNow: onSetEndNow
                    )
                }
                .padding(.bottom, 34)
        }
        .background(Color.pookieBg.ignoresSafeArea())
    }

    private var dayHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(dateTitle)
                .font(.pookie(26, weight: .bold))
                .foregroundStyle(Color.pookieText)
            if !workedHoursText.isEmpty {
                HStack(spacing: 0) {
                    Text(workedHoursText)
                        .font(.pookie(15, weight: .bold))
                        .foregroundStyle(Color.pookieAccentInk)
                    Text(" \(statusText)")
                        .font(.pookie(15))
                        .foregroundStyle(Color.pookieTextMuted)
                }
            } else {
                Text(statusText)
                    .font(.pookie(15))
                    .foregroundStyle(Color.pookieTextMuted)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 4)
        .padding(.bottom, 22)
    }

    private var breaksSection: some View {
        VStack(spacing: 8) {
            ForEach(breaks) { b in
                BreakRowCard(
                    label: b.label,
                    nowLabel: nowButtonLabel,
                    placeholder: timePlaceholder,
                    durationMinutes: b.durationMinutes,
                    startTime: b.startTime,
                    endTime: b.endTime,
                    onSetLength: { onSetBreakLength(b.id, $0) },
                    onSetStart: { onSetBreakStart(b.id, $0) },
                    onSetEnd: { onSetBreakEnd(b.id, $0) },
                    onSetStartNow: { onSetBreakStartNow(b.id) },
                    onSetEndNow: { onSetBreakEndNow(b.id) },
                    onRemove: { onRemoveBreak(b.id) }
                )
            }
            Button(action: onAddBreak) {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .semibold))
                    Text(addBreakLabel)
                        .font(.pookie(14, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .foregroundStyle(Color.pookieTextMuted)
                .overlay(
                    RoundedRectangle(cornerRadius: PookieRadius.md)
                        .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6]))
                        .foregroundStyle(Color.pookieBorder)
                )
            }
            .buttonStyle(.plain)
            if let breakText = totalBreakText {
                Text(breakText)
                    .font(.pookie(12.5))
                    .foregroundStyle(Color.pookieTextMuted)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 2)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }
}

// MARK: - TimeFieldCard

private struct TimeFieldCard: View {
    let label: String
    let defaultTime: TimeOfDay   // committed immediately when --:-- is tapped
    let nowLabel: String
    let placeholder: String
    let time: Binding<TimeOfDay?>
    let onNow: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(label)
                .font(.pookie(13, weight: .semibold))
                .foregroundStyle(Color.pookieTextMuted)
            HStack(spacing: 10) {
                if time.wrappedValue != nil {
                    // Time set → live DatePicker chip
                    DatePicker("", selection: pickerBinding, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                        .environment(\.timeZone, .gmt)
                        .tint(Color.pookieAccent)
                } else {
                    Button { time.wrappedValue = defaultTime } label: {
                        Text(placeholder)
                            .font(.pookie(30, weight: .bold))
                            .monospacedDigit()
                            .foregroundStyle(Color.pookieTextFaint)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.pookieSurface2)
                            .clipShape(RoundedRectangle(cornerRadius: PookieRadius.sm))
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
                Button(nowLabel, action: onNow)
                    .font(.pookie(13, weight: .semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Color.pookieAccentSoft)
                    .foregroundStyle(Color.pookieAccentInk)
                    .clipShape(Capsule())
                    .buttonStyle(.plain)
                if time.wrappedValue != nil {
                    Button { time.wrappedValue = nil } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.pookieTextMuted)
                    }
                    .buttonStyle(.plain)
                    .frame(width: 28, height: 28)
                    .background(Color.pookieSurface2)
                    .clipShape(Circle())
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .pookieCard()
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }

    private var pickerBinding: Binding<Date> {
        Binding(
            get: {
                let tod = time.wrappedValue ?? defaultTime
                return tod.pickerDate
            },
            set: { date in
                time.wrappedValue = TimeOfDay(pickerDate: date)
            }
        )
    }
}

// MARK: - BreakRowCard

private struct BreakRowCard: View {
    let label: String
    let nowLabel: String
    let placeholder: String
    let durationMinutes: Int?
    let startTime: TimeOfDay?
    let endTime: TimeOfDay?
    let onSetLength: (Int) -> Void
    let onSetStart: (TimeOfDay?) -> Void
    let onSetEnd: (TimeOfDay?) -> Void
    let onSetStartNow: () -> Void
    let onSetEndNow: () -> Void
    let onRemove: () -> Void

    private static let lengthOptions = [15, 30, 45, 60, 90]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(label)
                    .font(.pookie(13, weight: .semibold))
                    .foregroundStyle(Color.pookieTextMuted)
                Spacer()
                Menu {
                    ForEach(Self.lengthOptions, id: \.self) { m in
                        Button(durationLabel(m)) { onSetLength(m) }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "timer")
                            .font(.system(size: 10, weight: .semibold))
                        Text(durationMinutes.map(durationLabel) ?? "Length")
                            .font(.pookie(12, weight: .semibold))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.pookieAccentSoft)
                    .foregroundStyle(Color.pookieAccentInk)
                    .clipShape(Capsule())
                }
                Button(action: onRemove) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.pookieTextMuted)
                }
                .buttonStyle(.plain)
                .frame(width: 28, height: 28)
                .background(Color.pookieSurface2)
                .clipShape(Circle())
            }
            HStack(spacing: 8) {
                BreakTimeCell(
                    time: startTime,
                    defaultTime: TimeOfDay(hour: 12, minute: 30),
                    nowLabel: nowLabel,
                    placeholder: placeholder,
                    onSetNow: onSetStartNow,
                    onSet: onSetStart,
                    onClear: { onSetStart(nil) }
                )
                Text("→")
                    .font(.pookie(13, weight: .medium))
                    .foregroundStyle(Color.pookieTextFaint)
                BreakTimeCell(
                    time: endTime,
                    defaultTime: TimeOfDay(hour: 13, minute: 0),
                    nowLabel: nowLabel,
                    placeholder: placeholder,
                    onSetNow: onSetEndNow,
                    onSet: onSetEnd,
                    onClear: { onSetEnd(nil) }
                )
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .pookieCard()
    }
}

// MARK: - BreakTimeCell

private struct BreakTimeCell: View {
    let time: TimeOfDay?
    let defaultTime: TimeOfDay   // committed immediately when --:-- is tapped
    let nowLabel: String
    let placeholder: String
    let onSetNow: () -> Void
    let onSet: (TimeOfDay?) -> Void
    let onClear: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            if time != nil {
                DatePicker("", selection: pickerBinding, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                        .environment(\.timeZone, .gmt)
                    .font(.pookie(22, weight: .bold))
                    .tint(Color.pookieAccent)
            } else {
                Button { onSet(defaultTime) } label: {
                    Text(placeholder)
                        .font(.pookie(22, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(Color.pookieTextFaint)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.pookieSurface2)
                        .clipShape(RoundedRectangle(cornerRadius: PookieRadius.sm))
                }
                .buttonStyle(.plain)
            }
            Button(nowLabel, action: onSetNow)
                .font(.pookie(12, weight: .semibold))
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(Color.pookieAccentSoft)
                .foregroundStyle(Color.pookieAccentInk)
                .clipShape(Capsule())
                .buttonStyle(.plain)
            if time != nil {
                Button(action: onClear) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Color.pookieTextMuted)
                }
                .buttonStyle(.plain)
                .frame(width: 22, height: 22)
                .background(Color.pookieSurface2)
                .clipShape(Circle())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var pickerBinding: Binding<Date> {
        Binding(
            get: {
                let tod = time ?? defaultTime
                return tod.pickerDate
            },
            set: { date in
                onSet(TimeOfDay(pickerDate: date))
            }
        )
    }
}
