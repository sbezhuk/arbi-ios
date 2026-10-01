import Foundation

@MainActor
public enum FormValidationTests {
    public static func runAllTests() throws {
        print("--- Running FormValidationTests ---")
        try testP2POrderValidation()
        try testBankAccountValidation()
        try testCapitalSettingsValidation()
        try testCashWithdrawalValidation()
        try testSectionValidationGrouping()
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

    public static func testSectionValidationGrouping() throws {
        // 1. One missing required field → Fill in the required fields.
        let singleMissingFieldAccount = BankAccountDraft(name: "", turnoverLimitUAH: .value(150_000))
        let accountResult = BankAccountDraftValidator.validate(singleMissingFieldAccount)
        let singleRequiredMessage = accountResult.sectionErrorMessages(for: ["name"])
        assert(
            singleRequiredMessage == ["validation.required_fields"],
            "One missing required field must display 'Fill in the required fields.'"
        )

        let withdrawalMissingAmount = CashWithdrawalDraft(amountUAH: .empty, timestamp: Date())
        let withdrawalResult = CashWithdrawalDraftValidator.validate(withdrawalMissingAmount)
        assert(
            withdrawalResult.sectionErrorMessages(for: ["amount"]) == ["validation.required_fields"],
            "Single missing withdrawal amount must display 'Fill in the required fields.'"
        )

        // Missing bank account selection in order draft
        let missingAccountOrder = P2POrderDraft(
            usdtAmount: .value(100),
            price: .value(41),
            uahAmount: .value(4100),
            feeUSDT: .value(0),
            bankAccount: nil
        )
        let missingAccountResult = P2POrderDraftValidator.validate(missingAccountOrder)
        assert(
            missingAccountResult.sectionErrorMessages(for: ["bank_account"]) == ["validation.required_fields"],
            "Missing bank account selection must display 'Fill in the required fields.'"
        )

        // 2. Multiple missing required fields → exactly one Fill in the required fields.
        let emptyOrder = P2POrderDraft(
            usdtAmount: .empty,
            price: .empty,
            uahAmount: .empty,
            feeUSDT: .empty,
            bankAccount: nil
        )
        let orderResult = P2POrderDraftValidator.validate(emptyOrder)
        let amountsMessages = orderResult.sectionErrorMessages(for: ["usdt", "price", "uah"])
        assert(
            amountsMessages == ["validation.required_fields"],
            "Multiple missing required fields must yield exactly one 'Fill in the required fields.' message"
        )

        // 3. Duplicate required issues & mixed required + rule failures → exactly one message
        let mixedOrder = P2POrderDraft(
            usdtAmount: .malformed,
            price: .empty,
            uahAmount: .empty,
            feeUSDT: .empty,
            bankAccount: BankAccount(name: "Mono")
        )
        let mixedResult = P2POrderDraftValidator.validate(mixedOrder)
        let mixedMessages = mixedResult.sectionErrorMessages(for: ["usdt", "price", "uah"])
        assert(
            mixedMessages == ["validation.required_fields"],
            "Section containing invalid required fields must render only 'Fill in the required fields.' without stacking secondary failures"
        )

        // In Capital Settings: missing required initialUSDT with price entered
        let missingUsdtWithPrice = CapitalSettingsDraft(
            startingDepositUAH: .value(10000),
            toCashUAH: .value(0),
            initialUSDT: .empty,
            initialAvgBuyPrice: .value(41)
        )
        let missingUsdtResult = CapitalSettingsDraftValidator.validate(missingUsdtWithPrice)
        let capitalInventoryMessages = missingUsdtResult.sectionErrorMessages(for: ["initial_usdt", "initial_avg_price"])
        assert(
            capitalInventoryMessages == ["validation.required_fields"],
            "Missing required initial USDT with price entered must render only 'Fill in the required fields.' instead of stacking rule messages"
        )

        // Duplicate required issues manually verified
        let duplicateIssuesResult = FormValidationResult(issues: [
            .init(field: "a", messageKey: "validation.required"),
            .init(field: "b", messageKey: "validation.required"),
            .init(field: "c", messageKey: "validation.required")
        ])
        assert(
            duplicateIssuesResult.sectionErrorMessages(for: ["a", "b", "c"]) == ["validation.required_fields"],
            "Duplicate required issues must yield exactly one message"
        )

        // 4. Internal detailed validation issues remain available to validation/business logic
        assert(!orderResult.isValid, "Form validation result must remain invalid")
        assert(orderResult.issues.count == 4, "Internal issues list must retain all detailed field-level issues")
        assert(orderResult.issue(for: "usdt")?.messageKey == "validation.required", "Internal issue for usdt must be preserved")
        assert(orderResult.issue(for: "price")?.messageKey == "validation.required", "Internal issue for price must be preserved")
        assert(orderResult.issue(for: "uah")?.messageKey == "validation.required", "Internal issue for uah must be preserved")
        assert(orderResult.issue(for: "bank_account")?.messageKey == "validation.bank_account_required", "Internal issue for bank_account must be preserved")

        assert(mixedResult.issue(for: "usdt")?.messageKey == "validation.invalid_number", "Internal malformed number issue must be preserved")
        assert(missingUsdtResult.issue(for: "initial_avg_price")?.messageKey == "validation.initial_price_without_inventory",
               "Internal business rule failure must remain intact in issues list")

        // 5. Valid section returns empty list
        let validOrder = P2POrderDraft(
            usdtAmount: .value(100),
            price: .value(41),
            uahAmount: .value(4100),
            feeUSDT: .value(0),
            bankAccount: BankAccount(name: "Mono")
        )
        let validResult = P2POrderDraftValidator.validate(validOrder)
        assert(validResult.sectionErrorMessages(for: ["usdt", "price", "uah"]).isEmpty, "Valid section must return empty messages")

        // 6. When no required fields are missing, specific non-required value errors are presented concisely
        let orphanPriceWithoutMissingRequired = CapitalSettingsDraft(
            startingDepositUAH: .value(10000),
            toCashUAH: .value(0),
            initialUSDT: .value(0),
            initialAvgBuyPrice: .value(41)
        )
        let orphanPriceResult = CapitalSettingsDraftValidator.validate(orphanPriceWithoutMissingRequired)
        assert(
            orphanPriceResult.sectionErrorMessages(for: ["initial_usdt", "initial_avg_price"]) == ["validation.initial_price_without_inventory"],
            "Specific value errors when no required fields are missing must be displayed concisely"
        )

        print("✓ testSectionValidationGrouping passed")
    }
}
