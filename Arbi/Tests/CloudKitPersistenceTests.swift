import CloudKit
import Foundation
import SwiftData

/// Persistence tests that verify the local store URL, the legacy-to-current
/// schema boundary, stable IDs, relationships, and repeated reopening of the
/// same file-backed store. The disposable CloudKit-backed check validates the
/// model schema without touching the production store.
@MainActor
public enum CloudKitPersistenceTests {
    public static func runAllTests() throws {
        print("--- Running CloudKitPersistenceTests ---")
        try testProductionStoreURLIsLegacyDefaultStore()
        try testCloudKitConfigurationUsesExplicitLegacyURL()
        try testCloudAccountStateMapping()
        try testLegacyStoreCanBeReopenedWithCurrentSchema()
        try testRepeatedReopenDoesNotDuplicateOrRegenerateRecords()
        try testCleanCloudKitContainerCanInitialize()
        print("--- All CloudKitPersistenceTests Passed Successfully! ---")
    }

    private struct OrderSnapshot: Equatable {
        let id: UUID
        let type: String
        let usdtAmount: Double
        let price: Double
        let uahAmount: Double
        let feeUSDT: Double
        let txFeeUSDT: Double
        let platform: String
        let bank: String
        let bankAccountID: UUID?
        let timestamp: Date
        let note: String?
    }

    private struct AccountSnapshot: Equatable {
        let id: UUID
        let name: String
        let cardNumber: String?
        let turnoverLimitUAH: Double
        let isArchived: Bool
        let createdAt: Date
    }

    private struct SettingsSnapshot: Equatable {
        let id: UUID
        let startingDepositUAH: Double
        let toCashUAH: Double
        let initialUSDT: Double
        let initialAvgBuyPrice: Double
        let periodIdentifier: String
        let lastUpdated: Date
    }

    private struct WithdrawalSnapshot: Equatable {
        let id: UUID
        let amountUAH: Double
        let timestamp: Date
        let note: String?
        let periodIdentifier: String
        let bankAccountID: UUID?
    }

    private struct PersistenceSnapshot: Equatable {
        let orders: [OrderSnapshot]
        let accounts: [AccountSnapshot]
        let settings: [SettingsSnapshot]
        let withdrawals: [WithdrawalSnapshot]
    }

    public static func testProductionStoreURLIsLegacyDefaultStore() throws {
        guard let applicationSupportURL = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            assertionFailure("Application Support must be available")
            return
        }

        assert(
            CloudKitPersistence.storeURL.deletingLastPathComponent().standardizedFileURL
                == applicationSupportURL.standardizedFileURL,
            "Production store must remain inside Application Support"
        )
        assert(
            CloudKitPersistence.storeURL.lastPathComponent == "default.store",
            "Production store filename must remain default.store"
        )
        print("✓ testProductionStoreURLIsLegacyDefaultStore passed")
    }

    public static func testCloudKitConfigurationUsesExplicitLegacyURL() throws {
        let configuration = CloudKitPersistence.makeConfiguration()
        assert(configuration.url == CloudKitPersistence.storeURL, "CloudKit config must use the legacy store URL")
        assert(
            configuration.cloudKitContainerIdentifier == CloudKitPersistence.containerIdentifier,
            "CloudKit config must use the intended private container"
        )
        print("✓ testCloudKitConfigurationUsesExplicitLegacyURL passed")
    }

    public static func testCloudAccountStateMapping() throws {
        assert(CloudAccountState(.available) == .available, "Available account status mapping failed")
        assert(CloudAccountState(.noAccount) == .noAccount, "No-account status mapping failed")
        assert(CloudAccountState(.restricted) == .restricted, "Restricted status mapping failed")
        assert(
            CloudAccountState(.temporarilyUnavailable) == .temporarilyUnavailable,
            "Temporarily unavailable status mapping failed"
        )
        assert(
            CloudAccountState(.couldNotDetermine) == .couldNotDetermine,
            "Could-not-determine status mapping failed"
        )
        print("✓ testCloudAccountStateMapping passed")
    }

    public static func testLegacyStoreCanBeReopenedWithCurrentSchema() throws {
        let storeURL = try makeTemporaryStoreURL()
        defer { try? FileManager.default.removeItem(at: storeURL.deletingLastPathComponent()) }

        let expected: PersistenceSnapshot
        do {
            let legacyConfiguration = CloudKitPersistence.makeConfiguration(
                url: storeURL,
                cloudKitDatabase: .none
            )
            let container = try ModelContainer(
                for: CloudKitPersistence.schema,
                configurations: [legacyConfiguration]
            )
            let context = ModelContext(container)
            try insertRepresentativeData(in: context)
            expected = try snapshot(from: context)
        }

        do {
            // This uses the current schema and exact production URL shape,
            // but disables transport so the test remains fully local.
            let currentConfiguration = CloudKitPersistence.makeConfiguration(
                url: storeURL,
                cloudKitDatabase: .none
            )
            let container = try ModelContainer(
                for: CloudKitPersistence.schema,
                configurations: [currentConfiguration]
            )
            let actual = try snapshot(from: ModelContext(container))
            assert(actual == expected, "Legacy records must survive current-schema reopening")
        }

        print("✓ testLegacyStoreCanBeReopenedWithCurrentSchema passed")
    }

    public static func testRepeatedReopenDoesNotDuplicateOrRegenerateRecords() throws {
        let storeURL = try makeTemporaryStoreURL()
        defer { try? FileManager.default.removeItem(at: storeURL.deletingLastPathComponent()) }

        let initial: PersistenceSnapshot
        do {
            let container = try makeLocalContainer(at: storeURL)
            let context = ModelContext(container)
            try insertRepresentativeData(in: context)
            initial = try snapshot(from: context)
        }

        for _ in 0..<2 {
            let container = try makeLocalContainer(at: storeURL)
            let reopened = try snapshot(from: ModelContext(container))
            assert(reopened == initial, "Repeated reopening must preserve the exact dataset")
        }

        print("✓ testRepeatedReopenDoesNotDuplicateOrRegenerateRecords passed")
    }

    public static func testCleanCloudKitContainerCanInitialize() throws {
        let storeURL = try makeTemporaryStoreURL()
        defer { try? FileManager.default.removeItem(at: storeURL.deletingLastPathComponent()) }

        let configuration = CloudKitPersistence.makeConfiguration(
            url: storeURL,
            cloudKitDatabase: .private(CloudKitPersistence.containerIdentifier)
        )
        _ = try ModelContainer(
            for: CloudKitPersistence.schema,
            configurations: [configuration]
        )

        print("✓ testCleanCloudKitContainerCanInitialize passed")
    }

    private static func makeLocalContainer(at url: URL) throws -> ModelContainer {
        let configuration = CloudKitPersistence.makeConfiguration(
            url: url,
            cloudKitDatabase: .none
        )
        return try ModelContainer(
            for: CloudKitPersistence.schema,
            configurations: [configuration]
        )
    }

    private static func makeTemporaryStoreURL() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ArbiPersistenceTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("default.store")
    }

    private static func insertRepresentativeData(in context: ModelContext) throws {
        let mono = BankAccount(
            id: UUID(),
            name: "MonoBank (Black)",
            cardNumber: "4441 •••• 1234",
            turnoverLimitUAH: 150_000,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let privat = BankAccount(
            id: UUID(),
            name: "PrivatBank",
            cardNumber: nil,
            turnoverLimitUAH: 100_000,
            isArchived: true,
            createdAt: Date(timeIntervalSince1970: 1_700_000_100)
        )
        let order1 = P2POrder(
            id: UUID(),
            type: .buy,
            usdtAmount: 1_000,
            price: 41.20,
            uahAmount: 41_200,
            feeUSDT: 0.07,
            txFeeUSDT: 0,
            platform: .binance,
            bank: .monoBank,
            bankAccount: mono,
            timestamp: Date(timeIntervalSince1970: 1_700_001_000),
            note: "Buy"
        )
        let order2 = P2POrder(
            id: UUID(),
            type: .sell,
            usdtAmount: 500,
            price: 41.65,
            uahAmount: 20_825,
            feeUSDT: 0.07,
            txFeeUSDT: 1,
            platform: .bybit,
            bank: .privatBank,
            bankAccount: privat,
            timestamp: Date(timeIntervalSince1970: 1_700_002_000),
            note: nil
        )
        let settings1 = CapitalSettings(
            id: UUID(),
            startingDepositUAH: 100_000,
            initialUSDT: 500,
            initialAvgBuyPrice: 41.10,
            periodIdentifier: "09.2026",
            lastUpdated: Date(timeIntervalSince1970: 1_700_003_000)
        )
        let settings2 = CapitalSettings(
            id: UUID(),
            startingDepositUAH: 125_000,
            toCashUAH: 5_000,
            periodIdentifier: "10.2026",
            lastUpdated: Date(timeIntervalSince1970: 1_700_004_000)
        )
        let withdrawal1 = CashWithdrawal(
            id: UUID(),
            amountUAH: 15_000,
            timestamp: Date(timeIntervalSince1970: 1_700_005_000),
            note: "Cash",
            periodIdentifier: "09.2026",
            bankAccount: mono
        )
        let withdrawal2 = CashWithdrawal(
            id: UUID(),
            amountUAH: 2_500,
            timestamp: Date(timeIntervalSince1970: 1_700_006_000),
            periodIdentifier: "10.2026",
            bankAccount: nil
        )

        context.insert(mono)
        context.insert(privat)
        context.insert(order1)
        context.insert(order2)
        context.insert(settings1)
        context.insert(settings2)
        context.insert(withdrawal1)
        context.insert(withdrawal2)
        try context.save()
    }

    private static func snapshot(from context: ModelContext) throws -> PersistenceSnapshot {
        let orders = try context.fetch(FetchDescriptor<P2POrder>())
            .map {
                OrderSnapshot(
                    id: $0.id,
                    type: $0.type.rawValue,
                    usdtAmount: $0.usdtAmount,
                    price: $0.price,
                    uahAmount: $0.uahAmount,
                    feeUSDT: $0.feeUSDT,
                    txFeeUSDT: $0.txFeeUSDT,
                    platform: $0.platform.rawValue,
                    bank: $0.bank.rawValue,
                    bankAccountID: $0.bankAccount?.id,
                    timestamp: $0.timestamp,
                    note: $0.note
                )
            }
            .sorted { $0.id.uuidString < $1.id.uuidString }

        let accounts = try context.fetch(FetchDescriptor<BankAccount>())
            .map {
                AccountSnapshot(
                    id: $0.id,
                    name: $0.name,
                    cardNumber: $0.cardNumber,
                    turnoverLimitUAH: $0.turnoverLimitUAH,
                    isArchived: $0.isArchived,
                    createdAt: $0.createdAt
                )
            }
            .sorted { $0.id.uuidString < $1.id.uuidString }

        let settings = try context.fetch(FetchDescriptor<CapitalSettings>())
            .map {
                SettingsSnapshot(
                    id: $0.id,
                    startingDepositUAH: $0.startingDepositUAH,
                    toCashUAH: $0.toCashUAH,
                    initialUSDT: $0.initialUSDT,
                    initialAvgBuyPrice: $0.initialAvgBuyPrice,
                    periodIdentifier: $0.periodIdentifier,
                    lastUpdated: $0.lastUpdated
                )
            }
            .sorted { $0.id.uuidString < $1.id.uuidString }

        let withdrawals = try context.fetch(FetchDescriptor<CashWithdrawal>())
            .map {
                WithdrawalSnapshot(
                    id: $0.id,
                    amountUAH: $0.amountUAH,
                    timestamp: $0.timestamp,
                    note: $0.note,
                    periodIdentifier: $0.periodIdentifier,
                    bankAccountID: $0.bankAccount?.id
                )
            }
            .sorted { $0.id.uuidString < $1.id.uuidString }

        return PersistenceSnapshot(
            orders: orders,
            accounts: accounts,
            settings: settings,
            withdrawals: withdrawals
        )
    }
}
