import Foundation

/// Coordinates and coalesces Home dashboard invalidation signals.
///
/// Guarantees that multiple synchronous or same-run-loop invalidations
/// (e.g. a model context save followed by a sheet dismissal or query change)
/// coalesce into a single deterministic reload, while protecting against
/// out-of-order execution via generation tracking and task cancellation.
@MainActor
public final class HomeInvalidationPipeline {
    public private(set) var loadGeneration: Int = 0
    private var reloadTask: Task<Void, Never>?
    public var onReload: (@MainActor (Int) async -> Void)?

    public init(onReload: (@MainActor (Int) async -> Void)? = nil) {
        self.onReload = onReload
    }

    /// Signals that Home data has changed or the viewing period was altered.
    /// Cancels any pending reload and schedules a coalesced execution for the next run-loop turn.
    public func invalidate() {
        reloadTask?.cancel()
        loadGeneration &+= 1
        let currentGeneration = loadGeneration

        reloadTask = Task { @MainActor in
            await Task.yield()
            guard !Task.isCancelled, currentGeneration == self.loadGeneration else { return }
            if let onReload = self.onReload {
                await onReload(currentGeneration)
            }
        }
    }
}
