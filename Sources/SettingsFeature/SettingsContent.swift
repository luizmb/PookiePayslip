import AppDomain
import PookieStyle
import SwiftUI

public struct SettingsContent: View {
    let startTime: Binding<TimeOfDay>
    let endTime: Binding<TimeOfDay>
    let breakMinutes: Int
    let breakLabel: String
    let breakOptions: [Int]
    let titleLabel: String
    let subtitleLabel: String
    let startLabel: String
    let endLabel: String
    let breakSectionLabel: String
    let saveButtonLabel: String
    let exportSectionLabel: String
    let exportButtonLabel: String
    let exportShareable: ZipShareable?
    let onSetBreak: (Int) -> Void
    let onSave: () -> Void
    let onExport: () -> Void

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(titleLabel)
                    .font(.pookie(28, weight: .bold))
                    .foregroundStyle(Color.pookieText)
                    .padding(.horizontal, 24)
                    .padding(.top, 4)
                    .padding(.bottom, 6)
                Text(subtitleLabel)
                    .font(.pookie(14))
                    .foregroundStyle(Color.pookieTextMuted)
                    .lineSpacing(4)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 22)

                timeCard(label: startLabel, time: startTime)
                timeCard(label: endLabel, time: endTime)

                sectionCard {
                    Text(breakSectionLabel)
                        .font(.pookie(13, weight: .semibold))
                        .foregroundStyle(Color.pookieTextMuted)
                    Menu {
                        ForEach(breakOptions, id: \.self) { m in
                            Button(durationLabel(m)) { onSetBreak(m) }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "timer")
                                .font(.system(size: 12, weight: .semibold))
                            Text(breakLabel)
                                .font(.pookie(17, weight: .bold))
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(Color.pookieAccentSoft)
                        .foregroundStyle(Color.pookieAccentInk)
                        .clipShape(Capsule())
                    }
                }

                Button(action: onSave) {
                    Text(saveButtonLabel)
                        .font(.pookie(17, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .foregroundStyle(Color.white)
                .background(Color.pookieAccent)
                .clipShape(RoundedRectangle(cornerRadius: PookieRadius.md))
                .shadow(color: Color.pookieAccent.opacity(0.35), radius: 9, x: 0, y: 6)
                .padding(.horizontal, 16)
                .padding(.top, 10)

                sectionCard {
                    Text(exportSectionLabel)
                        .font(.pookie(13, weight: .semibold))
                        .foregroundStyle(Color.pookieTextMuted)
                    // Two-step: tap to zip, then the button becomes a ShareLink for the fresh backup.
                    if let zip = exportShareable {
                        ShareLink(item: zip, preview: SharePreview(exportButtonLabel, icon: Image(systemName: "doc.zipper"))) {
                            exportButtonLabelView(exportButtonLabel, systemImage: "square.and.arrow.up")
                        }
                    } else {
                        Button(action: onExport) {
                            exportButtonLabelView(exportButtonLabel, systemImage: "arrow.down.doc")
                        }
                    }
                }
                .padding(.top, 24)   // separate the backup card from the Save button
            }
            .padding(.bottom, 34)
        }
        .background(Color.pookieBg.ignoresSafeArea())
        .navigationTitle(titleLabel)
    }

    private func timeCard(label: String, time: Binding<TimeOfDay>) -> some View {
        sectionCard {
            Text(label)
                .font(.pookie(13, weight: .semibold))
                .foregroundStyle(Color.pookieTextMuted)
            DatePicker("", selection: timeBinding(time), displayedComponents: .hourAndMinute)
                .labelsHidden()
                .environment(\.timeZone, .gmt)
                .tint(Color.pookieAccent)
        }
    }

    private func exportButtonLabelView(_ label: String, systemImage: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))
            Text(label)
                .font(.pookie(17, weight: .bold))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(Color.pookieAccentSoft)
        .foregroundStyle(Color.pookieAccentInk)
        .clipShape(Capsule())
    }

    private func sectionCard<C: View>(@ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .pookieCard()
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }

    private func timeBinding(_ time: Binding<TimeOfDay>) -> Binding<Date> {
        Binding(
            get: { time.wrappedValue.pickerDate },
            set: { date in
                time.wrappedValue = TimeOfDay(pickerDate: date)
            }
        )
    }
}
