import Foundation
import SwiftData

/// Comprehensive accounting test suite verifying P2P commission handling and PnL calculations:
/// 1. Profitable trade without commission (Gross PnL == Net PnL)
/// 2. Profitable trade with commission on Sell (Net = Gross - SellFee)
/// 3. Profitable trade with commission on Buy (Net = Gross - BuyFee)
/// 4. Profitable trade with commission on both Buy & Sell (Net = Gross - BothFees)
/// 5. Zero commission leaves Net PnL unchanged
/// 6. Commission conversion rate uses transaction-specific execution price (feeUSDT * order.price)
/// 7. Materially large fee reducing profit and turning into net loss
/// 8. Double-counting prevention: invariants across avgBuyPrice, remainingUSDT, freeUAH, and calculatePnL
/// 9. Aggregate dashboard Net PnL across multiple orders, platforms, and banks
/// 10. Period rollover accounting invariant preservation with fees
@MainActor
public enum AccountingPnLTests {
    public static func runAllTests() throws {
        print("--- Running AccountingPnLTests ---")
        try testProfitableTradeWithoutCommission()
        try testProfitableTradeWithSellCommission()
        try testProfitableTradeWithBuyCommission()
        try testProfitableTradeWithBothBuyAndSellCommissions()
        try testZeroCommissionLeavesNetPnLUnchanged()
        try testCommissionConversionRateUsesTransactionPrice()
        try testLargeFeeMateriallyReducesProfitAndCausesNetLoss()
        try testPreventionOfDoubleFeeDeduction()
        try testAggregateDashboardPnL()
        try testPeriodRolloverAccountingInvariantsWithFees()
        try testRealAccountingFixtureRegression()
        try testCommissionInputAndPersistencePrecision()
        try testOrderRowCommissionFormatting()
        print("--- All AccountingPnLTests Passed Successfully! ---")
    }

    private static func makeInMemoryContainer() throws -> ModelContainer {
        let schema = Schema([P2POrder.self, CapitalSettings.self, BankAccount.self, CashWithdrawal.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    private static func makeDate(year: Int = 2026, month: Int = 9, day: Int = 15, hour: Int = 12) -> Date {
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = day
        comps.hour = hour
        return Calendar.current.date(from: comps) ?? Date()
    }

    // MARK: - 1. Profitable trade without commission

    public static func testProfitableTradeWithoutCommission() throws {
        // Buy 1000 USDT at 40.00 UAH = 40,000 UAH
        let buy = P2POrder(
            type: .buy,
            usdtAmount: 1000.0,
            price: 40.00,
            uahAmount: 40_000.0,
            feeUSDT: 0.0,
            txFeeUSDT: 0.0,
            timestamp: makeDate(day: 1)
        )
        // Sell 1000 USDT at 41.50 UAH = 41,500 UAH
        let sell = P2POrder(
            type: .sell,
            usdtAmount: 1000.0,
            price: 41.50,
            uahAmount: 41_500.0,
            feeUSDT: 0.0,
            txFeeUSDT: 0.0,
            timestamp: makeDate(day: 2)
        )
        let orders = [buy, sell]

        let avgPrice = P2PCalculator.averageBuyPrice(orders: orders)
        assert(abs(avgPrice - 40.00) < 0.0001, "Expected avgBuyPrice 40.00, got \(avgPrice)")

        let grossPnL = P2PCalculator.calculateGrossPnL(orders: orders, avgBuyPrice: avgPrice)
        let totalFees = P2PCalculator.calculateTotalFeesUAH(orders: orders)
        let netPnL = P2PCalculator.calculatePnL(orders: orders, avgBuyPrice: avgPrice)

        // Gross: 1000 * (41.50 - 40.00) = 1500 UAH
        assert(abs(grossPnL - 1500.0) < 0.0001, "Expected Gross PnL 1500.0, got \(grossPnL)")
        assert(abs(totalFees - 0.0) < 0.0001, "Expected Total Fees 0.0, got \(totalFees)")
        assert(abs(netPnL - 1500.0) < 0.0001, "Expected Net PnL 1500.0, got \(netPnL)")
        assert(abs(netPnL - grossPnL) < 0.0001, "Net PnL must equal Gross PnL when fees are zero")
        print("✓ testProfitableTradeWithoutCommission passed")
    }

    // MARK: - 2. Profitable trade with commission on Sell

    public static func testProfitableTradeWithSellCommission() throws {
        // Buy 1000 USDT at 40.00 UAH, 0 fee
        let buy = P2POrder(
            type: .buy,
            usdtAmount: 1000.0,
            price: 40.00,
            uahAmount: 40_000.0,
            feeUSDT: 0.0,
            timestamp: makeDate(day: 1)
        )
        // Sell 1000 USDT at 41.50 UAH, 2.0 USDT fee on sell
        let sell = P2POrder(
            type: .sell,
            usdtAmount: 1000.0,
            price: 41.50,
            uahAmount: 41_500.0,
            feeUSDT: 2.0, // 2.0 USDT * 41.50 = 83.00 UAH
            timestamp: makeDate(day: 2)
        )
        let orders = [buy, sell]

        let avgPrice = P2PCalculator.averageBuyPrice(orders: orders)
        let grossPnL = P2PCalculator.calculateGrossPnL(orders: orders, avgBuyPrice: avgPrice)
        let totalFees = P2PCalculator.calculateTotalFeesUAH(orders: orders)
        let netPnL = P2PCalculator.calculatePnL(orders: orders, avgBuyPrice: avgPrice)

        // Gross: 1500 UAH, Sell Fee: 83 UAH -> Net: 1417 UAH
        assert(abs(grossPnL - 1500.0) < 0.0001, "Expected Gross 1500.0, got \(grossPnL)")
        assert(abs(totalFees - 83.0) < 0.0001, "Expected Fees 83.0, got \(totalFees)")
        assert(abs(netPnL - 1417.0) < 0.0001, "Expected Net 1417.0, got \(netPnL)")
        assert(abs(netPnL - (grossPnL - totalFees)) < 0.0001, "Net PnL must equal Gross PnL - Total Fees")
        print("✓ testProfitableTradeWithSellCommission passed")
    }

    // MARK: - 3. Profitable trade with commission on Buy

    public static func testProfitableTradeWithBuyCommission() throws {
        // Buy 1000 USDT at 40.00 UAH, 2.0 USDT maker fee = 2.0 * 40.00 = 80.00 UAH
        let buy = P2POrder(
            type: .buy,
            usdtAmount: 1000.0,
            price: 40.00,
            uahAmount: 40_000.0,
            feeUSDT: 2.0,
            timestamp: makeDate(day: 1)
        )
        // Sell 1000 USDT at 41.50 UAH, 0 fee on sell
        let sell = P2POrder(
            type: .sell,
            usdtAmount: 1000.0,
            price: 41.50,
            uahAmount: 41_500.0,
            feeUSDT: 0.0,
            timestamp: makeDate(day: 2)
        )
        let orders = [buy, sell]

        let avgPrice = P2PCalculator.averageBuyPrice(orders: orders)
        let grossPnL = P2PCalculator.calculateGrossPnL(orders: orders, avgBuyPrice: avgPrice)
        let totalFees = P2PCalculator.calculateTotalFeesUAH(orders: orders)
        let netPnL = P2PCalculator.calculatePnL(orders: orders, avgBuyPrice: avgPrice)

        // Gross: 1500 UAH, Buy Fee: 80 UAH -> Net: 1420 UAH
        assert(abs(grossPnL - 1500.0) < 0.0001, "Expected Gross 1500.0, got \(grossPnL)")
        assert(abs(totalFees - 80.0) < 0.0001, "Expected Buy Fee 80.0, got \(totalFees)")
        assert(abs(netPnL - 1420.0) < 0.0001, "Expected Net 1420.0, got \(netPnL)")
        print("✓ testProfitableTradeWithBuyCommission passed")
    }

    // MARK: - 4. Profitable trade with commission on both Buy & Sell

    public static func testProfitableTradeWithBothBuyAndSellCommissions() throws {
        // Buy 1000 USDT at 40.00 UAH, fee: 2.0 USDT (= 80.00 UAH)
        let buy = P2POrder(
            type: .buy,
            usdtAmount: 1000.0,
            price: 40.00,
            uahAmount: 40_000.0,
            feeUSDT: 2.0,
            timestamp: makeDate(day: 1)
        )
        // Sell 1000 USDT at 41.50 UAH, fee: 2.0 USDT (= 83.00 UAH)
        let sell = P2POrder(
            type: .sell,
            usdtAmount: 1000.0,
            price: 41.50,
            uahAmount: 41_500.0,
            feeUSDT: 2.0,
            timestamp: makeDate(day: 2)
        )
        let orders = [buy, sell]

        let avgPrice = P2PCalculator.averageBuyPrice(orders: orders)
        let grossPnL = P2PCalculator.calculateGrossPnL(orders: orders, avgBuyPrice: avgPrice)
        let totalFees = P2PCalculator.calculateTotalFeesUAH(orders: orders)
        let netPnL = P2PCalculator.calculatePnL(orders: orders, avgBuyPrice: avgPrice)

        // Gross: 1500 UAH, Fees: 80 + 83 = 163 UAH -> Net: 1337 UAH
        assert(abs(grossPnL - 1500.0) < 0.0001, "Expected Gross 1500.0, got \(grossPnL)")
        assert(abs(totalFees - 163.0) < 0.0001, "Expected Total Fees 163.0, got \(totalFees)")
        assert(abs(netPnL - 1337.0) < 0.0001, "Expected Net 1337.0, got \(netPnL)")
        assert(abs(netPnL - (grossPnL - totalFees)) < 0.0001, "Net PnL must equal Gross PnL - Total Fees")
        print("✓ testProfitableTradeWithBothBuyAndSellCommissions passed")
    }

    // MARK: - 5. Zero commission leaves Net PnL unchanged

    public static func testZeroCommissionLeavesNetPnLUnchanged() throws {
        let buy = P2POrder(
            type: .buy,
            usdtAmount: 2500.0,
            price: 41.10,
            uahAmount: 102_750.0,
            feeUSDT: 0.0,
            txFeeUSDT: 0.0
        )
        let sell = P2POrder(
            type: .sell,
            usdtAmount: 2500.0,
            price: 41.60,
            uahAmount: 104_000.0,
            feeUSDT: 0.0,
            txFeeUSDT: 0.0
        )
        let orders = [buy, sell]

        let avgPrice = P2PCalculator.averageBuyPrice(orders: orders)
        let grossPnL = P2PCalculator.calculateGrossPnL(orders: orders, avgBuyPrice: avgPrice)
        let fees = P2PCalculator.calculateTotalFeesUAH(orders: orders)
        let netPnL = P2PCalculator.calculatePnL(orders: orders, avgBuyPrice: avgPrice)

        assert(fees == 0.0, "Fees must be exactly 0.0")
        assert(grossPnL == netPnL, "Gross PnL must equal Net PnL when fees are 0")
        assert(abs(netPnL - 1250.0) < 0.0001, "Expected 1250.0 UAH PnL")
        print("✓ testZeroCommissionLeavesNetPnLUnchanged passed")
    }

    // MARK: - 6. Commission conversion rate uses transaction price

    public static func testCommissionConversionRateUsesTransactionPrice() throws {
        // Buy order at 40.25 UAH with 1.5 USDT fee -> 1.5 * 40.25 = 60.375 UAH
        let buy = P2POrder(
            type: .buy,
            usdtAmount: 500.0,
            price: 40.25,
            uahAmount: 20_125.0,
            feeUSDT: 1.5,
            txFeeUSDT: 0.0
        )
        // Sell order at 41.80 UAH with 2.5 USDT fee and 0.5 USDT txFee -> (2.5 + 0.5) * 41.80 = 125.40 UAH
        let sell = P2POrder(
            type: .sell,
            usdtAmount: 500.0,
            price: 41.80,
            uahAmount: 20_900.0,
            feeUSDT: 2.5,
            txFeeUSDT: 0.5
        )
        let orders = [buy, sell]

        let expectedBuyFeeUAH = 1.5 * 40.25 // 60.375
        let expectedSellFeeUAH = 3.0 * 41.80 // 125.400
        let expectedTotalFees = expectedBuyFeeUAH + expectedSellFeeUAH // 185.775

        let actualTotalFees = P2PCalculator.calculateTotalFeesUAH(orders: orders)
        assert(abs(actualTotalFees - expectedTotalFees) < 0.0001, "Expected \(expectedTotalFees) fees, got \(actualTotalFees)")

        let avgPrice = P2PCalculator.averageBuyPrice(orders: orders)
        let grossPnL = P2PCalculator.calculateGrossPnL(orders: orders, avgBuyPrice: avgPrice)
        let netPnL = P2PCalculator.calculatePnL(orders: orders, avgBuyPrice: avgPrice)

        // Gross: 500 * (41.80 - 40.25) = 775.0 UAH
        // Net: 775.0 - 185.775 = 589.225 UAH
        assert(abs(grossPnL - 775.0) < 0.0001, "Expected Gross 775.0, got \(grossPnL)")
        assert(abs(netPnL - 589.225) < 0.0001, "Expected Net 589.225, got \(netPnL)")
        print("✓ testCommissionConversionRateUsesTransactionPrice passed")
    }

    // MARK: - 7. Materially large fee turning trade into net loss

    public static func testLargeFeeMateriallyReducesProfitAndCausesNetLoss() throws {
        // Buy 500 USDT at 41.00 UAH = 20,500 UAH
        let buy = P2POrder(
            type: .buy,
            usdtAmount: 500.0,
            price: 41.00,
            uahAmount: 20_500.0,
            feeUSDT: 0.0
        )
        // Sell 500 USDT at 41.20 UAH (tight spread): Gross profit = 500 * 0.20 = +100 UAH
        // Platform fee: 5.0 USDT at 41.20 = 206.00 UAH
        let sell = P2POrder(
            type: .sell,
            usdtAmount: 500.0,
            price: 41.20,
            uahAmount: 20_600.0,
            feeUSDT: 5.0
        )
        let orders = [buy, sell]

        let avgPrice = P2PCalculator.averageBuyPrice(orders: orders)
        let grossPnL = P2PCalculator.calculateGrossPnL(orders: orders, avgBuyPrice: avgPrice)
        let fees = P2PCalculator.calculateTotalFeesUAH(orders: orders)
        let netPnL = P2PCalculator.calculatePnL(orders: orders, avgBuyPrice: avgPrice)

        assert(abs(grossPnL - 100.0) < 0.0001, "Gross must be +100.0 UAH")
        assert(abs(fees - 206.0) < 0.0001, "Fees must be 206.0 UAH")
        assert(abs(netPnL - (-106.0)) < 0.0001, "Net PnL must be -106.0 UAH (net loss)")
        print("✓ testLargeFeeMateriallyReducesProfitAndCausesNetLoss passed")
    }

    // MARK: - 8. Prevention of double fee deduction & invariant verification

    public static func testPreventionOfDoubleFeeDeduction() throws {
        // Invariant:
        // 1. avgBuyPrice must NOT capitalize feeUSDT (stays unadjusted execution price)
        // 2. remainingUSDT deducts feeUSDT in crypto inventory
        // 3. freeUAH bank card cash balance is unaffected by crypto fee
        // 4. calculatePnL deducts total fees in UAH exactly once
        let settings = CapitalSettings(
            startingDepositUAH: 100_000.0,
            toCashUAH: 0.0,
            initialUSDT: 0.0,
            initialAvgBuyPrice: 0.0
        )

        let buy = P2POrder(
            type: .buy,
            usdtAmount: 1000.0,
            price: 40.00,
            uahAmount: 40_000.0,
            feeUSDT: 2.0 // 2 USDT fee paid in crypto
        )
        let sell = P2POrder(
            type: .sell,
            usdtAmount: 998.0,
            price: 42.00,
            uahAmount: 41_916.0,
            feeUSDT: 2.0 // 2 USDT fee paid in crypto
        )
        let orders = [buy, sell]

        // 1. avgBuyPrice check
        let avgPrice = P2PCalculator.averageBuyPrice(orders: orders, settings: settings)
        assert(abs(avgPrice - 40.00) < 0.0001, "avgBuyPrice must remain 40.00 and not be modified by fee")

        // 2. Breakdown calculation
        let breakdown = P2PCalculator.calculateCapitalBreakdown(orders: orders, settings: settings)

        // remainingUSDT = 0 + 1000 - 998 - (2 + 2) = 0 USDT (inventory clamped to 0)
        assert(abs(breakdown.remainingUSDT - 0.0) < 0.0001, "remainingUSDT must be 0.0")

        // freeUAH = starting (100,000) - toCash (0) + totalSell (41,916) - totalBuy (40,000) = 101,916 UAH
        assert(abs(breakdown.freeUAH - 101_916.0) < 0.0001, "freeUAH must be 101,916.0 UAH")

        // Gross PnL on sell = 998 * (42.00 - 40.00) = 1,996.00 UAH
        let grossPnL = P2PCalculator.calculateGrossPnL(orders: orders, avgBuyPrice: avgPrice)
        assert(abs(grossPnL - 1996.0) < 0.0001, "Gross PnL must be 1,996.0 UAH")

        // Total Fees = (2.0 * 40.00) + (2.0 * 42.00) = 80.00 + 84.00 = 164.00 UAH
        let totalFees = P2PCalculator.calculateTotalFeesUAH(orders: orders)
        assert(abs(totalFees - 164.0) < 0.0001, "Total fees must be 164.00 UAH")

        // Net PnL = 1996.0 - 164.0 = 1832.00 UAH
        assert(abs(breakdown.netPnLUAH - 1832.0) < 0.0001, "Net PnL must be 1,832.00 UAH, exactly once deducted")
        print("✓ testPreventionOfDoubleFeeDeduction passed")
    }

    // MARK: - 9. Aggregate dashboard Net PnL

    public static func testAggregateDashboardPnL() throws {
        // Multi-order trade period with mixed platforms, banks, and fee structures:
        let o1 = P2POrder(type: .buy, usdtAmount: 1000.0, price: 41.20, uahAmount: 41_200.0, feeUSDT: 1.0) // Fee: 41.20 UAH
        let o2 = P2POrder(type: .buy, usdtAmount: 1000.0, price: 41.40, uahAmount: 41_400.0, feeUSDT: 0.0) // Fee: 0 UAH
        // avgBuyPrice = (41200 + 41400) / 2000 = 82600 / 2000 = 41.30 UAH

        let o3 = P2POrder(type: .sell, usdtAmount: 1200.0, price: 41.80, uahAmount: 50_160.0, feeUSDT: 2.0) // Fee: 2 * 41.80 = 83.60 UAH
        let o4 = P2POrder(type: .sell, usdtAmount: 800.0, price: 42.00, uahAmount: 33_600.0, feeUSDT: 1.0, txFeeUSDT: 0.5) // Fee: 1.5 * 42.00 = 63.00 UAH

        let orders = [o1, o2, o3, o4]

        let avgPrice = P2PCalculator.averageBuyPrice(orders: orders)
        assert(abs(avgPrice - 41.30) < 0.0001, "Expected avgBuyPrice 41.30, got \(avgPrice)")

        // Gross PnL:
        // o3: 1200 * (41.80 - 41.30) = 1200 * 0.50 = 600.0 UAH
        // o4: 800 * (42.00 - 41.30) = 800 * 0.70 = 560.0 UAH
        // Total Gross = 1160.0 UAH
        let grossPnL = P2PCalculator.calculateGrossPnL(orders: orders, avgBuyPrice: avgPrice)
        assert(abs(grossPnL - 1160.0) < 0.0001, "Expected Gross 1160.0, got \(grossPnL)")

        // Fees:
        // o1: 41.20
        // o2: 0.00
        // o3: 83.60
        // o4: 63.00
        // Total Fees = 187.80 UAH
        let totalFees = P2PCalculator.calculateTotalFeesUAH(orders: orders)
        assert(abs(totalFees - 187.80) < 0.0001, "Expected Fees 187.80, got \(totalFees)")

        // Net PnL = 1160.0 - 187.80 = 972.20 UAH
        let netPnL = P2PCalculator.calculatePnL(orders: orders, avgBuyPrice: avgPrice)
        assert(abs(netPnL - 972.20) < 0.0001, "Expected Net 972.20, got \(netPnL)")
        print("✓ testAggregateDashboardPnL passed")
    }

    // MARK: - 10. Period rollover accounting invariant preservation with fees

    public static func testPeriodRolloverAccountingInvariantsWithFees() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)

        let closingMonth = "09.2026"
        let nextMonth = "10.2026"

        let septSettings = CapitalSettings(
            startingDepositUAH: 100_000.0,
            toCashUAH: 0.0,
            initialUSDT: 100.0,
            initialAvgBuyPrice: 41.00,
            periodIdentifier: closingMonth
        )
        context.insert(septSettings)

        // September trades with buy & sell fees:
        // Buy 1000 USDT at 41.50 UAH, fee = 1.0 USDT
        let buy = P2POrder(
            type: .buy,
            usdtAmount: 1000.0,
            price: 41.50,
            uahAmount: 41_500.0,
            feeUSDT: 1.0,
            timestamp: makeDate(day: 5)
        )
        // Sell 600 USDT at 42.20 UAH, fee = 2.0 USDT
        let sell = P2POrder(
            type: .sell,
            usdtAmount: 600.0,
            price: 42.20,
            uahAmount: 25_320.0,
            feeUSDT: 2.0,
            timestamp: makeDate(day: 20)
        )
        context.insert(buy)
        context.insert(sell)
        try context.save()

        let septOrders = [buy, sell]

        // Rollover to October
        let octSettings = try PeriodRolloverService.rolloverMonth(
            from: closingMonth,
            to: nextMonth,
            orders: septOrders,
            closingSettings: septSettings,
            reinvestProfit: true,
            cashOutAmount: 0.0,
            modelContext: context
        )

        // Invariant 1: Carry-over USDT inventory
        // Started 100 + bought 1000 - sold 600 - fees (1 + 2 = 3) = 497 USDT
        assert(abs(octSettings.initialUSDT - 497.0) < 0.001, "Expected 497.0 USDT carried over, got \(octSettings.initialUSDT)")

        // Invariant 2: Cost basis carry-over
        // Total USDT bought = 100 + 1000 = 1100
        // Total UAH = (100 * 41.00) + 41,500 = 4100 + 41500 = 45,600 UAH
        // Cost basis = 45600 / 1100 = 41.454545...
        let expectedCostBasis = 45_600.0 / 1100.0
        assert(abs(octSettings.initialAvgBuyPrice - expectedCostBasis) < 0.001, "Cost basis must be preserved")

        // Invariant 3: New period starting PnL must be 0
        let octOrders = PeriodRolloverService.ordersForPeriod(nextMonth, orders: septOrders)
        let octPnL = P2PCalculator.calculatePnL(orders: octOrders, avgBuyPrice: octSettings.initialAvgBuyPrice)
        assert(octPnL == 0.0, "New period PnL must reset to 0.0")

        // Invariant 4: Closing period Net PnL reflected fees:
        let closingAvgPrice = P2PCalculator.averageBuyPrice(orders: septOrders, settings: septSettings)
        let closingGross = P2PCalculator.calculateGrossPnL(orders: septOrders, avgBuyPrice: closingAvgPrice)
        let closingFees = P2PCalculator.calculateTotalFeesUAH(orders: septOrders)
        let closingNet = P2PCalculator.calculatePnL(orders: septOrders, avgBuyPrice: closingAvgPrice)

        // Gross: 600 * (42.20 - 41.454545) = 447.2727 UAH
        // Fees: (1.0 * 41.50) + (2.0 * 42.20) = 41.50 + 84.40 = 125.90 UAH
        // Net: 447.2727 - 125.90 = 321.3727 UAH
        assert(abs(closingGross - 447.2727) < 0.01, "Expected closing gross ~447.27")
        assert(abs(closingFees - 125.90) < 0.0001, "Expected closing fees 125.90")
        assert(abs(closingNet - (closingGross - closingFees)) < 0.0001, "Closing Net must equal Gross - Fees")
        print("✓ testPeriodRolloverAccountingInvariantsWithFees passed")
    }

    // MARK: - 11. Real accounting fixture regression test

    public static func testRealAccountingFixtureRegression() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let currentPeriod = "10.2026"

        // CapitalSettings providing current period cost basis = 45.08 UAH/USDT
        let settings = CapitalSettings(
            startingDepositUAH: 100_000.0,
            toCashUAH: 0.0,
            initialUSDT: 500.0,
            initialAvgBuyPrice: 45.08,
            periodIdentifier: currentPeriod
        )
        context.insert(settings)

        // Parse inputs via NumericInput to verify full precision survives text parsing
        let parsedFee1 = NumericInput(text: "0.047755").value!
        let parsedFee2 = NumericInput(text: "0.04898").value!
        assert(parsedFee1 == 0.047755, "Fee 1 must survive parsing with full precision")
        assert(parsedFee2 == 0.04898, "Fee 2 must survive parsing with full precision")

        // Sell #1: USDT: 3.97, price: 49.00, UAH settlement: 195.00, feeUSDT: 0.047755
        let sell1 = P2POrder(
            type: .sell,
            usdtAmount: 3.97,
            price: 49.00,
            uahAmount: 195.00,
            feeUSDT: parsedFee1,
            timestamp: makeDate(year: 2026, month: 10, day: 1)
        )
        // Sell #2: USDT: 4.08, price: 49.00, UAH settlement: 200.00, feeUSDT: 0.04898
        let sell2 = P2POrder(
            type: .sell,
            usdtAmount: 4.08,
            price: 49.00,
            uahAmount: 200.00,
            feeUSDT: parsedFee2,
            timestamp: makeDate(year: 2026, month: 10, day: 2)
        )
        context.insert(sell1)
        context.insert(sell2)
        try context.save()

        // 1. Fetch persisted orders from database
        let fetchedOrders = try context.fetch(FetchDescriptor<P2POrder>())
        assert(fetchedOrders.count == 2, "Both orders must be persisted in database")

        // 2. Verify period filtering includes both orders
        let periodOrders = PeriodRolloverService.ordersForPeriod(currentPeriod, orders: fetchedOrders)
        assert(periodOrders.count == 2, "Both orders must be included in periodOrders")

        // 3. Verify raw persisted fee values have full precision (neither is rounded to 0.05)
        let storedSell1 = periodOrders.first(where: { $0.usdtAmount == 3.97 })!
        let storedSell2 = periodOrders.first(where: { $0.usdtAmount == 4.08 })!
        assert(storedSell1.feeUSDT == 0.047755, "Stored feeUSDT for Sell #1 must retain full precision")
        assert(storedSell2.feeUSDT == 0.04898, "Stored feeUSDT for Sell #2 must retain full precision")

        // 4. Verify order.price values used by calculator
        assert(storedSell1.price == 49.00, "Stored price for Sell #1 must be 49.00")
        assert(storedSell2.price == 49.00, "Stored price for Sell #2 must be 49.00")

        // 5. Verify avgBuyPrice resolves exactly to 45.08
        let avgPrice = P2PCalculator.averageBuyPrice(orders: periodOrders, settings: settings)
        assert(abs(avgPrice - 45.08) < 0.0001, "Expected avgBuyPrice 45.08, got \(avgPrice)")

        // 6. Verify Gross PnL: (3.97 + 4.08) * (49.00 - 45.08) = 8.05 * 3.92 = 31.556 UAH
        let grossPnL = P2PCalculator.calculateGrossPnL(orders: periodOrders, avgBuyPrice: avgPrice)
        assert(abs(grossPnL - 31.556) < 0.000001, "Gross PnL must be exactly 31.556 UAH, got \(grossPnL)")

        // 7. Verify Total Fees: (0.047755 + 0.04898) * 49.00 = 4.740015 UAH
        let totalFees = P2PCalculator.calculateTotalFeesUAH(orders: periodOrders)
        assert(abs(totalFees - 4.740015) < 0.000001, "Total fees must be exactly 4.740015 UAH, got \(totalFees)")

        // 8. Verify Net PnL = Gross PnL - Total Fees = 31.556 - 4.740015 = 26.815985 UAH
        let netPnL = P2PCalculator.calculatePnL(orders: periodOrders, avgBuyPrice: avgPrice)
        assert(abs(netPnL - 26.815985) < 0.000001, "Net PnL must be exactly 26.815985 UAH, got \(netPnL)")

        // 9. Verify UI formatting displays 26.82 UAH
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.locale = Locale(identifier: "en_US_POSIX")
        let formattedString = formatter.string(from: NSNumber(value: netPnL)) ?? ""
        assert(formattedString == "26.82", "UI display format must be 26.82, got \(formattedString)")

        // 10. Root-cause diagnostic demonstration of the 29.20 discrepancy:
        // When Sell #2 fee is 0 (or missing) and Sell #1 fee is rounded to 3 decimal places (0.048):
        let fee1Rounded3Dec = Double(String(format: "%.3f", 0.047755))! // 0.048
        let discrepancyPnL = grossPnL - (fee1Rounded3Dec * 49.00) // 31.556 - 2.352 = 29.204
        let discrepancyFormatted = formatter.string(from: NSNumber(value: discrepancyPnL)) ?? ""
        assert(discrepancyFormatted == "29.20", "Demonstrates how missing Sell #2 fee + 3-dec rounded Sell #1 fee produces exactly 29.20")

        print("✓ testRealAccountingFixtureRegression passed")
    }

    // MARK: - 12. Commission input & persistence precision tests

    public static func testCommissionInputAndPersistencePrecision() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)

        // 1. 3.97 USDT with a preset producing a high-precision fee
        let usdt1 = 3.97
        let fee1Percent = FeePreset.onePercent.resolveFeeUSDT(usdtAmount: usdt1, customFeeText: "")
        assert(abs(fee1Percent - 0.0397) < 1e-9, "3.97 * 0.01 must be exactly 0.0397, got \(fee1Percent)")
        let feeDisplay = FeePreset.formatFeeForDisplay(fee1Percent)
        assert(feeDisplay == "0.0397", "Display format must be 0.0397, not rounded to 3 decimals (0.040), got \(feeDisplay)")

        let fee3Percent = FeePreset.threePercent.resolveFeeUSDT(usdtAmount: usdt1, customFeeText: "")
        assert(abs(fee3Percent - 0.1191) < 1e-9, "3.97 * 0.03 must be exactly 0.1191, got \(fee3Percent)")
        assert(FeePreset.formatFeeForDisplay(fee3Percent) == "0.1191", "Display format must be 0.1191")

        // 2. A fee such as 0.047755 survives the form → model path without becoming 0.048
        let inputFeeString = "0.047755"
        let customResolved = FeePreset.custom.resolveFeeUSDT(usdtAmount: 3.97, customFeeText: inputFeeString)
        assert(customResolved == 0.047755, "Custom resolved fee must equal exactly 0.047755, not 0.048")
        assert(customResolved != 0.048, "Fee must not have been rounded to 0.048")

        let orderWithCustomFee = P2POrder(
            type: .sell,
            usdtAmount: 3.97,
            price: 49.00,
            uahAmount: 195.00,
            feeUSDT: customResolved
        )
        context.insert(orderWithCustomFee)
        try context.save()
        assert(orderWithCustomFee.feeUSDT == 0.047755, "Persisted feeUSDT must be exactly 0.047755")

        // 3. Changing USDT after selecting a non-zero preset recalculates the correct raw fee
        var usdtAmount = 100.0
        let feeInitial = FeePreset.onePercent.resolveFeeUSDT(usdtAmount: usdtAmount, customFeeText: "")
        assert(feeInitial == 1.0, "Initial fee for 100 USDT at 1% must be 1.0")

        usdtAmount = 3.97
        let feeRecalculated = FeePreset.onePercent.resolveFeeUSDT(usdtAmount: usdtAmount, customFeeText: "")
        assert(abs(feeRecalculated - 0.0397) < 1e-9, "Recalculated fee after USDT change must be 0.0397")

        // 4. Save without expanding Commission still persists the correct selected preset fee
        let presetSelected = FeePreset.onePercent
        let feeFromUnopenedCommission = presetSelected.resolveFeeUSDT(usdtAmount: 250.0, customFeeText: "0.0")
        assert(feeFromUnopenedCommission == 2.5, "Save with 1% preset must produce 2.5 USDT even if custom feeText was '0.0'")
        let orderUnopened = P2POrder(
            type: .buy,
            usdtAmount: 250.0,
            price: 41.00,
            uahAmount: 10_250.0,
            feeUSDT: feeFromUnopenedCommission
        )
        context.insert(orderUnopened)
        try context.save()
        assert(orderUnopened.feeUSDT == 2.5, "Persisted order fee must be 2.5 USDT")

        // 5. Explicit 0% persists exactly zero (does not invent fees)
        let zeroFee = FeePreset.zeroPercent.resolveFeeUSDT(usdtAmount: 1000.0, customFeeText: "99.0")
        assert(zeroFee == 0.0, "Explicit 0% preset must resolve to exactly 0.0")
        let orderZero = P2POrder(
            type: .buy,
            usdtAmount: 1000.0,
            price: 41.00,
            uahAmount: 41_000.0,
            feeUSDT: zeroFee
        )
        context.insert(orderZero)
        try context.save()
        assert(orderZero.feeUSDT == 0.0, "Persisted fee for explicit 0% must be exactly 0.0")

        // 6. Custom fee preserves the user's entered precision (e.g. 8 decimals)
        let highPrecisionCustomText = "0.04775501"
        let highPrecisionFee = FeePreset.custom.resolveFeeUSDT(usdtAmount: 50.0, customFeeText: highPrecisionCustomText)
        assert(highPrecisionFee == 0.04775501, "Custom fee must preserve 8-decimal precision")
        let orderHighPrecision = P2POrder(
            type: .sell,
            usdtAmount: 50.0,
            price: 49.00,
            uahAmount: 2450.0,
            feeUSDT: highPrecisionFee
        )
        context.insert(orderHighPrecision)
        try context.save()
        assert(orderHighPrecision.feeUSDT == 0.04775501, "Persisted custom fee must preserve 8-decimal precision")

        // 7. Edit mode preserves an existing high-precision feeUSDT
        let existingFee = 0.04898
        let matchedPreset = FeePreset.matchingPreset(feeUSDT: existingFee, usdtAmount: 4.08)
        assert(matchedPreset == .custom, "Matching preset for non-standard fee must be .custom")
        let loadedText = FeePreset.formatFeeForDisplay(existingFee)
        assert(loadedText == "0.04898", "Loaded fee display text must be '0.04898'")
        let editedResolvedFee = matchedPreset.resolveFeeUSDT(usdtAmount: 4.08, customFeeText: loadedText)
        assert(editedResolvedFee == 0.04898, "Resolved fee in edit mode must preserve full precision")

        // 8. Switching preset → Custom → preset does not leave stale fee state
        var activePreset = FeePreset.onePercent
        var currentFeeText = FeePreset.formatFeeForDisplay(activePreset.resolveFeeUSDT(usdtAmount: 10.0, customFeeText: ""))
        assert(currentFeeText == "0.1", "1% of 10.0 USDT is 0.1")

        // User switches to custom and enters 5.0
        activePreset = .custom
        currentFeeText = "5.0"
        let customResolvedFee = activePreset.resolveFeeUSDT(usdtAmount: 10.0, customFeeText: currentFeeText)
        assert(customResolvedFee == 5.0, "Custom fee resolved to 5.0")

        // User switches back to 1% preset (with stale currentFeeText="5.0")
        activePreset = .onePercent
        let presetResolvedFee = activePreset.resolveFeeUSDT(usdtAmount: 10.0, customFeeText: currentFeeText)
        assert(presetResolvedFee == 0.1, "Preset must ignore stale custom feeText and calculate exact rate (0.1)")

        // User switches to 0% preset
        activePreset = .zeroPercent
        let zeroPresetResolvedFee = activePreset.resolveFeeUSDT(usdtAmount: 10.0, customFeeText: currentFeeText)
        assert(zeroPresetResolvedFee == 0.0, "Zero percent preset must resolve to 0.0 regardless of stale custom text")

        print("✓ testCommissionInputAndPersistencePrecision passed")
    }

    // MARK: - 13. OrderRowView / HomeFormatters commission formatting tests

    public static func testOrderRowCommissionFormatting() throws {
        let initialLang = LocalizationManager.shared.currentLanguage
        defer { LocalizationManager.shared.setLanguage(initialLang) }

        // 1. In English
        LocalizationManager.shared.setLanguage(.english)
        assert(HomeFormatters.commissionFee(0.047755) == "0.047755 USDT")
        assert(HomeFormatters.commissionLine(feeUSDT: 0.047755) == "Commission: 0.047755 USDT")

        assert(HomeFormatters.commissionFee(0.04898) == "0.04898 USDT")
        assert(HomeFormatters.commissionLine(feeUSDT: 0.04898) == "Commission: 0.04898 USDT")

        assert(HomeFormatters.commissionFee(0.05) == "0.05 USDT")
        assert(HomeFormatters.commissionLine(feeUSDT: 0.05) == "Commission: 0.05 USDT")

        assert(HomeFormatters.commissionFee(0.0) == "0 USDT")
        assert(HomeFormatters.commissionLine(feeUSDT: 0.0) == "Commission: 0 USDT")

        // 2. In Ukrainian
        LocalizationManager.shared.setLanguage(.ukrainian)
        assert(HomeFormatters.commissionFee(0.047755) == "0.047755 USDT")
        assert(HomeFormatters.commissionLine(feeUSDT: 0.047755) == "Комісія: 0.047755 USDT")

        assert(HomeFormatters.commissionFee(0.04898) == "0.04898 USDT")
        assert(HomeFormatters.commissionLine(feeUSDT: 0.04898) == "Комісія: 0.04898 USDT")

        assert(HomeFormatters.commissionFee(0.05) == "0.05 USDT")
        assert(HomeFormatters.commissionLine(feeUSDT: 0.05) == "Комісія: 0.05 USDT")

        assert(HomeFormatters.commissionFee(0.0) == "0 USDT")
        assert(HomeFormatters.commissionLine(feeUSDT: 0.0) == "Комісія: 0 USDT")

        // 3. Persisted P2POrder directly used by row display
        let sell1 = P2POrder(type: .sell, usdtAmount: 3.97, price: 49.00, uahAmount: 195.00, feeUSDT: 0.047755)
        let sell2 = P2POrder(type: .sell, usdtAmount: 4.08, price: 49.00, uahAmount: 200.00, feeUSDT: 0.04898)
        let zeroOrder = P2POrder(type: .buy, usdtAmount: 100.0, price: 41.00, uahAmount: 4100.0, feeUSDT: 0.0)

        LocalizationManager.shared.setLanguage(.english)
        assert(HomeFormatters.commissionLine(feeUSDT: sell1.feeUSDT) == "Commission: 0.047755 USDT")
        assert(HomeFormatters.commissionLine(feeUSDT: sell2.feeUSDT) == "Commission: 0.04898 USDT")
        assert(HomeFormatters.commissionLine(feeUSDT: zeroOrder.feeUSDT) == "Commission: 0 USDT")

        LocalizationManager.shared.setLanguage(.ukrainian)
        assert(HomeFormatters.commissionLine(feeUSDT: sell1.feeUSDT) == "Комісія: 0.047755 USDT")
        assert(HomeFormatters.commissionLine(feeUSDT: sell2.feeUSDT) == "Комісія: 0.04898 USDT")
        assert(HomeFormatters.commissionLine(feeUSDT: zeroOrder.feeUSDT) == "Комісія: 0 USDT")

        print("✓ testOrderRowCommissionFormatting passed")
    }
}

