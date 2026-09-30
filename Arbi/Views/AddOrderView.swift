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
        guard let rate else { return LocalizationManager.shared["order.fee.custom"] }
        let percentInt = Int((rate * 100).rounded())
        return "\(percentInt)%"
    }
}

/// High-efficiency, single-handed input sheet for recording crypto P2P arbitrage trades.
struct AddOrderView: View {
    fileprivate static let formLabelFont: Font = FormRowConstants.labelFont

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    // Form states
    @State private var selectedType: TransactionType = .buy
    @State private var selectedPlatform: ExchangePlatform = .binance
    @State private var selectedBank: BankType = .monoBank
    @State private var selectedBankAccount: BankAccount?
    @State private var showingAddAccountSheet: Bool = false
    @State private var timestamp: Date = Date()
    @State private var noteText: String = ""

    @Query(filter: #Predicate<BankAccount> { !$0.isArchived }, sort: \BankAccount.createdAt)
    private var bankAccounts: [BankAccount]

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
        parsedUSDT > 0 && parsedPrice > 0 && parsedUAH > 0 && selectedBankAccount != nil
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                // Layer 1: Screen background
                Color(uiColor: .systemGroupedBackground)
                    .ignoresSafeArea()

                // Layer 2 & 3: Scrollable Form with Edge Fade Mask
                Form {
                    // Section 0: Order Type
                    Section {
                        Picker("order.type.title", selection: $selectedType) {
                            ForEach(TransactionType.allCases, id: \.self) { type in
                                Group {
                                    switch type {
                                    case .buy:
                                        Text("order.type.buy")
                                    case .sell:
                                        Text("order.type.sell")
                                    }
                                }
                                .tag(type)
                            }
                        }
                        .pickerStyle(.segmented)
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    } header: {
                        Text("order.type.title")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Color(uiColor: .secondaryLabel))
                    }
                    
                    // Section 1: Platform Selector Chips
                    Section {
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
                        }
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    } header: {
                        Text("order.section.platform")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Color(uiColor: .secondaryLabel))
                    }

                // Section 3: Bank Account Selector Chips
                Section {
                    if bankAccounts.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 8) {
                                Image(systemName: "creditcard.trianglebadge.exclamationmark")
                                    .foregroundStyle(.secondary)
                                Text("bank.empty.no_accounts_found")
                                    .font(.subheadline.weight(.medium))
                            }

                            Text("bank.empty.description")
                                .font(.footnote)
                                .foregroundStyle(.secondary)

                            Button {
                                showingAddAccountSheet = true
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "plus.circle.fill")
                                    Text("bank.action.add_account")
                                        .fontWeight(.semibold)
                                }
                                .font(.subheadline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .padding(.vertical, 4)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(bankAccounts) { account in
                                    AccountChip(
                                        account: account,
                                        isSelected: selectedBankAccount?.id == account.id
                                    ) {
                                        selectedBankAccount = account
                                    }
                                }

                                Button {
                                    showingAddAccountSheet = true
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "plus")
                                            .font(.caption2)
                                        Text("common.action.add")
                                            .font(.caption.weight(.medium))
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                                    .foregroundStyle(Color.accentColor)
                                    .clipShape(Capsule())
                                    .overlay {
                                        Capsule()
                                            .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    }
                } header: {
                    Text("order.section.settlement")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color(uiColor: .secondaryLabel))
                } footer: {
                    if !bankAccounts.isEmpty, let selected = selectedBankAccount {
                        if let card = selected.cardNumber, !card.isEmpty {
                            Text(LocalizationManager.shared.string("order.footer.selected_card_turnover", card, Int(selected.turnoverLimitUAH / 1000)))
                        } else {
                            Text(LocalizationManager.shared.string("order.footer.turnover_limit", Int(selected.turnoverLimitUAH / 1000)))
                        }
                    }
                }

                // Section 4: Main Numeric Inputs with 2-way reactive calculations
                Section {
                    HStack {
                        FormRowLabel(
                            title: "order.field.usdt",
                            systemImage: "dollarsign.circle.fill",
                            color: .secondary,
                            fixedWidth: FormRowConstants.numericLabelWidth
                        )
                        TextField(String(""), text: $usdtText, prompt: Text(verbatim: "0.00"))
                            .keyboardType(.decimalPad)
                            .focused($focusedField, equals: .usdt)
                            .multilineTextAlignment(.trailing)
                            .font(.body.weight(.regular).monospacedDigit())
                            .onChange(of: usdtText) { _, _ in
                                handleUSDTChanged()
                            }
                    }
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))

                    HStack {
                        FormRowLabel(
                            title: "order.field.price_uah",
                            systemImage: "chart.line.uptrend.xyaxis",
                            color: .secondary,
                            fixedWidth: FormRowConstants.numericLabelWidth
                        )
                        TextField(String(""), text: $priceText, prompt: Text(verbatim: "0.00"))
                            .keyboardType(.decimalPad)
                            .focused($focusedField, equals: .price)
                            .multilineTextAlignment(.trailing)
                            .font(.body.weight(.regular).monospacedDigit())
                            .onChange(of: priceText) { _, _ in
                                handlePriceChanged()
                            }
                    }
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))

                    HStack {
                        FormRowLabel(
                            title: "order.field.total_uah",
                            systemImage: "hryvniasign.circle.fill",
                            color: .secondary,
                            fixedWidth: FormRowConstants.numericLabelWidth
                        )
                        TextField(String(""), text: $uahText, prompt: Text(verbatim: "0.00"))
                            .keyboardType(.decimalPad)
                            .focused($focusedField, equals: .totalUah)
                            .multilineTextAlignment(.trailing)
                            .font(.body.weight(.regular).monospacedDigit())
                            .onChange(of: uahText) { _, _ in
                                handleUAHChanged()
                            }
                    }
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                } header: {
                    Text("order.section.amounts_rate")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color(uiColor: .secondaryLabel))
                }

                // Section 5: Always-Visible Commission / Fee Section
                Section {
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
                    }
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))

                    // Direct Numeric Fee Input in USDT
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            FormRowLabel(
                                title: "order.field.fee_usdt",
                                systemImage: "percent",
                                color: .secondary,
                                fixedWidth: FormRowConstants.numericLabelWidth
                            )

                            TextField(String(""), text: $feeText, prompt: Text(verbatim: "0.00"))
                                .keyboardType(.decimalPad)
                                .focused($focusedField, equals: .fee)
                                .multilineTextAlignment(.trailing)
                                .font(.body.weight(.regular).monospacedDigit())
                                .onChange(of: feeText) { _, _ in
                                    handleFeeTextEdited()
                                }

                            Text("order.field.usdt")
                                .font(.caption2.weight(.regular))
                                .foregroundStyle(.secondary)
                        }

                        if parsedFee > 0 && parsedPrice > 0 {
                            HStack {
                                Spacer()
                                Text(LocalizationManager.shared.string("order.fee.approx_commission", formatCurrency(parsedFee * parsedPrice)))
                                    .font(.caption2.weight(.regular))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                } header: {
                    Text("order.section.commission")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color(uiColor: .secondaryLabel))
                }

                // Section 6: Date & Optional Note
                Section {
                    HStack {
                        FormRowLabel(
                            title: "order.field.date_time",
                            systemImage: "calendar",
                            color: .secondary
                        )

                        Spacer()

                        DatePicker(selection: $timestamp) {
                            Text(verbatim: "")
                        }
                            .labelsHidden()
                            .datePickerStyle(.compact)
                            .controlSize(.small)
                            .font(.footnote)
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))

                    HStack(spacing: FormRowConstants.spacing) {
                        FormRowIcon(systemImage: "note.text", color: .secondary)

                        TextField("order.field.note_placeholder", text: $noteText)
                            .font(.subheadline.weight(.regular))
                            .focused($focusedField, equals: .note)
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                } header: {
                    Text("order.section.details")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color(uiColor: .secondaryLabel))
                }
            }
            .listSectionSpacing(.compact)
            .contentMargins(.top, SheetLayoutConstants.topContentMargin, for: .scrollContent)
        }
        .navigationTitle(selectedType == .buy ? "order.title.record_buy" : "order.title.record_sell")
        .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.action.cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("common.action.save") {
                        saveOrder()
                    }
                    .disabled(!isValid)
                }

                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("common.action.done") {
                        focusedField = nil
                    }
                    .font(.subheadline.weight(.medium))
                }
            }
            .task {
                // Smoothly focus first input after sheet animation completes
                try? await Task.sleep(for: .milliseconds(150))
                focusedField = .usdt
            }
            .onAppear {
                autoSelectAccountIfNeeded(from: bankAccounts)
            }
            .onChange(of: bankAccounts) { _, newAccounts in
                autoSelectAccountIfNeeded(from: newAccounts)
            }
            .sheet(isPresented: $showingAddAccountSheet) {
                AddOrEditBankAccountView()
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

    // MARK: - Bank Account Auto-Selection

    private func autoSelectAccountIfNeeded(from accounts: [BankAccount]) {
        if let current = selectedBankAccount {
            // Retain selection if still present among active accounts
            if !accounts.contains(where: { $0.id == current.id }) {
                selectedBankAccount = accounts.first
            }
        } else {
            // Automatically select the first available account
            selectedBankAccount = accounts.first
        }
    }

    // MARK: - Persistence

    private func saveOrder() {
        guard isValid, let bankAccount = selectedBankAccount else { return }

        // Sync legacy bank enum if matching
        var bankFallback = selectedBank
        if let matched = BankType.allCases.first(where: { bankAccount.name.localizedCaseInsensitiveContains($0.rawValue) }) {
            bankFallback = matched
        }

        let order = P2POrder(
            type: selectedType,
            usdtAmount: parsedUSDT,
            price: parsedPrice,
            uahAmount: parsedUAH,
            feeUSDT: parsedFee,
            txFeeUSDT: 0.0, // Network fee temporarily removed from this screen
            platform: selectedPlatform,
            bank: bankFallback,
            bankAccount: bankAccount,
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

// MARK: - Aligned Form Row Components

enum FormRowConstants {
    static let labelFont: Font = .subheadline
    static let iconWidth: CGFloat = 22
    static let spacing: CGFloat = 8
    static let numericLabelWidth: CGFloat = 112
}

/// Reusable icon component aligned to a fixed column
private struct FormRowIcon: View {
    let systemImage: String
    let color: Color
    var font: Font = FormRowConstants.labelFont

    var body: some View {
        Image(systemName: systemImage)
            .font(font)
            .frame(width: FormRowConstants.iconWidth, alignment: .leading)
            .foregroundStyle(color)
    }
}

/// Reusable icon + text label component ensuring exact vertical and horizontal alignment
private struct FormRowLabel: View {
    let title: LocalizedStringKey
    let systemImage: String
    let color: Color
    var fixedWidth: CGFloat? = nil

    var body: some View {
        HStack(spacing: FormRowConstants.spacing) {
            FormRowIcon(systemImage: systemImage, color: color)
            Text(title)
                .font(FormRowConstants.labelFont.weight(.regular))
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
        .frame(width: fixedWidth, alignment: .leading)
    }
}

// MARK: - Chip Components

private struct PlatformChip: View {
    let platform: ExchangePlatform
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: iconName)
                    .font(.caption2)
                Text(platform.displayName)
                    .font(.caption.weight(.medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Color.accentColor : Color(uiColor: .secondarySystemGroupedBackground))
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .clipShape(Capsule())
            .overlay {
                Capsule()
                    .stroke(isSelected ? Color.clear : Color.secondary.opacity(0.2), lineWidth: 1)
            }
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

private struct AccountChip: View {
    let account: BankAccount
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: "building.columns.fill")
                    .font(.caption2)
                Text(account.name)
                    .font(.caption.weight(.medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Color.accentColor : Color(uiColor: .secondarySystemGroupedBackground))
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .clipShape(Capsule())
            .overlay {
                Capsule()
                    .stroke(isSelected ? Color.clear : Color.secondary.opacity(0.2), lineWidth: 1)
            }
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
            Group {
                if preset == .custom {
                    Text("order.fee.custom")
                } else {
                    Text(verbatim: preset.label)
                }
            }
            .font(.caption.weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.accentColor : Color(uiColor: .secondarySystemGroupedBackground))
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .clipShape(Capsule())
            .overlay {
                Capsule()
                    .stroke(isSelected ? Color.clear : Color.secondary.opacity(0.2), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}
