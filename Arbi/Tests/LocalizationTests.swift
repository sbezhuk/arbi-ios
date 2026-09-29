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
        assert(manager["trades.stats.total_trades"] == "Всього угод", "Dashboard: Total Trades")
        assert(manager["trades.action.add_trade"] == "Додати нову угоду", "Dashboard: Add New Trade")
        assert(manager.string("trades.period.current", "09.2026") == "09.2026 (Поточний)", "Dashboard: Current Period")
        assert(manager.string("trades.stats.buy_sell_breakdown", 2, 3) == "2 Купівля · 3 Продаж", "Dashboard: Buy Sell Breakdown")
        assert(manager.string("trades.limits.sell_orders_count", 5) == "5 угод продажу", "Dashboard: Sell Orders Count")
        assert(manager.string("trades.empty.no_trades_in_period", "Вересень 2026") == "Немає угод за Вересень 2026. Натисніть +, щоб записати угоду.", "Dashboard: Empty Trades")
        assert(manager["rollover.title.close_month"] == "Закриття місяця", "Dashboard: Close Month")

        // Order Form
        assert(manager["order.title.record_buy"] == "Записати купівлю", "Order Form: Record Buy Order")
        assert(manager["order.title.record_sell"] == "Записати продаж", "Order Form: Record Sell Order")
        assert(manager["order.section.commission"] == "Комісія", "Order Form: Commission / Fee")
        assert(manager["order.section.settlement"] == "Банк розрахунку", "Order Form: Bank Settlement")
        assert(manager["order.fee.custom"] == "Власна", "Order Form: Custom Fee Preset")
        assert(manager.string("order.fee.approx_commission", "15.00") == "≈ 15.00 ₴ комісія", "Order Form: Approx Commission")
        assert(manager.string("order.label.fee_amount", 0.070) == "Fee: 0.070 USDT" || manager.string("order.label.fee_amount", 0.070).contains("0.070"), "Order Form: Fee Amount")

        // Bank Accounts & Limits
        assert(manager["bank.title.management"] == "Банківські картки", "Bank Accounts Title")
        assert(manager["bank.section.turnover_limit"] == "Ліміт обороту (UAH)", "Bank Turnover Limit Header")
        assert(manager["bank.field.limit"] == "Ліміт (₴)", "Bank Field Limit")
        assert(manager["bank.placeholder.name"] == "напр., Моно Чорна (Основна)", "Bank Name Placeholder")
        assert(manager.string("bank.section.archived_cards", 2) == "Архівовані картки (2)", "Bank Archived Cards")

        // Capital Settings
        assert(manager["capital.label.total_portfolio_equity"] == "Загальний капітал портфеля", "Capital Equity")
        assert(manager.string("capital.title.period", "09.2026") == "Капітал (09.2026)", "Capital Title")

        // Cash Withdrawals
        assert(manager["withdrawal.title.log"] == "Журнал виведень", "Withdrawal Log Title")
        assert(manager["withdrawal.title.record"] == "Записати виведення готівки", "Withdrawal Record Title")
        assert(manager["withdrawal.action.log_cash_out"] == "Записати виведення", "Withdrawal Log Action")
        assert(manager.string("withdrawal.label.total_withdrawn", "09.2026") == "Всього виведено (09.2026)", "Withdrawal Total Label")
        assert(manager.string("withdrawal.label.entries_count", 3) == "3 записів", "Withdrawal Entries Count")

        // Rollover
        assert(manager["rollover.label.current_period"] == "Поточний період", "Rollover Current Period")
        assert(manager["rollover.label.new_period"] == "Новий період", "Rollover New Period")
        assert(manager["rollover.notice.turnover_title"] == "Скидання лімітів обороту", "Rollover Turnover Title")
        assert(manager["rollover.notice.pnl_title"] == "Скидання реалізованого PnL", "Rollover PnL Title")

        // Settings
        assert(manager["settings.value.engine_name"] == "Движок P2P-арбітражу Spred", "Settings Engine Name")

        // Actions & Common
        assert(manager["common.action.cancel"] == "Скасувати", "Action: Cancel")
        assert(manager["common.action.save"] == "Зберегти", "Action: Save")
        assert(manager["common.action.confirm"] == "Підтвердити", "Action: Confirm")
        assert(manager["common.action.ok"] == "ОК", "Action: OK")
        assert(manager["common.alert.error"] == "Помилка", "Alert: Error")
        assert(manager["common.label.other"] == "Інше", "Label: Other")

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
        assert(manager["trades.stats.total_trades"] == "Total Trades", "Dashboard: Total Trades")
        assert(manager["trades.action.add_trade"] == "Add New Trade", "Dashboard: Add New Trade")
        assert(manager.string("trades.period.current", "09.2026") == "09.2026 (Current)", "Dashboard: Current Period")
        assert(manager.string("trades.stats.buy_sell_breakdown", 2, 3) == "2 Buy · 3 Sell", "Dashboard: Buy Sell Breakdown")
        assert(manager.string("trades.limits.sell_orders_count", 5) == "5 sell orders", "Dashboard: Sell Orders Count")
        assert(manager["rollover.title.close_month"] == "Close Month", "Dashboard: Close Month")

        // Order Form
        assert(manager["order.title.record_buy"] == "Record Buy Order", "Order Form: Record Buy Order")
        assert(manager["order.title.record_sell"] == "Record Sell Order", "Order Form: Record Sell Order")
        assert(manager["order.section.commission"] == "Commission / Fee", "Order Form: Commission / Fee")
        assert(manager["order.section.settlement"] == "Bank Settlement", "Order Form: Bank Settlement")
        assert(manager["order.fee.custom"] == "Custom", "Order Form: Custom Fee Preset")
        assert(manager.string("order.fee.approx_commission", "15.00") == "≈ 15.00 ₴ commission", "Order Form: Approx Commission")

        // Bank Accounts & Limits
        assert(manager["bank.title.management"] == "Bank Accounts", "Bank Accounts Title")
        assert(manager["bank.section.turnover_limit"] == "Turnover Limit (UAH)", "Bank Turnover Limit Header")
        assert(manager["bank.field.limit"] == "Limit (₴)", "Bank Field Limit")
        assert(manager["bank.placeholder.name"] == "e.g. Mono Black (Main)", "Bank Name Placeholder")
        assert(manager.string("bank.section.archived_cards", 2) == "Archived Cards (2)", "Bank Archived Cards")

        // Capital Settings
        assert(manager["capital.label.total_portfolio_equity"] == "Total Portfolio Equity", "Capital Equity")
        assert(manager.string("capital.title.period", "09.2026") == "Capital (09.2026)", "Capital Title")

        // Cash Withdrawals
        assert(manager["withdrawal.title.log"] == "Cash Out Log", "Withdrawal Log Title")
        assert(manager["withdrawal.title.record"] == "Log Cash Withdrawal", "Withdrawal Record Title")
        assert(manager["withdrawal.action.log_cash_out"] == "Log Cash Out", "Withdrawal Log Action")
        assert(manager.string("withdrawal.label.total_withdrawn", "09.2026") == "Total Withdrawn (09.2026)", "Withdrawal Total Label")
        assert(manager.string("withdrawal.label.entries_count", 3) == "3 entries", "Withdrawal Entries Count")

        // Rollover
        assert(manager["rollover.label.current_period"] == "Current Period", "Rollover Current Period")
        assert(manager["rollover.label.new_period"] == "New Period", "Rollover New Period")
        assert(manager["rollover.notice.turnover_title"] == "Turnover Limits Reset", "Rollover Turnover Title")
        assert(manager["rollover.notice.pnl_title"] == "Realized PnL Resets", "Rollover PnL Title")

        // Settings
        assert(manager["settings.value.engine_name"] == "Spred P2P Arbitrage Engine", "Settings Engine Name")

        // Actions & Common
        assert(manager["common.action.cancel"] == "Cancel", "Action: Cancel")
        assert(manager["common.action.save"] == "Save", "Action: Save")
        assert(manager["common.action.confirm"] == "Confirm", "Action: Confirm")
        assert(manager["common.action.ok"] == "OK", "Action: OK")
        assert(manager["common.alert.error"] == "Error", "Alert: Error")
        assert(manager["common.label.other"] == "Other", "Label: Other")
    }

    public static func testMissingKeyFallback() throws {
        let manager = LocalizationManager()
        manager.setLanguage(.ukrainian)

        let arbitraryKey = "NonExistentKey123"
        // NSLocalizedString returns the key itself when no translation is found
        assert(manager[arbitraryKey] == arbitraryKey, "Missing key should fallback to key itself")
    }
}
