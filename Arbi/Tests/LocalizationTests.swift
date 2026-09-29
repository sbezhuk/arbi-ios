import Foundation

/// Unit tests verifying the native localization architecture:
/// 1. AppLanguage enum identifiers and display names
/// 2. Language switching and state updates
/// 3. String resolution for core UI strings via Localizable.xcstrings bundle lookup
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
        assert(manager["nav.tab.trades"] == "Trades", "Expected English translation for Trades")

        manager.setLanguage(.ukrainian)
        assert(manager.currentLanguage == .ukrainian, "Language should update to Ukrainian")
        assert(manager["nav.tab.trades"] == "Угоди", "Expected Ukrainian translation for Trades")
    }

    public static func testCoreStringsResolution() throws {
        let manager = LocalizationManager()

        // 1. Verify Ukrainian core strings
        manager.setLanguage(.ukrainian)

        // Tabs
        assert(manager["nav.tab.trades"] == "Угоди", "Tabs: Trades -> Угоди")
        assert(manager["nav.tab.settings"] == "Налаштування", "Tabs: Settings -> Налаштування")

        // Home Dashboard
        assert(manager["trades.stats.net_pnl"] == "Чистий прибуток", "Dashboard: Total Net PnL")
        assert(manager["trades.card.free_money"] == "Вільний капітал", "Dashboard: Free Money")
        assert(manager["trades.section.bank_limits"] == "Ліміти по банках", "Dashboard: Bank Turnover Limits")
        assert(manager["trades.stats.avg_buy_price"] == "Сер. ціна купівлі", "Dashboard: Avg Buy Price")
        assert(manager["rollover.title.close_month"] == "Закриття місяця", "Dashboard: Close Month")

        // Order Form
        assert(manager["order.title.record_buy"] == "Записати купівлю", "Order Form: Record Buy Order")
        assert(manager["order.title.record_sell"] == "Записати продаж", "Order Form: Record Sell Order")
        assert(manager["order.section.commission"] == "Комісія", "Order Form: Commission / Fee")
        assert(manager["order.section.settlement"] == "Банк розрахунку", "Order Form: Bank Settlement")

        // Actions
        assert(manager["common.action.cancel"] == "Скасувати", "Action: Cancel")
        assert(manager["common.action.save"] == "Зберегти", "Action: Save")
        assert(manager["common.action.confirm"] == "Підтвердити", "Action: Confirm")

        // 2. Verify English core strings
        manager.setLanguage(.english)

        // Tabs
        assert(manager["nav.tab.trades"] == "Trades", "Tabs: Trades -> Trades")
        assert(manager["nav.tab.settings"] == "Settings", "Tabs: Settings -> Settings")

        // Home Dashboard
        assert(manager["trades.stats.net_pnl"] == "Total Net PnL", "Dashboard: Total Net PnL")
        assert(manager["trades.card.free_money"] == "Free Money", "Dashboard: Free Money")
        assert(manager["trades.section.bank_limits"] == "Bank Turnover Limits", "Dashboard: Bank Turnover Limits")
        assert(manager["trades.stats.avg_buy_price"] == "Avg Buy Price", "Dashboard: Avg Buy Price")
        assert(manager["rollover.title.close_month"] == "Close Month", "Dashboard: Close Month")

        // Order Form
        assert(manager["order.title.record_buy"] == "Record Buy Order", "Order Form: Record Buy Order")
        assert(manager["order.title.record_sell"] == "Record Sell Order", "Order Form: Record Sell Order")
        assert(manager["order.section.commission"] == "Commission / Fee", "Order Form: Commission / Fee")
        assert(manager["order.section.settlement"] == "Bank Settlement", "Order Form: Bank Settlement")

        // Actions
        assert(manager["common.action.cancel"] == "Cancel", "Action: Cancel")
        assert(manager["common.action.save"] == "Save", "Action: Save")
        assert(manager["common.action.confirm"] == "Confirm", "Action: Confirm")
    }

    public static func testMissingKeyFallback() throws {
        let manager = LocalizationManager()
        manager.setLanguage(.ukrainian)

        let arbitraryKey = "NonExistentKey123"
        // NSLocalizedString returns the key itself when no translation is found
        assert(manager[arbitraryKey] == arbitraryKey, "Missing key should fallback to key itself")
    }
}
