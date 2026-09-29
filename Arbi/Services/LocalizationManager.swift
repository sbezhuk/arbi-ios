import SwiftUI

/// Available application languages.
public enum AppLanguage: String, CaseIterable, Identifiable {
    case ukrainian = "uk"
    case english = "en"

    public var id: String { rawValue }

    /// Display name shown in the language picker.
    public var title: String {
        switch self {
        case .ukrainian: return "Українська"
        case .english: return "English"
        }
    }
}

/// Lightweight manager responsible only for persisting the user's language preference.
/// String resolution is handled natively by SwiftUI via `.environment(\.locale)` and `Localizable.xcstrings`.
@Observable
final class LocalizationManager {

    /// Current active language, persisted to UserDefaults.
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

    /// Subscript backed by the native string catalog bundle lookup.
    /// Used by `LocalizationTests` to verify xcstrings resolution.
    subscript(_ key: String) -> String {
        key.localized(for: currentLanguage)
    }
}

// MARK: - String Extension for Bundle-Based Lookup

extension String {
    /// Resolves this string as a localization key using the given language's `.lproj` bundle,
    /// falling back to `NSLocalizedString` with the main bundle on failure.
    func localized(for language: AppLanguage) -> String {
        guard let path = Bundle.main.path(forResource: language.rawValue, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return NSLocalizedString(self, comment: "")
        }
        return NSLocalizedString(self, bundle: bundle, comment: "")
    }
}
