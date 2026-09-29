import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \P2POrder.timestamp, order: .reverse) private var orders: [P2POrder]
    @Query private var capitalSettingsList: [CapitalSettings]
    @Query(sort: \BankAccount.createdAt, order: .forward) private var allBankAccounts: [BankAccount]
    @Query(sort: \CashWithdrawal.timestamp, order: .reverse) private var allWithdrawals: [CashWithdrawal]

    @State private var selectedPeriod: String = PeriodRolloverService.currentPeriodIdentifier()
    @State private var showingAddOrderSheet: Bool = false
    @State private var showingCapitalSettingsSheet: Bool = false
    @State private var showingBankAccountsSheet: Bool = false
    @State private var showingRolloverSheet: Bool = false
    @State private var showingWithdrawalsSheet: Bool = false

    private var activeSettings: CapitalSettings? {
        CapitalSettings.settings(for: selectedPeriod, in: capitalSettingsList)
    }

    private var periodOrders: [P2POrder] {
        PeriodRolloverService.ordersForPeriod(selectedPeriod, orders: orders)
    }

    private var periodWithdrawals: [CashWithdrawal] {
        PeriodRolloverService.withdrawalsForPeriod(selectedPeriod, withdrawals: allWithdrawals)
    }

    private var capitalBreakdown: CapitalBreakdown {
        P2PCalculator.calculateCapitalBreakdown(
            orders: periodOrders,
            settings: activeSettings,
            withdrawals: periodWithdrawals
        )
    }

    private var buyOrdersCount: Int {
        periodOrders.filter { $0.type == .buy }.count
    }

    private var sellOrdersCount: Int {
        periodOrders.filter { $0.type == .sell }.count
    }

    private var avgBuyPrice: Double {
        P2PCalculator.averageBuyPrice(orders: periodOrders, settings: activeSettings)
    }

    private var totalPnL: Double {
        P2PCalculator.calculatePnL(orders: periodOrders, avgBuyPrice: avgBuyPrice)
    }

    private var activeBankAccounts: [BankAccount] {
        allBankAccounts.filter { !$0.isArchived }
    }

    private var accountStats: [AccountTurnoverStat] {
        P2PCalculator.accountTurnover(orders: periodOrders, accounts: activeBankAccounts)
    }

    var body: some View {
        NavigationStack {
            List {
                // Section 1: Free Money & Capital Card
                Section {
                    CapitalOverviewCard(
                        breakdown: capitalBreakdown,
                        period: selectedPeriod,
                        onTapConfigure: {
                            showingCapitalSettingsSheet = true
                        },
                        onTapRollover: {
                            showingRolloverSheet = true
                        },
                        onTapCashOut: {
                            showingWithdrawalsSheet = true
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
                .listSectionSpacing(0)

                // Section 3: Bank Turnover & Financial Monitoring Limits
                Section {
                    if activeBankAccounts.isEmpty {
                        HStack {
                            Image(systemName: "creditcard")
                                .foregroundStyle(.secondary)
                            Text("bank.empty.no_accounts")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button("common.action.add") {
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
                        Text("trades.section.bank_limits")
                        Text(verbatim: " (\(selectedPeriod))")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Spacer()
                            Button("common.action.manage") {
                            showingBankAccountsSheet = true
                        }
                        .font(.caption.weight(.medium))
                        .textCase(nil)
                    }
                }

                // Section 4: Recent Transactions
                Section {
                    if periodOrders.isEmpty {
                        ContentUnavailableView {
                            Label("trades.empty.no_transactions", systemImage: "arrow.triangle.swap")
                        } description: {
                            Text(LocalizationManager.shared.string("trades.empty.no_trades_in_period", PeriodRolloverService.formattedPeriodDisplay(selectedPeriod)))
                        } actions: {
                            Button("trades.empty.add_sample") {
                                insertSampleData()
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding(.vertical, 12)
                    } else {
                        ForEach(periodOrders) { order in
                            OrderRowView(order: order)
                        }
                        .onDelete(perform: deleteOrders)
                    }
                } header: {
                        Text("trades.section.recent_transactions")
                        Text(verbatim: " (\(periodOrders.count))")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .listSectionSpacing(8)
            .navigationTitle("trades.title.spread_arbitrage")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Section("common.label.calendar_month") {
                            Button {
                                selectedPeriod = PeriodRolloverService.currentPeriodIdentifier()
                            } label: {
                                let currentLabel = LocalizationManager.shared.string("trades.period.current", PeriodRolloverService.formattedPeriodDisplay(PeriodRolloverService.currentPeriodIdentifier()))
                                if selectedPeriod == PeriodRolloverService.currentPeriodIdentifier() {
                                    Label(currentLabel, systemImage: "checkmark")
                                } else {
                                    Text(currentLabel)
                                }
                            }

                            let prev = PeriodRolloverService.previousPeriodIdentifier(before: PeriodRolloverService.currentPeriodIdentifier())
                            Button {
                                selectedPeriod = prev
                            } label: {
                                if selectedPeriod == prev {
                                    Label(PeriodRolloverService.formattedPeriodDisplay(prev), systemImage: "checkmark")
                                } else {
                                    Text(PeriodRolloverService.formattedPeriodDisplay(prev))
                                }
                            }

                            let next = PeriodRolloverService.nextPeriodIdentifier(after: PeriodRolloverService.currentPeriodIdentifier())
                            Button {
                                selectedPeriod = next
                            } label: {
                                if selectedPeriod == next {
                                    Label(PeriodRolloverService.formattedPeriodDisplay(next), systemImage: "checkmark")
                                } else {
                                    Text(PeriodRolloverService.formattedPeriodDisplay(next))
                                }
                            }
                        }

                        Section {
                            Button {
                                showingRolloverSheet = true
                            } label: {
                                Label("rollover.title.close_month", systemImage: "arrow.triangle.2.circlepath")
                            }
                        }
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "calendar")
                            Text(selectedPeriod)
                                .font(.footnote.weight(.semibold).monospacedDigit())
                            Image(systemName: "chevron.down")
                                .font(.caption2.weight(.semibold))
                        }
                        .foregroundStyle(.primary)
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddOrderSheet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                    }
                    .accessibilityLabel(Text("trades.action.add_trade"))
                }
            }
            .sheet(isPresented: $showingAddOrderSheet) {
                AddOrderView()
            }
            .sheet(isPresented: $showingCapitalSettingsSheet) {
                CapitalSettingsView(periodIdentifier: selectedPeriod)
            }
            .sheet(isPresented: $showingBankAccountsSheet) {
                BankAccountsView()
            }
            .sheet(isPresented: $showingRolloverSheet) {
                PeriodRolloverView(closingPeriod: selectedPeriod) { newPeriod in
                    selectedPeriod = newPeriod
                }
            }
            .sheet(isPresented: $showingWithdrawalsSheet) {
                CashWithdrawalsListView(periodIdentifier: selectedPeriod)
            }
        }
    }

    private func deleteOrders(at offsets: IndexSet) {
        for index in offsets {
            let order = periodOrders[index]
            modelContext.delete(order)
        }
        try? modelContext.save()
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
    let period: String
    let onTapConfigure: () -> Void
    let onTapRollover: () -> Void
    let onTapCashOut: () -> Void

    var body: some View {
        Button(action: onTapConfigure) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Label("trades.card.free_money_bank_cards", systemImage: "wallet.pass.fill")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.green)

                    Spacer()

                    Button(action: onTapRollover) {
                        HStack(spacing: 3) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                            Text("trades.action.rollover")
                        }
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.12))
                        .clipShape(Capsule())
                    }

                    HStack(spacing: 3) {
                        Text("trades.action.configure")
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

                    Text(verbatim: "₴")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }

                Divider()

                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("trades.card.starting_deposit")
                            .font(.caption2.weight(.regular))
                            .foregroundStyle(.secondary)
                        Text(formatCurrency(breakdown.startingDepositUAH) + " ₴")
                            .font(.footnote.weight(.medium).monospacedDigit())
                    }

                    Spacer()

                    Button(action: onTapCashOut) {
                        VStack(alignment: .center, spacing: 1) {
                            HStack(spacing: 2) {
                                Text("trades.card.cash_out")
                                    .font(.caption2.weight(.regular))
                                    .foregroundStyle(.secondary)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 8))
                                    .foregroundStyle(.secondary)
                            }
                            Text(formatCurrency(breakdown.toCashUAH) + " ₴")
                                .font(.footnote.weight(.medium).monospacedDigit())
                                .foregroundStyle(breakdown.toCashUAH > 0 ? Color.orange : Color.primary)
                        }
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    VStack(alignment: .trailing, spacing: 1) {
                        Text("trades.card.usdt_inventory")
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
                Text("trades.stats.net_pnl")
                    .font(.caption.weight(.regular))
                    .foregroundStyle(.secondary)

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(pnlPrefix + formatCurrency(abs(totalPnL)))
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .foregroundStyle(pnlColor)

                    Text(verbatim: "UAH")
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
                    title: "trades.stats.avg_buy_price",
                    value: avgBuyPrice > 0 ? String(format: "%.2f ₴", avgBuyPrice) : "—",
                    subtitle: "common.label.per_usdt",
                    systemImage: "chart.line.uptrend.xyaxis",
                    accentColor: .blue
                )

                MetricTile(
                    title: "trades.stats.total_trades",
                    value: "\(buyCount + sellCount)",
                    subtitleText: LocalizationManager.shared.string("trades.stats.buy_sell_breakdown", buyCount, sellCount),
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
    let title: LocalizedStringKey
    let value: String
    let subtitleKey: LocalizedStringKey?
    let subtitleText: String?
    let systemImage: String
    let accentColor: Color

    init(
        title: LocalizedStringKey,
        value: String,
        subtitle: LocalizedStringKey,
        systemImage: String,
        accentColor: Color
    ) {
        self.title = title
        self.value = value
        self.subtitleKey = subtitle
        self.subtitleText = nil
        self.systemImage = systemImage
        self.accentColor = accentColor
    }

    init(
        title: LocalizedStringKey,
        value: String,
        subtitleText: String,
        systemImage: String,
        accentColor: Color
    ) {
        self.title = title
        self.value = value
        self.subtitleKey = nil
        self.subtitleText = subtitleText
        self.systemImage = systemImage
        self.accentColor = accentColor
    }

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

            if let subtitleKey {
                Text(subtitleKey)
                    .font(.caption2.weight(.regular))
                    .foregroundStyle(.secondary)
            } else if let subtitleText {
                Text(verbatim: subtitleText)
                    .font(.caption2.weight(.regular))
                    .foregroundStyle(.secondary)
            }
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
        return LocalizationManager.shared.string("trades.limits.progress_summary", stat.progress * 100, limitString)
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
                Text(LocalizationManager.shared.string("trades.limits.sell_orders_count", stat.sellOrdersCount))
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
                Group {
                    switch order.type {
                    case .buy:
                        Text("order.type.buy")
                    case .sell:
                        Text("order.type.sell")
                    }
                }
                .textCase(.uppercase)
                .font(.system(size: 10, weight: .bold))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(order.type == .buy ? Color.green.opacity(0.15) : Color.blue.opacity(0.15))
                .foregroundStyle(order.type == .buy ? Color.green : Color.blue)
                .clipShape(Capsule())

                // Platform & Bank Account
                let bankTitle = order.bankAccount?.name ?? order.bank.rawValue
                Text(verbatim: "\(order.platform.displayName) · \(bankTitle)")
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
                        Text(LocalizationManager.shared.string("order.label.fee_amount", totalFee))
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
