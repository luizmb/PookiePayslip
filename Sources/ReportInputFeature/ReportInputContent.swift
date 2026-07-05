import AppDomain
import PookieStyle
import SwiftUI

public struct ReportInputContent: View {
    let from: Binding<Date>
    let to: Binding<Date>
    let estimate: Binding<Bool>
    let showEstimateToggle: Bool
    let canGenerate: Bool
    let noSalaryWarning: String?
    let titleLabel: String
    let subtitleLabel: String
    let fromLabel: String
    let toLabel: String
    let estimateTitleLabel: String
    let estimateDescriptionLabel: String
    let generateButtonLabel: String
    let onGenerate: () -> Void

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

                dateField(label: fromLabel, date: from)
                dateField(label: toLabel, date: to)

                if let warning = noSalaryWarning {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 13, weight: .semibold))
                        Text(warning)
                            .font(.pookie(13))
                    }
                    .foregroundStyle(Color(red: 0.54, green: 0.35, blue: 0.06))
                    .padding(.horizontal, 15)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(red: 0.75, green: 0.54, blue: 0.16).opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: PookieRadius.md))
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                }

                if showEstimateToggle { estimateToggle }

                Button(action: onGenerate) {
                    Text(generateButtonLabel)
                        .font(.pookie(17, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .foregroundStyle(canGenerate ? Color.white : Color.pookieTextFaint)
                .background(canGenerate ? Color.pookieAccent : Color.pookieSurface2)
                .clipShape(RoundedRectangle(cornerRadius: PookieRadius.md))
                .shadow(color: canGenerate ? Color.pookieAccent.opacity(0.35) : .clear, radius: 9, x: 0, y: 6)
                .disabled(!canGenerate)
                .padding(.horizontal, 16)
                .padding(.top, 22)
            }
            .padding(.bottom, 34)
        }
        .background(Color.pookieBg.ignoresSafeArea())
    }

    private func dateField(label: String, date: Binding<Date>) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(label)
                .font(.pookie(13, weight: .semibold))
                .foregroundStyle(Color.pookieTextMuted)
            DatePicker("", selection: date, displayedComponents: .date)
                .labelsHidden()
                .font(.pookie(19, weight: .semibold))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 15)
        .pookieCard()
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }

    private var estimateToggle: some View {
        Button { estimate.wrappedValue.toggle() } label: {
            HStack(alignment: .top, spacing: 13) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7)
                        .strokeBorder(estimate.wrappedValue ? Color.pookieAccent : Color.pookieTextFaint, lineWidth: 2)
                        .background(
                            estimate.wrappedValue
                                ? RoundedRectangle(cornerRadius: 7).fill(Color.pookieAccent)
                                : RoundedRectangle(cornerRadius: 7).fill(Color.clear)
                        )
                        .frame(width: 22, height: 22)
                    if estimate.wrappedValue {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .padding(.top, 1)
                VStack(alignment: .leading, spacing: 4) {
                    Text(estimateTitleLabel)
                        .font(.pookie(15, weight: .bold))
                        .foregroundStyle(Color.pookieText)
                    Text(estimateDescriptionLabel)
                        .font(.pookie(12.5))
                        .foregroundStyle(Color.pookieTextMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(estimate.wrappedValue ? Color.pookieAccentSoft : Color.pookieSurface)
            .clipShape(RoundedRectangle(cornerRadius: PookieRadius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: PookieRadius.lg)
                    .strokeBorder(estimate.wrappedValue ? Color.pookieAccent : Color.pookieBorder, lineWidth: 1.5)
            )
            .pookieShadow()
            .padding(.horizontal, 16)
            .padding(.bottom, 4)
        }
        .buttonStyle(.plain)
    }
}
