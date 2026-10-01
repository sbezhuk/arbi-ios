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
        try testLocalizationCatalogIntegrity()
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
        assert(manager["trades.stats.net_pnl"] == "Чистий P&L", "Dashboard: Net P&L")
        assert(manager["trades.card.free_money_bank_cards"] == "Вільний капітал (Картки)", "Dashboard: Free Money")
        assert(manager["trades.section.bank_limits"] == "Ліміти банків", "Dashboard: Bank Limits")
        assert(manager["trades.stats.avg_buy_price"] == "Сер. ціна купівлі", "Dashboard: Avg Buy Price")
        assert(manager["trades.stats.total_trades"] == "Всього угод", "Dashboard: Total Trades")
        assert(manager["trades.action.add_trade"] == "Додати нову угоду", "Dashboard: Add New Trade")
        assert(manager.string("trades.period.current", "09.2026") == "09.2026 (Поточний)", "Dashboard: Current Period")
        assert(manager.string("trades.stats.buy_sell_breakdown", 2, 3) == "2 Купівля · 3 Продаж", "Dashboard: Buy Sell Breakdown")
        assert(manager.string("trades.limits.sell_orders_count", 5) == "5 угод продажу", "Dashboard: Sell Orders Count")
        assert(manager.string("trades.empty.no_trades_in_period", "Вересень 2026") == "Немає угод за Вересень 2026. Натисніть +, щоб записати угоду.", "Dashboard: Empty Trades")
        assert(manager["rollover.title.close_month"] == "Закриття місяця", "Dashboard: Close Month")
        assert(manager["trades.row.commission"] == "Комісія", "Dashboard: Row Commission")

        // Order Form
        assert(manager["order.title.record_buy"] == "Записати купівлю", "Order Form: Record Buy Order")
        assert(manager["order.title.record_sell"] == "Записати продаж", "Order Form: Record Sell Order")
        assert(manager["order.section.commission"] == "Комісія", "Order Form: Commission / Fee")
        assert(manager["order.section.settlement"] == "Банк розрахунку", "Order Form: Bank Settlement")
        assert(manager["order.fee.custom"] == "Власна", "Order Form: Custom Fee Preset")
        assert(manager.string("order.fee.approx_commission", "15.00") == "≈ 15.00 ₴ комісія", "Order Form: Approx Commission")
        assert(manager.string("order.label.fee_amount", 0.070).contains("0.070") || manager.string("order.label.fee_amount", 0.070).contains("0,070"), "Order Form: Fee Amount")

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
        assert(manager["withdrawal.label.total_withdrawn"] == "Всього виведено", "Withdrawal Total Label")
        assert(manager.string("withdrawal.label.entries_count", 3) == "3 записів", "Withdrawal Entries Count")
        assert(manager.string("withdrawal.label.entries_count.one", 1) == "1 запис", "Withdrawal Singular Count")
        assert(manager.string("withdrawal.label.entries_count.few", 2) == "2 записи", "Withdrawal Few Count")

        // Rollover
        assert(manager["rollover.label.current_period"] == "Поточний період", "Rollover Current Period")
        assert(manager["rollover.label.new_period"] == "Новий період", "Rollover New Period")
        assert(manager["rollover.notice.turnover_title"] == "Скидання лімітів обороту", "Rollover Turnover Title")
        assert(manager["rollover.notice.pnl_title"] == "Скидання реалізованого PnL", "Rollover PnL Title")

        // Settings
        assert(manager["settings.value.engine_name"] == "Движок P2P-арбітражу Arbi" || manager["settings.value.engine_name"] == "Движок P2P-арбітражу Spred", "Settings Engine Name")

        // Actions & Common
        assert(manager["common.action.cancel"] == "Скасувати", "Action: Cancel")
        assert(manager["common.action.save"] == "Зберегти", "Action: Save")
        assert(manager["common.action.confirm"] == "Підтвердити", "Action: Confirm")
        assert(manager["common.action.ok"] == "ОК", "Action: OK")
        assert(manager["common.alert.error"] == "Помилка", "Alert: Error")
        assert(manager["common.label.other"] == "Інше", "Label: Other")
        assert(manager["sync.restore.message"] == "Відновлення ваших даних з iCloud…", "Sync restore message")

        // 2. Verify English core strings
        manager.setLanguage(.english)

        // Tabs
        assert(manager["nav.tab.trades"] == "Trades", "Tabs: Trades -> Trades")
        assert(manager["nav.tab.settings"] == "Settings", "Tabs: Settings -> Settings")

        // Home Dashboard
        assert(manager["trades.stats.net_pnl"] == "Net P&L", "Dashboard: Net P&L")
        assert(manager["trades.card.free_money_bank_cards"] == "Free Money (Bank Cards)", "Dashboard: Free Money")
        assert(manager["trades.section.bank_limits"] == "Bank Limits", "Dashboard: Bank Limits")
        assert(manager["trades.stats.avg_buy_price"] == "Avg Buy Price", "Dashboard: Avg Buy Price")
        assert(manager["trades.stats.total_trades"] == "Total Trades", "Dashboard: Total Trades")
        assert(manager["trades.action.add_trade"] == "Add New Trade", "Dashboard: Add New Trade")
        assert(manager.string("trades.period.current", "09.2026") == "09.2026 (Current)", "Dashboard: Current Period")
        assert(manager.string("trades.stats.buy_sell_breakdown", 2, 3) == "2 Buy · 3 Sell", "Dashboard: Buy Sell Breakdown")
        assert(manager.string("trades.limits.sell_orders_count", 5) == "5 sell orders", "Dashboard: Sell Orders Count")
        assert(manager["rollover.title.close_month"] == "Close Month", "Dashboard: Close Month")
        assert(manager["trades.row.commission"] == "Commission", "Dashboard: Row Commission")

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
        assert(manager["withdrawal.label.total_withdrawn"] == "Total Withdrawn", "Withdrawal Total Label")
        assert(manager.string("withdrawal.label.entries_count", 3) == "3 entries", "Withdrawal Entries Count")
        assert(manager.string("withdrawal.label.entries_count.one", 1) == "1 entry", "Withdrawal Singular Count")

        // Rollover
        assert(manager["rollover.label.current_period"] == "Current Period", "Rollover Current Period")
        assert(manager["rollover.label.new_period"] == "New Period", "Rollover New Period")
        assert(manager["rollover.notice.turnover_title"] == "Turnover Limits Reset", "Rollover Turnover Title")
        assert(manager["rollover.notice.pnl_title"] == "Realized PnL Resets", "Rollover PnL Title")

        // Settings
        assert(manager["settings.value.engine_name"] == "Arbi P2P Arbitrage Engine" || manager["settings.value.engine_name"] == "Spred P2P Arbitrage Engine", "Settings Engine Name")

        // Actions & Common
        assert(manager["common.action.cancel"] == "Cancel", "Action: Cancel")
        assert(manager["common.action.save"] == "Save", "Action: Save")
        assert(manager["common.action.confirm"] == "Confirm", "Action: Confirm")
        assert(manager["common.action.ok"] == "OK", "Action: OK")
        assert(manager["common.alert.error"] == "Error", "Alert: Error")
        assert(manager["common.label.other"] == "Other", "Label: Other")
        assert(manager["sync.restore.message"] == "Restoring your data from iCloud…", "Sync restore message")
    }

    public static func testMissingKeyFallback() throws {
        let manager = LocalizationManager()
        manager.setLanguage(.ukrainian)

        let arbitraryKey = "NonExistentKey123"
        // NSLocalizedString returns the key itself when no translation is found
        assert(manager[raw: arbitraryKey] == arbitraryKey, "Missing key should fallback to key itself")
    }

    // MARK: - Catalog Integrity Verification

    /// Blacklist of non-localizable literals that must never be auto-extracted into the String Catalog.
    private static let prohibitedLiteralKeys: Set<String> = [
        "",
        " (%@)",
        " (%lld)",
        "%@ · %@",
        "%lldk ₴",
        "(%@)",
        "0.00",
        "150000",
        "Arbi v%@",
        "UAH",
        "₴"
    ]

    /// Invariant regex validating standard `.snake_case` hierarchy: e.g., "common.action.cancel"
    private static let validKeyRegex = try! NSRegularExpression(pattern: "^[a-z]+(\\.[a-z0-9_]+)+$")

    /// Validates key naming convention, ENG/UA translation presence, and absence of prohibited literals
    /// in the underlying String Catalog without enforcing compiler-extraction parity or hardcoded counts.
    public static func testLocalizationCatalogIntegrity() throws {
        guard let catalog = try loadCatalogData() else {
            assertionFailure("Failed to locate or load Localizable.xcstrings for catalog integrity verification.")
            return
        }

        guard let strings = catalog["strings"] as? [String: Any] else {
            assertionFailure("Malformed Localizable.xcstrings: 'strings' dictionary not found.")
            return
        }

        assert(!strings.isEmpty, "Localizable.xcstrings must not be empty.")

        for (key, value) in strings {
            // Invariant 1: Prevent accidental String Catalog pollution via prohibited literal blacklist
            assert(
                !prohibitedLiteralKeys.contains(key),
                "Non-localizable literal was accidentally extracted as a localization key: \(key)"
            )

            // Invariant 2: Localization key format must follow .snake_case hierarchy
            let range = NSRange(location: 0, length: key.utf16.count)
            let isMatch = validKeyRegex.firstMatch(in: key, options: [], range: range) != nil
            assert(
                isMatch,
                "Invalid localization key format: \(key)"
            )

            // Invariant 3: ENG / UA translation parity
            guard let entry = value as? [String: Any],
                  let localizations = entry["localizations"] as? [String: Any] else {
                assertionFailure("Missing localizations container for key: \(key)")
                continue
            }

            let enTranslation = extractTranslationValue(from: localizations["en"])
            assert(
                !enTranslation.isEmpty,
                "Missing English translation for: \(key)"
            )

            let ukTranslation = extractTranslationValue(from: localizations["uk"])
            assert(
                !ukTranslation.isEmpty,
                "Missing Ukrainian translation for: \(key)"
            )
        }
    }

    private static func extractTranslationValue(from langEntry: Any?) -> String {
        guard let dict = langEntry as? [String: Any] else { return "" }
        if let stringUnit = dict["stringUnit"] as? [String: Any],
           let value = stringUnit["value"] as? String {
            return value.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return ""
    }

    private static func loadCatalogData() throws -> [String: Any]? {
        // 1. Try relative path from this source file (#filePath)
        let sourceUrl = URL(fileURLWithPath: #filePath)
        let catalogUrl = sourceUrl
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Localizable.xcstrings")

        if let data = try? Data(contentsOf: catalogUrl),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return json
        }

        // 2. Try main bundle if copied into resources
        if let bundleUrl = Bundle.main.url(forResource: "Localizable", withExtension: "xcstrings"),
           let data = try? Data(contentsOf: bundleUrl),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return json
        }

        // 3. Fallback to process working directory
        let cwdUrl = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("Arbi")
            .appendingPathComponent("Localizable.xcstrings")

        if let data = try? Data(contentsOf: cwdUrl),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return json
        }

        return nil
    }
}
