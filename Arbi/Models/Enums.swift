import Foundation

/// Transaction type for a crypto P2P trade.
public enum TransactionType: String, Codable, CaseIterable, Sendable {
    case buy = "Buy"
    case sell = "Sell"
}

/// Supported crypto exchange / wallet platforms.
public enum ExchangePlatform: String, Codable, CaseIterable, Sendable {
    case binance = "Binance"
    case tgWallet = "TG Wallet"
    case bybit = "ByBit"
    case other = "Other"
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

