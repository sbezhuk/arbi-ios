import Foundation
import SwiftData

/// Unit tests verifying the Home accounting optimization and bounded period data flow:
/// 1. Parity between legacy whole-history in-memory filtering and bounded PeriodAccountingService fetch
/// 2. Verification that multi-period database only fetches selected-period records
/// 3. Exact parity for avgBuyPrice, Gross PnL, total fees, Net PnL, remaining USDT, free UAH, counts, accountStats
/// 4. Real commission precision fixture (feeUSDT = 0.047755 and 0.04898)
/// 5. Reactivity updates on order insert, edit, delete, and period change
@MainActor
public enum HomeAccountingOptimizationTests {
    public static func runAllTests() throws {
        print("--- Running HomeAccountingOptimizationTests ---")
        try testBoundedPeriodFetchExcludesOtherPeriods()
        try testExactAccountingParityWithLegacyCalculator()
        try testRealCommissionPrecisionFixtureParity()
        try testRecentOrdersLimitedFetch()
        try testPeriodOrdersCountQuery()
        try testReactivityOnMutation()
        print("--- All HomeAccountingOptimizationTests Passed Successfully! ---")
    }

    private static func makeInMemoryContainer() throws -> ModelContainer {
        let schema = Schema([P2POrder.self, CapitalSettings.self, BankAccount.self, CashWithdrawal.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    private static func makeDate(year: Int, month: Int, day: Int, hour: Int = 12) -> Date {
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = day
        comps.hour = hour
        comps.minute = 0
        comps.second = 0
        return Calendar.current.date(from: comps) ?? Date()
    }

    // MARK: - 1. Bounded Period Fetch Excludes Other Periods

    public static func testBoundedPeriodFetchExcludesOtherPeriods() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        // Populate multiple historical months
        // July 2026: 10 orders
        for d in 1...10 {
            context.insert(P2POrder(type: .buy, usdtAmount: 100, price: 40.0, uahAmount: 4000, timestamp: makeDate(year: 2026, month: 7, day: d)))
        }
        // August 2026: 15 orders
        for d in 1...15 {
            context.insert(P2POrder(type: .sell, usdtAmount: 100, price: 40.5, uahAmount: 4050, timestamp: makeDate(year: 2026, month: 8, day: d)))
        }
        // September 2026: 20 orders
        for d in 1...20 {
            context.insert(P2POrder(type: .buy, usdtAmount: 100, price: 41.0, uahAmount: 4100, timestamp: makeDate(year: 2026, month: 9, day: d)))
        }
        // October 2026 (Selected period): 7 orders
        for d in 1...7 {
            context.insert(P2POrder(type: .buy, usdtAmount: 100, price: 41.5, uahAmount: 4150, timestamp: makeDate(year: 2026, month: 10, day: d)))
        }
        try context.save()

        // Total lifetime orders in DB = 52
        let allLifetimeCount = try context.fetchCount(FetchDescriptor<P2POrder>())
        assert(allLifetimeCount == 52, "Expected 52 total lifetime orders across all months")

        // October bounded fetch
        let octOrders = try PeriodAccountingService.fetchPeriodOrders(modelContext: context, periodIdentifier: "10.2026")
        assert(octOrders.count == 7, "October bounded fetch must return ONLY the 7 October orders, got \(octOrders.count)")

        for order in octOrders {
            assert(PeriodRolloverService.period(for: order.timestamp) == "10.2026", "Every fetched order must belong to 10.2026")
        }

        // September bounded fetch
        let septOrders = try PeriodAccountingService.fetchPeriodOrders(modelContext: context, periodIdentifier: "09.2026")
        assert(septOrders.count == 20, "September bounded fetch must return ONLY the 20 September orders")
    }

    // MARK: - 2. Exact Accounting Parity with Legacy Calculator

    public static func testExactAccountingParityWithLegacyCalculator() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let period = "10.2026"

        let bankA = BankAccount(name: "Mono (Black)", cardNumber: "1111", turnoverLimitUAH: 150_000)
        let bankB = BankAccount(name: "Privat (Gold)", cardNumber: "2222", turnoverLimitUAH: 100_000)
        context.insert(bankA)
        context.insert(bankB)

        let settings = CapitalSettings(
            startingDepositUAH: 100_000.0,
            toCashUAH: 5_000.0,
            initialUSDT: 500.0,
            initialAvgBuyPrice: 41.00,
            periodIdentifier: period
        )
        context.insert(settings)

        let withdrawal = CashWithdrawal(amountUAH: 10_000.0, periodIdentifier: period)
        context.insert(withdrawal)

        // Seed 12 orders in October
        let ordersData: [(TransactionType, Double, Double, Double, Double, BankAccount)] = [
            (.buy, 1000.0, 41.20, 41200.0, 0.07, bankA),
            (.buy, 500.0, 41.25, 20625.0, 0.05, bankB),
            (.sell, 600.0, 41.80, 25080.0, 0.06, bankA),
            (.sell, 400.0, 41.85, 16740.0, 0.04, bankB),
            (.buy, 800.0, 41.30, 33040.0, 0.08, bankA),
            (.sell, 500.0, 41.90, 20950.0, 0.05, bankA),
            (.sell, 300.0, 41.75, 12525.0, 0.03, bankB),
            (.buy, 200.0, 41.15, 8230.0, 0.02, bankA),
            (.sell, 400.0, 41.95, 16780.0, 0.04, bankB),
            (.buy, 300.0, 41.20, 12360.0, 0.03, bankA),
            (.sell, 200.0, 41.80, 8360.0, 0.02, bankA),
            (.sell, 100.0, 41.70, 4170.0, 0.01, bankB)
        ]

        var createdOrders: [P2POrder] = []
        for (i, row) in ordersData.enumerated() {
            let o = P2POrder(
                type: row.0,
                usdtAmount: row.1,
                price: row.2,
                uahAmount: row.3,
                feeUSDT: row.4,
                bankAccount: row.5,
                timestamp: makeDate(year: 2026, month: 10, day: (i % 25) + 1, hour: i)
            )
            context.insert(o)
            createdOrders.append(o)
        }
        try context.save()

        // 1. Legacy computation using all orders filtered by PeriodRolloverService
        let allOrdersFromDB = try context.fetch(FetchDescriptor<P2POrder>())
        let legacyPeriodOrders = PeriodRolloverService.ordersForPeriod(period, orders: allOrdersFromDB)
        let legacyAvgBuy = P2PCalculator.averageBuyPrice(orders: legacyPeriodOrders, settings: settings)
        let legacyGrossPnL = P2PCalculator.calculateGrossPnL(orders: legacyPeriodOrders, avgBuyPrice: legacyAvgBuy)
        let legacyTotalFees = P2PCalculator.calculateTotalFeesUAH(orders: legacyPeriodOrders)
        let legacyNetPnL = P2PCalculator.calculatePnL(orders: legacyPeriodOrders, avgBuyPrice: legacyAvgBuy)
        let legacyBreakdown = P2PCalculator.calculateCapitalBreakdown(
            orders: legacyPeriodOrders,
            settings: settings,
            withdrawals: [withdrawal]
        )
        let legacyAccountStats = P2PCalculator.accountTurnover(
            orders: legacyPeriodOrders,
            accounts: [bankA, bankB]
        )

        // 2. New bounded fetch and summary
        let summary = try PeriodAccountingService.fetchSummary(
            modelContext: context,
            periodIdentifier: period,
            settings: settings,
            withdrawals: [withdrawal],
            activeBankAccounts: [bankA, bankB]
        )

        // 3. Exact parity verification
        assert(summary.avgBuyPrice == legacyAvgBuy, "avgBuyPrice mismatch: \(summary.avgBuyPrice) vs \(legacyAvgBuy)")
        assert(summary.grossPnL == legacyGrossPnL, "grossPnL mismatch: \(summary.grossPnL) vs \(legacyGrossPnL)")
        assert(summary.totalFeesUAH == legacyTotalFees, "totalFeesUAH mismatch: \(summary.totalFeesUAH) vs \(legacyTotalFees)")
        assert(summary.netPnL == legacyNetPnL, "netPnL mismatch: \(summary.netPnL) vs \(legacyNetPnL)")
        assert(summary.buyOrdersCount == 5, "buyOrdersCount must be 5")
        assert(summary.sellOrdersCount == 7, "sellOrdersCount must be 7")
        assert(summary.availableCapital == legacyBreakdown.freeUAH, "availableCapital mismatch")
        assert(summary.capitalBreakdown.remainingUSDT == legacyBreakdown.remainingUSDT, "remainingUSDT mismatch")
        assert(summary.capitalBreakdown.freeUAH == legacyBreakdown.freeUAH, "freeUAH mismatch")
        assert(summary.capitalBreakdown.totalEquityUAH == legacyBreakdown.totalEquityUAH, "totalEquityUAH mismatch")
        assert(summary.accountStats == legacyAccountStats, "accountStats mismatch")
    }

    // MARK: - 3. Real Commission Precision Fixture Parity

    public static func testRealCommissionPrecisionFixtureParity() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let period = "10.2026"

        // Fixture with precise fee amounts
        let fee1 = 0.047755
        let fee2 = 0.04898

        let buy = P2POrder(
            type: .buy,
            usdtAmount: 1000.0,
            price: 41.00,
            uahAmount: 41000.0,
            feeUSDT: 0.0,
            timestamp: makeDate(year: 2026, month: 10, day: 1, hour: 10)
        )
        let sell1 = P2POrder(
            type: .sell,
            usdtAmount: 500.0,
            price: 41.50,
            uahAmount: 20750.0,
            feeUSDT: fee1,
            timestamp: makeDate(year: 2026, month: 10, day: 2, hour: 11)
        )
        let sell2 = P2POrder(
            type: .sell,
            usdtAmount: 500.0,
            price: 41.60,
            uahAmount: 20800.0,
            feeUSDT: fee2,
            timestamp: makeDate(year: 2026, month: 10, day: 3, hour: 12)
        )

        context.insert(buy)
        context.insert(sell1)
        context.insert(sell2)
        try context.save()

        let summary = try PeriodAccountingService.fetchSummary(
            modelContext: context,
            periodIdentifier: period,
            settings: nil,
            withdrawals: [],
            activeBankAccounts: []
        )

        // Expected fee = fee1 * 41.50 + fee2 * 41.60
        let expectedFeeUAH = (fee1 * 41.50) + (fee2 * 41.60)
        assert(abs(summary.totalFeesUAH - expectedFeeUAH) < 1e-9, "High precision fees must match exactly")

        // Expected Gross PnL: sell1 profit + sell2 profit
        // Avg buy price = 41.00
        let expectedGross = (500.0 * (41.50 - 41.00)) + (500.0 * (41.60 - 41.00))
        assert(abs(summary.grossPnL - expectedGross) < 1e-9, "Gross PnL must match")

        let expectedNet = expectedGross - expectedFeeUAH
        assert(abs(summary.netPnL - expectedNet) < 1e-9, "Net PnL with precise fees must match")
    }

    // MARK: - 4. Recent Orders Limited Fetch

    public static func testRecentOrdersLimitedFetch() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let period = "10.2026"

        for i in 1...20 {
            context.insert(P2POrder(
                type: .buy,
                usdtAmount: Double(i * 10),
                price: 41.0,
                uahAmount: Double(i * 410),
                timestamp: makeDate(year: 2026, month: 10, day: i)
            ))
        }
        try context.save()

        let recent = try PeriodAccountingService.fetchRecentOrders(modelContext: context, periodIdentifier: period, limit: 5)
        assert(recent.count == 5, "fetchRecentOrders with limit 5 must return strictly 5 items")

        // Verify newest first
        for i in 0..<(recent.count - 1) {
            assert(recent[i].timestamp >= recent[i + 1].timestamp, "Recent orders must be sorted newest first")
        }

        // Verify the newest order corresponds to day 20
        assert(Calendar.current.component(.day, from: recent.first!.timestamp) == 20, "First recent order must be day 20")
    }

    // MARK: - 5. Period Orders Count Query

    public static func testPeriodOrdersCountQuery() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        for i in 1...8 {
            context.insert(P2POrder(type: .buy, usdtAmount: 100, price: 41.0, uahAmount: 4100, timestamp: makeDate(year: 2026, month: 10, day: i)))
        }
        // Other month
        for i in 1...4 {
            context.insert(P2POrder(type: .buy, usdtAmount: 100, price: 41.0, uahAmount: 4100, timestamp: makeDate(year: 2026, month: 11, day: i)))
        }
        try context.save()

        let octCount = try PeriodAccountingService.fetchPeriodOrdersCount(modelContext: context, periodIdentifier: "10.2026")
        assert(octCount == 8, "October count query must return 8, got \(octCount)")

        let novCount = try PeriodAccountingService.fetchPeriodOrdersCount(modelContext: context, periodIdentifier: "11.2026")
        assert(novCount == 4, "November count query must return 4, got \(novCount)")

        let emptyCount = try PeriodAccountingService.fetchPeriodOrdersCount(modelContext: context, periodIdentifier: "01.2026")
        assert(emptyCount == 0, "Empty period count query must return 0")
    }

    // MARK: - 6. Reactivity on Mutation

    public static func testReactivityOnMutation() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let period = "10.2026"

        let order = P2POrder(type: .buy, usdtAmount: 1000.0, price: 41.00, uahAmount: 41000.0, timestamp: makeDate(year: 2026, month: 10, day: 5))
        context.insert(order)
        try context.save()

        var summary = try PeriodAccountingService.fetchSummary(modelContext: context, periodIdentifier: period, settings: nil, withdrawals: [], activeBankAccounts: [])
        assert(summary.buyOrdersCount == 1, "Initial count is 1")
        assert(summary.avgBuyPrice == 41.00, "Initial avgBuyPrice is 41.00")

        // Edit
        order.price = 42.00
        order.uahAmount = 42000.0
        try context.save()

        summary = try PeriodAccountingService.fetchSummary(modelContext: context, periodIdentifier: period, settings: nil, withdrawals: [], activeBankAccounts: [])
        assert(summary.avgBuyPrice == 42.00, "Edited avgBuyPrice must immediately reflect 42.00")

        // Delete
        context.delete(order)
        try context.save()

        summary = try PeriodAccountingService.fetchSummary(modelContext: context, periodIdentifier: period, settings: nil, withdrawals: [], activeBankAccounts: [])
        assert(summary.buyOrdersCount == 0, "After delete count must be 0")
        assert(summary.avgBuyPrice == 0.0, "After delete avgBuyPrice must be 0.0")
    }
}
