import Foundation
import SwiftData

/// Immutable summary of all accounting metrics for a specific calendar period.
public struct PeriodAccountingSummary: Sendable, Equatable {
    public let avgBuyPrice: Double
    public let grossPnL: Double
    public let totalFeesUAH: Double
    public let netPnL: Double
    public let buyOrdersCount: Int
    public let sellOrdersCount: Int
    public let totalTradesCount: Int
    public let availableCapital: Double
    public let capitalBreakdown: CapitalBreakdown
    public let accountStats: [AccountTurnoverStat]

    public static let zero = PeriodAccountingSummary(
        avgBuyPrice: 0.0,
        grossPnL: 0.0,
        totalFeesUAH: 0.0,
        netPnL: 0.0,
        buyOrdersCount: 0,
        sellOrdersCount: 0,
        availableCapital: 0.0,
        capitalBreakdown: CapitalBreakdown(
            startingDepositUAH: 0.0,
            toCashUAH: 0.0,
            freeUAH: 0.0,
            initialUSDT: 0.0,
            initialAvgBuyPrice: 0.0,
            remainingUSDT: 0.0,
            usdtValueUAH: 0.0,
            totalEquityUAH: 0.0,
            netPnLUAH: 0.0
        ),
        accountStats: []
    )

    public init(
        avgBuyPrice: Double,
        grossPnL: Double,
        totalFeesUAH: Double,
        netPnL: Double,
        buyOrdersCount: Int,
        sellOrdersCount: Int,
        availableCapital: Double,
        capitalBreakdown: CapitalBreakdown,
        accountStats: [AccountTurnoverStat]
    ) {
        self.avgBuyPrice = avgBuyPrice
        self.grossPnL = grossPnL
        self.totalFeesUAH = totalFeesUAH
        self.netPnL = netPnL
        self.buyOrdersCount = buyOrdersCount
        self.sellOrdersCount = sellOrdersCount
        self.totalTradesCount = buyOrdersCount + sellOrdersCount
        self.availableCapital = availableCapital
        self.capitalBreakdown = capitalBreakdown
        self.accountStats = accountStats
    }
}

/// Dedicated accounting service providing bounded period queries and computing PeriodAccountingSummary
/// via the canonical P2PCalculator engine without loading unbounded lifetime history.
@MainActor
public struct PeriodAccountingService {
    private init() {}

    /// Fetches all P2POrders bounded strictly to the given period [startDate, endDate).
    public static func fetchPeriodOrders(
        modelContext: ModelContext,
        periodIdentifier: String
    ) throws -> [P2POrder] {
        let descriptor = FetchDescriptor<P2POrder>(
            predicate: TransactionsPaginationFetcher.predicate(for: periodIdentifier),
            sortBy: [
                SortDescriptor(\P2POrder.timestamp, order: .reverse),
                SortDescriptor(\P2POrder.id, order: .reverse)
            ]
        )
        return try modelContext.fetch(descriptor)
    }

    /// Fetches only the N newest P2POrders for the given period directly from SwiftData.
    public static func fetchRecentOrders(
        modelContext: ModelContext,
        periodIdentifier: String,
        limit: Int = 5
    ) throws -> [P2POrder] {
        var descriptor = FetchDescriptor<P2POrder>(
            predicate: TransactionsPaginationFetcher.predicate(for: periodIdentifier),
            sortBy: [
                SortDescriptor(\P2POrder.timestamp, order: .reverse),
                SortDescriptor(\P2POrder.id, order: .reverse)
            ]
        )
        descriptor.fetchLimit = limit
        return try modelContext.fetch(descriptor)
    }

    /// Fetches the count of transactions in the given period without materializing objects.
    public static func fetchPeriodOrdersCount(
        modelContext: ModelContext,
        periodIdentifier: String
    ) throws -> Int {
        let descriptor = FetchDescriptor<P2POrder>(
            predicate: TransactionsPaginationFetcher.predicate(for: periodIdentifier)
        )
        return try modelContext.fetchCount(descriptor)
    }

    /// Computes accounting summary from bounded period orders using the canonical P2PCalculator.
    public static func computeSummary(
        orders: [P2POrder],
        settings: CapitalSettings?,
        withdrawals: [CashWithdrawal],
        activeBankAccounts: [BankAccount]
    ) -> PeriodAccountingSummary {
        let breakdown = P2PCalculator.calculateCapitalBreakdown(
            orders: orders,
            settings: settings,
            withdrawals: withdrawals
        )
        let avgPrice = P2PCalculator.averageBuyPrice(orders: orders, settings: settings)
        let grossPnL = P2PCalculator.calculateGrossPnL(orders: orders, avgBuyPrice: avgPrice)
        let totalFees = P2PCalculator.calculateTotalFeesUAH(orders: orders)
        let netPnL = P2PCalculator.calculatePnL(orders: orders, avgBuyPrice: avgPrice)
        let buyCount = orders.filter { $0.type == .buy }.count
        let sellCount = orders.filter { $0.type == .sell }.count
        let accountStats = P2PCalculator.accountTurnover(orders: orders, accounts: activeBankAccounts)

        return PeriodAccountingSummary(
            avgBuyPrice: avgPrice,
            grossPnL: grossPnL,
            totalFeesUAH: totalFees,
            netPnL: netPnL,
            buyOrdersCount: buyCount,
            sellOrdersCount: sellCount,
            availableCapital: breakdown.freeUAH,
            capitalBreakdown: breakdown,
            accountStats: accountStats
        )
    }

    /// High-level method: fetches only the selected period orders and computes the summary.
    public static func fetchSummary(
        modelContext: ModelContext,
        periodIdentifier: String,
        settings: CapitalSettings?,
        withdrawals: [CashWithdrawal],
        activeBankAccounts: [BankAccount]
    ) throws -> PeriodAccountingSummary {
        let periodOrders = try fetchPeriodOrders(modelContext: modelContext, periodIdentifier: periodIdentifier)
        return computeSummary(
            orders: periodOrders,
            settings: settings,
            withdrawals: withdrawals,
            activeBankAccounts: activeBankAccounts
        )
    }
}
