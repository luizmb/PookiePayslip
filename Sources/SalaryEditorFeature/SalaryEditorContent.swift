import AppDomain
import PookieStyle
import SwiftUI

public struct SalaryEditorContent: View {
    let amountText: Binding<String>
    let periodicity: Binding<SalaryPeriodicity>
    let niClass: Binding<NIClass>
    let studentLoan: Binding<StudentLoanPlan>
    let pensionEnabled: Binding<Bool>
    let pensionLabel: String
    let displayPreview: String
    let canSave: Bool
    let titleLabel: String
    let amountLabel: String
    let currencySymbol: String
    let saveButtonLabel: String
    let onSave: () -> Void

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                Text(displayPreview)
                    .font(.pookie(22, weight: .bold))
                    .foregroundStyle(Color.pookieText)
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
                    .padding(.bottom, 22)

                // Amount
                sectionCard {
                    Text(amountLabel)
                        .font(.pookie(13, weight: .semibold))
                        .foregroundStyle(Color.pookieTextMuted)
                    HStack(alignment: .lastTextBaseline, spacing: 0) {
                        Text(currencySymbol)
                            .font(.pookie(32, weight: .bold))
                            .foregroundStyle(Color.pookieText)
                        TextField("0", text: amountText)
                            .font(.pookie(32, weight: .bold))
                            .foregroundStyle(Color.pookieText)
#if os(iOS)
                            .keyboardType(.decimalPad)
#endif
                            .frame(maxWidth: 200)
                    }
                }

                // Periodicity
                sectionCard {
                    Text("Pay period")
                        .font(.pookie(13, weight: .semibold))
                        .foregroundStyle(Color.pookieTextMuted)
                    VStack(spacing: 10) {
                        ForEach(SalaryPeriodicity.allCases, id: \.rawValue) { option in
                            radioRow(
                                label: option.label,
                                selected: periodicity.wrappedValue == option,
                                onSelect: { periodicity.wrappedValue = option }
                            )
                        }
                    }
                }

                // Employment type (NI class)
                sectionCard {
                    Text("Employment type")
                        .font(.pookie(13, weight: .semibold))
                        .foregroundStyle(Color.pookieTextMuted)
                    VStack(spacing: 10) {
                        ForEach(NIClass.allCases, id: \.rawValue) { option in
                            radioRow(
                                label: option.displayLabel,
                                selected: niClass.wrappedValue == option,
                                onSelect: { niClass.wrappedValue = option }
                            )
                        }
                    }
                }

                // Student Loan
                sectionCard {
                    Text("Student Loan")
                        .font(.pookie(13, weight: .semibold))
                        .foregroundStyle(Color.pookieTextMuted)
                    VStack(spacing: 10) {
                        ForEach(StudentLoanPlan.allCases, id: \.rawValue) { option in
                            radioRow(
                                label: option.displayLabel,
                                selected: studentLoan.wrappedValue == option,
                                onSelect: { studentLoan.wrappedValue = option }
                            )
                        }
                    }
                }

                // Workplace pension (opt-in, default off)
                sectionCard {
                    Toggle(isOn: pensionEnabled) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(pensionLabel)
                                .font(.pookie(15, weight: .semibold))
                                .foregroundStyle(Color.pookieText)
                            Text("Deduct an auto-enrolment pension contribution.")
                                .font(.pookie(12.5))
                                .foregroundStyle(Color.pookieTextMuted)
                        }
                    }
                    .tint(Color.pookieAccent)
                }

                Button(action: onSave) {
                    Text(saveButtonLabel)
                        .font(.pookie(17, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .foregroundStyle(canSave ? Color.white : Color.pookieTextFaint)
                .background(canSave ? Color.pookieAccent : Color.pookieSurface2)
                .clipShape(RoundedRectangle(cornerRadius: PookieRadius.md))
                .shadow(color: canSave ? Color.pookieAccent.opacity(0.35) : .clear, radius: 9, x: 0, y: 6)
                .disabled(!canSave)
                .padding(.horizontal, 16)
                .padding(.top, 4)
            }
            .padding(.bottom, 34)
        }
        .background(Color.pookieBg.ignoresSafeArea())
        .navigationTitle(titleLabel)
    }

    private func sectionCard<C: View>(@ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            content()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .pookieCard()
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }

    private func radioRow(label: String, selected: Bool, onSelect: @escaping () -> Void) -> some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .strokeBorder(selected ? Color.pookieAccent : Color.pookieTextFaint, lineWidth: 2)
                        .frame(width: 20, height: 20)
                    if selected {
                        Circle()
                            .fill(Color.pookieAccent)
                            .frame(width: 10, height: 10)
                    }
                }
                Text(label)
                    .font(.pookie(15, weight: selected ? .semibold : .regular))
                    .foregroundStyle(selected ? Color.pookieText : Color.pookieTextMuted)
                Spacer()
            }
        }
        .buttonStyle(.plain)
    }
}

private extension SalaryPeriodicity {
    var label: String {
        switch self {
        case .hourly:  "Per hour"
        case .monthly: "Per month"
        case .yearly:  "Per year"
        }
    }
}
