import Foundation
import SwiftData

/// Focused unit tests verifying Dynamic Cash Out / Withdrawal Log:
/// 1. SwiftData model creation and persistence
/// 2. Capital breakdown calculation with multiple intermediate withdrawals
/// 3. Period-based filtering of withdrawals
/// 4. Period rollover service factoring in intermediate withdrawals
/// 5. Relationship nullification when associated bank account is deleted
@MainActor
public enum CashWithdrawalTests {
    public static func runAllTests() throws {
        print("--- Running CashWithdrawalTests ---")
        try testCashWithdrawalCreationAndPersistence()
        try testCapitalBreakdownWithDynamicWithdrawals()
        try testPeriodFilteringForWithdrawals()
        try testRolloverMonthWithWithdrawals()
        try testBankDeletionNullifiesWithdrawalRelationship()
        print("--- All CashWithdrawalTests Passed Successfully! ---")
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

    /// 1. Verifies CashWithdrawal creation and database persistence
    public static func testCashWithdrawalCreationAndPersistence() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)

        let bank = BankAccount(name: "MonoBank (Black)", cardNumber: "4441 •••• 1234")
        context.insert(bank)

        let withdrawal = CashWithdrawal(
            amountUAH: 15_000.0,
            timestamp: makeDate(year: 2026, month: 9, day: 10),
            note: "Physical USD exchange",
            periodIdentifier: "09.2026",
            bankAccount: bank
        )
        context.insert(withdrawal)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<CashWithdrawal>())
        assert(fetched.count == 1, "Expected 1 withdrawal in database")
        let item = fetched[0]
        assert(item.amountUAH == 15_000.0, "Expected amount 15,000 UAH")
        assert(item.note == "Physical USD exchange", "Expected matching note")
        assert(item.periodIdentifier == "09.2026", "Expected period 09.2026")
        assert(item.bankAccount?.name == "MonoBank (Black)", "Expected linked bank account")
        print("✓ testCashWithdrawalCreationAndPersistence passed")
    }

    /// 2. Verifies P2PCalculator.calculateCapitalBreakdown with multiple intermediate withdrawals
    public static func testCapitalBreakdownWithDynamicWithdrawals() throws {
        let settings = CapitalSettings(
            startingDepositUAH: 100_000.0,
            toCashUAH: 0.0,
            periodIdentifier: "09.2026"
        )

        // Buy 1000 USDT for 41,000 UAH
        let buy = P2POrder(
            type: .buy,
            usdtAmount: 1000.0,
            price: 41.00,
            uahAmount: 41_000.0,
            timestamp: makeDate(year: 2026, month: 9, day: 2)
        )
        // Sell 1000 USDT for 42,000 UAH (1000 UAH profit)
        let sell = P2POrder(
            type: .sell,
            usdtAmount: 1000.0,
            price: 42.00,
            uahAmount: 42_000.0,
            timestamp: makeDate(year: 2026, month: 9, day: 3)
        )

        // Two intermediate cash withdrawals: 10,000 UAH and 15,000 UAH
        let w1 = CashWithdrawal(
            amountUAH: 10_000.0,
            timestamp: makeDate(year: 2026, month: 9, day: 5),
            periodIdentifier: "09.2026"
        )
        let w2 = CashWithdrawal(
            amountUAH: 15_000.0,
            timestamp: makeDate(year: 2026, month: 9, day: 12),
            periodIdentifier: "09.2026"
        )

        let breakdown = P2PCalculator.calculateCapitalBreakdown(
            orders: [buy, sell],
            settings: settings,
            withdrawals: [w1, w2]
        )

        // Total cash out: 10,000 + 15,000 = 25,000 UAH
        assert(breakdown.toCashUAH == 25_000.0, "Expected toCashUAH == 25,000, got \(breakdown.toCashUAH)")

        // Free UAH: 100,000 - 25,000 + 42,000 - 41,000 = 76,000 UAH
        assert(breakdown.freeUAH == 76_000.0, "Expected freeUAH == 76,000, got \(breakdown.freeUAH)")

        print("✓ testCapitalBreakdownWithDynamicWithdrawals passed")
    }

    /// 3. Verifies PeriodRolloverService.withdrawalsForPeriod filters correctly
    public static func testPeriodFilteringForWithdrawals() throws {
        let wSept1 = CashWithdrawal(amountUAH: 5_000.0, periodIdentifier: "09.2026")
        let wSept2 = CashWithdrawal(amountUAH: 8_000.0, periodIdentifier: "09.2026")
        let wOct = CashWithdrawal(amountUAH: 12_000.0, periodIdentifier: "10.2026")

        let all = [wSept1, wSept2, wOct]

        let sept = PeriodRolloverService.withdrawalsForPeriod("09.2026", withdrawals: all)
        assert(sept.count == 2, "Expected 2 withdrawals for 09.2026")
        assert(sept.reduce(0.0) { $0 + $1.amountUAH } == 13_000.0, "Expected 13,000 total")

        let oct = PeriodRolloverService.withdrawalsForPeriod("10.2026", withdrawals: all)
        assert(oct.count == 1, "Expected 1 withdrawal for 10.2026")
        assert(oct.first?.amountUAH == 12_000.0, "Expected 12,000")

        print("✓ testPeriodFilteringForWithdrawals passed")
    }

    /// 4. Verifies PeriodRolloverService factors in intermediate withdrawals during month closing
    public static func testRolloverMonthWithWithdrawals() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)

        let sept = "09.2026"
        let oct = "10.2026"

        let septSettings = CapitalSettings(
            startingDepositUAH: 100_000.0,
            periodIdentifier: sept
        )
        context.insert(septSettings)

        // Trade with 20,000 UAH profit:
        // Buy 2000 USDT for 80,000 UAH
        let buy = P2POrder(
            type: .buy,
            usdtAmount: 2000.0,
            price: 40.00,
            uahAmount: 80_000.0,
            timestamp: makeDate(year: 2026, month: 9, day: 2)
        )
        // Sell 2000 USDT for 100,000 UAH
        let sell = P2POrder(
            type: .sell,
            usdtAmount: 2000.0,
            price: 50.00,
            uahAmount: 100_000.0,
            timestamp: makeDate(year: 2026, month: 9, day: 15)
        )
        context.insert(buy)
        context.insert(sell)

        // Intermediate cash withdrawals in Sept: 15,000 UAH
        let w = CashWithdrawal(
            amountUAH: 15_000.0,
            timestamp: makeDate(year: 2026, month: 9, day: 10),
            periodIdentifier: sept
        )
        context.insert(w)
        try context.save()

        // Rollover to October reinvesting remaining free money
        // Free money in Sept = 100,000 - 15,000 + 100,000 - 80,000 = 105,000 UAH
        let octSettings = try PeriodRolloverService.rolloverMonth(
            from: sept,
            to: oct,
            orders: [buy, sell],
            withdrawals: [w],
            closingSettings: septSettings,
            reinvestProfit: true,
            cashOutAmount: 0.0,
            modelContext: context
        )

        assert(octSettings.startingDepositUAH == 105_000.0, "Expected 105,000 UAH next starting deposit, got \(octSettings.startingDepositUAH)")
        print("✓ testRolloverMonthWithWithdrawals passed")
    }

    /// 5. Verifies that deleting a BankAccount sets withdrawal.bankAccount = nil without deleting the withdrawal record
    public static func testBankDeletionNullifiesWithdrawalRelationship() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)

        let bank = BankAccount(name: "A-Bank", cardNumber: "5375 •••• 5678")
        context.insert(bank)

        let withdrawal = CashWithdrawal(
            amountUAH: 7_500.0,
            timestamp: makeDate(year: 2026, month: 9, day: 5),
            periodIdentifier: "09.2026",
            bankAccount: bank
        )
        context.insert(withdrawal)
        try context.save()

        // Delete the bank account
        context.delete(bank)
        try context.save()

        let remainingWithdrawals = try context.fetch(FetchDescriptor<CashWithdrawal>())
        assert(remainingWithdrawals.count == 1, "Withdrawal record must NOT be deleted")
        assert(remainingWithdrawals[0].bankAccount == nil, "Withdrawal's bankAccount relationship must be nullified")
        assert(remainingWithdrawals[0].amountUAH == 7_500.0, "Amount must remain intact")

        print("✓ testBankDeletionNullifiesWithdrawalRelationship passed")
    }
}
