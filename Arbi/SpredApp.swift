import SwiftUI
import SwiftData

@main
struct SpredApp: App {
    init() {
        #if DEBUG
        if ProcessInfo.processInfo.environment["RUN_TESTS"] == "1" {
            do {
                try BankAccountsTests.runAllTests()
                try PeriodRolloverTests.runAllTests()
                try CashWithdrawalTests.runAllTests()
                try LocalizationTests.runAllTests()
                print("🎉 ALL TESTS PASSED SUCCESSFULLY! 🎉")
            } catch {
                fatalError("Unit tests failed: \(error)")
            }
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
        .modelContainer(for: [P2POrder.self, CapitalSettings.self, BankAccount.self, CashWithdrawal.self])
    }
}
