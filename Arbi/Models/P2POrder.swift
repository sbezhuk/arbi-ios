import Foundation
import SwiftData

@Model
public final class P2POrder {
    public var id: UUID
    public var type: TransactionType
    public var usdtAmount: Double
    public var price: Double
    public var uahAmount: Double
    public var feeUSDT: Double
    public var txFeeUSDT: Double
    public var platform: ExchangePlatform
    public var bank: BankType
    public var bankAccount: BankAccount?
    public var timestamp: Date
    public var note: String?

    public init(
        id: UUID = UUID(),
        type: TransactionType = .buy,
        usdtAmount: Double = 0.0,
        price: Double = 0.0,
        uahAmount: Double = 0.0,
        feeUSDT: Double = 0.0,
        txFeeUSDT: Double = 0.0,
        platform: ExchangePlatform = .binance,
        bank: BankType = .monoBank,
        bankAccount: BankAccount? = nil,
        timestamp: Date = Date(),
        note: String? = nil
    ) {
        self.id = id
        self.type = type
        self.usdtAmount = usdtAmount
        self.price = price
        self.uahAmount = uahAmount
        self.feeUSDT = feeUSDT
        self.txFeeUSDT = txFeeUSDT
        self.platform = platform
        self.bank = bank
        self.bankAccount = bankAccount
        self.timestamp = timestamp
        self.note = note
    }
}
