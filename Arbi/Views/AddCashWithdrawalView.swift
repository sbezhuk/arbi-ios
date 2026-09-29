import SwiftUI
import SwiftData

/// Modal sheet for recording intermediate cash withdrawals (e.g. taking profit to cash or personal savings).
struct AddCashWithdrawalView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var initialPeriod: String = PeriodRolloverService.currentPeriodIdentifier()
    var preselectedBankAccount: BankAccount? = nil
    var onSaved: ((CashWithdrawal) -> Void)? = nil

    @Query(filter: #Predicate<BankAccount> { !$0.isArchived }, sort: \BankAccount.name)
    private var activeBankAccounts: [BankAccount]

    @State private var amountText: String = ""
    @State private var timestamp: Date = Date()
    @State private var selectedBankAccount: BankAccount?
    @State private var note: String = ""

    @FocusState private var isAmountFocused: Bool

    private var parsedAmount: Double {
        let cleaned = amountText.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        return Double(cleaned) ?? 0.0
    }

    private var targetPeriod: String {
        PeriodRolloverService.period(for: timestamp)
    }

    private var isValid: Bool {
        parsedAmount > 0
    }

    var body: some View {
        NavigationStack {
            Form {
                // Section 1: Amount
                Section {
                    HStack(alignment: .firstTextBaseline) {
                        Text("₴")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(Color.accentColor)

                        TextField("0.00", text: $amountText)
                            .keyboardType(.decimalPad)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .focused($isAmountFocused)

                        if !amountText.isEmpty {
                            Button {
                                amountText = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("withdrawal.section.amount")
                } footer: {
                    Text("withdrawal.footer.amount")
                }

                // Section 2: Details & Source Bank Account
                Section {
                    DatePicker("order.field.date_time", selection: $timestamp)

                    Picker("withdrawal.field.source_card", selection: $selectedBankAccount) {
                        Text("withdrawal.option.direct_cash").tag(nil as BankAccount?)
                        ForEach(activeBankAccounts) { account in
                            HStack {
                                Text(account.name)
                                if let card = account.cardNumber, !card.isEmpty {
                                    Text("(\(card))")
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .tag(account as BankAccount?)
                        }
                    }

                    HStack {
                        Text("withdrawal.field.period")
                        Spacer()
                        Text(targetPeriod)
                            .font(.footnote.weight(.semibold).monospacedDigit())
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color(uiColor: .tertiarySystemFill))
                            .clipShape(Capsule())
                    }
                } header: {
                    Text("order.section.details")
                }

                // Section 3: Note
                Section {
                    TextField("withdrawal.placeholder.note", text: $note)
                } header: {
                    Text("withdrawal.section.note")
                }
            }
            .navigationTitle("withdrawal.title.record")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.action.cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("common.action.save") {
                        saveWithdrawal()
                    }
                    .fontWeight(.bold)
                    .disabled(!isValid)
                }
            }
            .onAppear {
                if let preselected = preselectedBankAccount {
                    selectedBankAccount = preselected
                }
                isAmountFocused = true
            }
        }
    }

    private func saveWithdrawal() {
        guard isValid else { return }

        let withdrawal = CashWithdrawal(
            amountUAH: parsedAmount,
            timestamp: timestamp,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : note.trimmingCharacters(in: .whitespacesAndNewlines),
            periodIdentifier: targetPeriod,
            bankAccount: selectedBankAccount
        )

        modelContext.insert(withdrawal)
        try? modelContext.save()

        onSaved?(withdrawal)
        dismiss()
    }
}
