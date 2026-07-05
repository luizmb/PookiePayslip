import AppDomain
import PookieStyle
import SwiftUI

public struct ReportResultContent: View {
    let kickerLabel: String
    let periodLabel: String
    let yearLabel: String
    let heroTitleLabel: String
    let netPayText: String
    let heroMetaText: String
    let estimateNoteText: String?
    let incompleteWarningText: String?
    let breakdownRows: [ReportResultFeature.BreakdownRow]
    let netCardLabel: String
    let finePrintHeading: String
    let finePrintBody: String
    let pdfShareable: PDFShareable?   // for snapshot/preview awareness; print is in toolbar

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                reportHeader
                heroCard
                if let note = estimateNoteText { estimateNote(note) }
                if let warning = incompleteWarningText { incompleteWarning(warning) }
                breakdownCard
                netCard
                finePrint
            }
            .padding(.bottom, 34)
        }
        .background(Color.pookieBg.ignoresSafeArea())
    }

    private var reportHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(kickerLabel)
                .font(.pookie(11, weight: .bold))
                .foregroundStyle(Color.pookieAccent)
                .kerning(1.4)
            if !periodLabel.isEmpty {
                Text(periodLabel)
                    .font(.pookie(23, weight: .bold))
                    .foregroundStyle(Color.pookieText)
                Text(yearLabel)
                    .font(.pookie(14, weight: .medium))
                    .foregroundStyle(Color.pookieTextMuted)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 6)
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(heroTitleLabel)
                .font(.pookie(13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
            Text(netPayText)
                .font(.pookie(44, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(.white)
                .padding(.top, 6)
                .padding(.bottom, 8)
            Text(heroMetaText)
                .font(.pookie(13))
                .foregroundStyle(.white.opacity(0.85))
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.pookieAccent)
        .clipShape(RoundedRectangle(cornerRadius: PookieRadius.lg))
        .shadow(color: Color.pookieAccent.opacity(0.32), radius: 14, x: 0, y: 10)
        .padding(.horizontal, 16)
        .padding(.top, 18)
    }

    private func estimateNote(_ text: String) -> some View {
        Text(text)
            .font(.pookie(12.5))
            .foregroundStyle(Color.pookieAccentInk)
            .padding(.horizontal, 15)
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.pookieAccentSoft)
            .clipShape(RoundedRectangle(cornerRadius: PookieRadius.md))
            .padding(.horizontal, 16)
            .padding(.top, 12)
    }

    private func incompleteWarning(_ text: String) -> some View {
        Text(text)
            .font(.pookie(12.5))
            .foregroundStyle(Color(red: 0.54, green: 0.35, blue: 0.06))
            .padding(.horizontal, 15)
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(red: 0.75, green: 0.54, blue: 0.16).opacity(0.14))
            .clipShape(RoundedRectangle(cornerRadius: PookieRadius.md))
            .padding(.horizontal, 16)
            .padding(.top, 12)
    }

    private var breakdownCard: some View {
        VStack(spacing: 0) {
            ForEach(breakdownRows.indices, id: \.self) { i in
                let row = breakdownRows[i]
                BreakdownLineView(
                    label: row.label,
                    sub: row.sub,
                    value: row.value,
                    isNegative: row.isNegative,
                    isLast: i == breakdownRows.indices.last
                )
            }
        }
        .background(Color.pookieSurface)
        .clipShape(RoundedRectangle(cornerRadius: PookieRadius.lg))
        .pookieShadow()
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }

    private var netCard: some View {
        HStack {
            Text(netCardLabel)
                .font(.pookie(15, weight: .semibold))
                .foregroundStyle(Color.pookieBg.opacity(0.8))
            Spacer()
            Text(netPayText)
                .font(.pookie(24, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(Color.pookieBg)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 18)
        .background(Color.pookieText)
        .clipShape(RoundedRectangle(cornerRadius: PookieRadius.lg))
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    private var finePrint: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(finePrintHeading)
                .font(.pookie(12, weight: .bold))
                .foregroundStyle(Color.pookieTextMuted)
                .kerning(0.3)
            Text(finePrintBody)
                .font(.pookie(11.5))
                .foregroundStyle(Color.pookieTextFaint)
                .lineSpacing(4)
        }
        .padding(.horizontal, 24)
        .padding(.top, 22)
    }
}

// MARK: - BreakdownLineView

private struct BreakdownLineView: View {
    let label: String
    let sub: String?
    let value: String
    let isNegative: Bool
    let isLast: Bool

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                Text(label)
                    .font(.pookie(15, weight: .semibold))
                    .foregroundStyle(Color.pookieText)
                if let sub {
                    Text(sub)
                        .font(.pookie(11.5))
                        .foregroundStyle(Color.pookieTextMuted)
                }
            }
            Spacer()
            Text(isNegative ? "− \(value)" : value)
                .font(.pookie(16, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(isNegative ? Color.pookieNegative : Color.pookieText)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .overlay(alignment: .bottom) {
            if !isLast {
                Rectangle()
                    .fill(Color.pookieBorder)
                    .frame(height: 1)
                    .padding(.horizontal, 18)
            }
        }
    }
}
