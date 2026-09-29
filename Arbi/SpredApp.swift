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
                print("🎉 ALL TESTS PASSED SUCCESSFULLY! 🎉")
            } catch {
                fatalError("Unit tests failed: \(error)")
            }
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [P2POrder.self, CapitalSettings.self, BankAccount.self, CashWithdrawal.self])
    }
}
