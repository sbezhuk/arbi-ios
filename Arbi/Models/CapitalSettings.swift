import Foundation
import SwiftData

@Model
public final class CapitalSettings {
    public var id: UUID
    public var startingDepositUAH: Double
    public var toCashUAH: Double
    public var periodIdentifier: String // e.g. "2026-09" or "global"
    public var lastUpdated: Date

    public init(
        id: UUID = UUID(),
        startingDepositUAH: Double = 0.0,
        toCashUAH: Double = 0.0,
        periodIdentifier: String = "global",
        lastUpdated: Date = Date()
    ) {
        self.id = id
        self.startingDepositUAH = startingDepositUAH
        self.toCashUAH = toCashUAH
        self.periodIdentifier = periodIdentifier
        self.lastUpdated = lastUpdated
    }
}
