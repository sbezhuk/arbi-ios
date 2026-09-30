import Foundation

/// A numeric form value that preserves the distinction between missing,
/// malformed, and valid numeric input until business validation is complete.
public enum NumericInput: Equatable, Sendable {
    case empty
    case malformed
    case value(Double)

    public init(text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            self = .empty
            return
        }

        let normalized = trimmed.replacingOccurrences(of: ",", with: ".")
        guard let value = Double(normalized) else {
            self = .malformed
            return
        }
        self = .value(value)
    }

    public var value: Double? {
        guard case let .value(value) = self else { return nil }
        return value
    }
}

public struct FieldValidationIssue: Equatable, Sendable {
    public let field: String
    public let messageKey: String

    public init(field: String, messageKey: String) {
        self.field = field
        self.messageKey = messageKey
    }
}

public struct FormValidationResult: Equatable, Sendable {
    public let issues: [FieldValidationIssue]

    public init(issues: [FieldValidationIssue] = []) {
        self.issues = issues
    }

    public var isValid: Bool { issues.isEmpty }

    public func issue(for field: String) -> FieldValidationIssue? {
        issues.first { $0.field == field }
    }
}

public struct P2POrderDraft {
    public let usdtAmount: NumericInput
    public let price: NumericInput
    public let uahAmount: NumericInput
    public let feeUSDT: NumericInput
    public let bankAccount: BankAccount?

    public init(
        usdtAmount: NumericInput,
        price: NumericInput,
        uahAmount: NumericInput,
        feeUSDT: NumericInput,
        bankAccount: BankAccount?
    ) {
        self.usdtAmount = usdtAmount
        self.price = price
        self.uahAmount = uahAmount
        self.feeUSDT = feeUSDT
        self.bankAccount = bankAccount
    }
}

public enum P2POrderDraftValidator {
    public static func validate(_ draft: P2POrderDraft) -> FormValidationResult {
        var issues: [FieldValidationIssue] = []
        validatePositive(draft.usdtAmount, field: "usdt", issues: &issues)
        validatePositive(draft.price, field: "price", issues: &issues)
        validatePositive(draft.uahAmount, field: "uah", issues: &issues)

        switch draft.feeUSDT {
        case .empty:
            break
        case .malformed:
            issues.append(.init(field: "fee", messageKey: "validation.invalid_number"))
        case let .value(value):
            if !value.isFinite {
                issues.append(.init(field: "fee", messageKey: "validation.must_be_finite"))
            } else if value < 0 {
                issues.append(.init(field: "fee", messageKey: "validation.must_be_non_negative"))
            }
        }

        guard let bankAccount = draft.bankAccount else {
            issues.append(.init(field: "bank_account", messageKey: "validation.bank_account_required"))
            return FormValidationResult(issues: issues)
        }
        if bankAccount.isArchived {
            issues.append(.init(field: "bank_account", messageKey: "validation.bank_account_archived"))
        }
        return FormValidationResult(issues: issues)
    }

    private static func validatePositive(
        _ input: NumericInput,
        field: String,
        issues: inout [FieldValidationIssue]
    ) {
        switch input {
        case .empty:
            issues.append(.init(field: field, messageKey: "validation.required"))
        case .malformed:
            issues.append(.init(field: field, messageKey: "validation.invalid_number"))
        case let .value(value):
            if !value.isFinite {
                issues.append(.init(field: field, messageKey: "validation.must_be_finite"))
            } else if value <= 0 {
                issues.append(.init(field: field, messageKey: "validation.must_be_positive"))
            }
        }
    }
}

public struct BankAccountDraft {
    public let name: String
    public let turnoverLimitUAH: NumericInput

    public init(name: String, turnoverLimitUAH: NumericInput) {
        self.name = name
        self.turnoverLimitUAH = turnoverLimitUAH
    }
}

public enum BankAccountDraftValidator {
    public static func validate(_ draft: BankAccountDraft) -> FormValidationResult {
        var issues: [FieldValidationIssue] = []
        if draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(.init(field: "name", messageKey: "validation.required"))
        }
        validatePositive(draft.turnoverLimitUAH, field: "limit", issues: &issues)
        return FormValidationResult(issues: issues)
    }

    private static func validatePositive(
        _ input: NumericInput,
        field: String,
        issues: inout [FieldValidationIssue]
    ) {
        switch input {
        case .empty:
            issues.append(.init(field: field, messageKey: "validation.required"))
        case .malformed:
            issues.append(.init(field: field, messageKey: "validation.invalid_number"))
        case let .value(value):
            if !value.isFinite {
                issues.append(.init(field: field, messageKey: "validation.must_be_finite"))
            } else if value <= 0 {
                issues.append(.init(field: field, messageKey: "validation.must_be_positive"))
            }
        }
    }
}

public struct CapitalSettingsDraft {
    public let startingDepositUAH: NumericInput
    public let toCashUAH: NumericInput
    public let initialUSDT: NumericInput
    public let initialAvgBuyPrice: NumericInput

    public init(
        startingDepositUAH: NumericInput,
        toCashUAH: NumericInput,
        initialUSDT: NumericInput,
        initialAvgBuyPrice: NumericInput
    ) {
        self.startingDepositUAH = startingDepositUAH
        self.toCashUAH = toCashUAH
        self.initialUSDT = initialUSDT
        self.initialAvgBuyPrice = initialAvgBuyPrice
    }
}

public enum CapitalSettingsDraftValidator {
    public static func validate(_ draft: CapitalSettingsDraft) -> FormValidationResult {
        var issues: [FieldValidationIssue] = []
        validateNonNegative(draft.startingDepositUAH, field: "deposit", issues: &issues)
        validateNonNegative(draft.toCashUAH, field: "to_cash", issues: &issues)
        validateNonNegative(draft.initialUSDT, field: "initial_usdt", issues: &issues)

        switch draft.initialUSDT {
        case .empty:
            validateWithoutInventory(draft.initialAvgBuyPrice, issues: &issues)
        case .malformed:
            break
        case let .value(initialUSDT) where initialUSDT.isFinite && initialUSDT > 0:
            validatePositive(draft.initialAvgBuyPrice, field: "initial_avg_price", issues: &issues)
        case let .value(initialUSDT) where initialUSDT.isFinite && initialUSDT == 0:
            validateWithoutInventory(draft.initialAvgBuyPrice, issues: &issues)
        case .value:
            break
        }
        return FormValidationResult(issues: issues)
    }

    private static func validateWithoutInventory(
        _ input: NumericInput,
        issues: inout [FieldValidationIssue]
    ) {
        switch input {
        case .empty:
            break
        case .malformed:
            issues.append(.init(field: "initial_avg_price", messageKey: "validation.invalid_number"))
        case let .value(value):
            if !value.isFinite {
                issues.append(.init(field: "initial_avg_price", messageKey: "validation.must_be_finite"))
            } else if value > 0 {
                issues.append(.init(field: "initial_avg_price", messageKey: "validation.initial_price_without_inventory"))
            } else if value < 0 {
                issues.append(.init(field: "initial_avg_price", messageKey: "validation.must_be_non_negative"))
            }
        }
    }

    private static func validateNonNegative(
        _ input: NumericInput,
        field: String,
        issues: inout [FieldValidationIssue]
    ) {
        switch input {
        case .empty:
            issues.append(.init(field: field, messageKey: "validation.required"))
        case .malformed:
            issues.append(.init(field: field, messageKey: "validation.invalid_number"))
        case let .value(value):
            if !value.isFinite {
                issues.append(.init(field: field, messageKey: "validation.must_be_finite"))
            } else if value < 0 {
                issues.append(.init(field: field, messageKey: "validation.must_be_non_negative"))
            }
        }
    }

    private static func validatePositive(
        _ input: NumericInput,
        field: String,
        issues: inout [FieldValidationIssue]
    ) {
        switch input {
        case .empty:
            issues.append(.init(field: field, messageKey: "validation.required"))
        case .malformed:
            issues.append(.init(field: field, messageKey: "validation.invalid_number"))
        case let .value(value):
            if !value.isFinite {
                issues.append(.init(field: field, messageKey: "validation.must_be_finite"))
            } else if value <= 0 {
                issues.append(.init(field: field, messageKey: "validation.must_be_positive"))
            }
        }
    }
}

public struct CashWithdrawalDraft {
    public let amountUAH: NumericInput
    public let timestamp: Date

    public init(amountUAH: NumericInput, timestamp: Date) {
        self.amountUAH = amountUAH
        self.timestamp = timestamp
    }
}

public enum CashWithdrawalDraftValidator {
    public static func validate(_ draft: CashWithdrawalDraft) -> FormValidationResult {
        var issues: [FieldValidationIssue] = []
        switch draft.amountUAH {
        case .empty:
            issues.append(.init(field: "amount", messageKey: "validation.required"))
        case .malformed:
            issues.append(.init(field: "amount", messageKey: "validation.invalid_number"))
        case let .value(value):
            if !value.isFinite {
                issues.append(.init(field: "amount", messageKey: "validation.must_be_finite"))
            } else if value <= 0 {
                issues.append(.init(field: "amount", messageKey: "validation.must_be_positive"))
            }
        }
        return FormValidationResult(issues: issues)
    }
}
