import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \P2POrder.timestamp, order: .reverse) private var orders: [P2POrder]
    @Query private var capitalSettingsList: [CapitalSettings]
    @Query(sort: \BankAccount.createdAt, order: .forward) private var allBankAccounts: [BankAccount]

    @State private var showingAddOrderSheet: Bool = false
    @State private var showingCapitalSettingsSheet: Bool = false
    @State private var showingBankAccountsSheet: Bool = false

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
        P2PCalculator.averageBuyPrice(orders: orders, settings: activeSettings)
    }

    private var totalPnL: Double {
        P2PCalculator.calculatePnL(orders: orders, avgBuyPrice: avgBuyPrice)
    }

    private var activeBankAccounts: [BankAccount] {
        allBankAccounts.filter { !$0.isArchived }
    }

    private var accountStats: [AccountTurnoverStat] {
        P2PCalculator.accountTurnover(orders: orders, accounts: activeBankAccounts)
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
                Section {
                    if activeBankAccounts.isEmpty {
                        HStack {
                            Image(systemName: "creditcard")
                                .foregroundStyle(.secondary)
                            Text("No bank accounts added yet.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button("Add") {
                                showingBankAccountsSheet = true
                            }
                            .font(.footnote.weight(.medium))
                        }
                        .padding(.vertical, 2)
                    } else {
                        ForEach(accountStats) { stat in
                            AccountTurnoverRow(stat: stat)
                        }
                    }
                } header: {
                    HStack {
                        Text("Bank Turnover Limits")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Manage") {
                            showingBankAccountsSheet = true
                        }
                        .font(.caption.weight(.medium))
                        .textCase(nil)
                    }
                }

                // Section 4: Recent Transactions
                Section {
                    if orders.isEmpty {
                        ContentUnavailableView {
                            Label("No Transactions", systemImage: "arrow.triangle.swap")
                        } description: {
                            Text("Tap the + button in the toolbar to record your first trade.")
                        } actions: {
                            Button("Add Sample Trades") {
                                insertSampleData()
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding(.vertical, 12)
                    } else {
                        ForEach(orders) { order in
                            OrderRowView(order: order)
                        }
                        .onDelete(perform: deleteOrders)
                    }
                } header: {
                    Text("Recent Transactions (\(orders.count))")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .listSectionSpacing(8)
            .navigationTitle("Spred Arbitrage")
            .toolbar {
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
            .sheet(isPresented: $showingBankAccountsSheet) {
                BankAccountsView()
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
        var mono = allBankAccounts.first(where: { $0.name.contains("Mono") })
        if mono == nil {
            let newMono = BankAccount(name: "MonoBank (Black)", cardNumber: "4441 •••• 1234", turnoverLimitUAH: 150_000.0)
            modelContext.insert(newMono)
            mono = newMono
        }

        var privat = allBankAccounts.first(where: { $0.name.contains("Privat") })
        if privat == nil {
            let newPrivat = BankAccount(name: "PrivatBank (Gold)", cardNumber: "5168 •••• 9876", turnoverLimitUAH: 150_000.0)
            modelContext.insert(newPrivat)
            privat = newPrivat
        }

        let sample1 = P2POrder(
            type: .buy,
            usdtAmount: 1000.0,
            price: 41.20,
            uahAmount: 41200.0,
            feeUSDT: 0.07,
            txFeeUSDT: 0.0,
            platform: .binance,
            bank: .monoBank,
            bankAccount: mono,
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
            bankAccount: mono,
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
            bankAccount: privat,
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
                initialUSDT: 500.0,
                initialAvgBuyPrice: 41.10,
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
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Label("Free Money (Bank Cards)", systemImage: "wallet.pass.fill")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.green)

                    Spacer()

                    HStack(spacing: 3) {
                        Text("Configure")
                            .font(.caption2.weight(.medium))
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                    }
                    .foregroundStyle(.secondary)
                }

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(formatCurrency(breakdown.freeUAH))
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .foregroundStyle(breakdown.freeUAH >= 0 ? Color.primary : Color.red)

                    Text("₴")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }

                Divider()

                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Starting Deposit")
                            .font(.caption2.weight(.regular))
                            .foregroundStyle(.secondary)
                        Text(formatCurrency(breakdown.startingDepositUAH) + " ₴")
                            .font(.footnote.weight(.medium).monospacedDigit())
                    }

                    Spacer()

                    VStack(alignment: .center, spacing: 1) {
                        Text("Cash Out")
                            .font(.caption2.weight(.regular))
                            .foregroundStyle(.secondary)
                        Text(formatCurrency(breakdown.toCashUAH) + " ₴")
                            .font(.footnote.weight(.medium).monospacedDigit())
                            .foregroundStyle(breakdown.toCashUAH > 0 ? Color.orange : Color.primary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 1) {
                        Text("USDT Inventory")
                            .font(.caption2.weight(.regular))
                            .foregroundStyle(.secondary)
                        Text(String(format: "%.2f USDT", breakdown.remainingUSDT))
                            .font(.footnote.weight(.medium).monospacedDigit())
                    }
                }
            }
            .padding(10)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 4)
        .padding(.top, 2)
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
        VStack(spacing: 8) {
            // Hero card: PnL
            VStack(spacing: 4) {
                Text("Total Net PnL")
                    .font(.caption.weight(.regular))
                    .foregroundStyle(.secondary)

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(pnlPrefix + formatCurrency(abs(totalPnL)))
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .foregroundStyle(pnlColor)

                    Text("UAH")
                        .font(.caption2.weight(.regular))
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
            HStack(spacing: 8) {
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
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: systemImage)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(accentColor)
                Text(title)
                    .font(.caption2.weight(.regular))
                    .foregroundStyle(.secondary)
                Spacer()
            }

            Text(value)
                .font(.callout.weight(.medium).monospacedDigit())

            Text(subtitle)
                .font(.caption2.weight(.regular))
                .foregroundStyle(.secondary)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Account Turnover Row Component

private struct AccountTurnoverRow: View {
    let stat: AccountTurnoverStat

    private var progressColor: Color {
        if stat.progress >= 0.9 {
            return .red
        } else if stat.progress >= 0.7 {
            return .orange
        } else {
            return .indigo
        }
    }

    private var limitSummaryLabel: String {
        let limitString: String
        if stat.turnoverLimitUAH >= 1000 {
            limitString = "\(Int(stat.turnoverLimitUAH / 1000))k"
        } else {
            limitString = "\(Int(stat.turnoverLimitUAH)) ₴"
        }
        return String(format: "%.1f%% of %@ limit", stat.progress * 100, limitString)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "creditcard.fill")
                        .font(.caption2)
                        .foregroundStyle(.indigo)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(stat.accountName)
                            .font(.subheadline.weight(.medium))

                        if let card = stat.cardNumber, !card.isEmpty {
                            Text(card)
                                .font(.caption2.weight(.regular).monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Spacer()

                Text(formatUAH(stat.totalSellUAH))
                    .font(.subheadline.weight(.regular).monospacedDigit())
            }

            ProgressView(value: stat.progress)
                .tint(progressColor)

            HStack {
                Text("\(stat.sellOrdersCount) sell orders")
                    .font(.caption2.weight(.regular))
                    .foregroundStyle(.secondary)

                Spacer()

                Text(limitSummaryLabel)
                    .font(.caption2.weight(.regular))
                    .foregroundStyle(progressColor)
            }
        }
        .padding(.vertical, 2)
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
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .center) {
                // Type badge
                Text(order.type.rawValue.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(order.type == .buy ? Color.green.opacity(0.15) : Color.blue.opacity(0.15))
                    .foregroundStyle(order.type == .buy ? Color.green : Color.blue)
                    .clipShape(Capsule())

                // Platform & Bank Account
                let bankTitle = order.bankAccount?.name ?? order.bank.rawValue
                Text("\(order.platform.rawValue) · \(bankTitle)")
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
                VStack(alignment: .leading, spacing: 1) {
                    Text(String(format: "%.2f USDT", order.usdtAmount))
                        .font(.subheadline.weight(.medium).monospacedDigit())

                    Text(String(format: "@ %.2f ₴", order.price))
                        .font(.caption2.weight(.regular).monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 1) {
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
                    .font(.caption2.weight(.regular))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 1)
    }
}
