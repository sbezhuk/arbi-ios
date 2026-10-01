import Foundation
import SwiftData

/// Focused unit tests verifying Month Roll-over & Period Closing:
/// 1. Bank turnover resets to 0 in new period
/// 2. Realized PnL resets to 0 in new period
/// 3. Crypto inventory & weighted purchase cost basis carry over accurately
/// 4. Profit reinvestment vs Cash-out calculations
/// 5. Custom starting deposit
/// 6. Idempotency & update behavior
@MainActor
public enum PeriodRolloverTests {
    public static func runAllTests() throws {
        print("--- Running PeriodRolloverTests ---")
        try testPeriodFormattingAndNavigation()
        try testInventoryAndCostBasisCarryOver()
        try testTurnoverAndPnLResetInNewPeriod()
        try testProfitReinvestmentVsCashOut()
        try testCustomStartingDeposit()
        try testIdempotentRolloverUpdate()
        print("--- All PeriodRolloverTests Passed Successfully! ---")
    }

    private static func makeInMemoryContainer() throws -> ModelContainer {
        let schema = Schema([P2POrder.self, CapitalSettings.self, BankAccount.self, CashWithdrawal.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    private static func makeDate(year: Int, month: Int, day: Int) -> Date {
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = day
        comps.hour = 12
        return Calendar.current.date(from: comps) ?? Date()
    }

    /// Tests period string parsing, formatting, and increment/decrement helpers
    public static func testPeriodFormattingAndNavigation() throws {
        let dateSept = makeDate(year: 2026, month: 9, day: 15)
        let septPeriod = PeriodRolloverService.period(for: dateSept)
        assert(septPeriod == "09.2026", "Expected 09.2026, got \(septPeriod)")

        let nextFromSept = PeriodRolloverService.nextPeriodIdentifier(after: "09.2026")
        assert(nextFromSept == "10.2026", "Expected 10.2026, got \(nextFromSept)")

        let nextFromDec = PeriodRolloverService.nextPeriodIdentifier(after: "12.2026")
        assert(nextFromDec == "01.2027", "Expected 01.2027, got \(nextFromDec)")

        let prevFromJan = PeriodRolloverService.previousPeriodIdentifier(before: "01.2027")
        assert(prevFromJan == "12.2026", "Expected 12.2026, got \(prevFromJan)")

        let prevFromOct = PeriodRolloverService.previousPeriodIdentifier(before: "10.2026")
        assert(prevFromOct == "09.2026", "Expected 09.2026, got \(prevFromOct)")

        let display = PeriodRolloverService.formattedPeriodDisplay("09.2026")
        assert(display == "September 2026" || display == "Вересень 2026", "Expected September 2026 or Вересень 2026, got \(display)")
        print("✓ testPeriodFormattingAndNavigation passed")
    }

    /// Tests that unliquidated USDT and weighted cost basis carry over accurately into the new month
    public static func testInventoryAndCostBasisCarryOver() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)

        let sept = "09.2026"
        let oct = "10.2026"

        // September Settings: Starting 100,000 UAH
        let septSettings = CapitalSettings(
            startingDepositUAH: 100_000.0,
            toCashUAH: 0.0,
            initialUSDT: 200.0,
            initialAvgBuyPrice: 41.00,
            periodIdentifier: sept
        )
        context.insert(septSettings)

        // September Orders:
        // Buy 1000 USDT at 41.50 UAH = 41,500 UAH
        let buyOrder = P2POrder(
            type: .buy,
            usdtAmount: 1000.0,
            price: 41.50,
            uahAmount: 41500.0,
            feeUSDT: 0.0,
            platform: .binance,
            bank: .monoBank,
            timestamp: makeDate(year: 2026, month: 9, day: 5)
        )
        // Sell 500 USDT at 42.00 UAH = 21,000 UAH
        let sellOrder = P2POrder(
            type: .sell,
            usdtAmount: 500.0,
            price: 42.00,
            uahAmount: 21000.0,
            feeUSDT: 0.0,
            platform: .binance,
            bank: .monoBank,
            timestamp: makeDate(year: 2026, month: 9, day: 10)
        )
        context.insert(buyOrder)
        context.insert(sellOrder)
        try context.save()

        let allOrders = [buyOrder, sellOrder]

        // Roll over from 09.2026 to 10.2026
        let octSettings = try PeriodRolloverService.rolloverMonth(
            from: sept,
            to: oct,
            orders: allOrders,
            closingSettings: septSettings,
            reinvestProfit: true,
            cashOutAmount: 0.0,
            modelContext: context
        )

        // Inventory check:
        // Started with 200 USDT + bought 1000 USDT - sold 500 USDT = 700 USDT remaining
        assert(abs(octSettings.initialUSDT - 700.0) < 0.001, "Expected 700.0 remaining USDT, got \(octSettings.initialUSDT)")

        // Weighted acquisition price check:
        // (200 * 41.00 + 1000 * 41.50) / 1200 = (8200 + 41500) / 1200 = 49700 / 1200 = 41.4167
        let expectedAvgPrice = 49700.0 / 1200.0
        assert(abs(octSettings.initialAvgBuyPrice - expectedAvgPrice) < 0.001, "Expected \(expectedAvgPrice) cost basis, got \(octSettings.initialAvgBuyPrice)")

        assert(octSettings.periodIdentifier == oct, "Expected periodIdentifier == \(oct)")
        assert(octSettings.toCashUAH == 0.0, "toCashUAH must reset to 0 in new period")
        print("✓ testInventoryAndCostBasisCarryOver passed")
    }

    /// Tests that in the new month:
    /// - Bank turnover starts at 0 ₴ (financial monitoring reset)
    /// - Realized PnL starts at 0 ₴
    public static func testTurnoverAndPnLResetInNewPeriod() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)

        let sept = "09.2026"
        let oct = "10.2026"

        let mono = BankAccount(name: "MonoBank (Black)", turnoverLimitUAH: 150_000.0)
        context.insert(mono)

        let septSettings = CapitalSettings(
            startingDepositUAH: 50_000.0,
            periodIdentifier: sept
        )
        context.insert(septSettings)

        // September sell order of 30,000 UAH
        let septSell = P2POrder(
            type: .sell,
            usdtAmount: 700.0,
            price: 42.857,
            uahAmount: 30_000.0,
            platform: .binance,
            bank: .monoBank,
            bankAccount: mono,
            timestamp: makeDate(year: 2026, month: 9, day: 20)
        )
        context.insert(septSell)
        try context.save()

        let allOrders = [septSell]

        // Rollover to October
        let octSettings = try PeriodRolloverService.rolloverMonth(
            from: sept,
            to: oct,
            orders: allOrders,
            closingSettings: septSettings,
            reinvestProfit: true,
            modelContext: context
        )

        // Verify October orders are empty
        let octOrders = PeriodRolloverService.ordersForPeriod(oct, orders: allOrders)
        assert(octOrders.isEmpty, "October should have zero orders initially")

        // 1. Bank turnover in October must be 0 ₴
        let octTurnoverStats = P2PCalculator.accountTurnover(orders: octOrders, accounts: [mono])
        assert(octTurnoverStats.first?.totalSellUAH == 0.0, "October bank turnover must reset to 0 ₴")
        assert(octTurnoverStats.first?.sellOrdersCount == 0, "October sell count must be 0")

        // 2. Realized PnL in October must be 0 ₴
        let octAvgBuyPrice = P2PCalculator.averageBuyPrice(orders: octOrders, settings: octSettings)
        let octPnL = P2PCalculator.calculatePnL(orders: octOrders, avgBuyPrice: octAvgBuyPrice)
        assert(octPnL == 0.0, "October realized PnL must start at 0 ₴")
        print("✓ testTurnoverAndPnLResetInNewPeriod passed")
    }

    /// Tests profit reinvestment vs cash out calculation:
    /// - Reinvest: Free UAH - CashOut carries over into next starting deposit
    /// - Cash Out Profit: Base starting deposit - CashOut carries over
    public static func testProfitReinvestmentVsCashOut() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)

        let sept = "09.2026"
        let oct = "10.2026"

        // Starting deposit 100,000 UAH
        let septSettings = CapitalSettings(
            startingDepositUAH: 100_000.0,
            periodIdentifier: sept
        )
        context.insert(septSettings)

        // Arbitrage cycle in Sept generating 10,000 UAH net profit:
        // Buy 2000 USDT at 40.00 = 80,000 UAH
        let buy = P2POrder(
            type: .buy,
            usdtAmount: 2000.0,
            price: 40.00,
            uahAmount: 80_000.0,
            timestamp: makeDate(year: 2026, month: 9, day: 2)
        )
        // Sell 2000 USDT at 45.00 = 90,000 UAH
        let sell = P2POrder(
            type: .sell,
            usdtAmount: 2000.0,
            price: 45.00,
            uahAmount: 90_000.0,
            timestamp: makeDate(year: 2026, month: 9, day: 15)
        )
        context.insert(buy)
        context.insert(sell)
        try context.save()

        let allOrders = [buy, sell]
        // Free money = 100,000 - 80,000 + 90,000 = 110,000 UAH (profit is +10,000 UAH)

        // Case A: Reinvest all profit with 0 cash out -> starting deposit becomes 110,000 UAH
        let octReinvestSettings = try PeriodRolloverService.rolloverMonth(
            from: sept,
            to: oct,
            orders: allOrders,
            closingSettings: septSettings,
            reinvestProfit: true,
            cashOutAmount: 0.0,
            modelContext: context
        )
        assert(octReinvestSettings.startingDepositUAH == 110_000.0, "Expected 110,000 UAH reinvested deposit, got \(octReinvestSettings.startingDepositUAH)")

        // Case B: Cash out 5,000 UAH profit -> starting deposit becomes 105,000 UAH
        let octPartialCashOut = try PeriodRolloverService.rolloverMonth(
            from: sept,
            to: oct,
            orders: allOrders,
            closingSettings: septSettings,
            reinvestProfit: true,
            cashOutAmount: 5_000.0,
            modelContext: context
        )
        assert(octPartialCashOut.startingDepositUAH == 105_000.0, "Expected 105,000 UAH after partial cash out, got \(octPartialCashOut.startingDepositUAH)")

        // Case C: Cash out profit completely (reinvestProfit = false) -> retains base 100,000 UAH
        let octBaseOnly = try PeriodRolloverService.rolloverMonth(
            from: sept,
            to: oct,
            orders: allOrders,
            closingSettings: septSettings,
            reinvestProfit: false,
            cashOutAmount: 0.0,
            modelContext: context
        )
        assert(octBaseOnly.startingDepositUAH == 100_000.0, "Expected base 100,000 UAH retained, got \(octBaseOnly.startingDepositUAH)")
        print("✓ testProfitReinvestmentVsCashOut passed")
    }

    /// Tests custom starting deposit override
    public static func testCustomStartingDeposit() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)

        let sept = "09.2026"
        let oct = "10.2026"

        let septSettings = CapitalSettings(startingDepositUAH: 100_000.0, periodIdentifier: sept)
        context.insert(septSettings)

        let octSettings = try PeriodRolloverService.rolloverMonth(
            from: sept,
            to: oct,
            orders: [],
            closingSettings: septSettings,
            reinvestProfit: true,
            customStartingDeposit: 250_000.0,
            modelContext: context
        )

        assert(octSettings.startingDepositUAH == 250_000.0, "Expected custom 250,000 UAH deposit, got \(octSettings.startingDepositUAH)")
        print("✓ testCustomStartingDeposit passed")
    }

    /// Tests that repeating rollover for the same period updates the existing CapitalSettings rather than creating duplicates
    public static func testIdempotentRolloverUpdate() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)

        let sept = "09.2026"
        let oct = "10.2026"

        let septSettings = CapitalSettings(startingDepositUAH: 100_000.0, periodIdentifier: sept)
        context.insert(septSettings)

        // First rollover
        try PeriodRolloverService.rolloverMonth(
            from: sept,
            to: oct,
            orders: [],
            closingSettings: septSettings,
            reinvestProfit: true,
            modelContext: context
        )

        // Second rollover with modified cash out
        try PeriodRolloverService.rolloverMonth(
            from: sept,
            to: oct,
            orders: [],
            closingSettings: septSettings,
            reinvestProfit: true,
            cashOutAmount: 10_000.0,
            modelContext: context
        )

        let allSettings = try context.fetch(FetchDescriptor<CapitalSettings>())
        let octSettingsList = allSettings.filter { $0.periodIdentifier == oct }
        assert(octSettingsList.count == 1, "Must not create duplicate settings for the same period")
        assert(octSettingsList.first?.startingDepositUAH == 90_000.0, "Expected updated deposit 90,000 UAH")
        print("✓ testIdempotentRolloverUpdate passed")
    }
}
