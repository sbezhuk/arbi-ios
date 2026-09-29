import Foundation
import SwiftData

@Model
public final class CashWithdrawal {
    public var id: UUID
    public var amountUAH: Double
    public var timestamp: Date
    public var note: String?
    public var periodIdentifier: String // e.g. "09.2026"
    
    // Optional relationship to track which bank card the cash was drawn from
    public var bankAccount: BankAccount?

    public init(
        id: UUID = UUID(),
        amountUAH: Double,
        timestamp: Date = Date(),
        note: String? = nil,
        periodIdentifier: String = PeriodRolloverService.currentPeriodIdentifier(),
        bankAccount: BankAccount? = nil
    ) {
        self.id = id
        self.amountUAH = amountUAH
        self.timestamp = timestamp
        self.note = note
        self.periodIdentifier = periodIdentifier
        self.bankAccount = bankAccount
    }
}
