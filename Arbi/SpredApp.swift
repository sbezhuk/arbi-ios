import SwiftUI
import SwiftData

@main
struct SpredApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [P2POrder.self, CapitalSettings.self, BankAccount.self])
    }
}
