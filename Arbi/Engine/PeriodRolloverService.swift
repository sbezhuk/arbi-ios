import Foundation
import SwiftData

/// Service orchestrating month-end closing and period roll-overs for Spred.
@MainActor
public struct PeriodRolloverService {
    private init() {}

    /// Formats a Date into a period identifier string (e.g. "09.2026").
    nonisolated public static func period(for date: Date = Date()) -> String {
        let comps = Calendar.current.dateComponents([.year, .month], from: date)
        let year = comps.year ?? 2026
        let month = comps.month ?? 9
        return String(format: "%02d.%d", month, year)
    }

    /// Convenience alias for the current active period identifier.
    nonisolated public static func currentPeriodIdentifier() -> String {
        period(for: Date())
    }

    /// Calculates the next period identifier after a given period string (e.g. "09.2026" -> "10.2026").
    nonisolated public static func nextPeriodIdentifier(after period: String) -> String {
        let parts = period.split(separator: ".")
        guard parts.count == 2,
              let month = Int(parts[0]),
              let year = Int(parts[1]) else {
            return period
        }

        if month >= 12 {
            return String(format: "%02d.%d", 1, year + 1)
        } else {
            return String(format: "%02d.%d", month + 1, year)
        }
    }

    /// Calculates the previous period identifier before a given period string (e.g. "10.2026" -> "09.2026").
    nonisolated public static func previousPeriodIdentifier(before period: String) -> String {
        let parts = period.split(separator: ".")
        guard parts.count == 2,
              let month = Int(parts[0]),
              let year = Int(parts[1]) else {
            return period
        }

        if month <= 1 {
            return String(format: "%02d.%d", 12, year - 1)
        } else {
            return String(format: "%02d.%d", month - 1, year)
        }
    }

    /// Formats a period identifier into human-readable text (e.g. "09.2026" -> "September 2026").
    nonisolated public static func formattedPeriodDisplay(_ period: String, locale: Locale? = nil) -> String {
        let parts = period.split(separator: ".")
        guard parts.count == 2,
              let month = Int(parts[0]),
              let year = Int(parts[1]),
              month >= 1 && month <= 12 else {
            return period
        }

        let dateFormatter = DateFormatter()
        if let locale {
            dateFormatter.locale = locale
        } else if let savedLang = UserDefaults.standard.string(forKey: "app_language") {
            dateFormatter.locale = Locale(identifier: savedLang)
        } else {
            dateFormatter.locale = Locale(identifier: "en")
        }
        let symbols = dateFormatter.standaloneMonthSymbols ?? dateFormatter.monthSymbols ?? []
        let rawMonth = symbols[month - 1]
        let monthName = rawMonth.capitalized(with: dateFormatter.locale)
        return "\(monthName) \(year)"
    }

    /// Filters orders that belong to a specific calendar month period (e.g. "09.2026").
    nonisolated public static func ordersForPeriod(_ period: String, orders: [P2POrder]) -> [P2POrder] {
        orders.filter { order in
            self.period(for: order.timestamp) == period
        }
    }

    /// Filters withdrawals that belong to a specific calendar month period (e.g. "09.2026").
    nonisolated public static func withdrawalsForPeriod(_ period: String, withdrawals: [CashWithdrawal]) -> [CashWithdrawal] {
        withdrawals.filter { withdrawal in
            withdrawal.periodIdentifier == period
        }
    }

    /// Carries over balances, inventory, and cost basis from closingPeriod into nextPeriod.
    @discardableResult
    public static func rolloverMonth(
        from closingPeriod: String,
        to nextPeriod: String,
        orders: [P2POrder],
        withdrawals: [CashWithdrawal] = [],
        closingSettings: CapitalSettings?,
        reinvestProfit: Bool,
        cashOutAmount: Double = 0.0,
        customStartingDeposit: Double? = nil,
        modelContext: ModelContext
    ) throws -> CapitalSettings {
        // 1. Calculate final state of the closing period
        let filteredOrders = ordersForPeriod(closingPeriod, orders: orders)
        let filteredWithdrawals = withdrawalsForPeriod(closingPeriod, withdrawals: withdrawals)

        let breakdown = P2PCalculator.calculateCapitalBreakdown(
            orders: filteredOrders,
            settings: closingSettings,
            withdrawals: filteredWithdrawals
        )

        // 2. Compute starting funds for the next month:
        let nextStartingDepositUAH: Double
        if let custom = customStartingDeposit, custom > 0 {
            nextStartingDepositUAH = custom
        } else if reinvestProfit {
            // Reinvesting profit: starting UAH = freeUAH - cashOutAmount
            nextStartingDepositUAH = max(0.0, breakdown.freeUAH - cashOutAmount)
        } else {
            // Not reinvesting: starting UAH = closing starting deposit - cashOutAmount
            let baseStarting = closingSettings?.startingDepositUAH ?? 0.0
            nextStartingDepositUAH = max(0.0, baseStarting - cashOutAmount)
        }

        // 3. Compute carry-over inventory and weighted cost basis
        let carryOverUSDT = breakdown.remainingUSDT
        let carryOverAvgPrice = carryOverUSDT > 0
            ? P2PCalculator.averageBuyPrice(orders: filteredOrders, settings: closingSettings)
            : 0.0

        // 4. Fetch or create CapitalSettings for nextPeriod
        let descriptor = FetchDescriptor<CapitalSettings>()
        let allSettings = (try? modelContext.fetch(descriptor)) ?? []

        let targetSettings: CapitalSettings
        if let existing = allSettings.first(where: { $0.periodIdentifier == nextPeriod }) {
            existing.startingDepositUAH = nextStartingDepositUAH
            existing.toCashUAH = 0.0 // Resets for the new month
            existing.initialUSDT = carryOverUSDT
            existing.initialAvgBuyPrice = carryOverAvgPrice
            existing.lastUpdated = Date()
            targetSettings = existing
        } else {
            let newSettings = CapitalSettings(
                startingDepositUAH: nextStartingDepositUAH,
                toCashUAH: 0.0,
                initialUSDT: carryOverUSDT,
                initialAvgBuyPrice: carryOverAvgPrice,
                periodIdentifier: nextPeriod,
                lastUpdated: Date()
            )
            modelContext.insert(newSettings)
            targetSettings = newSettings
        }

        try modelContext.save()
        return targetSettings
    }
}
