import SwiftUI

/// Root tab container providing bottom navigation bar and dynamic localization environment.
struct MainTabView: View {
    @AppStorage("app_language") private var appLanguage: String = "uk" // Default to Ukrainian
    @State private var selectedTab: Tab = .trades
    @State private var localizationManager = LocalizationManager.shared

    enum Tab: Hashable {
        case trades
        case settings
    }

    init() {
        if let envLang = ProcessInfo.processInfo.environment["INITIAL_LANG"] {
            UserDefaults.standard.set(envLang, forKey: "app_language")
            _appLanguage = AppStorage(wrappedValue: envLang, "app_language")
        }
        if ProcessInfo.processInfo.environment["INITIAL_TAB"] == "settings" {
            _selectedTab = State(initialValue: .settings)
        }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            ContentView()
                .tabItem {
                    Label(
                        appLanguage == "uk" ? "Угоди" : "Trades",
                        systemImage: "chart.line.uptrend.xyaxis"
                    )
                }
                .tag(Tab.trades)

            SettingsView()
                .tabItem {
                    Label(
                        appLanguage == "uk" ? "Налаштування" : "Settings",
                        systemImage: "gearshape.fill"
                    )
                }
                .tag(Tab.settings)
        }
        .id(appLanguage) // Forces UITabBar geometry recalculation on language switch
        .environment(\.locale, Locale(identifier: appLanguage))
        .environment(\.localization, localizationManager)
        .onChange(of: localizationManager.currentLanguage) { _, newLang in
            if appLanguage != newLang.rawValue {
                appLanguage = newLang.rawValue
            }
        }
        .onChange(of: appLanguage) { _, newCode in
            if let lang = AppLanguage(rawValue: newCode), localizationManager.currentLanguage != lang {
                localizationManager.setLanguage(lang)
            }
        }
        .onAppear {
            if let lang = AppLanguage(rawValue: appLanguage), localizationManager.currentLanguage != lang {
                localizationManager.setLanguage(lang)
            } else if appLanguage != localizationManager.currentLanguage.rawValue {
                appLanguage = localizationManager.currentLanguage.rawValue
            }
        }
    }
}
