import SwiftUI
import SwiftData

/// View for managing user bank accounts and cards with custom turnover limits.
struct BankAccountsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \BankAccount.createdAt, order: .forward) private var allAccounts: [BankAccount]
    @Query(sort: \P2POrder.timestamp, order: .reverse) private var allOrders: [P2POrder]
    @State private var showingAddSheet: Bool = false
    @State private var accountToEdit: BankAccount?
    @State private var errorMessage: String?
    @State private var showingErrorAlert: Bool = false

    private var activeAccounts: [BankAccount] {
        allAccounts.filter { !$0.isArchived }
    }

    private var archivedAccounts: [BankAccount] {
        allAccounts.filter { $0.isArchived }
    }

    private var turnoverStatsByID: [UUID: AccountTurnoverStat] {
        let periodOrders = PeriodRolloverService.ordersForPeriod(
            PeriodRolloverService.currentPeriodIdentifier(),
            orders: allOrders
        )
        return Dictionary(
            uniqueKeysWithValues: P2PCalculator.accountTurnover(orders: periodOrders, accounts: allAccounts)
                .map { ($0.id, $0) }
        )
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if activeAccounts.isEmpty {
                        ContentUnavailableView {
                            Label("bank.empty.no_accounts", systemImage: "building.columns")
                        } description: {
                            Text("bank.empty.description")
                        } actions: {
                            Button("bank.action.add_defaults") {
                                seedDefaultAccounts()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .padding(.vertical, 12)
                    } else {
                        ForEach(activeAccounts) { account in
                            if let stat = turnoverStatsByID[account.id] {
                                BankAccountRow(stat: stat)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        accountToEdit = account
                                    }
                                    .swipeActions(edge: .trailing) {
                                        Button(role: .destructive) {
                                            deleteAccount(account)
                                        } label: {
                                            Label("common.action.delete", systemImage: "trash")
                                        }

                                        Button {
                                            toggleArchive(account)
                                        } label: {
                                            Label("common.action.archive", systemImage: "archivebox")
                                        }
                                        .tint(.orange)
                                    }
                                }
                        }
                    }
                } header: {
                    Text("bank.section.active_accounts")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color(uiColor: .secondaryLabel))
                }

                if !archivedAccounts.isEmpty {
                    Section {
                        ForEach(archivedAccounts) { account in
                            if let stat = turnoverStatsByID[account.id] {
                                BankAccountRow(stat: stat)
                                    .swipeActions(edge: .trailing) {
                                        Button {
                                            toggleArchive(account)
                                        } label: {
                                            Label("common.action.unarchive", systemImage: "arrow.up.bin")
                                        }
                                        .tint(.green)
                                    }
                            }
                        }
                    } header: {
                        Text(LocalizationManager.shared.string("bank.section.archived_cards", archivedAccounts.count))
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Color(uiColor: .secondaryLabel))
                    }
                }
            }
            .contentMargins(.top, SheetLayoutConstants.topContentMargin, for: .scrollContent)
            .navigationTitle("bank.title.management")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.action.done") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("bank.action.add_account")
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddOrEditBankAccountView()
            }
            .sheet(item: $accountToEdit) { account in
                AddOrEditBankAccountView(editingAccount: account)
            }
            .alert("common.alert.error", isPresented: $showingErrorAlert) {
                Button("common.action.ok", role: .cancel) { }
            } message: {
                if let errorMessage {
                    Text(verbatim: errorMessage)
                } else {
                    Text("common.error.unknown")
                }
            }
        }
    }

    private func toggleArchive(_ account: BankAccount) {
        account.isArchived.toggle()
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            errorMessage = error.localizedDescription
            showingErrorAlert = true
        }
    }

    private func deleteAccount(_ account: BankAccount) {
        modelContext.delete(account)
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            errorMessage = error.localizedDescription
            showingErrorAlert = true
        }
    }

    private func seedDefaultAccounts() {
        do {
            try BankAccount.seedDefaultUkrainianBanks(in: modelContext)
        } catch {
            modelContext.rollback()
            errorMessage = error.localizedDescription
            showingErrorAlert = true
        }
    }
}

private struct BankAccountRow: View {
    let stat: AccountTurnoverStat

    private var progress: Double {
        min(max(stat.progress, 0), 1)
    }

    private var progressColor: Color {
        if stat.progress >= 0.9 {
            return .red
        } else if stat.progress >= 0.7 {
            return .orange
        } else {
            return .indigo
        }
    }

    private var maskedCardNumber: String? {
        guard let card = stat.cardNumber, !card.isEmpty else { return nil }
        let digits = card.filter(\.isNumber)
        guard digits.count >= 4 else { return card }
        return "•••• " + String(digits.suffix(4))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(HomeDisplayNames.bankAccount(stat.accountName))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    if let card = maskedCardNumber {
                        Text(card)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Text(HomeFormatters.percent(progress))
                    .font(.caption.weight(.medium).monospacedDigit())
                    .foregroundStyle(progressColor)
            }

            ProgressView(value: progress)
                .tint(progressColor)

            HStack(alignment: .firstTextBaseline) {
                HStack(spacing: 4) {
                    Text(HomeFormatters.uah(stat.totalSellUAH))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                    Text("bank.label.used")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                HStack(spacing: 4) {
                    Text(HomeFormatters.uah(stat.turnoverLimitUAH))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.tertiary)
                    Text("bank.label.limit")
                        .font(.caption)
                    .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, 8)
        .alignmentGuide(.listRowSeparatorLeading) { dimensions in
            dimensions[.leading]
        }
    }
}

/// Sheet to create or edit a BankAccount.
struct AddOrEditBankAccountView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var editingAccount: BankAccount?

    @State private var name: String = ""
    @State private var cardNumber: String = ""
    @State private var limitText: String = "150000"
    @State private var errorMessage: String?
    @State private var showingErrorAlert: Bool = false
    @State private var attemptedSave: Bool = false
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case name
        case limit
    }

    private var parsedLimit: Double? {
        NumericInput(text: limitText).value
    }

    private var validationResult: FormValidationResult {
        BankAccountDraftValidator.validate(
            BankAccountDraft(name: name, turnoverLimitUAH: NumericInput(text: limitText))
        )
    }

    private var isValid: Bool {
        validationResult.isValid
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                            Label {
                                HStack(spacing: 2) {
                                    Text("bank.field.title")
                                    Text("*").foregroundStyle(.secondary)
                                }
                            } icon: {
                                Image(systemName: "building.columns.fill")
                            }
                            .font(.subheadline.weight(.regular))
                            .foregroundStyle(.secondary)
                            .frame(width: 100, alignment: .leading)

                        TextField("bank.placeholder.name", text: $name)
                            .font(.body.weight(.regular))
                            .focused($focusedField, equals: .name)
                    }

                    HStack {
                        Label("bank.field.card_number", systemImage: "creditcard")
                            .font(.subheadline.weight(.regular))
                            .foregroundStyle(.secondary)
                            .frame(width: 100, alignment: .leading)

                        TextField("bank.placeholder.card_number", text: $cardNumber)
                            .font(.body.monospacedDigit().weight(.regular))
                    }
                } header: {
                    Text("bank.section.account_details")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color(uiColor: .secondaryLabel))
                } footer: {
                    SectionValidationFooter(
                        result: validationResult,
                        field: "name",
                        isVisible: attemptedSave,
                        helperText: "bank.footer.security_notice"
                    )
                }

                Section {
                    HStack {
                            Label {
                                HStack(spacing: 2) {
                                    Text("bank.field.limit")
                                    Text("*").foregroundStyle(.secondary)
                                }
                            } icon: {
                                Image(systemName: "chart.line.uptrend.xyaxis")
                            }
                            .font(.subheadline.weight(.regular))
                            .foregroundStyle(.secondary)
                            .frame(width: 100, alignment: .leading)

                        TextField(String(""), text: $limitText, prompt: Text(verbatim: "150000"))
                            .keyboardType(.numberPad)
                            .font(.body.monospacedDigit().weight(.regular))
                            .multilineTextAlignment(.trailing)
                            .focused($focusedField, equals: .limit)
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach([50_000, 100_000, 150_000, 200_000, 250_000], id: \.self) { amount in
                                Button {
                                    limitText = "\(amount)"
                                } label: {
                                    Text(verbatim: "\(amount / 1000)k ₴")
                                }
                                .font(.caption.weight(.medium))
                                .buttonStyle(.bordered)
                                .tint(isPresetSelected(amount) ? Color.accentColor : Color.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text("bank.section.turnover_limit")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color(uiColor: .secondaryLabel))
                } footer: {
                    SectionValidationFooter(
                        result: validationResult,
                        field: "limit",
                        isVisible: attemptedSave,
                        helperText: "bank.footer.turnover_limit_description"
                    )
                }
            }
            .navigationTitle(editingAccount == nil ? "bank.title.new_account" : "bank.title.edit_account")
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
                        save()
                    }
                    .fontWeight(.bold)
                }
            }
            .onAppear {
                if let account = editingAccount {
                    name = account.name
                    cardNumber = account.cardNumber ?? ""
                    limitText = String(format: "%.0f", account.turnoverLimitUAH)
                }
            }
            .alert("common.alert.error", isPresented: $showingErrorAlert) {
                Button("common.action.ok", role: .cancel) { }
            } message: {
                if let errorMessage {
                    Text(verbatim: errorMessage)
                } else {
                    Text("common.error.unknown")
                }
            }
        }
    }

    private func save() {
        attemptedSave = true
        guard isValid, let parsedLimit else { return }

        let trimmedCard = cardNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalCardNumber = trimmedCard.isEmpty ? nil : trimmedCard

        if let existing = editingAccount {
            existing.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
            existing.cardNumber = finalCardNumber
            existing.turnoverLimitUAH = parsedLimit
        } else {
            let newAccount = BankAccount(
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                cardNumber: finalCardNumber,
                turnoverLimitUAH: parsedLimit
            )
            modelContext.insert(newAccount)
        }

        do {
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.rollback()
            errorMessage = error.localizedDescription
            showingErrorAlert = true
        }
    }

    private func isPresetSelected(_ amount: Int) -> Bool {
        parsedLimit == Double(amount)
    }
}
