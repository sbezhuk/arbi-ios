import Foundation
import SwiftData

@Model
public final class CapitalSettings {
    public var id: UUID = UUID()
    public var startingDepositUAH: Double = 0.0
    public var toCashUAH: Double = 0.0
    public var initialUSDT: Double = 0.0           // Existing USDT holding at onboarding/period start
    public var initialAvgBuyPrice: Double = 0.0    // Average acquisition rate in UAH for initial USDT
    public var periodIdentifier: String = "global" // e.g. "2026-09" or "global"
    public var lastUpdated: Date = Date()

    public init(
        id: UUID = UUID(),
        startingDepositUAH: Double = 0.0,
        toCashUAH: Double = 0.0,
        initialUSDT: Double = 0.0,
        initialAvgBuyPrice: Double = 0.0,
        periodIdentifier: String = "global",
        lastUpdated: Date = Date()
    ) {
        self.id = id
        self.startingDepositUAH = startingDepositUAH
        self.toCashUAH = toCashUAH
        self.initialUSDT = initialUSDT
        self.initialAvgBuyPrice = initialAvgBuyPrice
        self.periodIdentifier = periodIdentifier
        self.lastUpdated = lastUpdated
    }
}

public extension CapitalSettings {
    /// Finds settings matching the specific period identifier, falling back to global settings if available.
    static func settings(for period: String, in list: [CapitalSettings]) -> CapitalSettings? {
        list.first(where: { $0.periodIdentifier == period })
            ?? list.first(where: { $0.periodIdentifier == "global" })
    }
}
