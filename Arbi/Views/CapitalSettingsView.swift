import SwiftUI
import SwiftData

/// Modal sheet for managing starting working deposit, cash out, and reviewing liquid capital.
struct CapitalSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var periodIdentifier: String = PeriodRolloverService.currentPeriodIdentifier()

    @Query private var settingsList: [CapitalSettings]
    @Query(sort: \P2POrder.timestamp, order: .reverse) private var orders: [P2POrder]
    @Query(sort: \CashWithdrawal.timestamp, order: .reverse) private var withdrawals: [CashWithdrawal]

    @State private var depositText: String = ""
    @State private var toCashText: String = ""
    @State private var initialUSDTText: String = ""
    @State private var initialAvgBuyPriceText: String = ""
    @State private var attemptedSave: Bool = false
    @State private var errorMessage: String?
    @State private var showingErrorAlert: Bool = false

    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case deposit
        case toCash
        case initialUSDT
        case initialAvgBuyPrice
    }

    private var activeSettings: CapitalSettings? {
        CapitalSettings.settings(for: periodIdentifier, in: settingsList)
    }

    private var parsedDeposit: Double {
        parseDouble(depositText)
    }

    private var parsedToCash: Double {
        parseDouble(toCashText)
    }

    private var parsedInitialUSDT: Double {
        parseDouble(initialUSDTText)
    }

    private var parsedInitialAvgBuyPrice: Double {
        parseDouble(initialAvgBuyPriceText)
    }

    private var validationResult: FormValidationResult {
        CapitalSettingsDraftValidator.validate(
            CapitalSettingsDraft(
                startingDepositUAH: NumericInput(text: depositText),
                toCashUAH: NumericInput(text: toCashText),
                initialUSDT: NumericInput(text: initialUSDTText),
                initialAvgBuyPrice: NumericInput(text: initialAvgBuyPriceText)
            )
        )
    }

    private var simulatedSettings: CapitalSettings {
        CapitalSettings(
            startingDepositUAH: parsedDeposit,
            toCashUAH: parsedToCash,
            initialUSDT: parsedInitialUSDT,
            initialAvgBuyPrice: parsedInitialAvgBuyPrice,
            periodIdentifier: periodIdentifier,
            lastUpdated: Date()
        )
    }

    private var periodOrders: [P2POrder] {
        PeriodRolloverService.ordersForPeriod(periodIdentifier, orders: orders)
    }

    private var periodWithdrawals: [CashWithdrawal] {
        PeriodRolloverService.withdrawalsForPeriod(periodIdentifier, withdrawals: withdrawals)
    }

    private var breakdown: CapitalBreakdown {
        P2PCalculator.calculateCapitalBreakdown(
            orders: periodOrders,
            settings: simulatedSettings,
            withdrawals: periodWithdrawals
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                    // Section 1: Real-time Capital Simulation Card
                    Section {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("rollover.label.free_uah")
                                .font(.caption.weight(.regular))
                                .foregroundStyle(.secondary)

                            Text(formatCurrency(breakdown.freeUAH) + " ₴")
                                .font(.system(size: 22, weight: .semibold, design: .rounded))
                                .foregroundStyle(breakdown.freeUAH >= 0 ? Color.green : Color.red)

                            Divider()

                            HStack {
                                VStack(alignment: .leading, spacing: 1) {
                                    Text("rollover.label.unliquidated_usdt")
                                        .font(.caption2.weight(.regular))
                                        .foregroundStyle(.secondary)
                                    Text(String(format: "%.2f USDT", breakdown.remainingUSDT))
                                        .font(.footnote.weight(.medium).monospacedDigit())
                                }

                                Spacer()

                                VStack(alignment: .trailing, spacing: 1) {
                                    Text("capital.label.total_portfolio_equity")
                                        .font(.caption2.weight(.regular))
                                        .foregroundStyle(.secondary)
                                    Text(formatCurrency(breakdown.totalEquityUAH) + " ₴")
                                        .font(.footnote.weight(.medium).monospacedDigit())
                                }
                            }
                        }
                        .padding(.vertical, 4)
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    }

                    // Section 2: Initial Working Deposit
                    Section {
                        HStack {
                            FormRowLabel(
                                title: "trades.card.starting_deposit",
                                systemImage: "banknote.fill",
                                color: .green,
                                required: true
                            )

                            Spacer(minLength: 8)

                            TextField(String(""), text: $depositText, prompt: Text(verbatim: "0.00"))
                                .keyboardType(.decimalPad)
                                .focused($focusedField, equals: .deposit)
                                .multilineTextAlignment(.trailing)
                                .font(.body.weight(.regular).monospacedDigit())
                        }
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))

                        // Quick deposit presets
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach([50_000, 100_000, 150_000, 200_000, 300_000], id: \.self) { amount in
                                    Button {
                                        depositText = "\(amount)"
                                    } label: {
                                        Text(verbatim: "\(amount / 1000)k ₴")
                                    }
                                    .font(.caption.weight(.medium))
                                    .buttonStyle(.bordered)
                                    .tint(.green)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    } header: {
                        Text("capital.label.starting_working_capital")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                    } footer: {
                        SectionValidationFooter(
                            result: validationResult,
                            field: "deposit",
                            isVisible: attemptedSave,
                            helperText: "capital.footer.starting_deposit"
                        )
                    }

                    // Section 3: Initial Crypto Inventory
                    Section {
                        HStack {
                            FormRowLabel(
                                title: "capital.field.initial_usdt",
                                systemImage: "dollarsign.circle.fill",
                                color: .green,
                                required: true
                            )

                            Spacer(minLength: 8)

                            TextField(String(""), text: $initialUSDTText, prompt: Text(verbatim: "0.00"))
                                .keyboardType(.decimalPad)
                                .focused($focusedField, equals: .initialUSDT)
                                .multilineTextAlignment(.trailing)
                                .font(.body.weight(.regular).monospacedDigit())
                        }
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))

                        HStack {
                            FormRowLabel(
                                title: "capital.field.avg_buy_rate",
                                systemImage: "chart.line.uptrend.xyaxis",
                                color: .blue
                            )

                            Spacer(minLength: 8)

                            TextField(String(""), text: $initialAvgBuyPriceText, prompt: Text(verbatim: "0.00"))
                                .keyboardType(.decimalPad)
                                .focused($focusedField, equals: .initialAvgBuyPrice)
                                .multilineTextAlignment(.trailing)
                                .font(.body.weight(.regular).monospacedDigit())
                        }
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))

                        if parsedInitialUSDT > 0 && parsedInitialAvgBuyPrice > 0 {
                            HStack {
                                Text("capital.label.initial_crypto_value")
                                    .font(.caption2.weight(.regular))
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(formatCurrency(parsedInitialUSDT * parsedInitialAvgBuyPrice) + " ₴")
                                    .font(.footnote.weight(.medium).monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                        }
                    } header: {
                        Text("capital.label.initial_crypto_inventory")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                    } footer: {
                        SectionValidationFooter(
                            result: validationResult,
                            fields: ["initial_usdt", "initial_avg_price"],
                            isVisible: attemptedSave,
                            helperText: "capital.footer.initial_crypto"
                        )
                    }

                    // Section 4: Cash Out (To Cash)
                    Section {
                        HStack {
                            FormRowLabel(
                                title: "trades.card.cash_out",
                                systemImage: "arrow.down.forward.circle.fill",
                                color: .orange,
                                required: true
                            )

                            Spacer(minLength: 8)

                            TextField(String(""), text: $toCashText, prompt: Text(verbatim: "0.00"))
                                .keyboardType(.decimalPad)
                                .focused($focusedField, equals: .toCash)
                                .multilineTextAlignment(.trailing)
                                .font(.body.weight(.regular).monospacedDigit())
                        }
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    } header: {
                        Text("trades.card.cash_out")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                    } footer: {
                        SectionValidationFooter(
                            result: validationResult,
                            field: "to_cash",
                            isVisible: attemptedSave,
                            helperText: "capital.footer.cash_out"
                        )
                    }
                }
            .listSectionSpacing(.compact)
            .contentMargins(.top, SheetLayoutConstants.topContentMargin, for: .scrollContent)
            .contentMargins(.bottom, SheetLayoutConstants.bottomContentMargin, for: .scrollContent)
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(LocalizationManager.shared.string("capital.title.period", periodIdentifier))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.action.cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("common.action.save") {
                        attemptedSave = true
                        saveSettings()
                    }
                }

                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("common.action.done") {
                        focusedField = nil
                    }
                    .font(.subheadline.weight(.medium))
                }
            }
            .onAppear {
                if let settings = activeSettings {
                    depositText = settings.startingDepositUAH > 0 ? formatPlain(settings.startingDepositUAH) : ""
                    toCashText = settings.toCashUAH > 0 ? formatPlain(settings.toCashUAH) : ""
                    initialUSDTText = settings.initialUSDT > 0 ? formatPlain(settings.initialUSDT) : ""
                    initialAvgBuyPriceText = settings.initialAvgBuyPrice > 0 ? formatPlain(settings.initialAvgBuyPrice) : ""
                }
            }
            .alert("common.alert.error", isPresented: $showingErrorAlert) {
                Button("common.action.ok", role: .cancel) {}
            } message: {
                Text(verbatim: errorMessage ?? "")
            }
        }
    }

    private func saveSettings() {
        attemptedSave = true
        guard validationResult.isValid else { return }

        if let existing = settingsList.first(where: { $0.periodIdentifier == periodIdentifier }) {
            existing.startingDepositUAH = parsedDeposit
            existing.toCashUAH = parsedToCash
            existing.initialUSDT = parsedInitialUSDT
            existing.initialAvgBuyPrice = parsedInitialAvgBuyPrice
            existing.lastUpdated = Date()
        } else {
            let newSettings = CapitalSettings(
                startingDepositUAH: parsedDeposit,
                toCashUAH: parsedToCash,
                initialUSDT: parsedInitialUSDT,
                initialAvgBuyPrice: parsedInitialAvgBuyPrice,
                periodIdentifier: periodIdentifier,
                lastUpdated: Date()
            )
            modelContext.insert(newSettings)
        }
        do {
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.rollback()
            errorMessage = error.localizedDescription
            showingErrorAlert = true
        }
    }

    private func parseDouble(_ text: String) -> Double {
        NumericInput(text: text).value ?? 0.0
    }

    private func formatPlain(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
    }

    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
    }
}

// MARK: - Sheet Layout Constants

/// Standard layout and spacing constants for modal sheets and forms across the app.
public enum SheetLayoutConstants {
    /// Top content margin below the navigation header for modal form sheets
    public static let topContentMargin: CGFloat = 8
    /// Bottom content margin for modal form sheets
    public static let bottomContentMargin: CGFloat = 24
}
