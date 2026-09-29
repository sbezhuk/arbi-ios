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
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Label("Total Withdrawn (\(periodIdentifier))", systemImage: "banknote.fill")
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(.orange)
                            Spacer()
                            Text("\(periodWithdrawals.count) entries")
                                .font(.caption2.weight(.regular))
                                .foregroundStyle(.secondary)
                        }

                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(formatCurrency(totalWithdrawn))
                                .font(.system(size: 26, weight: .bold, design: .rounded))
                                .foregroundStyle(totalWithdrawn > 0 ? Color.orange : Color.primary)

                            Text("₴")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }

                        Text("Total profit taken to physical cash or personal savings in \(PeriodRolloverService.formattedPeriodDisplay(periodIdentifier)).")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.top, 2)
                    }
                    .padding(10)
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }

                // Section 2: Withdrawals List
                Section {
                    if periodWithdrawals.isEmpty {
                        ContentUnavailableView {
                            Label("No Withdrawals", systemImage: "banknote")
                        } description: {
                            Text("No intermediate cash withdrawals recorded for \(PeriodRolloverService.formattedPeriodDisplay(periodIdentifier)).")
                        } actions: {
                            Button("Log Cash Out") {
                                showingAddSheet = true
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .padding(.vertical, 16)
                    } else {
                        ForEach(periodWithdrawals) { withdrawal in
                            CashWithdrawalRow(withdrawal: withdrawal)
                        }
                        .onDelete(perform: deleteWithdrawals)
                    }
                } header: {
                    if !periodWithdrawals.isEmpty {
                        Text("Withdrawal History")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .listSectionSpacing(8)
            .bottomScrollFade()
            .navigationTitle("Cash Out Log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
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
                    .accessibilityLabel("Log Cash Out")
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

    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = " "
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
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
                    Text(formatCurrency(withdrawal.amountUAH) + " ₴")
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

    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = " "
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
