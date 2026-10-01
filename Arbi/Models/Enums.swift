import Foundation

/// Transaction type for a crypto P2P trade.
public enum TransactionType: String, Codable, CaseIterable, Sendable {
    case buy = "Buy"
    case sell = "Sell"

    public var localizedKey: String {
        switch self {
        case .buy: return "order.type.buy"
        case .sell: return "order.type.sell"
        }
    }

    public var localizedTitle: String {
        switch self {
        case .buy: return LocalizationManager.shared["order.type.buy"]
        case .sell: return LocalizationManager.shared["order.type.sell"]
        }
    }
}

/// Supported crypto exchange / wallet platforms.
public enum ExchangePlatform: String, Codable, CaseIterable, Sendable {
    case binance = "Binance"
    case tgWallet = "TG Wallet"
    case bybit = "ByBit"
    case other = "Other"

    public var displayName: String {
        switch self {
        case .binance: return "Binance"
        case .tgWallet: return "TG Wallet"
        case .bybit: return "ByBit"
        case .other: return LocalizationManager.shared["common.label.other"]
        }
    }
}

/// Supported Ukrainian and international banking institutions.
public enum BankType: String, Codable, CaseIterable, Sendable {
    case monoBank = "MonoBank"
    case aBank = "A-Bank"
    case pumb = "PUMB"
    case senseBank = "Sense Bank"
    case privatBank = "PrivatBank"
    case other = "Other"
}

public extension BankType {
    /// Predefined Ukrainian banks
    static var defaultUkrainianBanks: [BankType] {
        [.monoBank, .privatBank, .aBank, .pumb, .senseBank]
    }

    /// Canonical display title for accounts of this bank
    var defaultAccountName: String {
        switch self {
        case .monoBank:
            return "MonoBank (Black)"
        case .privatBank:
            return "PrivatBank"
        case .aBank:
            return "A-Bank"
        case .pumb:
            return "PUMB"
        case .senseBank:
            return "Sense Bank"
        case .other:
            return "Other Bank"
        }
    }

    /// Default monthly turnover monitoring limit in UAH
    var defaultTurnoverLimit: Double {
        150_000.0
    }
}

/// Quick presets for order commission.
public enum FeePreset: CaseIterable, Identifiable, Equatable, Sendable {
    case custom
    case zeroPercent
    case onePercent
    case threePercent

    public var id: String { label }

    /// Single Source of Truth: numerical rate multiplier (0.01 for 1%, 0.03 for 3%, 0.0 for 0%, nil for Custom)
    public var rate: Double? {
        switch self {
        case .custom: return nil
        case .zeroPercent: return 0.0
        case .onePercent: return 0.01
        case .threePercent: return 0.03
        }
    }

    /// UI label dynamically computed from rate
    public var label: String {
        guard let rate else { return LocalizationManager.shared["order.fee.custom"] }
        let percentInt = Int((rate * 100).rounded())
        return "\(percentInt)%"
    }

    /// Resolves the exact commission in USDT for a given USDT amount and custom fee input.
    /// Preserves full Double precision without presentation rounding.
    public func resolveFeeUSDT(usdtAmount: Double, customFeeText: String) -> Double {
        if let rate {
            return max(0.0, usdtAmount * rate)
        } else {
            return max(0.0, NumericInput(text: customFeeText).value ?? 0.0)
        }
    }

    /// Determines the matching preset for an existing fee and USDT amount,
    /// returning .custom if the fee does not match standard 0%, 1%, or 3% rates.
    public static func matchingPreset(feeUSDT: Double, usdtAmount: Double) -> FeePreset {
        if feeUSDT == 0.0 {
            return .zeroPercent
        } else if usdtAmount > 0 && abs(feeUSDT - (usdtAmount * 0.01)) < 0.0000001 {
            return .onePercent
        } else if usdtAmount > 0 && abs(feeUSDT - (usdtAmount * 0.03)) < 0.0000001 {
            return .threePercent
        } else {
            return .custom
        }
    }

    /// Formats a fee amount up to 8 decimal places without trailing zeroes (e.g. 0.047755, 0.05, 0).
    public static func formatFeeAmount(_ value: Double) -> String {
        guard value > 0 else { return "0" }
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 8
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }

    /// Formats a fee value for text display up to 8 decimal places without trailing zeroes.
    public static func formatFeeForDisplay(_ value: Double) -> String {
        guard value > 0 else { return "0.0" }
        return formatFeeAmount(value)
    }
}


