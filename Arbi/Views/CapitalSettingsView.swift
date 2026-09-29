import SwiftUI
import SwiftData

/// Modal sheet for managing starting working deposit, cash out, and reviewing liquid capital.
struct CapitalSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query private var settingsList: [CapitalSettings]
    @Query(sort: \P2POrder.timestamp, order: .reverse) private var orders: [P2POrder]

    @State private var depositText: String = ""
    @State private var toCashText: String = ""
    @State private var initialUSDTText: String = ""
    @State private var initialAvgBuyPriceText: String = ""

    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case deposit
        case toCash
        case initialUSDT
        case initialAvgBuyPrice
    }

    private var activeSettings: CapitalSettings? {
        settingsList.first(where: { $0.periodIdentifier == "global" })
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

    private var simulatedSettings: CapitalSettings {
        CapitalSettings(
            startingDepositUAH: parsedDeposit,
            toCashUAH: parsedToCash,
            initialUSDT: parsedInitialUSDT,
            initialAvgBuyPrice: parsedInitialAvgBuyPrice,
            periodIdentifier: "global",
            lastUpdated: Date()
        )
    }

    private var breakdown: CapitalBreakdown {
        P2PCalculator.calculateCapitalBreakdown(
            orders: orders,
            settings: simulatedSettings
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                // Section 1: Real-time Capital Simulation Card
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Available Free Money (UAH)")
                            .font(.caption.weight(.regular))
                            .foregroundStyle(.secondary)

                        Text(formatCurrency(breakdown.freeUAH) + " ₴")
                            .font(.system(size: 22, weight: .semibold, design: .rounded))
                            .foregroundStyle(breakdown.freeUAH >= 0 ? Color.green : Color.red)

                        Divider()

                        HStack {
                            VStack(alignment: .leading, spacing: 1) {
                                Text("Remaining USDT")
                                    .font(.caption2.weight(.regular))
                                    .foregroundStyle(.secondary)
                                Text(String(format: "%.2f USDT", breakdown.remainingUSDT))
                                    .font(.footnote.weight(.medium).monospacedDigit())
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 1) {
                                Text("Total Portfolio Equity")
                                    .font(.caption2.weight(.regular))
                                    .foregroundStyle(.secondary)
                                Text(formatCurrency(breakdown.totalEquityUAH) + " ₴")
                                    .font(.footnote.weight(.medium).monospacedDigit())
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }

                // Section 2: Initial Working Deposit
                Section {
                    HStack {
                        Label("Starting Deposit", systemImage: "banknote.fill")
                            .font(.subheadline.weight(.regular))
                            .foregroundStyle(.green)
                            .frame(width: 120, alignment: .leading)

                        TextField("0.00", text: $depositText)
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
                                Button("\(amount / 1000)k ₴") {
                                    depositText = "\(amount)"
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
                    Text("Starting Working Capital")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                } footer: {
                    Text("The initial cash pool in UAH you started trading with for this period.")
                }

                // Section 3: Initial Crypto Inventory
                Section {
                    HStack {
                        Label("Initial USDT", systemImage: "dollarsign.circle.fill")
                            .font(.subheadline.weight(.regular))
                            .foregroundStyle(.green)
                            .frame(width: 120, alignment: .leading)

                        TextField("0.00", text: $initialUSDTText)
                            .keyboardType(.decimalPad)
                            .focused($focusedField, equals: .initialUSDT)
                            .multilineTextAlignment(.trailing)
                            .font(.body.weight(.regular).monospacedDigit())
                    }
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))

                    HStack {
                        Label("Avg Buy Rate (₴)", systemImage: "chart.line.uptrend.xyaxis")
                            .font(.subheadline.weight(.regular))
                            .foregroundStyle(.blue)
                            .frame(width: 120, alignment: .leading)

                        TextField("0.00", text: $initialAvgBuyPriceText)
                            .keyboardType(.decimalPad)
                            .focused($focusedField, equals: .initialAvgBuyPrice)
                            .multilineTextAlignment(.trailing)
                            .font(.body.weight(.regular).monospacedDigit())
                    }
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))

                    if parsedInitialUSDT > 0 && parsedInitialAvgBuyPrice > 0 {
                        HStack {
                            Text("Initial Crypto Value")
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
                    Text("Initial Crypto Inventory")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                } footer: {
                    Text("Existing USDT inventory and weighted acquisition price prior to tracking trades in Spred.")
                }

                // Section 4: Cash Out (To Cash)
                Section {
                    HStack {
                        Label("Cash Out", systemImage: "arrow.down.forward.circle.fill")
                            .font(.subheadline.weight(.regular))
                            .foregroundStyle(.orange)
                            .frame(width: 120, alignment: .leading)

                        TextField("0.00", text: $toCashText)
                            .keyboardType(.decimalPad)
                            .focused($focusedField, equals: .toCash)
                            .multilineTextAlignment(.trailing)
                            .font(.body.weight(.regular).monospacedDigit())
                    }
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                } header: {
                    Text("Cash Out (To Cash)")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                } footer: {
                    Text("Arbitrage profits or working funds withdrawn from bank cards to physical cash or savings.")
                }
            }
            .listSectionSpacing(.compact)
            .navigationTitle("Capital Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveSettings()
                    }
                }

                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
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
        }
    }

    private func saveSettings() {
        if let existing = activeSettings {
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
                periodIdentifier: "global",
                lastUpdated: Date()
            )
            modelContext.insert(newSettings)
        }
        dismiss()
    }

    private func parseDouble(_ text: String) -> Double {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        return Double(cleaned) ?? 0.0
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
