import SwiftUI

/// Available application languages.
enum AppLanguage: String, CaseIterable, Identifiable {
    case ukrainian = "uk"
    case english = "en"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .ukrainian: return "Українська"
        case .english: return "English"
        }
    }
}

/// Dynamic observable manager providing in-app language switching and localized string resolution.
@Observable
final class LocalizationManager {
    static let shared = LocalizationManager()

    /// Current active language.
    var currentLanguage: AppLanguage {
        didSet {
            UserDefaults.standard.set(currentLanguage.rawValue, forKey: "app_language")
        }
    }

    init() {
        let envLang = ProcessInfo.processInfo.environment["INITIAL_LANG"]
        let savedCode = envLang ?? UserDefaults.standard.string(forKey: "app_language") ?? AppLanguage.ukrainian.rawValue
        self.currentLanguage = AppLanguage(rawValue: savedCode) ?? .ukrainian
    }

    /// Set language dynamically.
    func setLanguage(_ language: AppLanguage) {
        currentLanguage = language
    }

    /// Retrieve localized string for the specified key using the current language.
    func string(for key: String) -> String {
        guard let translations = Self.translations[key] else {
            return key
        }
        return translations[currentLanguage] ?? key
    }

    /// Subscript access for convenience.
    subscript(_ key: String) -> String {
        string(for: key)
    }

    // MARK: - Core Translations Dictionary

    private static let translations: [String: [AppLanguage: String]] = [
        // Tabs
        "Trades": [.english: "Trades", .ukrainian: "Угоди"],
        "Settings": [.english: "Settings", .ukrainian: "Налаштування"],

        // Home Dashboard
        "Spread Arbitrage": [.english: "Spread Arbitrage", .ukrainian: "P2P Арбітраж"],
        "Total Net PnL": [.english: "Total Net PnL", .ukrainian: "Чистий прибуток"],
        "Free Money": [.english: "Free Money", .ukrainian: "Вільний капітал"],
        "Free Money (Bank Cards)": [.english: "Free Money (Bank Cards)", .ukrainian: "Вільний капітал (Картки)"],
        "Bank Turnover Limits": [.english: "Bank Turnover Limits", .ukrainian: "Ліміти по банках"],
        "Avg Buy Price": [.english: "Avg Buy Price", .ukrainian: "Сер. ціна купівлі"],
        "Close Month": [.english: "Close Month", .ukrainian: "Закрити місяць"],
        "Month Roll-Over...": [.english: "Month Roll-Over...", .ukrainian: "Закриття місяця..."],
        "Calendar Month": [.english: "Calendar Month", .ukrainian: "Календарний місяць"],
        "Recent Transactions": [.english: "Recent Transactions", .ukrainian: "Останні операції"],
        "No Transactions": [.english: "No Transactions", .ukrainian: "Немає операцій"],
        "Add Sample Trades": [.english: "Add Sample Trades", .ukrainian: "Додати зразки угод"],
        "Starting Deposit": [.english: "Starting Deposit", .ukrainian: "Початковий депозит"],
        "Cash Out": [.english: "Cash Out", .ukrainian: "Виведення готівки"],
        "USDT Inventory": [.english: "USDT Inventory", .ukrainian: "Залишок USDT"],
        "Total Trades": [.english: "Total Trades", .ukrainian: "Всього угод"],
        "per 1 USDT": [.english: "per 1 USDT", .ukrainian: "за 1 USDT"],
        "Configure": [.english: "Configure", .ukrainian: "Налаштувати"],
        "Roll-Over": [.english: "Roll-Over", .ukrainian: "Перенести"],
        "No bank accounts added yet.": [.english: "No bank accounts added yet.", .ukrainian: "Банківські картки ще не додані."],

        // Order Form
        "Record Buy Order": [.english: "Record Buy Order", .ukrainian: "Записати купівлю"],
        "Record Sell Order": [.english: "Record Sell Order", .ukrainian: "Записати продаж"],
        "Commission / Fee": [.english: "Commission / Fee", .ukrainian: "Комісія"],
        "Bank Settlement": [.english: "Bank Settlement", .ukrainian: "Банк розрахунку"],
        "Exchange / Platform": [.english: "Exchange / Platform", .ukrainian: "Біржа / Платформа"],
        "Trade Amounts & Rate": [.english: "Trade Amounts & Rate", .ukrainian: "Суми угоди та курс"],
        "Date & Time": [.english: "Date & Time", .ukrainian: "Дата та час"],
        "Details & Note": [.english: "Details & Note", .ukrainian: "Деталі та примітка"],
        "Fee (USDT)": [.english: "Fee (USDT)", .ukrainian: "Комісія (USDT)"],
        "Price (UAH)": [.english: "Price (UAH)", .ukrainian: "Ціна (UAH)"],
        "Total UAH": [.english: "Total UAH", .ukrainian: "Всього UAH"],
        "Order Type": [.english: "Order Type", .ukrainian: "Тип ордера"],
        "Add Bank Account": [.english: "Add Bank Account", .ukrainian: "Додати банківський рахунок"],
        "Add Bank": [.english: "Add Bank", .ukrainian: "Додати банк"],
        "Optional trade note / counterparty": [.english: "Optional trade note / counterparty", .ukrainian: "Примітка / контрагент"],

        // Actions
        "Cancel": [.english: "Cancel", .ukrainian: "Скасувати"],
        "Save": [.english: "Save", .ukrainian: "Зберегти"],
        "Confirm": [.english: "Confirm", .ukrainian: "Підтвердити"],
        "Done": [.english: "Done", .ukrainian: "Готово"],
        "Add": [.english: "Add", .ukrainian: "Додати"],
        "Manage": [.english: "Manage", .ukrainian: "Керувати"],
        "Delete": [.english: "Delete", .ukrainian: "Видалити"],
        "Archive": [.english: "Archive", .ukrainian: "Архівувати"],
        "Unarchive": [.english: "Unarchive", .ukrainian: "Розархівувати"],

        // Settings Screen
        "Language": [.english: "Language", .ukrainian: "Мова"],
        "Language / Мова": [.english: "Language / Мова", .ukrainian: "Мова / Language"],
        "Data & Export": [.english: "Data & Export", .ukrainian: "Дані та експорт"],
        "Export to CSV": [.english: "Export to CSV", .ukrainian: "Експорт у CSV"],
        "Coming Soon": [.english: "Coming Soon", .ukrainian: "Незабаром"],
        "App Information": [.english: "App Information", .ukrainian: "Про застосунок"],
        "Version": [.english: "Version", .ukrainian: "Версія"],
        "Build": [.english: "Build", .ukrainian: "Збірка"],
        "Engine": [.english: "Engine", .ukrainian: "Двигун розрахунків"],
        "Developer": [.english: "Developer", .ukrainian: "Розробник"],
        "Spred P2P Arbitrage Engine": [.english: "Spred P2P Arbitrage Engine", .ukrainian: "Двигун P2P арбітражу Spred"]
    ]
}

// MARK: - SwiftUI Environment Key

private struct LocalizationManagerKey: EnvironmentKey {
    static let defaultValue: LocalizationManager = LocalizationManager.shared
}

extension EnvironmentValues {
    var localization: LocalizationManager {
        get { self[LocalizationManagerKey.self] }
        set { self[LocalizationManagerKey.self] = newValue }
    }
}
