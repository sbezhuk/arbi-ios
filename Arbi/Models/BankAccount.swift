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

public extension BankAccount {
    /// Resolves the corresponding BankType based on the account name
    var bankType: BankType {
        BankType.allCases.first(where: { name.localizedCaseInsensitiveContains($0.rawValue) }) ?? .other
    }

    /// Creates a default BankAccount instance for a given BankType
    static func createDefault(for bank: BankType) -> BankAccount {
        BankAccount(
            name: bank.defaultAccountName,
            turnoverLimitUAH: bank.defaultTurnoverLimit
        )
    }

    /// Creates and persists default Ukrainian bank accounts if they don't already exist.
    /// If an existing default bank account was archived, unarchives it so it is active.
    /// Returns the newly created or restored accounts.
    @discardableResult
    static func seedDefaultUkrainianBanks(in context: ModelContext) throws -> [BankAccount] {
        let descriptor = FetchDescriptor<BankAccount>()
        let existingAccounts = try context.fetch(descriptor)

        var addedOrRestoredAccounts: [BankAccount] = []
        for bank in BankType.defaultUkrainianBanks {
            if let existing = existingAccounts.first(where: {
                $0.bankType == bank || $0.name.localizedCaseInsensitiveContains(bank.rawValue)
            }) {
                if existing.isArchived {
                    existing.isArchived = false
                    addedOrRestoredAccounts.append(existing)
                }
            } else {
                let newAccount = BankAccount.createDefault(for: bank)
                context.insert(newAccount)
                addedOrRestoredAccounts.append(newAccount)
            }
        }

        if !addedOrRestoredAccounts.isEmpty {
            try context.save()
        }

        return addedOrRestoredAccounts
    }
}

