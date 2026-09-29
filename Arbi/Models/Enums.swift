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
