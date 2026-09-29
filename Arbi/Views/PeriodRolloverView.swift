import SwiftUI
import SwiftData

/// Modal sheet for month-end rollover and automatic carry-over of liquid capital and inventory into the new period.
struct PeriodRolloverView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \P2POrder.timestamp, order: .forward) private var allOrders: [P2POrder]
    @Query private var allSettings: [CapitalSettings]
    @Query(sort: \CashWithdrawal.timestamp, order: .forward) private var allWithdrawals: [CashWithdrawal]

    var closingPeriod: String
    var nextPeriod: String
    var onRolloverComplete: ((String) -> Void)?

    @State private var errorMessage: String?
    @State private var showingErrorAlert: Bool = false

    init(
        closingPeriod: String? = nil,
        nextPeriod: String? = nil,
        onRolloverComplete: ((String) -> Void)? = nil
    ) {
        let closing = closingPeriod ?? PeriodRolloverService.currentPeriodIdentifier()
        self.closingPeriod = closing
        self.nextPeriod = nextPeriod ?? PeriodRolloverService.nextPeriodIdentifier(after: closing)
        self.onRolloverComplete = onRolloverComplete
    }

    private var closingSettings: CapitalSettings? {
        CapitalSettings.settings(for: closingPeriod, in: allSettings)
    }

    private var closingOrders: [P2POrder] {
        PeriodRolloverService.ordersForPeriod(closingPeriod, orders: allOrders)
    }

    private var closingWithdrawals: [CashWithdrawal] {
        PeriodRolloverService.withdrawalsForPeriod(closingPeriod, withdrawals: allWithdrawals)
    }

    private var closingBreakdown: CapitalBreakdown {
        P2PCalculator.calculateCapitalBreakdown(
            orders: closingOrders,
            settings: closingSettings,
            withdrawals: closingWithdrawals
        )
    }

    private var closingAvgBuyPrice: Double {
        closingBreakdown.remainingUSDT > 0
            ? P2PCalculator.averageBuyPrice(orders: closingOrders, settings: closingSettings)
            : 0.0
    }

    var body: some View {
        NavigationStack {
            Form {
                // Section 1: Period Transition Header
                Section {
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Current Period")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.secondary)
                            Text(closingPeriod)
                                .font(.headline.weight(.semibold).monospacedDigit())
                            Text(PeriodRolloverService.formattedPeriodDisplay(closingPeriod))
                                .font(.caption.weight(.regular))
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Image(systemName: "arrow.right.circle.fill")
                            .font(.title2)
                            .foregroundStyle(Color.accentColor)

                        Spacer()

                        VStack(alignment: .trailing, spacing: 3) {
                            Text("New Period")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.secondary)
                            Text(nextPeriod)
                                .font(.headline.weight(.semibold).monospacedDigit())
                            Text(PeriodRolloverService.formattedPeriodDisplay(nextPeriod))
                                .font(.caption.weight(.regular))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                } header: {
                    Text("rollover.section.transition")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                // Section 2: Carry-Over Balances Card
                Section {
                    HStack {
                        RolloverRowLabel(
                            title: "rollover.label.free_uah",
                            systemImage: "banknote.fill",
                            color: .indigo
                        )
                        Spacer()
                        Text(formatCurrency(closingBreakdown.freeUAH) + " ₴")
                            .font(.body.weight(.medium).monospacedDigit())
                            .foregroundStyle(closingBreakdown.freeUAH >= 0 ? Color.green : Color.red)
                    }
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))

                    HStack {
                        RolloverRowLabel(
                            title: "rollover.label.unliquidated_usdt",
                            systemImage: "dollarsign.circle.fill",
                            color: .teal
                        )
                        Spacer()
                        Text(String(format: "%.2f USDT", closingBreakdown.remainingUSDT))
                            .font(.body.weight(.medium).monospacedDigit())
                    }
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))

                    if closingBreakdown.remainingUSDT > 0 {
                        HStack {
                            RolloverRowLabel(
                                title: "rollover.label.weighted_cost",
                                systemImage: "scalemass.fill",
                                color: .secondary
                            )
                            Spacer()
                            Text(String(format: "%.2f ₴/USDT", closingAvgBuyPrice))
                                .font(.footnote.weight(.regular).monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    }

                    HStack {
                        RolloverRowLabel(
                            title: "rollover.label.net_pnl",
                            systemImage: "chart.line.uptrend.xyaxis",
                            color: .green
                        )
                        Spacer()
                        Text((closingBreakdown.netPnLUAH >= 0 ? "+" : "") + formatCurrency(closingBreakdown.netPnLUAH) + " ₴")
                            .font(.body.weight(.medium).monospacedDigit())
                            .foregroundStyle(closingBreakdown.netPnLUAH >= 0 ? Color.green : Color.red)
                    }
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                } header: {
                    Text("rollover.section.summary")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                } footer: {
                    Text("Remaining liquid UAH and crypto inventory will automatically become the starting capital for \(nextPeriod).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Section 3: Reset Notice Card
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "arrow.counterclockwise.circle.fill")
                                .font(.title3)
                                .frame(width: 22, alignment: .center)
                                .foregroundStyle(.blue)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Turnover Limits Reset")
                                    .font(.footnote.weight(.semibold))
                                Text("Bank card turnover limits reset to 0 ₴ for the new calendar month.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Divider()

                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "chart.line.uptrend.xyaxis.circle.fill")
                                .font(.title3)
                                .frame(width: 22, alignment: .center)
                                .foregroundStyle(.green)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Realized PnL Resets")
                                    .font(.footnote.weight(.semibold))
                                Text("Monthly profit counter resets to 0 ₴. Previous period performance remains saved in history.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                } header: {
                    Text("rollover.section.what_changes")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                // Section 4: Action Button
                Section {
                    Button {
                        performRollover()
                    } label: {
                        HStack {
                            Spacer()
                            Text("common.action.confirm")
                                .font(.body.weight(.semibold))
                            Spacer()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    .listRowBackground(Color.clear)
                }
                .padding(.bottom, 24)
            }
            .listSectionSpacing(.compact)
            .contentMargins(.bottom, 24, for: .scrollContent)
            .bottomScrollFade()
            .navigationTitle("rollover.title.close_month")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.action.cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("common.action.confirm") {
                        performRollover()
                    }
                    .fontWeight(.semibold)
                }
            }
            .alert("Error", isPresented: $showingErrorAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "An unknown error occurred.")
            }
        }
    }

    private func performRollover() {
        do {
            try PeriodRolloverService.rolloverMonth(
                from: closingPeriod,
                to: nextPeriod,
                orders: allOrders,
                withdrawals: allWithdrawals,
                closingSettings: closingSettings,
                reinvestProfit: true,
                cashOutAmount: 0.0,
                customStartingDeposit: nil,
                modelContext: modelContext
            )

            onRolloverComplete?(nextPeriod)
            dismiss()
        } catch {
            modelContext.rollback()
            errorMessage = error.localizedDescription
            showingErrorAlert = true
        }
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

// MARK: - Aligned Form Row Label Component

private struct RolloverRowLabel: View {
    let title: LocalizedStringKey
    let systemImage: String
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.subheadline)
                .frame(width: 22, alignment: .leading)
                .foregroundStyle(color)

            Text(title)
                .font(.subheadline.weight(.regular))
                .foregroundStyle(.primary)
        }
    }
}
