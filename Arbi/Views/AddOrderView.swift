import SwiftUI
import SwiftData

/// Quick presets for order commission.
enum FeePreset: CaseIterable, Identifiable, Equatable {
    case custom
    case zeroPercent
    case onePercent
    case threePercent

    var id: String { label }

    /// Single Source of Truth: numerical rate multiplier (0.01 for 1%, 0.03 for 3%, nil for Custom)
    var rate: Double? {
        switch self {
        case .custom: return nil
        case .zeroPercent: return 0.0
        case .onePercent: return 0.01
        case .threePercent: return 0.03
        }
    }

    /// UI label dynamically computed from rate
    var label: String {
        guard let rate else { return "Custom" }
        let percentInt = Int((rate * 100).rounded())
        return "\(percentInt)%"
    }
}

/// High-efficiency, single-handed input sheet for recording crypto P2P arbitrage trades.
struct AddOrderView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    // Form states
    @State private var selectedType: TransactionType = .buy
    @State private var selectedPlatform: ExchangePlatform = .binance
    @State private var selectedBank: BankType = .monoBank
    @State private var timestamp: Date = Date()
    @State private var noteText: String = ""

    // Numeric inputs represented as text to preserve localized decimals (comma/dot)
    @State private var usdtText: String = ""
    @State private var priceText: String = ""
    @State private var uahText: String = ""
    @State private var feeText: String = "0.0"

    // Fee preset state (default is Custom)
    @State private var selectedFeePreset: FeePreset = .custom
    @State private var isProgrammaticFeeUpdate: Bool = false

    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case usdt
        case price
        case totalUah
        case fee
        case note
    }

    private var parsedUSDT: Double { parseDouble(usdtText) }
    private var parsedPrice: Double { parseDouble(priceText) }
    private var parsedUAH: Double { parseDouble(uahText) }
    private var parsedFee: Double { parseDouble(feeText) }

    private var isValid: Bool {
        parsedUSDT > 0 && parsedPrice > 0 && parsedUAH > 0
    }

    var body: some View {
        NavigationStack {
            Form {
                // Section 1: Transaction Type Segment
                Section {
                    Picker("Order Type", selection: $selectedType) {
                        ForEach(TransactionType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                    .listRowBackground(Color.clear)
                }

                // Section 2: Platform Selector Chips
                Section("Exchange / Platform") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(ExchangePlatform.allCases, id: \.self) { platform in
                                PlatformChip(
                                    platform: platform,
                                    isSelected: selectedPlatform == platform
                                ) {
                                    selectedPlatform = platform
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                }

                // Section 3: Bank Selector Chips
                Section("Bank Settlement") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(BankType.allCases, id: \.self) { bank in
                                BankChip(
                                    bank: bank,
                                    isSelected: selectedBank == bank
                                ) {
                                    selectedBank = bank
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                }

                // Section 4: Main Numeric Inputs with 2-way reactive calculations
                Section("Trade Amounts & Rate") {
                    HStack {
                        Label("USDT", systemImage: "dollarsign.circle.fill")
                            .font(.subheadline.weight(.regular))
                            .foregroundStyle(.green)
                            .frame(width: 110, alignment: .leading)
                        TextField("0.00", text: $usdtText)
                            .keyboardType(.decimalPad)
                            .focused($focusedField, equals: .usdt)
                            .multilineTextAlignment(.trailing)
                            .font(.body.weight(.regular).monospacedDigit())
                            .onChange(of: usdtText) { _, _ in
                                handleUSDTChanged()
                            }
                    }

                    HStack {
                        Label("Price (UAH)", systemImage: "chart.line.uptrend.xyaxis")
                            .font(.subheadline.weight(.regular))
                            .foregroundStyle(.blue)
                            .frame(width: 110, alignment: .leading)
                        TextField("0.00", text: $priceText)
                            .keyboardType(.decimalPad)
                            .focused($focusedField, equals: .price)
                            .multilineTextAlignment(.trailing)
                            .font(.body.weight(.regular).monospacedDigit())
                            .onChange(of: priceText) { _, _ in
                                handlePriceChanged()
                            }
                    }

                    HStack {
                        Label("Total UAH", systemImage: "hryvniasign.circle.fill")
                            .font(.subheadline.weight(.regular))
                            .foregroundStyle(.orange)
                            .frame(width: 110, alignment: .leading)
                        TextField("0.00", text: $uahText)
                            .keyboardType(.decimalPad)
                            .focused($focusedField, equals: .totalUah)
                            .multilineTextAlignment(.trailing)
                            .font(.body.weight(.medium).monospacedDigit())
                            .onChange(of: uahText) { _, _ in
                                handleUAHChanged()
                            }
                    }
                }

                // Section 5: Always-Visible Commission / Fee Section
                Section("Commission / Fee") {
                    // Quick Preset Chips
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(FeePreset.allCases) { preset in
                                FeePresetChip(
                                    preset: preset,
                                    isSelected: selectedFeePreset == preset
                                ) {
                                    applyFeePreset(preset)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))

                    // Direct Numeric Fee Input in USDT
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Label("Fee (USDT)", systemImage: "percent")
                                .font(.subheadline.weight(.regular))
                                .foregroundStyle(.purple)
                                .frame(width: 130, alignment: .leading)

                            TextField("0.00", text: $feeText)
                                .keyboardType(.decimalPad)
                                .focused($focusedField, equals: .fee)
                                .multilineTextAlignment(.trailing)
                                .font(.body.weight(.regular).monospacedDigit())
                                .onChange(of: feeText) { _, _ in
                                    handleFeeTextEdited()
                                }

                            Text("USDT")
                                .font(.caption.weight(.regular))
                                .foregroundStyle(.secondary)
                        }

                        if parsedFee > 0 && parsedPrice > 0 {
                            HStack {
                                Spacer()
                                Text("≈ \(formatCurrency(parsedFee * parsedPrice)) ₴ commission")
                                    .font(.caption2.weight(.regular))
                                    .foregroundStyle(.purple.opacity(0.85))
                            }
                        }
                    }
                }

                // Section 6: Date & Optional Note
                Section("Details & Note") {
                    DatePicker("Date & Time", selection: $timestamp)

                    HStack(spacing: 8) {
                        Image(systemName: "note.text")
                            .foregroundStyle(.secondary)
                        TextField("Optional trade note / counterparty", text: $noteText)
                            .focused($focusedField, equals: .note)
                    }
                }
            }
            .navigationTitle(selectedType == .buy ? "Record Buy Order" : "Record Sell Order")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveOrder()
                    }
                    .disabled(!isValid)
                    .fontWeight(.bold)
                }

                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        focusedField = nil
                    }
                }
            }
            .task {
                // Smoothly focus first input after sheet animation completes
                try? await Task.sleep(nanoseconds: 150_000_000)
                focusedField = .usdt
            }
        }
    }

    // MARK: - Reactive 2-Way Calculations

    private func handleUSDTChanged() {
        guard focusedField == .usdt else { return }
        let usdt = parseDouble(usdtText)
        let price = parseDouble(priceText)

        if price > 0 && usdt > 0 {
            uahText = formatNumber(usdt * price, maxDecimals: 2)
        }

        recalculatePresetFeeIfPercentage(usdt: usdt)
    }

    private func handlePriceChanged() {
        guard focusedField == .price else { return }
        let price = parseDouble(priceText)
        let usdt = parseDouble(usdtText)
        let uah = parseDouble(uahText)

        if price > 0 {
            if usdt > 0 {
                uahText = formatNumber(usdt * price, maxDecimals: 2)
            } else if uah > 0 {
                let calculatedUSDT = uah / price
                usdtText = formatNumber(calculatedUSDT, maxDecimals: 4)
                recalculatePresetFeeIfPercentage(usdt: calculatedUSDT)
            }
        }
    }

    private func handleUAHChanged() {
        guard focusedField == .totalUah else { return }
        let uah = parseDouble(uahText)
        let price = parseDouble(priceText)

        if price > 0 && uah > 0 {
            let calculatedUSDT = uah / price
            usdtText = formatNumber(calculatedUSDT, maxDecimals: 4)
            recalculatePresetFeeIfPercentage(usdt: calculatedUSDT)
        }
    }

    // MARK: - Fee Presets

    private func applyFeePreset(_ preset: FeePreset) {
        selectedFeePreset = preset
        isProgrammaticFeeUpdate = true

        if let rate = preset.rate {
            if focusedField == .fee { focusedField = nil }
            applyPercentageFee(rate: rate, usdt: parsedUSDT)
        } else {
            isProgrammaticFeeUpdate = false
            focusedField = .fee
        }
    }

    private func applyPercentageFee(rate: Double, usdt: Double) {
        if rate > 0 && usdt > 0 {
            let fee = usdt * rate
            feeText = formatNumber(fee, maxDecimals: 3)
        } else {
            feeText = "0.0"
        }
    }

    private func recalculatePresetFeeIfPercentage(usdt: Double) {
        guard let rate = selectedFeePreset.rate, rate > 0 else { return }
        isProgrammaticFeeUpdate = true
        applyPercentageFee(rate: rate, usdt: usdt)
    }

    private func handleFeeTextEdited() {
        if isProgrammaticFeeUpdate {
            isProgrammaticFeeUpdate = false
            return
        }
        guard focusedField == .fee else { return }
        if selectedFeePreset != .custom {
            selectedFeePreset = .custom
        }
    }

    // MARK: - Persistence

    private func saveOrder() {
        guard isValid else { return }

        let order = P2POrder(
            type: selectedType,
            usdtAmount: parsedUSDT,
            price: parsedPrice,
            uahAmount: parsedUAH,
            feeUSDT: parsedFee,
            txFeeUSDT: 0.0, // Network fee temporarily removed from this screen
            platform: selectedPlatform,
            bank: selectedBank,
            timestamp: timestamp,
            note: noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : noteText
        )

        modelContext.insert(order)
        dismiss()
    }

    // MARK: - Parsing & Formatting Helpers

    private func parseDouble(_ text: String) -> Double {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        return Double(cleaned) ?? 0.0
    }

    private func formatNumber(_ value: Double, maxDecimals: Int) -> String {
        guard value > 0 else { return "" }
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = maxDecimals
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.\(maxDecimals)f", value)
    }

    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
    }
}

// MARK: - Chip Components

private struct PlatformChip: View {
    let platform: ExchangePlatform
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: iconName)
                    .font(.caption)
                Text(platform.rawValue)
                    .font(.caption.weight(.medium))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isSelected ? Color.accentColor : Color(uiColor: .secondarySystemGroupedBackground))
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(isSelected ? Color.clear : Color.secondary.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var iconName: String {
        switch platform {
        case .binance: return "b.circle.fill"
        case .tgWallet: return "paperplane.fill"
        case .bybit: return "arrow.left.arrow.right.circle.fill"
        case .other: return "network"
        }
    }
}

private struct BankChip: View {
    let bank: BankType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "building.columns.fill")
                    .font(.caption2)
                Text(bank.rawValue)
                    .font(.caption.weight(.medium))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isSelected ? Color.indigo : Color(uiColor: .secondarySystemGroupedBackground))
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(isSelected ? Color.clear : Color.secondary.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct FeePresetChip: View {
    let preset: FeePreset
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(preset.label)
                .font(.caption.weight(.medium))
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(isSelected ? Color.purple : Color(uiColor: .secondarySystemGroupedBackground))
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(isSelected ? Color.clear : Color.secondary.opacity(0.2), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}
