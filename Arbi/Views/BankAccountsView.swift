import SwiftUI
import SwiftData

/// View for managing user bank accounts and cards with custom turnover limits.
struct BankAccountsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.localization) private var loc

    @Query(sort: \BankAccount.createdAt, order: .forward) private var allAccounts: [BankAccount]
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

    var body: some View {
        NavigationStack {
            ZStack {
                // Layer 1: Screen background
                Color(uiColor: .systemGroupedBackground)
                    .ignoresSafeArea()

                // Layer 2 & 3: Scrollable content & Edge Fade Mask
                List {
                Section {
                    if activeAccounts.isEmpty {
                        ContentUnavailableView {
                            Label("No Active Bank Accounts", systemImage: "building.columns")
                        } description: {
                            Text("Add your bank accounts to track specific card turnover and financial monitoring limits.")
                        } actions: {
                            Button("Add Default Ukrainian Banks") {
                                seedDefaultAccounts()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .padding(.vertical, 12)
                    } else {
                        ForEach(activeAccounts) { account in
                            BankAccountRow(account: account)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    accountToEdit = account
                                }
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        deleteAccount(account)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }

                                    Button {
                                        toggleArchive(account)
                                    } label: {
                                        Label("Archive", systemImage: "archivebox")
                                    }
                                    .tint(.orange)
                                }
                        }
                    }
                } header: {
                    Text("Active Accounts & Cards")
                }

                if !archivedAccounts.isEmpty {
                    Section("Archived Cards (\(archivedAccounts.count))") {
                        ForEach(archivedAccounts) { account in
                            BankAccountRow(account: account)
                                .swipeActions(edge: .trailing) {
                                    Button {
                                        toggleArchive(account)
                                    } label: {
                                        Label("Unarchive", systemImage: "arrow.up.bin")
                                    }
                                    .tint(.green)
                                }
                        }
                    }
                }
            }
            .scrollEdgeFade()
            .ignoresSafeArea(edges: .bottom)
        }
        .navigationTitle(loc["Bank Accounts"])
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(loc["Done"]) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel(loc["Add Bank Account"])
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddOrEditBankAccountView()
            }
            .sheet(item: $accountToEdit) { account in
                AddOrEditBankAccountView(editingAccount: account)
            }
            .alert("Error", isPresented: $showingErrorAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage ?? "An unknown error occurred.")
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
    let account: BankAccount

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "creditcard.fill")
                .font(.title3)
                .foregroundStyle(account.isArchived ? Color.secondary : Color.indigo)

            VStack(alignment: .leading, spacing: 3) {
                Text(account.name)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(account.isArchived ? .secondary : .primary)

                if let card = account.cardNumber, !card.isEmpty {
                    Text(card)
                        .font(.caption2.monospacedDigit().weight(.regular))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(formatCurrency(account.turnoverLimitUAH) + " ₴")
                    .font(.subheadline.weight(.regular).monospacedDigit())
                    .foregroundStyle(.secondary)

                Text("monthly limit")
                    .font(.caption2.weight(.regular))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }

    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.0f", value)
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

    private var parsedLimit: Double {
        let cleaned = limitText.replacingOccurrences(of: ",", with: ".")
        return Double(cleaned) ?? 150_000.0
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && parsedLimit > 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Label("Title", systemImage: "building.columns.fill")
                            .font(.subheadline.weight(.regular))
                            .foregroundStyle(.indigo)
                            .frame(width: 100, alignment: .leading)

                        TextField("e.g. Mono Black (Main)", text: $name)
                            .font(.body.weight(.regular))
                    }

                    HStack {
                        Label("Card No.", systemImage: "creditcard")
                            .font(.subheadline.weight(.regular))
                            .foregroundStyle(.secondary)
                            .frame(width: 100, alignment: .leading)

                        TextField("Optional (e.g. •••• 1234)", text: $cardNumber)
                            .font(.body.monospacedDigit().weight(.regular))
                    }
                } header: {
                    Text("Account Details")
                } footer: {
                    Text("CVV and expiration date are never requested or stored for security and privacy.")
                }

                Section {
                    HStack {
                        Label("Limit (₴)", systemImage: "chart.line.uptrend.xyaxis")
                            .font(.subheadline.weight(.regular))
                            .foregroundStyle(.orange)
                            .frame(width: 100, alignment: .leading)

                        TextField("150000", text: $limitText)
                            .keyboardType(.numberPad)
                            .font(.body.monospacedDigit().weight(.regular))
                            .multilineTextAlignment(.trailing)
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach([50_000, 100_000, 150_000, 200_000, 250_000], id: \.self) { amount in
                                Button("\(amount / 1000)k ₴") {
                                    limitText = "\(amount)"
                                }
                                .font(.caption.weight(.medium))
                                .buttonStyle(.bordered)
                                .tint(.orange)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text("Turnover Limit (UAH)")
                } footer: {
                    Text("Monthly P2P turnover monitoring threshold for this specific bank or card.")
                }
            }
            .navigationTitle(editingAccount == nil ? "New Bank Account" : "Edit Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .disabled(!isValid)
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
            .alert("Error", isPresented: $showingErrorAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage ?? "An unknown error occurred.")
            }
        }
    }

    private func save() {
        guard isValid else { return }

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
}
