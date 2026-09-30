import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var synchronizationReadiness: CloudKitSynchronizationReadiness
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

    private var localStoreIsEmpty: Bool {
        orders.isEmpty
            && capitalSettingsList.isEmpty
            && allBankAccounts.isEmpty
            && allWithdrawals.isEmpty
    }

    var body: some View {
        NavigationStack {
            if synchronizationReadiness.shouldShowRestoring(localStoreIsEmpty: localStoreIsEmpty) {
                CloudKitRestoreView()
                    .navigationTitle("trades.title.spread_arbitrage")
                    .navigationBarTitleDisplayMode(.large)
            } else {
                List {
                Section {
                    PeriodPickerRow(
                        selectedPeriod: selectedPeriod,
                        onSelectPeriod: { selectedPeriod = $0 },
                        onRollover: { showingRolloverSheet = true }
                    )
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 8, trailing: 0))
                    .listRowBackground(Color.clear)
                }

                // Section 1: Dashboard overview
                Section {
                    SummaryMetricsView(
                        avgBuyPrice: avgBuyPrice,
                        totalPnL: totalPnL,
                        buyCount: buyOrdersCount,
                        sellCount: sellOrdersCount,
                        availableCapital: capitalBreakdown.freeUAH,
                        onTapManage: { showingCapitalSettingsSheet = true },
                        onTapCashOut: { showingWithdrawalsSheet = true }
                    )
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
                .listSectionSpacing(0)

                // Section 2: Bank Turnover & Financial Monitoring Limits
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
                        Spacer()
                        Button("common.action.see_all") {
                            showingBankAccountsSheet = true
                        }
                        .font(.caption.weight(.medium))
                        .textCase(nil)
                    }
                }

                // Section 3: Recent Transactions
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
            .contentMargins(.bottom, 56, for: .scrollContent)
            .navigationTitle("trades.title.spread_arbitrage")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
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
    let availableCapital: Double
    let onTapManage: () -> Void
    let onTapCashOut: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 1) {
                Text(pnlPrefix + HomeFormatters.uah(abs(totalPnL)))
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .foregroundStyle(pnlColor)
                Text("trades.stats.net_pnl")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(alignment: .firstTextBaseline) {
                Text("trades.section.available_capital")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(HomeFormatters.uah(availableCapital))
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                Menu {
                    Button("common.action.manage", action: onTapManage)
                    Button("trades.card.cash_out", action: onTapCashOut)
                } label: {
                    HStack(spacing: 3) {
                        Text("common.action.manage")
                        Image(systemName: "chevron.down")
                            .font(.caption2.weight(.semibold))
                    }
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.accentColor)
                }
            }

            Divider()

            HStack(alignment: .top, spacing: 0) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("trades.stats.avg_buy_price")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(avgBuyPrice > 0 ? HomeFormatters.rate(avgBuyPrice) + " ₴" : "—")
                        .font(.subheadline.weight(.medium).monospacedDigit())
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 3) {
                    Text("trades.stats.total_trades")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(buyCount + sellCount)")
                        .font(.subheadline.weight(.medium).monospacedDigit())
                    Text(LocalizationManager.shared.string("trades.stats.buy_sell_breakdown", buyCount, sellCount))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(ContainerRelativeShape())
        .padding(.horizontal, 4)
        .padding(.vertical, 4)
    }

    private var pnlColor: Color {
        if totalPnL > 0 {
            return .green
        } else if totalPnL < 0 {
            return .red
        } else {
            return .primary
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

}

private struct PeriodPickerRow: View {
    let selectedPeriod: String
    let onSelectPeriod: (String) -> Void
    let onRollover: () -> Void

    var body: some View {
        Menu {
            Section("common.label.calendar_month") {
                ForEach(periodOptions, id: \.self) { period in
                    Button {
                        onSelectPeriod(period)
                    } label: {
                        if period == selectedPeriod {
                            Label(PeriodRolloverService.formattedPeriodDisplay(period), systemImage: "checkmark")
                        } else {
                            Text(PeriodRolloverService.formattedPeriodDisplay(period))
                        }
                    }
                }
            }

            Section {
                Button {
                    onRollover()
                } label: {
                    Label("rollover.title.close_month", systemImage: "arrow.triangle.2.circlepath")
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(PeriodRolloverService.formattedPeriodDisplay(selectedPeriod))
                    .font(.subheadline)
                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.semibold))
            }
            .foregroundStyle(.secondary)
        }
        .accessibilityLabel(Text("common.label.calendar_month"))
    }

    private var periodOptions: [String] {
        let current = PeriodRolloverService.currentPeriodIdentifier()
        return [
            PeriodRolloverService.previousPeriodIdentifier(before: current),
            current,
            PeriodRolloverService.nextPeriodIdentifier(after: current)
        ]
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

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(HomeDisplayNames.bankAccount(stat.accountName))
                        .font(.subheadline.weight(.medium))

                    if let card = maskedCardNumber, !card.isEmpty {
                        Text(card)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Text(HomeFormatters.percent(stat.progress))
                    .font(.caption.weight(.medium).monospacedDigit())
                    .foregroundStyle(progressColor)
            }

            ProgressView(value: stat.progress)
                .tint(progressColor)

            HStack(alignment: .firstTextBaseline) {
                Text(HomeFormatters.uah(stat.totalSellUAH))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                Spacer()
                Text("/ " + HomeFormatters.uah(stat.turnoverLimitUAH))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }

    private var maskedCardNumber: String? {
        guard let card = stat.cardNumber, !card.isEmpty else { return nil }
        let digits = card.filter(\.isNumber)
        guard digits.count >= 4 else { return card }
        return "•••• " + digits.suffix(4)
    }

}

// MARK: - Order Row Component

private struct OrderRowView: View {
    let order: P2POrder

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(order.type.localizedTitle.uppercased())
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background((order.type == .buy ? Color.green : Color.blue).opacity(0.12))
                        .clipShape(Capsule())
                        .foregroundStyle(order.type == .buy ? Color.green : Color.blue)

                    let bankTitle = HomeDisplayNames.bankAccount(order.bankAccount?.name ?? order.bank.rawValue)
                    Text(verbatim: "\(order.platform.displayName) · \(bankTitle)")
                        .font(.subheadline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }

                Spacer(minLength: 8)

                Text(HomeFormatters.uah(order.uahAmount))
                    .font(.callout.weight(.medium).monospacedDigit())
            }

            HStack(alignment: .firstTextBaseline) {
                Text(HomeFormatters.usdt(order.usdtAmount) + " · " + HomeFormatters.rate(order.price) + " ₴")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                Spacer()
                Text(order.timestamp.formatted(date: .omitted, time: .shortened))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 3)
    }

}

enum HomeFormatters {
    static func uah(_ value: Double) -> String {
        decimal(value, minimumFractionDigits: 0, maximumFractionDigits: 2) + " ₴"
    }

    static func rate(_ value: Double) -> String {
        decimal(value, minimumFractionDigits: 2, maximumFractionDigits: 2)
    }

    static func usdt(_ value: Double) -> String {
        decimal(value, minimumFractionDigits: 2, maximumFractionDigits: 2) + " USDT"
    }

    static func percent(_ progress: Double) -> String {
        decimal(progress * 100, minimumFractionDigits: 1, maximumFractionDigits: 1) + "%"
    }

    private static func decimal(
        _ value: Double,
        minimumFractionDigits: Int,
        maximumFractionDigits: Int
    ) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: LocalizationManager.shared.currentLanguage.rawValue)
        formatter.minimumFractionDigits = minimumFractionDigits
        formatter.maximumFractionDigits = maximumFractionDigits
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }
}

enum HomeDisplayNames {
    static func bankAccount(_ name: String) -> String {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let openParen = trimmedName.firstIndex(of: "(") else { return trimmedName }

        let bank = trimmedName[..<openParen].trimmingCharacters(in: .whitespacesAndNewlines)
        let type = trimmedName[trimmedName.index(after: openParen)...]
            .trimmingCharacters(in: CharacterSet(charactersIn: ") "))
        guard !bank.isEmpty else { return trimmedName }
        return type.isEmpty ? bank : "\(bank) · \(type)"
    }
}
