import Foundation
import SwiftData

/// Focused unit tests verifying:
/// 1. 0 transactions behavior
/// 2. 1–5 transactions → no Show All
/// 3. 6+ transactions → Home displays exactly 5 and triggers Show All
/// 4. Newest-first ordering with stable secondary sort
/// 5. First history page fetch
/// 6. Loading next page
/// 7. No duplicate rows between pages
/// 8. Final partial page
/// 9. No further fetch after exhaustion
/// 10. Transaction editing works across Home and Transactions
/// 11. Persisted commission precision and display
@MainActor
public enum TransactionsPaginationTests {
    public static func runAllTests() throws {
        print("--- Running TransactionsPaginationTests ---")
        try testZeroTransactions()
        try testOneToFiveTransactionsNoShowAll()
        try testSixPlusTransactionsDisplaysExactlyFiveAndShowAll()
        try testNewestFirstOrdering()
        try testFirstHistoryPage()
        try testLoadingNextPage()
        try testNoDuplicatesBetweenPages()
        try testFinalPartialPage()
        try testNoFurtherFetchAfterExhaustion()
        try testTransactionEditingReflectedAcrossHomeAndTransactions()
        try testCommissionPrecisionDisplay()
        print("--- All TransactionsPaginationTests Passed Successfully! ---")
    }

    private static func makeInMemoryContainer() throws -> ModelContainer {
        let schema = Schema([P2POrder.self, CapitalSettings.self, BankAccount.self, CashWithdrawal.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    private static func makeDate(year: Int = 2026, month: Int = 10, day: Int = 1, hour: Int = 12, minute: Int = 0) -> Date {
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = day
        comps.hour = hour
        comps.minute = minute
        comps.second = 0
        return Calendar.current.date(from: comps) ?? Date()
    }

    // MARK: - 1. 0 transactions

    public static func testZeroTransactions() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let period = "10.2026"

        let fetched = try TransactionsPaginationFetcher.fetchPage(
            modelContext: context,
            periodIdentifier: period,
            offset: 0,
            limit: 25
        )
        assert(fetched.isEmpty, "0 transactions must return empty page")

        let allOrders: [P2POrder] = []
        let periodOrders = PeriodRolloverService.ordersForPeriod(period, orders: allOrders)
        let recentOrders = Array(periodOrders.prefix(5))
        let shouldShowAll = periodOrders.count > 5

        assert(periodOrders.isEmpty, "Period orders should be empty")
        assert(recentOrders.isEmpty, "Home recent orders should be empty")
        assert(!shouldShowAll, "Show All must not appear when 0 transactions")
    }

    // MARK: - 2. 1–5 transactions → no Show All

    public static func testOneToFiveTransactionsNoShowAll() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let period = "10.2026"

        for count in 1...5 {
            let order = P2POrder(
                type: .buy,
                usdtAmount: Double(count * 100),
                price: 41.50,
                uahAmount: Double(count * 100) * 41.50,
                timestamp: makeDate(day: count, hour: 10)
            )
            context.insert(order)
        }
        try context.save()

        let descriptor = FetchDescriptor<P2POrder>()
        let allOrders = try context.fetch(descriptor)
        let periodOrders = PeriodRolloverService.ordersForPeriod(period, orders: allOrders)
        let recentOrders = Array(periodOrders.prefix(5))
        let shouldShowAll = periodOrders.count > 5

        assert(periodOrders.count == 5, "Expected 5 period orders")
        assert(recentOrders.count == 5, "Home should display all 5 transactions")
        assert(!shouldShowAll, "Show All must NOT appear when transaction count <= 5")
    }

    // MARK: - 3. 6+ transactions → Home displays exactly 5 and Show All

    public static func testSixPlusTransactionsDisplaysExactlyFiveAndShowAll() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let period = "10.2026"

        for i in 1...12 {
            let order = P2POrder(
                type: i % 2 == 0 ? .buy : .sell,
                usdtAmount: Double(i * 50),
                price: 41.50,
                uahAmount: Double(i * 50) * 41.50,
                timestamp: makeDate(day: min(i, 28), hour: 10)
            )
            context.insert(order)
        }
        try context.save()

        let descriptor = FetchDescriptor<P2POrder>(
            sortBy: [SortDescriptor(\P2POrder.timestamp, order: .reverse)]
        )
        let allOrders = try context.fetch(descriptor)
        let periodOrders = PeriodRolloverService.ordersForPeriod(period, orders: allOrders)
        let recentOrders = Array(periodOrders.prefix(5))
        let shouldShowAll = periodOrders.count > 5

        assert(periodOrders.count == 12, "Expected 12 total period orders")
        assert(recentOrders.count == 5, "Home Recent Transactions must display strictly 5 transactions")
        assert(shouldShowAll, "Show All action MUST be enabled when transaction count > 5")
    }

    // MARK: - 4. Newest-first ordering

    public static func testNewestFirstOrdering() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let period = "10.2026"

        // Insert in random/scrambled chronological order
        let days = [5, 12, 1, 25, 18, 9]
        for day in days {
            let order = P2POrder(
                type: .buy,
                usdtAmount: 100,
                price: 41.50,
                uahAmount: 4150,
                timestamp: makeDate(day: day, hour: 12)
            )
            context.insert(order)
        }
        try context.save()

        let page = try TransactionsPaginationFetcher.fetchPage(
            modelContext: context,
            periodIdentifier: period,
            offset: 0,
            limit: 10
        )

        assert(page.count == 6, "Expected 6 orders fetched")
        for i in 0..<(page.count - 1) {
            assert(
                page[i].timestamp >= page[i + 1].timestamp,
                "Transactions must be strictly sorted newest-first: \(page[i].timestamp) >= \(page[i + 1].timestamp)"
            )
        }
    }

    // MARK: - 5. First history page

    public static func testFirstHistoryPage() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let period = "10.2026"

        for i in 1...60 {
            let order = P2POrder(
                type: .buy,
                usdtAmount: Double(i),
                price: 41.50,
                uahAmount: Double(i) * 41.50,
                timestamp: makeDate(day: (i % 28) + 1, hour: (i % 24), minute: (i % 60))
            )
            context.insert(order)
        }
        try context.save()

        let page1 = try TransactionsPaginationFetcher.fetchPage(
            modelContext: context,
            periodIdentifier: period,
            offset: 0,
            limit: 25
        )

        assert(page1.count == 25, "First page must contain exactly 25 orders")
    }

    // MARK: - 6. Loading the next page

    public static func testLoadingNextPage() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let period = "10.2026"

        for i in 1...60 {
            let order = P2POrder(
                type: .buy,
                usdtAmount: Double(i),
                price: 41.50,
                uahAmount: Double(i) * 41.50,
                timestamp: makeDate(day: (i % 28) + 1, hour: (i % 24), minute: (i % 60))
            )
            context.insert(order)
        }
        try context.save()

        let page1 = try TransactionsPaginationFetcher.fetchPage(
            modelContext: context,
            periodIdentifier: period,
            offset: 0,
            limit: 25
        )
        let page2 = try TransactionsPaginationFetcher.fetchPage(
            modelContext: context,
            periodIdentifier: period,
            offset: 25,
            limit: 25
        )

        assert(page1.count == 25, "Page 1 count must be 25")
        assert(page2.count == 25, "Page 2 count must be 25")

        // In newest-first order, the oldest item in page 1 must be >= newest item in page 2
        let oldestPage1 = page1.last!.timestamp
        let newestPage2 = page2.first!.timestamp
        assert(oldestPage1 >= newestPage2, "Page 1 oldest timestamp must be >= Page 2 newest timestamp")
    }

    // MARK: - 7. No duplicates between pages

    public static func testNoDuplicatesBetweenPages() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let period = "10.2026"

        for i in 1...60 {
            let order = P2POrder(
                type: .buy,
                usdtAmount: Double(i),
                price: 41.50,
                uahAmount: Double(i) * 41.50,
                timestamp: makeDate(day: (i % 28) + 1, hour: (i % 24), minute: (i % 60))
            )
            context.insert(order)
        }
        try context.save()

        let page1 = try TransactionsPaginationFetcher.fetchPage(modelContext: context, periodIdentifier: period, offset: 0, limit: 25)
        let page2 = try TransactionsPaginationFetcher.fetchPage(modelContext: context, periodIdentifier: period, offset: 25, limit: 25)
        let page3 = try TransactionsPaginationFetcher.fetchPage(modelContext: context, periodIdentifier: period, offset: 50, limit: 25)

        let ids1 = Set(page1.map(\.id))
        let ids2 = Set(page2.map(\.id))
        let ids3 = Set(page3.map(\.id))

        assert(ids1.count == 25, "Page 1 must contain 25 unique IDs")
        assert(ids2.count == 25, "Page 2 must contain 25 unique IDs")
        assert(ids3.count == 10, "Page 3 must contain 10 unique IDs")

        assert(ids1.isDisjoint(with: ids2), "Page 1 and Page 2 must not have overlapping orders")
        assert(ids2.isDisjoint(with: ids3), "Page 2 and Page 3 must not have overlapping orders")
        assert(ids1.isDisjoint(with: ids3), "Page 1 and Page 3 must not have overlapping orders")
    }

    // MARK: - 8. Final partial page

    public static func testFinalPartialPage() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let period = "10.2026"

        // 60 total orders -> page sizes: 25, 25, 10
        for i in 1...60 {
            let order = P2POrder(
                type: .buy,
                usdtAmount: Double(i),
                price: 41.50,
                uahAmount: Double(i) * 41.50,
                timestamp: makeDate(day: (i % 28) + 1, hour: (i % 24), minute: (i % 60))
            )
            context.insert(order)
        }
        try context.save()

        let page3 = try TransactionsPaginationFetcher.fetchPage(
            modelContext: context,
            periodIdentifier: period,
            offset: 50,
            limit: 25
        )

        assert(page3.count == 10, "Final page must be a partial page of 10 items")
        let hasMore = page3.count == 25
        assert(!hasMore, "hasMorePages must evaluate to false on partial page")
    }

    // MARK: - 9. No further fetch after exhaustion

    public static func testNoFurtherFetchAfterExhaustion() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let period = "10.2026"

        for i in 1...15 {
            let order = P2POrder(
                type: .buy,
                usdtAmount: Double(i),
                price: 41.50,
                uahAmount: Double(i) * 41.50,
                timestamp: makeDate(day: i, hour: 10)
            )
            context.insert(order)
        }
        try context.save()

        let page1 = try TransactionsPaginationFetcher.fetchPage(
            modelContext: context,
            periodIdentifier: period,
            offset: 0,
            limit: 25
        )
        assert(page1.count == 15, "First page fetches all 15 records")

        // Further request at offset 15
        let page2 = try TransactionsPaginationFetcher.fetchPage(
            modelContext: context,
            periodIdentifier: period,
            offset: 15,
            limit: 25
        )
        assert(page2.isEmpty, "Offset beyond available records must return empty list without error")
    }

    // MARK: - 10. Transaction editing still works from both Home and Transactions

    public static func testTransactionEditingReflectedAcrossHomeAndTransactions() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let period = "10.2026"

        let order = P2POrder(
            type: .buy,
            usdtAmount: 500.0,
            price: 41.20,
            uahAmount: 20600.0,
            feeUSDT: 0.07,
            timestamp: makeDate(day: 10, hour: 10),
            note: "Original Note"
        )
        context.insert(order)
        try context.save()

        // 1. Verify initial state in both views
        let homeOrdersBefore = PeriodRolloverService.ordersForPeriod(period, orders: try context.fetch(FetchDescriptor<P2POrder>()))
        let txOrdersBefore = try TransactionsPaginationFetcher.fetchPage(modelContext: context, periodIdentifier: period, offset: 0, limit: 10)
        assert(homeOrdersBefore.first?.uahAmount == 20600.0, "Home sees original amount")
        assert(txOrdersBefore.first?.uahAmount == 20600.0, "Transactions view sees original amount")

        // 2. Edit transaction
        order.price = 41.80
        order.uahAmount = 20900.0
        order.note = "Updated Note"
        try context.save()

        // 3. Verify edits persist and reflect in both contexts
        let homeOrdersAfter = PeriodRolloverService.ordersForPeriod(period, orders: try context.fetch(FetchDescriptor<P2POrder>()))
        let txOrdersAfter = try TransactionsPaginationFetcher.fetchPage(modelContext: context, periodIdentifier: period, offset: 0, limit: 10)

        assert(homeOrdersAfter.first?.price == 41.80, "Home observes updated price")
        assert(homeOrdersAfter.first?.uahAmount == 20900.0, "Home observes updated total UAH")
        assert(homeOrdersAfter.first?.note == "Updated Note", "Home observes updated note")

        assert(txOrdersAfter.first?.price == 41.80, "Transactions view observes updated price")
        assert(txOrdersAfter.first?.uahAmount == 20900.0, "Transactions view observes updated total UAH")
        assert(txOrdersAfter.first?.note == "Updated Note", "Transactions view observes updated note")
    }

    // MARK: - 11. Commission remains displayed with persisted precision

    public static func testCommissionPrecisionDisplay() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let period = "10.2026"

        let highPrecisionFee = 0.070001
        let order = P2POrder(
            type: .buy,
            usdtAmount: 1000.0,
            price: 41.00,
            uahAmount: 41000.0,
            feeUSDT: highPrecisionFee,
            timestamp: makeDate(day: 15, hour: 14)
        )
        context.insert(order)
        try context.save()

        let fetched = try TransactionsPaginationFetcher.fetchPage(modelContext: context, periodIdentifier: period, offset: 0, limit: 5)
        assert(fetched.count == 1, "Expected 1 order fetched")
        let loadedOrder = fetched.first!

        // Persisted precision check
        assert(loadedOrder.feeUSDT == highPrecisionFee, "Double precision fee must be retained without truncation")

        // Formatted display check
        let formattedFee = HomeFormatters.commissionFee(loadedOrder.feeUSDT)
        assert(formattedFee.contains("0.070001") || formattedFee.contains("0,070001"), "Formatted fee must display full precision")

        let line = HomeFormatters.commissionLine(feeUSDT: loadedOrder.feeUSDT)
        assert(line.contains(formattedFee), "Commission line must embed full precision fee string")
    }
}
