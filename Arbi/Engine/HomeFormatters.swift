import Foundation

public enum HomeFormatters {
    public static func uah(_ value: Double) -> String {
        decimal(value, minimumFractionDigits: 0, maximumFractionDigits: 2) + " ₴"
    }

    public static func rate(_ value: Double) -> String {
        decimal(value, minimumFractionDigits: 2, maximumFractionDigits: 2)
    }

    public static func usdt(_ value: Double) -> String {
        decimal(value, minimumFractionDigits: 2, maximumFractionDigits: 2) + " USDT"
    }

    public static func percent(_ progress: Double) -> String {
        decimal(progress * 100, minimumFractionDigits: 1, maximumFractionDigits: 1) + "%"
    }

    public static func commissionFee(_ value: Double) -> String {
        "\(FeePreset.formatFeeAmount(value)) USDT"
    }

    public static func commissionLine(feeUSDT: Double) -> String {
        "\(LocalizationManager.shared["trades.row.commission"]): \(commissionFee(feeUSDT))"
    }

    private static func decimal(
        _ value: Double,
        minimumFractionDigits: Int,
        maximumFractionDigits: Int
    ) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: LocalizationManager.shared.currentLanguage.rawValue)
        formatter.minimumFractionDigits = minimumFractionDigits
        formatter.maximumFractionDigits = maximumFractionDigits
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }
}

public enum HomeDisplayNames {
    public static func bankAccount(_ name: String) -> String {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let openParen = trimmedName.firstIndex(of: "(") else { return trimmedName }

        let bank = trimmedName[..<openParen].trimmingCharacters(in: .whitespacesAndNewlines)
        let type = trimmedName[trimmedName.index(after: openParen)...]
            .trimmingCharacters(in: CharacterSet(charactersIn: ") "))
        guard !bank.isEmpty else { return trimmedName }
        return type.isEmpty ? bank : "\(bank) · \(type)"
    }
}
