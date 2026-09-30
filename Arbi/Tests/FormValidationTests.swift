import Foundation

@MainActor
public enum FormValidationTests {
    public static func runAllTests() throws {
        print("--- Running FormValidationTests ---")
        try testP2POrderValidation()
        try testBankAccountValidation()
        try testCapitalSettingsValidation()
        try testCashWithdrawalValidation()
        print("--- All FormValidationTests Passed Successfully! ---")
    }

    public static func testP2POrderValidation() throws {
        let account = BankAccount(name: "MonoBank")
        let valid = P2POrderDraft(
            usdtAmount: .value(100), price: .value(41), uahAmount: .value(4_100),
            feeUSDT: .value(0), bankAccount: account
        )
        assert(P2POrderDraftValidator.validate(valid).isValid, "Valid BUY/SELL numeric values should pass")

        for value in [NumericInput.empty, .malformed, .value(0), .value(-1), .value(.infinity)] {
            let draft = P2POrderDraft(
                usdtAmount: value, price: .value(41), uahAmount: .value(4_100),
                feeUSDT: .value(0), bankAccount: account
            )
            assert(!P2POrderDraftValidator.validate(draft).isValid, "Invalid USDT input must fail")
        }

        let negativeFee = P2POrderDraft(
            usdtAmount: .value(100), price: .value(41), uahAmount: .value(4_100),
            feeUSDT: .value(-0.1), bankAccount: account
        )
        assert(!P2POrderDraftValidator.validate(negativeFee).isValid, "Negative fee must fail")

        let missingAccount = P2POrderDraft(
            usdtAmount: .value(100), price: .value(41), uahAmount: .value(4_100),
            feeUSDT: .value(0), bankAccount: nil
        )
        assert(!P2POrderDraftValidator.validate(missingAccount).isValid, "Missing account must fail")

        let archived = BankAccount(name: "Archived", isArchived: true)
        let archivedDraft = P2POrderDraft(
            usdtAmount: .value(100), price: .value(41), uahAmount: .value(4_100),
            feeUSDT: .empty, bankAccount: archived
        )
        assert(!P2POrderDraftValidator.validate(archivedDraft).isValid, "Archived account must fail")
        print("✓ testP2POrderValidation passed")
    }

    public static func testBankAccountValidation() throws {
        let valid = BankAccountDraft(name: "  Main card  ", turnoverLimitUAH: .value(150_000))
        assert(BankAccountDraftValidator.validate(valid).isValid, "Valid bank account should pass")
        assert(!BankAccountDraftValidator.validate(.init(name: "  ", turnoverLimitUAH: .value(150_000))).isValid, "Blank name must fail")
        assert(!BankAccountDraftValidator.validate(.init(name: "Main", turnoverLimitUAH: .malformed)).isValid, "Malformed limit must fail")
        assert(!BankAccountDraftValidator.validate(.init(name: "Main", turnoverLimitUAH: .value(0))).isValid, "Zero limit must fail")
        assert(!BankAccountDraftValidator.validate(.init(name: "Main", turnoverLimitUAH: .value(-1))).isValid, "Negative limit must fail")
        print("✓ testBankAccountValidation passed")
    }

    public static func testCapitalSettingsValidation() throws {
        let zeros = CapitalSettingsDraft(
            startingDepositUAH: .value(0), toCashUAH: .value(0),
            initialUSDT: .value(0), initialAvgBuyPrice: .empty
        )
        assert(CapitalSettingsDraftValidator.validate(zeros).isValid, "Legitimate zero capital should pass")

        let inventory = CapitalSettingsDraft(
            startingDepositUAH: .value(0), toCashUAH: .value(0),
            initialUSDT: .value(100), initialAvgBuyPrice: .value(41)
        )
        assert(CapitalSettingsDraftValidator.validate(inventory).isValid, "Inventory with positive cost basis should pass")

        let missingPrice = CapitalSettingsDraft(
            startingDepositUAH: .value(0), toCashUAH: .value(0),
            initialUSDT: .value(100), initialAvgBuyPrice: .empty
        )
        assert(!CapitalSettingsDraftValidator.validate(missingPrice).isValid, "Inventory requires a price")

        let orphanPrice = CapitalSettingsDraft(
            startingDepositUAH: .value(0), toCashUAH: .value(0),
            initialUSDT: .value(0), initialAvgBuyPrice: .value(41)
        )
        assert(!CapitalSettingsDraftValidator.validate(orphanPrice).isValid, "Price without inventory must fail")

        let malformed = CapitalSettingsDraft(
            startingDepositUAH: .malformed, toCashUAH: .value(0),
            initialUSDT: .value(0), initialAvgBuyPrice: .empty
        )
        assert(!CapitalSettingsDraftValidator.validate(malformed).isValid, "Malformed capital input must fail")
        print("✓ testCapitalSettingsValidation passed")
    }

    public static func testCashWithdrawalValidation() throws {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let valid = CashWithdrawalDraft(amountUAH: .value(1_000), timestamp: date)
        assert(CashWithdrawalDraftValidator.validate(valid).isValid, "Positive direct-cash withdrawal should pass")

        for value in [NumericInput.empty, .malformed, .value(0), .value(-1), .value(.infinity)] {
            assert(!CashWithdrawalDraftValidator.validate(.init(amountUAH: value, timestamp: date)).isValid, "Invalid withdrawal amount must fail")
        }
        assert(PeriodRolloverService.period(for: date).contains("."), "Withdrawal period must derive from its timestamp")
        print("✓ testCashWithdrawalValidation passed")
    }
}
