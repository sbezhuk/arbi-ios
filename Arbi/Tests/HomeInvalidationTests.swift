import Foundation
import SwiftData
import Combine
import CoreData

/// Comprehensive unit test suite verifying the Home invalidation pipeline:
/// - ModelContext.didSave observation
/// - Coalescing duplicate / rapid signals via next run-loop Task.yield()
/// - Measured reload counts for each mutation scenario:
///   * Add transaction       → 1 logical Home reload
///   * Edit transaction      → 1 logical Home reload
///   * Delete transaction    → 1 logical Home reload
///   * Capital Settings save → 1 logical Home reload
///   * Bank Account save     → 1 logical Home reload
///   * Withdrawal save       → 1 logical Home reload
///   * Period rollover       → 1 logical Home reload after state settles
///   * Sheet Cancel          → 0 logical Home reloads
///   * selectedPeriod change → 1 logical Home reload
///   * CloudKit / remote     → 1 logical Home reload, duplicate signals coalesced
///   * Stale generation      → superseded, older task does not commit
@MainActor
public enum HomeInvalidationTests {
    public static func runAllTests() async throws {
        print("--- Running HomeInvalidationTests ---")
        try await testAddTransactionTriggersExactlyOneReload()
        try await testEditTransactionTriggersExactlyOneReload()
        try await testDeleteTransactionTriggersExactlyOneReload()
        try await testCapitalSettingsSaveTriggersExactlyOneReload()
        try await testBankAccountSaveTriggersExactlyOneReload()
        try await testWithdrawalSaveTriggersExactlyOneReload()
        try await testPeriodRolloverTriggersExactlyOneReload()
        try await testSheetCancelTriggersZeroReloads()
        try await testSelectedPeriodChangeTriggersExactlyOneReload()
        try await testCloudKitRemoteChangeTriggersReloadAndCoalescesDuplicates()
        try await testStaleGenerationDiscarded()
        print("--- All HomeInvalidationTests Passed Successfully! ---")
    }

    private static func makeInMemoryContainer() throws -> ModelContainer {
        let schema = Schema([P2POrder.self, CapitalSettings.self, BankAccount.self, CashWithdrawal.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    /// Harness that wires HomeInvalidationPipeline exactly as ContentView does.
    private final class Harness {
        let pipeline: HomeInvalidationPipeline
        var reloadCount = 0
        var lastLoadedGeneration = 0
        private var cancellables = Set<AnyCancellable>()

        init() {
            pipeline = HomeInvalidationPipeline()
            pipeline.onReload = { [weak self] generation in
                self?.reloadCount += 1
                self?.lastLoadedGeneration = generation
            }

            NotificationCenter.default
                .publisher(for: ModelContext.didSave)
                .sink { [weak self] _ in
                    self?.pipeline.invalidate()
                }
                .store(in: &cancellables)

            CloudKitPersistence.remoteStoreChangePublisher
                .sink { [weak self] _ in
                    self?.pipeline.invalidate()
                }
                .store(in: &cancellables)
        }

        func onSelectedPeriodChanged() {
            pipeline.invalidate()
        }

        /// Waits for cooperative tasks on the main actor to settle.
        func waitForSettle() async {
            // Task.yield() allows the scheduled invalidation task to run.
            await Task.yield()
            // Micro-sleep to ensure any run-loop drain completes.
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
    }

    // MARK: - 1. Add Transaction
    public static func testAddTransactionTriggersExactlyOneReload() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let harness = Harness()

        let order = P2POrder(type: .buy, usdtAmount: 100, price: 41.0, uahAmount: 4100, timestamp: Date())
        context.insert(order)
        try context.save()

        await harness.waitForSettle()
        assert(harness.reloadCount == 1, "Add transaction must trigger exactly 1 reload, got \(harness.reloadCount)")
    }

    // MARK: - 2. Edit Transaction
    public static func testEditTransactionTriggersExactlyOneReload() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let order = P2POrder(type: .buy, usdtAmount: 100, price: 41.0, uahAmount: 4100, timestamp: Date())
        context.insert(order)
        try context.save()

        let harness = Harness()
        order.price = 42.0
        try context.save()

        await harness.waitForSettle()
        assert(harness.reloadCount == 1, "Edit transaction must trigger exactly 1 reload, got \(harness.reloadCount)")
    }

    // MARK: - 3. Delete Transaction
    public static func testDeleteTransactionTriggersExactlyOneReload() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let order = P2POrder(type: .buy, usdtAmount: 100, price: 41.0, uahAmount: 4100, timestamp: Date())
        context.insert(order)
        try context.save()

        let harness = Harness()
        context.delete(order)
        try context.save()

        await harness.waitForSettle()
        assert(harness.reloadCount == 1, "Delete transaction must trigger exactly 1 reload, got \(harness.reloadCount)")
    }

    // MARK: - 4. Capital Settings Save
    public static func testCapitalSettingsSaveTriggersExactlyOneReload() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let harness = Harness()

        let settings = CapitalSettings(
            startingDepositUAH: 100_000.0,
            toCashUAH: 0.0,
            initialUSDT: 500.0,
            initialAvgBuyPrice: 41.10,
            periodIdentifier: "10.2026"
        )
        context.insert(settings)
        try context.save()

        await harness.waitForSettle()
        assert(harness.reloadCount == 1, "Capital Settings save must trigger exactly 1 reload, got \(harness.reloadCount)")
    }

    // MARK: - 5. Bank Account Save
    public static func testBankAccountSaveTriggersExactlyOneReload() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let harness = Harness()

        let account = BankAccount(name: "Mono (Black)", cardNumber: "1234", turnoverLimitUAH: 150_000)
        context.insert(account)
        try context.save()

        await harness.waitForSettle()
        assert(harness.reloadCount == 1, "Bank Account save must trigger exactly 1 reload, got \(harness.reloadCount)")
    }

    // MARK: - 6. Withdrawal Save
    public static func testWithdrawalSaveTriggersExactlyOneReload() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let harness = Harness()

        let withdrawal = CashWithdrawal(amountUAH: 5_000.0, periodIdentifier: "10.2026")
        context.insert(withdrawal)
        try context.save()

        await harness.waitForSettle()
        assert(harness.reloadCount == 1, "Withdrawal save must trigger exactly 1 reload, got \(harness.reloadCount)")
    }

    // MARK: - 7. Period Rollover
    public static func testPeriodRolloverTriggersExactlyOneReload() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let harness = Harness()

        // Rollover action: inserts new CapitalSettings AND updates selectedPeriod
        let newSettings = CapitalSettings(
            startingDepositUAH: 120_000.0,
            toCashUAH: 0.0,
            initialUSDT: 600.0,
            initialAvgBuyPrice: 41.50,
            periodIdentifier: "11.2026"
        )
        context.insert(newSettings)
        try context.save()
        harness.onSelectedPeriodChanged()

        await harness.waitForSettle()
        assert(harness.reloadCount == 1, "Period rollover must coalesce into exactly 1 reload, got \(harness.reloadCount)")
    }

    // MARK: - 8. Sheet Cancel
    public static func testSheetCancelTriggersZeroReloads() async throws {
        let harness = Harness()
        // User opens sheet and cancels without saving -> no save notification, no selectedPeriod change.
        await harness.waitForSettle()
        assert(harness.reloadCount == 0, "Sheet cancel without saving must trigger 0 reloads, got \(harness.reloadCount)")
    }

    // MARK: - 9. selectedPeriod Change
    public static func testSelectedPeriodChangeTriggersExactlyOneReload() async throws {
        let harness = Harness()
        harness.onSelectedPeriodChanged()

        await harness.waitForSettle()
        assert(harness.reloadCount == 1, "selectedPeriod change must trigger exactly 1 reload, got \(harness.reloadCount)")
    }

    // MARK: - 10. CloudKit / Remote Change & Coalescing
    public static func testCloudKitRemoteChangeTriggersReloadAndCoalescesDuplicates() async throws {
        let harness = Harness()

        // Simulate rapid duplicate store remote change notifications (e.g. multi-table or chunked CloudKit import)
        NotificationCenter.default.post(name: NSNotification.Name.NSPersistentStoreRemoteChange, object: nil)
        NotificationCenter.default.post(name: NSNotification.Name.NSPersistentStoreRemoteChange, object: nil)

        await harness.waitForSettle()
        assert(harness.reloadCount == 1, "Duplicate CloudKit/remote notifications must coalesce into exactly 1 reload, got \(harness.reloadCount)")
    }

    // MARK: - 11. Stale Generation Discarded
    public static func testStaleGenerationDiscarded() async throws {
        let pipeline = HomeInvalidationPipeline()
        var completedGenerations: [Int] = []

        pipeline.onReload = { generation in
            completedGenerations.append(generation)
        }

        // Trigger two rapid invalidations back-to-back
        pipeline.invalidate()
        let gen1 = pipeline.loadGeneration
        pipeline.invalidate()
        let gen2 = pipeline.loadGeneration

        assert(gen2 > gen1, "Second generation must be greater than first")

        await Task.yield()
        try? await Task.sleep(nanoseconds: 10_000_000)

        assert(completedGenerations == [gen2], "Only the latest generation must complete, got \(completedGenerations)")
    }
}
