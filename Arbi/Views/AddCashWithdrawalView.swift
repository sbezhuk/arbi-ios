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
    @State private var attemptedSave: Bool = false
    @State private var errorMessage: String?
    @State private var showingErrorAlert: Bool = false

    @FocusState private var isAmountFocused: Bool

    private var parsedAmount: Double {
        NumericInput(text: amountText).value ?? 0.0
    }

    private var targetPeriod: String {
        PeriodRolloverService.period(for: timestamp)
    }

    private var isValid: Bool {
        validationResult.isValid
    }

    private var validationResult: FormValidationResult {
        CashWithdrawalDraftValidator.validate(
            CashWithdrawalDraft(amountUAH: NumericInput(text: amountText), timestamp: timestamp)
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                // Section 1: Amount
                Section {
                    HStack(alignment: .firstTextBaseline) {
                        Text(verbatim: "₴")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(Color.accentColor)
                        Text("*")
                            .foregroundStyle(.secondary)

                        TextField(String(""), text: $amountText, prompt: Text(verbatim: "0.00"))
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
                    SectionValidationFooter(
                        result: validationResult,
                        field: "amount",
                        isVisible: attemptedSave,
                        helperText: "withdrawal.footer.amount"
                    )
                }

                // Section 2: Details & Source Bank Account
                Section {
                    DatePicker("order.field.date_time", selection: $timestamp)

                    Picker("withdrawal.field.source_card", selection: $selectedBankAccount) {
                        Text("withdrawal.option.direct_cash").tag(nil as BankAccount?)
                        ForEach(activeBankAccounts) { account in
                            HStack {
                                Text(verbatim: account.name)
                                if let card = account.cardNumber, !card.isEmpty {
                                    Text(verbatim: "(\(card))")
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
                        attemptedSave = true
                        saveWithdrawal()
                    }
                    .fontWeight(.bold)
                }
            }
            .onAppear {
                if let preselected = preselectedBankAccount {
                    selectedBankAccount = preselected
                }
                isAmountFocused = true
            }
            .alert("common.alert.error", isPresented: $showingErrorAlert) {
                Button("common.action.ok", role: .cancel) {}
            } message: {
                Text(verbatim: errorMessage ?? "")
            }
        }
    }

    private func saveWithdrawal() {
        attemptedSave = true
        guard isValid else { return }

        let withdrawal = CashWithdrawal(
            amountUAH: parsedAmount,
            timestamp: timestamp,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : note.trimmingCharacters(in: .whitespacesAndNewlines),
            periodIdentifier: targetPeriod,
            bankAccount: selectedBankAccount
        )

        modelContext.insert(withdrawal)
        do {
            try modelContext.save()
            onSaved?(withdrawal)
            dismiss()
        } catch {
            modelContext.rollback()
            errorMessage = error.localizedDescription
            showingErrorAlert = true
        }
    }
}
