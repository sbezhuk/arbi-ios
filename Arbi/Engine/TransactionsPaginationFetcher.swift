import Foundation
import SwiftData

/// Service providing incremental, SwiftData-backed pagination for transaction history.
@MainActor
public struct TransactionsPaginationFetcher {
    nonisolated public static let defaultPageSize: Int = 25

    private init() {}

    /// Builds a date-range Predicate for the given monthly period identifier (e.g. "09.2026"),
    /// or returns nil if all historical transactions are requested.
    nonisolated public static func predicate(for periodIdentifier: String?) -> Predicate<P2POrder>? {
        guard let period = periodIdentifier,
              let interval = PeriodRolloverService.dateInterval(for: period) else {
            return nil
        }
        let start = interval.start
        let end = interval.end
        return #Predicate<P2POrder> { order in
            order.timestamp >= start && order.timestamp < end
        }
    }

    /// Fetches a single page of P2POrders with deterministic ordering (newest first, id tiebreaker).
    public static func fetchPage(
        modelContext: ModelContext,
        periodIdentifier: String? = nil,
        offset: Int,
        limit: Int = defaultPageSize
    ) throws -> [P2POrder] {
        var descriptor = FetchDescriptor<P2POrder>(
            predicate: predicate(for: periodIdentifier),
            sortBy: [
                SortDescriptor(\P2POrder.timestamp, order: .reverse),
                SortDescriptor(\P2POrder.id, order: .reverse)
            ]
        )
        descriptor.fetchOffset = offset
        descriptor.fetchLimit = limit
        return try modelContext.fetch(descriptor)
    }

    /// Returns the total count of transactions matching the given period filter.
    public static func count(
        modelContext: ModelContext,
        periodIdentifier: String? = nil
    ) throws -> Int {
        let descriptor = FetchDescriptor<P2POrder>(
            predicate: predicate(for: periodIdentifier)
        )
        return try modelContext.fetchCount(descriptor)
    }
}
