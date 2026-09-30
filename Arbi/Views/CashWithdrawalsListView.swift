import SwiftUI
import SwiftData

/// View and management sheet for intermediate cash withdrawals in a specific period.
struct CashWithdrawalsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var periodIdentifier: String = PeriodRolloverService.currentPeriodIdentifier()

    @Query(sort: \CashWithdrawal.timestamp, order: .reverse)
    private var allWithdrawals: [CashWithdrawal]

    @State private var showingAddSheet: Bool = false

    private var periodWithdrawals: [CashWithdrawal] {
        PeriodRolloverService.withdrawalsForPeriod(periodIdentifier, withdrawals: allWithdrawals)
    }

    private var totalWithdrawn: Double {
        periodWithdrawals.reduce(0.0) { $0 + $1.amountUAH }
    }

    var body: some View {
        NavigationStack {
            List {
                // Section 1: Summary Card
                Section {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            Label("withdrawal.label.total_withdrawn", systemImage: "banknote.fill")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.orange)
                            Spacer()
                            Text(entryCountLabel)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(CashOutFormatters.uah(totalWithdrawn))
                                .font(.system(size: 28, weight: .semibold, design: .rounded))
                                .foregroundStyle(totalWithdrawn > 0 ? Color.orange : Color.primary)
                        }
                        .padding(.top, 8)

                        Text(formattedPeriodDisplay)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.top, 4)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .clipShape(ContainerRelativeShape())
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }

                // Section 2: Withdrawals List
                Section {
                    if periodWithdrawals.isEmpty {
                        VStack(spacing: 0) {
                            Image(systemName: "banknote")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                                .padding(.bottom, 6)

                            Text("withdrawal.empty.title")
                                .font(.subheadline.weight(.medium))
                                .padding(.bottom, 6)

                            Text(LocalizationManager.shared.string("withdrawal.empty.description", formattedPeriodDisplay))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                    } else {
                        ForEach(periodWithdrawals) { withdrawal in
                            CashWithdrawalRow(withdrawal: withdrawal)
                        }
                        .onDelete(perform: deleteWithdrawals)
                    }
                } header: {
                    if !periodWithdrawals.isEmpty {
                        Text("withdrawal.section.history")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .listSectionSpacing(12)
            .contentMargins(.top, SheetLayoutConstants.topContentMargin, for: .scrollContent)
            .navigationTitle("withdrawal.title.log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.action.done") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                            .fontWeight(.semibold)
                    }
                    .accessibilityLabel(Text("withdrawal.action.log_cash_out"))
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddCashWithdrawalView(initialPeriod: periodIdentifier)
            }
        }
    }

    private func deleteWithdrawals(at offsets: IndexSet) {
        for index in offsets {
            let item = periodWithdrawals[index]
            modelContext.delete(item)
        }
        try? modelContext.save()
    }

    private var formattedPeriodDisplay: String {
        PeriodRolloverService.formattedPeriodDisplay(
            periodIdentifier,
            locale: Locale(identifier: LocalizationManager.shared.currentLanguage.rawValue)
        )
    }

    private var entryCountLabel: String {
        let language = LocalizationManager.shared.currentLanguage
        let key: String
        switch language {
        case .english:
            key = periodWithdrawals.count == 1
                ? "withdrawal.label.entries_count.one"
                : "withdrawal.label.entries_count.many"
        case .ukrainian:
            let count = periodWithdrawals.count
            if count % 10 == 1 && count % 100 != 11 {
                key = "withdrawal.label.entries_count.one"
            } else if (2...4).contains(count % 10) && !(12...14).contains(count % 100) {
                key = "withdrawal.label.entries_count.few"
            } else {
                key = "withdrawal.label.entries_count.many"
            }
        }
        let template = LocalizationManager.shared[raw: key]
        return String(
            format: template,
            locale: Locale(identifier: language.rawValue),
            arguments: [periodWithdrawals.count]
        )
    }
}

// MARK: - Row Component

private struct CashWithdrawalRow: View {
    let withdrawal: CashWithdrawal

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "arrow.down.right.circle.fill")
                .font(.title2)
                .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(CashOutFormatters.uah(withdrawal.amountUAH))
                        .font(.body.weight(.semibold).monospacedDigit())
                        .foregroundStyle(Color.primary)

                    if let bank = withdrawal.bankAccount {
                        HStack(spacing: 3) {
                            Image(systemName: "creditcard.fill")
                                .font(.system(size: 9))
                            Text(bank.name)
                                .font(.caption2.weight(.medium))
                        }
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(uiColor: .tertiarySystemFill))
                        .clipShape(Capsule())
                    }
                }

                if let note = withdrawal.note, !note.isEmpty {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(formatDate(withdrawal.timestamp))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: LocalizationManager.shared.currentLanguage.rawValue)
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

private enum CashOutFormatters {
    static func uah(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: LocalizationManager.shared.currentLanguage.rawValue)
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        return (formatter.string(from: NSNumber(value: value)) ?? String(value)) + " ₴"
    }
}
