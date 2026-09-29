import SwiftUI

/// Root tab container providing bottom navigation bar and locale environment injection.
struct MainTabView: View {
    @AppStorage("app_language") private var selectedLanguage: AppLanguage = .ukrainian
    @State private var selectedTab: Tab = .trades

    enum Tab: Hashable {
        case trades
        case settings
    }

    init() {
        if let envLang = ProcessInfo.processInfo.environment["INITIAL_LANG"] {
            UserDefaults.standard.set(envLang, forKey: "app_language")
            _selectedLanguage = AppStorage(wrappedValue: AppLanguage(rawValue: envLang) ?? .ukrainian, "app_language")
        }
        if ProcessInfo.processInfo.environment["INITIAL_TAB"] == "settings" {
            _selectedTab = State(initialValue: .settings)
        }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            ContentView()
                .tabItem {
                    Label("nav.tab.trades", systemImage: "chart.line.uptrend.xyaxis")
                }
                .tag(Tab.trades)

            SettingsView()
                .tabItem {
                    Label("nav.tab.settings", systemImage: "gearshape.fill")
                }
                .tag(Tab.settings)
        }
        .id(selectedLanguage.rawValue) // Forces full tab bar reinit on language switch
        .environment(\.locale, Locale(identifier: selectedLanguage.rawValue))
    }
}
