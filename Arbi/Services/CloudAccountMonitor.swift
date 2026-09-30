import CloudKit
import Combine
import Foundation
import OSLog

enum CloudAccountState: Equatable, Sendable {
    case checking
    case available
    case noAccount
    case restricted
    case temporarilyUnavailable
    case couldNotDetermine

    init(_ status: CKAccountStatus) {
        switch status {
        case .available:
            self = .available
        case .noAccount:
            self = .noAccount
        case .restricted:
            self = .restricted
        case .temporarilyUnavailable:
            self = .temporarilyUnavailable
        case .couldNotDetermine:
            self = .couldNotDetermine
        @unknown default:
            self = .couldNotDetermine
        }
    }
}

/// Observes iCloud account availability without making local persistence
/// depend on CloudKit. Account changes are a privacy boundary, but this
/// monitor deliberately does not delete, reset, or replace the local store.
@MainActor
final class CloudAccountMonitor: ObservableObject {
    @Published private(set) var state: CloudAccountState = .checking

    private let container = CKContainer(identifier: CloudKitPersistence.containerIdentifier)
    private var accountChangeObserver: NSObjectProtocol?
    private let logger = Logger(subsystem: "com.arbi.production", category: "cloud-account")

    func start() {
        guard accountChangeObserver == nil else { return }

        accountChangeObserver = NotificationCenter.default.addObserver(
            forName: .CKAccountChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                await self.refresh()
            }
        }

        Task { @MainActor in
            await refresh()
        }
    }

    func refresh() async {
        do {
            let accountStatus = try await accountStatus()
            state = CloudAccountState(accountStatus)
        } catch {
            state = .couldNotDetermine
        }

        logger.info("iCloud account state changed to \(String(describing: self.state), privacy: .public)")
    }

    private func accountStatus() async throws -> CKAccountStatus {
        try await withCheckedThrowingContinuation { continuation in
            container.accountStatus { status, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: status)
                }
            }
        }
    }
}
