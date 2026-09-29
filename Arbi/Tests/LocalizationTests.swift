import Foundation

/// Unit tests verifying in-app dynamic localization architecture:
/// 1. AppLanguage enum identifiers and titles
/// 2. Language switching and state updates
/// 3. String resolution for core UI strings across Ukrainian and English
/// 4. Fallback behavior for unlocalized or missing keys
@MainActor
public enum LocalizationTests {
    public static func runAllTests() throws {
        print("--- Running LocalizationTests ---")
        try testAppLanguageEnum()
        try testLanguageSwitching()
        try testCoreStringsResolution()
        try testMissingKeyFallback()
        print("--- All LocalizationTests Passed Successfully! ---")
    }

    public static func testAppLanguageEnum() throws {
        assert(AppLanguage.ukrainian.rawValue == "uk", "Ukrainian code must be 'uk'")
        assert(AppLanguage.english.rawValue == "en", "English code must be 'en'")
        assert(AppLanguage.ukrainian.title == "Українська", "Ukrainian title mismatch")
        assert(AppLanguage.english.title == "English", "English title mismatch")
        assert(AppLanguage.allCases.count == 2, "Expected 2 supported languages")
    }

    public static func testLanguageSwitching() throws {
        let manager = LocalizationManager()
        
        manager.setLanguage(.english)
        assert(manager.currentLanguage == .english, "Language should update to English")
        assert(manager["Trades"] == "Trades", "Expected English translation for Trades")

        manager.setLanguage(.ukrainian)
        assert(manager.currentLanguage == .ukrainian, "Language should update to Ukrainian")
        assert(manager["Trades"] == "Угоди", "Expected Ukrainian translation for Trades")
    }

    public static func testCoreStringsResolution() throws {
        let manager = LocalizationManager()

        // 1. Verify Ukrainian core strings
        manager.setLanguage(.ukrainian)

        // Tabs
        assert(manager["Trades"] == "Угоди", "Tabs: Trades -> Угоди")
        assert(manager["Settings"] == "Налаштування", "Tabs: Settings -> Налаштування")

        // Home Dashboard
        assert(manager["Total Net PnL"] == "Чистий прибуток", "Dashboard: Total Net PnL")
        assert(manager["Free Money"] == "Вільний капітал", "Dashboard: Free Money")
        assert(manager["Bank Turnover Limits"] == "Ліміти по банках", "Dashboard: Bank Turnover Limits")
        assert(manager["Avg Buy Price"] == "Сер. ціна купівлі", "Dashboard: Avg Buy Price")
        assert(manager["Close Month"] == "Закрити місяць", "Dashboard: Close Month")

        // Order Form
        assert(manager["Record Buy Order"] == "Записати купівлю", "Order Form: Record Buy Order")
        assert(manager["Record Sell Order"] == "Записати продаж", "Order Form: Record Sell Order")
        assert(manager["Commission / Fee"] == "Комісія", "Order Form: Commission / Fee")
        assert(manager["Bank Settlement"] == "Банк розрахунку", "Order Form: Bank Settlement")

        // Actions
        assert(manager["Cancel"] == "Скасувати", "Action: Cancel")
        assert(manager["Save"] == "Зберегти", "Action: Save")
        assert(manager["Confirm"] == "Підтвердити", "Action: Confirm")

        // 2. Verify English core strings
        manager.setLanguage(.english)

        // Tabs
        assert(manager["Trades"] == "Trades", "Tabs: Trades -> Trades")
        assert(manager["Settings"] == "Settings", "Tabs: Settings -> Settings")

        // Home Dashboard
        assert(manager["Total Net PnL"] == "Total Net PnL", "Dashboard: Total Net PnL")
        assert(manager["Free Money"] == "Free Money", "Dashboard: Free Money")
        assert(manager["Bank Turnover Limits"] == "Bank Turnover Limits", "Dashboard: Bank Turnover Limits")
        assert(manager["Avg Buy Price"] == "Avg Buy Price", "Dashboard: Avg Buy Price")
        assert(manager["Close Month"] == "Close Month", "Dashboard: Close Month")

        // Order Form
        assert(manager["Record Buy Order"] == "Record Buy Order", "Order Form: Record Buy Order")
        assert(manager["Record Sell Order"] == "Record Sell Order", "Order Form: Record Sell Order")
        assert(manager["Commission / Fee"] == "Commission / Fee", "Order Form: Commission / Fee")
        assert(manager["Bank Settlement"] == "Bank Settlement", "Order Form: Bank Settlement")

        // Actions
        assert(manager["Cancel"] == "Cancel", "Action: Cancel")
        assert(manager["Save"] == "Save", "Action: Save")
        assert(manager["Confirm"] == "Confirm", "Action: Confirm")
    }

    public static func testMissingKeyFallback() throws {
        let manager = LocalizationManager()
        manager.setLanguage(.ukrainian)

        let arbitraryKey = "NonExistentKey123"
        assert(manager[arbitraryKey] == arbitraryKey, "Missing key should fallback to key itself")
    }
}
