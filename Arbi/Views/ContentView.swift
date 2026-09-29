import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \P2POrder.timestamp, order: .reverse) private var orders: [P2POrder]
    @Query private var capitalSettingsList: [CapitalSettings]

    @State private var showingAddOrderSheet: Bool = false
    @State private var showingCapitalSettingsSheet: Bool = false

    private var activeSettings: CapitalSettings? {
        capitalSettingsList.first(where: { $0.periodIdentifier == "global" })
    }

    private var capitalBreakdown: CapitalBreakdown {
        P2PCalculator.calculateCapitalBreakdown(
            orders: orders,
            settings: activeSettings
        )
    }

    private var buyOrdersCount: Int {
        orders.filter { $0.type == .buy }.count
    }

    private var sellOrdersCount: Int {
        orders.filter { $0.type == .sell }.count
    }

    private var avgBuyPrice: Double {
        P2PCalculator.averageBuyPrice(orders: orders)
    }

    private var totalPnL: Double {
        P2PCalculator.calculatePnL(orders: orders, avgBuyPrice: avgBuyPrice)
    }

    private var bankStats: [BankTurnoverStat] {
        P2PCalculator.bankTurnover(orders: orders)
    }

    var body: some View {
        NavigationStack {
            List {
                // Section 1: Free Money & Capital Card
                Section {
                    CapitalOverviewCard(
                        breakdown: capitalBreakdown,
                        onTapConfigure: {
                            showingCapitalSettingsSheet = true
                        }
                    )
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }

                // Section 2: Dashboard Overview Cards
                Section {
                    SummaryMetricsView(
                        avgBuyPrice: avgBuyPrice,
                        totalPnL: totalPnL,
                        buyCount: buyOrdersCount,
                        sellCount: sellOrdersCount
                    )
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }

                // Section 3: Bank Turnover & Financial Monitoring Limits
                Section("Bank Turnover Limits") {
                    if bankStats.isEmpty {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundStyle(.secondary)
                            Text("No sell orders recorded yet. Sells will populate turnover stats per bank.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    } else {
                        ForEach(bankStats) { stat in
                            BankTurnoverRow(stat: stat)
                        }
                    }
                }

                // Section 4: Recent Transactions
                Section("Recent Transactions (\(orders.count))") {
                    if orders.isEmpty {
                        ContentUnavailableView {
                            Label("No Transactions", systemImage: "arrow.triangle.swap")
                        } description: {
                            Text("Record your first USDT ↔ UAH trade using the button below.")
                        } actions: {
                            Button("Add Sample Trades") {
                                insertSampleData()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .padding(.vertical, 24)
                    } else {
                        ForEach(orders) { order in
                            OrderRowView(order: order)
                        }
                        .onDelete(perform: deleteOrders)
                    }
                }
            }
            .navigationTitle("Spred Arbitrage")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingCapitalSettingsSheet = true
                    } label: {
                        Label("Capital", systemImage: "banknote")
                    }
                    .accessibilityLabel("Manage Capital Settings")
                }

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddOrderSheet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                    }
                    .accessibilityLabel("Add New Trade")
                }
            }
            .sheet(isPresented: $showingAddOrderSheet) {
                AddOrderView()
            }
            .sheet(isPresented: $showingCapitalSettingsSheet) {
                CapitalSettingsView()
            }
            .overlay(alignment: .bottomTrailing) {
                // Floating Action Button for rapid single-handed input
                Button {
                    showingAddOrderSheet = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                            .fontWeight(.bold)
                        Text("New Order")
                            .fontWeight(.semibold)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                    .shadow(color: .black.opacity(0.18), radius: 8, x: 0, y: 4)
                }
                .padding(.trailing, 20)
                .padding(.bottom, 20)
            }
        }
    }

    private func deleteOrders(at offsets: IndexSet) {
        for index in offsets {
            let order = orders[index]
            modelContext.delete(order)
        }
    }

    private func insertSampleData() {
        let sample1 = P2POrder(
            type: .buy,
            usdtAmount: 1000.0,
            price: 41.20,
            uahAmount: 41200.0,
            feeUSDT: 0.07,
            txFeeUSDT: 0.0,
            platform: .binance,
            bank: .monoBank,
            timestamp: Date().addingTimeInterval(-3600 * 3),
            note: "Binance P2P Maker buy"
        )

        let sample2 = P2POrder(
            type: .sell,
            usdtAmount: 500.0,
            price: 41.65,
            uahAmount: 20825.0,
            feeUSDT: 0.07,
            txFeeUSDT: 0.0,
            platform: .binance,
            bank: .monoBank,
            timestamp: Date().addingTimeInterval(-3600 * 2),
            note: "MonoBank card payout"
        )

        let sample3 = P2POrder(
            type: .sell,
            usdtAmount: 500.0,
            price: 41.70,
            uahAmount: 20850.0,
            feeUSDT: 0.0,
            txFeeUSDT: 1.0,
            platform: .bybit,
            bank: .privatBank,
            timestamp: Date().addingTimeInterval(-3600 * 1),
            note: "Bybit P2P sell"
        )

        modelContext.insert(sample1)
        modelContext.insert(sample2)
        modelContext.insert(sample3)

        if activeSettings == nil {
            let defaultCapital = CapitalSettings(
                startingDepositUAH: 100_000.0,
                toCashUAH: 0.0,
                periodIdentifier: "global",
                lastUpdated: Date()
            )
            modelContext.insert(defaultCapital)
        }
    }
}

// MARK: - Capital Overview Card

private struct CapitalOverviewCard: View {
    let breakdown: CapitalBreakdown
    let onTapConfigure: () -> Void

    var body: some View {
        Button(action: onTapConfigure) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Free Money (Bank Cards)", systemImage: "wallet.pass.fill")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.green)

                    Spacer()

                    HStack(spacing: 4) {
                        Text("Configure")
                            .font(.caption2.weight(.medium))
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                    }
                    .foregroundStyle(.secondary)
                }

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(formatCurrency(breakdown.freeUAH))
                        .font(.system(size: 24, weight: .semibold, design: .rounded))
                        .foregroundStyle(breakdown.freeUAH >= 0 ? Color.primary : Color.red)

                    Text("₴")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }

                Divider()

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Starting Deposit")
                            .font(.caption2.weight(.regular))
                            .foregroundStyle(.secondary)
                        Text(formatCurrency(breakdown.startingDepositUAH) + " ₴")
                            .font(.caption.weight(.medium).monospacedDigit())
                    }

                    Spacer()

                    VStack(alignment: .center, spacing: 2) {
                        Text("Cash Out")
                            .font(.caption2.weight(.regular))
                            .foregroundStyle(.secondary)
                        Text(formatCurrency(breakdown.toCashUAH) + " ₴")
                            .font(.caption.weight(.medium).monospacedDigit())
                            .foregroundStyle(breakdown.toCashUAH > 0 ? Color.orange : Color.primary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("USDT Inventory")
                            .font(.caption2.weight(.regular))
                            .foregroundStyle(.secondary)
                        Text(String(format: "%.2f USDT", breakdown.remainingUSDT))
                            .font(.caption.weight(.medium).monospacedDigit())
                    }
                }
            }
            .padding(16)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 4)
        .padding(.top, 4)
    }

    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
    }
}

// MARK: - Summary Metrics Component

private struct SummaryMetricsView: View {
    let avgBuyPrice: Double
    let totalPnL: Double
    let buyCount: Int
    let sellCount: Int

    var body: some View {
        VStack(spacing: 12) {
            // Hero card: PnL
            VStack(spacing: 6) {
                Text("Total Net PnL")
                    .font(.subheadline.weight(.regular))
                    .foregroundStyle(.secondary)

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(pnlPrefix + formatCurrency(abs(totalPnL)))
                        .font(.system(size: 24, weight: .semibold, design: .rounded))
                        .foregroundStyle(pnlColor)

                    Text("UAH")
                        .font(.caption.weight(.regular))
                        .foregroundStyle(pnlColor.opacity(0.8))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(pnlColor.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(pnlColor.opacity(0.25), lineWidth: 1)
            )

            // Secondary metrics: Avg Buy Rate + Trade Count
            HStack(spacing: 12) {
                MetricTile(
                    title: "Avg Buy Price",
                    value: avgBuyPrice > 0 ? String(format: "%.2f ₴", avgBuyPrice) : "—",
                    subtitle: "per 1 USDT",
                    systemImage: "chart.line.uptrend.xyaxis",
                    accentColor: .blue
                )

                MetricTile(
                    title: "Total Trades",
                    value: "\(buyCount + sellCount)",
                    subtitle: "\(buyCount) Buy · \(sellCount) Sell",
                    systemImage: "arrow.left.arrow.right",
                    accentColor: .purple
                )
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 8)
    }

    private var pnlColor: Color {
        if totalPnL > 0 {
            return .green
        } else if totalPnL < 0 {
            return .red
        } else {
            return .secondary
        }
    }

    private var pnlPrefix: String {
        if totalPnL > 0 {
            return "+"
        } else if totalPnL < 0 {
            return "-"
        } else {
            return ""
        }
    }

    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
    }
}

private struct MetricTile: View {
    let title: String
    let value: String
    let subtitle: String
    let systemImage: String
    let accentColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: systemImage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(accentColor)
                Text(title)
                    .font(.caption.weight(.regular))
                    .foregroundStyle(.secondary)
                Spacer()
            }

            Text(value)
                .font(.callout.weight(.medium).monospacedDigit())

            Text(subtitle)
                .font(.caption2.weight(.regular))
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// MARK: - Bank Turnover Row Component

private struct BankTurnoverRow: View {
    let stat: BankTurnoverStat

    // Standard Ukrainian financial monitoring reference threshold (150,000 UAH/month)
    private let monitoringLimitUAH: Double = 150_000.0

    private var progress: Double {
        min(stat.totalSellUAH / monitoringLimitUAH, 1.0)
    }

    private var progressColor: Color {
        if progress >= 0.9 {
            return .red
        } else if progress >= 0.7 {
            return .orange
        } else {
            return .indigo
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "building.columns.fill")
                        .font(.caption)
                        .foregroundStyle(.indigo)
                    Text(stat.bank.rawValue)
                        .font(.subheadline.weight(.medium))
                }

                Spacer()

                Text(formatUAH(stat.totalSellUAH))
                    .font(.subheadline.weight(.regular).monospacedDigit())
            }

            ProgressView(value: progress)
                .tint(progressColor)

            HStack {
                Text("\(stat.sellOrdersCount) sell orders")
                    .font(.caption2.weight(.regular))
                    .foregroundStyle(.secondary)

                Spacer()

                Text(String(format: "%.1f%% of 150k limit", progress * 100))
                    .font(.caption2.weight(.regular))
                    .foregroundStyle(progressColor)
            }
        }
        .padding(.vertical, 4)
    }

    private func formatUAH(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        let formatted = formatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
        return "\(formatted) ₴"
    }
}

// MARK: - Order Row Component

private struct OrderRowView: View {
    let order: P2POrder

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                // Type badge
                Text(order.type.rawValue.uppercased())
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(order.type == .buy ? Color.green.opacity(0.15) : Color.blue.opacity(0.15))
                    .foregroundStyle(order.type == .buy ? Color.green : Color.blue)
                    .clipShape(Capsule())

                // Platform & Bank
                Text("\(order.platform.rawValue) · \(order.bank.rawValue)")
                    .font(.caption.weight(.regular))
                    .foregroundStyle(.secondary)

                Spacer()

                // Timestamp
                Text(order.timestamp.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2.weight(.regular))
                    .foregroundStyle(.tertiary)
            }

            // Main amounts
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(format: "%.2f USDT", order.usdtAmount))
                        .font(.subheadline.weight(.medium).monospacedDigit())

                    Text(String(format: "@ %.2f ₴", order.price))
                        .font(.caption.weight(.regular).monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(String(format: "%.2f ₴", order.uahAmount))
                        .font(.subheadline.weight(.medium).monospacedDigit())

                    if order.feeUSDT > 0 || order.txFeeUSDT > 0 {
                        let totalFee = order.feeUSDT + order.txFeeUSDT
                        Text(String(format: "Fee: %.3f USDT", totalFee))
                            .font(.caption2.weight(.regular).monospacedDigit())
                            .foregroundStyle(.orange)
                    }
                }
            }

            if let note = order.note, !note.isEmpty {
                Text(note)
                    .font(.caption.weight(.regular))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }
}
