import Foundation

/// Pure statistics container representing a dynamic user-managed bank account turnover and limits.
public struct AccountTurnoverStat: Identifiable, Sendable, Equatable {
    public var id: UUID
    public let accountName: String
    public let cardNumber: String?
    public let turnoverLimitUAH: Double
    public let sellOrdersCount: Int
    public let totalSellUAH: Double

    public var progress: Double {
        guard turnoverLimitUAH > 0 else { return 0.0 }
        return min(totalSellUAH / turnoverLimitUAH, 1.0)
    }

    public init(
        id: UUID,
        accountName: String,
        cardNumber: String? = nil,
        turnoverLimitUAH: Double = 150_000.0,
        sellOrdersCount: Int,
        totalSellUAH: Double
    ) {
        self.id = id
        self.accountName = accountName
        self.cardNumber = cardNumber
        self.turnoverLimitUAH = turnoverLimitUAH
        self.sellOrdersCount = sellOrdersCount
        self.totalSellUAH = totalSellUAH
    }
}

/// Pure statistics container representing bank turnover and transaction count.
public struct BankTurnoverStat: Identifiable, Sendable, Equatable {
    public var id: BankType { bank }
    public let bank: BankType
    public let sellOrdersCount: Int
    public let totalSellUAH: Double

    public init(bank: BankType, sellOrdersCount: Int, totalSellUAH: Double) {
        self.bank = bank
        self.sellOrdersCount = sellOrdersCount
        self.totalSellUAH = totalSellUAH
    }
}

/// Comprehensive working capital breakdown for arbitrage operations.
public struct CapitalBreakdown: Sendable, Equatable {
    public let startingDepositUAH: Double
    public let toCashUAH: Double
    public let freeUAH: Double
    public let initialUSDT: Double
    public let initialAvgBuyPrice: Double
    public let remainingUSDT: Double
    public let usdtValueUAH: Double
    public let totalEquityUAH: Double
    public let netPnLUAH: Double

    public init(
        startingDepositUAH: Double,
        toCashUAH: Double,
        freeUAH: Double,
        initialUSDT: Double = 0.0,
        initialAvgBuyPrice: Double = 0.0,
        remainingUSDT: Double,
        usdtValueUAH: Double,
        totalEquityUAH: Double,
        netPnLUAH: Double
    ) {
        self.startingDepositUAH = startingDepositUAH
        self.toCashUAH = toCashUAH
        self.freeUAH = freeUAH
        self.initialUSDT = initialUSDT
        self.initialAvgBuyPrice = initialAvgBuyPrice
        self.remainingUSDT = remainingUSDT
        self.usdtValueUAH = usdtValueUAH
        self.totalEquityUAH = totalEquityUAH
        self.netPnLUAH = netPnLUAH
    }
}

/// Dedicated calculator engine for crypto P2P arbitrage math operations.
@MainActor
public struct P2PCalculator {
    private init() {}

    /// Calculates the weighted average buy price in UAH per 1 USDT across all buy orders,
    /// optionally factoring in initial USDT holdings and its acquisition rate from CapitalSettings.
    /// Formula: (initialUSDT * initialAvgBuyPrice + Sum(uahAmount [buy])) / (initialUSDT + Sum(usdtAmount [buy])).
    public static func averageBuyPrice(orders: [P2POrder], settings: CapitalSettings? = nil) -> Double {
        let buyOrders = orders.filter { $0.type == .buy }
        let ordersUAH = buyOrders.reduce(0.0) { $0 + $1.uahAmount }
        let ordersUSDT = buyOrders.reduce(0.0) { $0 + $1.usdtAmount }

        let initUSDT = settings?.initialUSDT ?? 0.0
        let initPrice = settings?.initialAvgBuyPrice ?? 0.0
        let initUAH = (initUSDT > 0 && initPrice > 0) ? (initUSDT * initPrice) : 0.0

        let totalUSDT = ordersUSDT + max(0.0, initUSDT)
        let totalUAH = ordersUAH + initUAH

        guard totalUSDT > 0 else { return 0.0 }
        return totalUAH / totalUSDT
    }

    /// Convenience overload computing weighted average buy price directly across buy orders.
    public static func averageBuyPrice(orders: [P2POrder]) -> Double {
        averageBuyPrice(orders: orders, settings: nil)
    }

    /// Calculates gross Profit & Loss in UAH from completed sell orders against the weighted cost basis.
    /// Realized trading profit is generated only by Sell transactions:
    /// Sum_Sell(usdtAmount * (price - avgBuyPrice))
    public static func calculateGrossPnL(orders: [P2POrder], avgBuyPrice: Double) -> Double {
        orders
            .filter { $0.type == .sell }
            .reduce(0.0) { $0 + ($1.usdtAmount * ($1.price - avgBuyPrice)) }
    }

    /// Convenience overload computing gross PnL directly using the orders' weighted average buy price.
    public static func calculateGrossPnL(orders: [P2POrder]) -> Double {
        let avgPrice = averageBuyPrice(orders: orders)
        return calculateGrossPnL(orders: orders, avgBuyPrice: avgPrice)
    }

    /// Calculates total commission expenses in UAH across all orders (both buy and sell),
    /// converting USDT fees at each transaction's execution exchange rate:
    /// Sum_All((feeUSDT + txFeeUSDT) * price)
    public static func calculateTotalFeesUAH(orders: [P2POrder]) -> Double {
        orders.reduce(0.0) { acc, order in
            acc + ((order.feeUSDT + order.txFeeUSDT) * order.price)
        }
    }

    /// Calculates net Profit & Loss in UAH.
    /// Formula:
    /// Net PnL = Gross PnL - Total Fees UAH
    /// where Total Fees UAH = Sum_All((feeUSDT + txFeeUSDT) * price)
    public static func calculatePnL(orders: [P2POrder], avgBuyPrice: Double) -> Double {
        let grossProfit = calculateGrossPnL(orders: orders, avgBuyPrice: avgBuyPrice)
        let totalFees = calculateTotalFeesUAH(orders: orders)
        return grossProfit - totalFees
    }

    /// Convenience overload computing net PnL directly using the orders' weighted average buy price.
    public static func calculatePnL(orders: [P2POrder]) -> Double {
        let avgPrice = averageBuyPrice(orders: orders)
        return calculatePnL(orders: orders, avgBuyPrice: avgPrice)
    }

    /// Returns turnover statistics for each user-defined BankAccount (only for `.sell` transactions).
    public static func accountTurnover(orders: [P2POrder], accounts: [BankAccount]) -> [AccountTurnoverStat] {
        let sellOrders = orders.filter { $0.type == .sell }
        let grouped = Dictionary(grouping: sellOrders, by: { $0.bankAccount?.id })

        let stats = accounts.map { account -> AccountTurnoverStat in
            let ordersForAccount = grouped[account.id] ?? []
            let total = ordersForAccount.reduce(0.0) { $0 + $1.uahAmount }
            return AccountTurnoverStat(
                id: account.id,
                accountName: account.name,
                cardNumber: account.cardNumber,
                turnoverLimitUAH: account.turnoverLimitUAH,
                sellOrdersCount: ordersForAccount.count,
                totalSellUAH: total
            )
        }

        return stats.sorted { $0.totalSellUAH > $1.totalSellUAH }
    }

    /// Returns turnover statistics per bank (only for `.sell` transactions).
    /// By default includes banks with at least one sell transaction, sorted descending by turnover.
    public static func bankTurnover(orders: [P2POrder], includeEmpty: Bool = false) -> [BankTurnoverStat] {
        let sellOrders = orders.filter { $0.type == .sell }
        let grouped = Dictionary(grouping: sellOrders, by: \.bank)

        let stats = BankType.allCases.compactMap { bank -> BankTurnoverStat? in
            let ordersForBank = grouped[bank] ?? []
            if ordersForBank.isEmpty && !includeEmpty {
                return nil
            }
            let total = ordersForBank.reduce(0.0) { $0 + $1.uahAmount }
            return BankTurnoverStat(
                bank: bank,
                sellOrdersCount: ordersForBank.count,
                totalSellUAH: total
            )
        }

        return stats.sorted { $0.totalSellUAH > $1.totalSellUAH }
    }

    /// Calculates available free cash (UAH), remaining USDT inventory, and total equity.
    /// Incorporates dynamic intermediate cash withdrawals alongside any manual settings toCashUAH.
    public static func calculateCapitalBreakdown(
        orders: [P2POrder],
        settings: CapitalSettings?,
        withdrawals: [CashWithdrawal] = []
    ) -> CapitalBreakdown {
        let starting = settings?.startingDepositUAH ?? 0.0
        let loggedCashOut = withdrawals.reduce(0.0) { $0 + $1.amountUAH }
        let toCash = (settings?.toCashUAH ?? 0.0) + loggedCashOut
        let initUSDT = max(0.0, settings?.initialUSDT ?? 0.0)
        let initAvgPrice = max(0.0, settings?.initialAvgBuyPrice ?? 0.0)

        let buyOrders = orders.filter { $0.type == .buy }
        let sellOrders = orders.filter { $0.type == .sell }

        let totalBuyUAH = buyOrders.reduce(0.0) { $0 + $1.uahAmount }
        let totalSellUAH = sellOrders.reduce(0.0) { $0 + $1.uahAmount }

        let totalBuyUSDT = buyOrders.reduce(0.0) { $0 + $1.usdtAmount }
        let totalSellUSDT = sellOrders.reduce(0.0) { $0 + $1.usdtAmount }
        let totalFeesUSDT = orders.reduce(0.0) { $0 + $1.feeUSDT + $1.txFeeUSDT }

        let remainingUSDT = max(0.0, initUSDT + totalBuyUSDT - totalSellUSDT - totalFeesUSDT)
        let avgPrice = averageBuyPrice(orders: orders, settings: settings)
        let usdtValueUAH = remainingUSDT * (avgPrice > 0 ? avgPrice : 0.0)

        // Free money in UAH currently on bank accounts / cards
        let freeUAH = starting - toCash + totalSellUAH - totalBuyUAH
        let totalEquity = freeUAH + usdtValueUAH
        let pnl = calculatePnL(orders: orders, avgBuyPrice: avgPrice)

        return CapitalBreakdown(
            startingDepositUAH: starting,
            toCashUAH: toCash,
            freeUAH: freeUAH,
            initialUSDT: initUSDT,
            initialAvgBuyPrice: initAvgPrice,
            remainingUSDT: remainingUSDT,
            usdtValueUAH: usdtValueUAH,
            totalEquityUAH: totalEquity,
            netPnLUAH: pnl
        )
    }
}
