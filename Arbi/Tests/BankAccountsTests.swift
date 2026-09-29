import Foundation
import SwiftData

/// Focused tests verifying the complete action flow for adding default Ukrainian banks:
/// 1. Action triggering
/// 2. Default Ukrainian banks creation
/// 3. Persistence through SwiftData ModelContext
/// 4. Immediate state updates
/// 5. Duplicate prevention and idempotency
/// 6. Error handling & rollback
@MainActor
public enum BankAccountsTests {
    public static func runAllTests() throws {
        print("--- Running BankAccountsTests ---")
        try testDefaultUkrainianBanksCreation()
        try testPersistenceThroughExistingPersistenceLayer()
        try testStateUpdatesImmediatelyAfterCreation()
        try testRepeatingOperationDoesNotCreateDuplicates()
        try testExistingCustomNamedBankNotDuplicated()
        try testArchivedDefaultBankRestoredToActive()
        try testPersistenceFailureRollback()
        print("--- All BankAccountsTests Passed Successfully! ---")
    }

    private static func makeInMemoryContainer() throws -> ModelContainer {
        let schema = Schema([P2POrder.self, CapitalSettings.self, BankAccount.self, CashWithdrawal.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    /// 1 & 2: Tests that default Ukrainian banks are created with canonical properties
    public static func testDefaultUkrainianBanksCreation() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)

        let initialAccounts = try context.fetch(FetchDescriptor<BankAccount>())
        assert(initialAccounts.isEmpty, "Initial state must have zero accounts")

        let created = try BankAccount.seedDefaultUkrainianBanks(in: context)
        assert(created.count == 5, "Expected exactly 5 default Ukrainian banks created, got \(created.count)")

        let expectedBanks: Set<BankType> = [.monoBank, .privatBank, .aBank, .pumb, .senseBank]
        let createdBanks = Set(created.map { $0.bankType })
        assert(createdBanks == expectedBanks, "Created banks do not match canonical default Ukrainian banks")

        for account in created {
            assert(account.turnoverLimitUAH == 150_000.0, "Expected default turnover limit 150,000 UAH")
            assert(!account.isArchived, "Newly seeded accounts must be active (not archived)")
            assert(!account.name.isEmpty, "Account name must not be empty")
        }
        print("✓ testDefaultUkrainianBanksCreation passed")
    }

    /// 3: Tests that accounts are persisted through the storage layer and readable from a fresh context
    public static func testPersistenceThroughExistingPersistenceLayer() throws {
        let container = try makeInMemoryContainer()
        let context1 = ModelContext(container)

        try BankAccount.seedDefaultUkrainianBanks(in: context1)

        // Read from an independent ModelContext sharing the same container
        let context2 = ModelContext(container)
        let persistedAccounts = try context2.fetch(FetchDescriptor<BankAccount>())
        assert(persistedAccounts.count == 5, "Fresh context should fetch 5 persisted accounts, got \(persistedAccounts.count)")

        let names = Set(persistedAccounts.map { $0.name })
        assert(names.contains("MonoBank (Black)"), "Expected MonoBank (Black) in persisted accounts")
        assert(names.contains("PrivatBank"), "Expected PrivatBank in persisted accounts")
        print("✓ testPersistenceThroughExistingPersistenceLayer passed")
    }

    /// 4: Tests that the observable state/query immediately updates from empty to non-empty
    public static func testStateUpdatesImmediatelyAfterCreation() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)

        var activeAccounts = try context.fetch(FetchDescriptor<BankAccount>()).filter { !$0.isArchived }
        assert(activeAccounts.isEmpty, "Active accounts must initially be empty")

        // Trigger action
        try BankAccount.seedDefaultUkrainianBanks(in: context)

        // Query immediately without restarting app or recreating context
        activeAccounts = try context.fetch(FetchDescriptor<BankAccount>()).filter { !$0.isArchived }
        assert(!activeAccounts.isEmpty, "Active accounts must immediately be non-empty after seeding")
        assert(activeAccounts.count == 5, "Expected 5 active accounts immediately")
        print("✓ testStateUpdatesImmediatelyAfterCreation passed")
    }

    /// 5: Tests idempotency - repeating the action does not create duplicates
    public static func testRepeatingOperationDoesNotCreateDuplicates() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)

        let firstRun = try BankAccount.seedDefaultUkrainianBanks(in: context)
        assert(firstRun.count == 5, "First run should create 5 accounts")

        let secondRun = try BankAccount.seedDefaultUkrainianBanks(in: context)
        assert(secondRun.isEmpty, "Second run should create 0 accounts because defaults already exist")

        let totalAccounts = try context.fetch(FetchDescriptor<BankAccount>())
        assert(totalAccounts.count == 5, "Total accounts must remain exactly 5 after repeated execution")
        print("✓ testRepeatingOperationDoesNotCreateDuplicates passed")
    }

    /// 5b: Tests deduplication using project domain identity when an existing account has a custom name
    public static func testExistingCustomNamedBankNotDuplicated() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)

        // User already has a custom Mono account
        let customMono = BankAccount(name: "Monobank Main Card", cardNumber: "4441 •••• 9999", turnoverLimitUAH: 200_000.0)
        context.insert(customMono)
        try context.save()

        // Trigger seeding
        let added = try BankAccount.seedDefaultUkrainianBanks(in: context)
        assert(added.count == 4, "Should only create the 4 missing Ukrainian banks, skipping existing MonoBank")

        let allAccounts = try context.fetch(FetchDescriptor<BankAccount>())
        let monoAccounts = allAccounts.filter { $0.bankType == .monoBank }
        assert(monoAccounts.count == 1, "There should be only 1 MonoBank account, preserving custom account without duplicates")
        assert(monoAccounts.first?.name == "Monobank Main Card", "Existing custom account name should be preserved")
        assert(monoAccounts.first?.turnoverLimitUAH == 200_000.0, "Existing custom limit should be preserved")
        print("✓ testExistingCustomNamedBankNotDuplicated passed")
    }

    /// 5c: Tests that an archived default bank is restored to active instead of duplicated
    public static func testArchivedDefaultBankRestoredToActive() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)

        let archivedPrivat = BankAccount(name: "PrivatBank", isArchived: true)
        context.insert(archivedPrivat)
        try context.save()

        let result = try BankAccount.seedDefaultUkrainianBanks(in: context)
        assert(result.contains(where: { $0.name == "PrivatBank" && !$0.isArchived }), "Archived PrivatBank should be unarchived")

        let allPrivat = try context.fetch(FetchDescriptor<BankAccount>()).filter { $0.bankType == .privatBank }
        assert(allPrivat.count == 1, "Must not create a duplicate PrivatBank")
        assert(!allPrivat[0].isArchived, "PrivatBank must now be active")
        print("✓ testArchivedDefaultBankRestoredToActive passed")
    }

    /// 6: Tests that if an error occurs and context.rollback() is invoked, no partially inserted state remains
    public static func testPersistenceFailureRollback() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)

        // Simulate an uncommitted insertion followed by rollback
        let dummy = BankAccount(name: "Temporary Unsaved Account")
        context.insert(dummy)
        assert(context.hasChanges, "Context should have unsaved changes before rollback")

        context.rollback()
        assert(!context.hasChanges, "Context should have no changes after rollback")

        let fetched = try context.fetch(FetchDescriptor<BankAccount>())
        assert(fetched.isEmpty, "No accounts should be stored after rollback")
        print("✓ testPersistenceFailureRollback passed")
    }
}
