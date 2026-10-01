import SwiftUI
import SwiftData

@main
struct SpredApp: App {
    private let modelContainer: ModelContainer?
    private let persistenceErrorMessage: String?
    private let synchronizationReadiness: CloudKitSynchronizationReadiness
    @StateObject private var cloudAccountMonitor = CloudAccountMonitor()

    init() {
        let readiness = CloudKitSynchronizationReadiness()
        synchronizationReadiness = readiness

#if DEBUG
        if ProcessInfo.processInfo.environment["RUN_TESTS"] == "1" {
            readiness.resolveWithoutCloudKit()
            do {
                modelContainer = try CloudKitPersistence.makeInMemoryContainer()
                persistenceErrorMessage = nil
            } catch {
                modelContainer = nil
                persistenceErrorMessage = "Test persistence could not be initialized."
            }
        } else {
            do {
                modelContainer = try CloudKitPersistence.makeContainer()
                persistenceErrorMessage = nil
            } catch {
                modelContainer = nil
                persistenceErrorMessage = "Arbi could not open its existing local database."
            }
        }
#else
        do {
            modelContainer = try CloudKitPersistence.makeContainer()
            persistenceErrorMessage = nil
        } catch {
            modelContainer = nil
            persistenceErrorMessage = "Arbi could not open its existing local database."
        }
#endif

        #if DEBUG
        if ProcessInfo.processInfo.environment["RUN_TESTS"] == "1" {
            do {
                try BankAccountsTests.runAllTests()
                try PeriodRolloverTests.runAllTests()
                try CashWithdrawalTests.runAllTests()
                try FormValidationTests.runAllTests()
                try LocalizationTests.runAllTests()
                try CloudKitPersistenceTests.runAllTests()
                try CloudKitSynchronizationReadinessTests.runAllTests()
                try AccountingPnLTests.runAllTests()
                try TransactionsPaginationTests.runAllTests()
                print("🎉 ALL TESTS PASSED SUCCESSFULLY! 🎉")
            } catch {
                fatalError("Unit tests failed: \(error)")
            }
        }

        #endif
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if let modelContainer {
                    MainTabView()
                        .modelContainer(modelContainer)
                } else {
                    PersistenceFailureView(
                        message: persistenceErrorMessage ?? "The persistence store could not be opened."
                    )
                }
            }
            .environmentObject(cloudAccountMonitor)
            .environmentObject(synchronizationReadiness)
            .task {
#if DEBUG
                if ProcessInfo.processInfo.environment["RUN_TESTS"] != "1" {
                    cloudAccountMonitor.start()
                    synchronizationReadiness.accountStateChanged(cloudAccountMonitor.state)
                }
#else
                cloudAccountMonitor.start()
                synchronizationReadiness.accountStateChanged(cloudAccountMonitor.state)
#endif
            }
            .onChange(of: cloudAccountMonitor.state) { _, state in
                synchronizationReadiness.accountStateChanged(state)
            }
        }
    }
}
