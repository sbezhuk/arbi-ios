import Foundation
import SwiftData

@Model
public final class BankAccount {
    public var id: UUID
    public var name: String                // e.g. "Mono Black (Main)", "A-Bank Drop 1"
    public var cardNumber: String?         // Optional 16-digit or last 4 digits (e.g. "4441 •••• 1234")
    public var turnoverLimitUAH: Double    // Custom limit, e.g. 150_000.0 or 100_000.0
    public var isArchived: Bool            // For hiding inactive cards
    public var createdAt: Date

    // Relationship: all orders settled to this bank account
    @Relationship(deleteRule: .nullify, inverse: \P2POrder.bankAccount)
    public var orders: [P2POrder]?

    public init(
        id: UUID = UUID(),
        name: String,
        cardNumber: String? = nil,
        turnoverLimitUAH: Double = 150_000.0,
        isArchived: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.cardNumber = cardNumber
        self.turnoverLimitUAH = turnoverLimitUAH
        self.isArchived = isArchived
        self.createdAt = createdAt
    }
}
