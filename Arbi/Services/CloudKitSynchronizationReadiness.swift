import Combine
import CoreData
import Foundation

/// Tracks whether the first CloudKit synchronization attempt has resolved.
///
/// The state is intentionally independent from the local store contents. A
/// caller can show the restore UI only when this state is pending *and* its
/// local queries are empty, preserving local-first behavior.
@MainActor
final class CloudKitSynchronizationReadiness: ObservableObject {
    enum InitialSyncState: Equatable {
        case pending
        case resolved
    }

    enum EventType {
        case setup
        case `import`
        case export
    }

    enum EventPhase {
        case started
        case completed(succeeded: Bool)
    }

    @Published private(set) var initialSyncState: InitialSyncState = .pending

    private let notificationCenter: NotificationCenter
    private var eventObserver: NSObjectProtocol?
    private var didResolveInitialImport = false

    init(
        notificationCenter: NotificationCenter = .default,
        observeNotifications: Bool = true
    ) {
        self.notificationCenter = notificationCenter
        guard observeNotifications else { return }

        eventObserver = notificationCenter.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: nil,
            queue: nil
        ) { [weak self] notification in
            guard let event = notification.userInfo?[
                NSPersistentCloudKitContainer.eventNotificationUserInfoKey
            ] as? NSPersistentCloudKitContainer.Event else {
                return
            }

            Task { @MainActor [weak self] in
                self?.handle(event)
            }
        }
    }

    deinit {
        if let eventObserver {
            notificationCenter.removeObserver(eventObserver)
        }
    }

    var isRestoring: Bool {
        initialSyncState == .pending
    }

    func shouldShowRestoring(localStoreIsEmpty: Bool) -> Bool {
        localStoreIsEmpty && isRestoring
    }

    func handle(_ event: NSPersistentCloudKitContainer.Event) {
        let type: EventType
        switch event.type {
        case .setup:
            type = .setup
        case .import:
            type = .import
        case .export:
            type = .export
        @unknown default:
            return
        }

        let phase: EventPhase
        if event.endDate == nil {
            phase = .started
        } else {
            phase = .completed(succeeded: event.succeeded)
        }

        handle(eventType: type, phase: phase)
    }

    func handle(eventType: EventType, phase: EventPhase) {
        guard !didResolveInitialImport else { return }

        switch (eventType, phase) {
        case (.setup, .started), (.import, .started):
            initialSyncState = .pending

        case (.setup, .completed(succeeded: true)):
            // Setup completion only means the container is ready to begin
            // synchronization; the first import still needs to resolve.
            break

        case (.setup, .completed(succeeded: false)):
            resolveWithoutCloudKit()

        case (.import, .completed):
            didResolveInitialImport = true
            initialSyncState = .resolved

        case (.export, _):
            break
        }
    }

    func accountStateChanged(_ state: CloudAccountState) {
        switch state {
        case .checking, .available:
            break
        case .noAccount, .restricted, .temporarilyUnavailable, .couldNotDetermine:
            resolveWithoutCloudKit()
        }
    }

    func resolveWithoutCloudKit() {
        didResolveInitialImport = true
        initialSyncState = .resolved
    }
}
