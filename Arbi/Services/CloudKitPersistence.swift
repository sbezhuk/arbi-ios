import Foundation
import OSLog
import SwiftData
import CoreData
import Combine
#if DEBUG
import CloudKit
#endif

/// The single persistence configuration used by the app.
///
/// The explicit schema keeps the existing SwiftData store as the source of
/// truth while enabling SwiftData's private CloudKit sync for the same models.
/// CloudKit owns record identity and tombstones; UUID properties remain stable
/// application-level identifiers.
@MainActor
enum CloudKitPersistence {
    /// A publisher that emits when external/remote changes (such as CloudKit background sync imports) occur.
    /// Encapsulates Core Data store notifications away from view layers.
    static var remoteStoreChangePublisher: AnyPublisher<Void, Never> {
        let remoteChange = NotificationCenter.default
            .publisher(for: NSNotification.Name.NSPersistentStoreRemoteChange)
            .map { _ in () }

        let cloudKitImport = NotificationCenter.default
            .publisher(for: NSPersistentCloudKitContainer.eventChangedNotification)
            .compactMap { notification -> Void? in
                guard let event = notification.userInfo?[
                    NSPersistentCloudKitContainer.eventNotificationUserInfoKey
                ] as? NSPersistentCloudKitContainer.Event else {
                    return nil
                }
                return (event.type == .import && event.endDate != nil) ? () : nil
            }

        return Publishers.Merge(remoteChange, cloudKitImport)
            .eraseToAnyPublisher()
    }
    /// This follows the app's bundle identifier. It must also be created in
    /// the Apple Developer portal and assigned to the app target.
    static let containerIdentifier = "iCloud.com.arbi.production"

    /// The filename used by the pre-iCloud SwiftData configuration.
    /// Keep this URL stable: changing it would make an existing installation
    /// appear to have an empty database.
    static let storeURL: URL = {
        guard let applicationSupportURL = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            preconditionFailure("Application Support is unavailable")
        }

        return applicationSupportURL.appendingPathComponent("default.store")
    }()

    static let schema: Schema = {
        let models: [any PersistentModel.Type] = [
            P2POrder.self,
            CapitalSettings.self,
            BankAccount.self,
            CashWithdrawal.self
        ]
        return Schema(models)
    }()

    static func makeConfiguration(
        url: URL = storeURL,
        cloudKitDatabase: ModelConfiguration.CloudKitDatabase = .private(containerIdentifier)
    ) -> ModelConfiguration {
        ModelConfiguration(
            schema: schema,
            url: url,
            cloudKitDatabase: cloudKitDatabase
        )
    }

    static func makeContainer() throws -> ModelContainer {
        let configuration = makeConfiguration()

        #if DEBUG
        installSynchronizationDiagnostics()
        #endif

        do {
            return try ModelContainer(
                for: schema,
                configurations: [configuration]
            )
        } catch {
            #if DEBUG
            let logger = Logger(subsystem: "com.arbi.production", category: "persistence")
            logDiagnostic(
                "ModelContainer configuration: schema=[P2POrder, CapitalSettings, BankAccount, CashWithdrawal], "
                    + "storeURL=\(configuration.url.path), cloudKitDatabase=.private(\(containerIdentifier))",
                logger: logger
            )
            logErrorChain(error, logger: logger)
            #endif
            throw error
        }
    }

    #if DEBUG
    private static let diagnosticMaximumDepth = 8
    private static var synchronizationDiagnosticObservers: [NSObjectProtocol] = []
    private static var synchronizationDiagnosticsInstalled = false
    private static var activeCloudKitEventIDs = Set<UUID>()
    private static var lastLocalSave: (id: UUID, date: Date)?
    private static var destinationDiagnosticsStarted = false

    private static func installSynchronizationDiagnostics() {
        guard !synchronizationDiagnosticsInstalled else { return }
        synchronizationDiagnosticsInstalled = true

        let logger = Logger(subsystem: "com.arbi.production", category: "cloudkit-sync")
        let notificationCenter = NotificationCenter.default

        let eventObserver = notificationCenter.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: nil,
            queue: nil
        ) { notification in
            guard let event = notification.userInfo?[
                NSPersistentCloudKitContainer.eventNotificationUserInfoKey
            ] as? NSPersistentCloudKitContainer.Event else {
                return
            }

            Task { @MainActor in
                logCloudKitEvent(event, logger: logger)
            }
        }

        let saveObserver = notificationCenter.addObserver(
            forName: NSManagedObjectContext.didSaveObjectsNotification,
            object: nil,
            queue: nil
        ) { _ in
            Task { @MainActor in
                let saveID = UUID()
                let saveDate = Date()
                lastLocalSave = (saveID, saveDate)
                logDiagnostic(
                    "local SwiftData save completed, saveID=\(saveID.uuidString), date=\(saveDate)",
                    logger: logger
                )
            }
        }

        synchronizationDiagnosticObservers = [eventObserver, saveObserver]
        logDiagnostic("CloudKit synchronization diagnostics installed", logger: logger)

        guard !destinationDiagnosticsStarted else { return }
        destinationDiagnosticsStarted = true
        Task { @MainActor in
            await logCloudKitDestinationDiagnostics(logger: logger)
        }
    }

    private static func logCloudKitDestinationDiagnostics(logger: Logger) async {
        let container = CKContainer(identifier: containerIdentifier)

        do {
            let accountStatus = try await accountStatus(for: container)
            logDiagnostic(
                "CloudKit destination container=\(containerIdentifier), accountStatus=\(accountStatus)",
                logger: logger
            )

            guard accountStatus == .available else { return }

            let zones = try await container.privateCloudDatabase.allRecordZones()
            let zoneNames = zones.map(\.zoneID.zoneName).sorted()
            logDiagnostic(
                "CloudKit private database zones=[\(zoneNames.joined(separator: ", "))]",
                logger: logger
            )
        } catch {
            logDiagnostic(
                "CloudKit destination diagnostics failed for container=\(containerIdentifier)",
                logger: logger
            )
            logErrorChain(error, logger: logger)
        }
    }

    private static func accountStatus(for container: CKContainer) async throws -> CKAccountStatus {
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

    private static func logCloudKitEvent(
        _ event: NSPersistentCloudKitContainer.Event,
        logger: Logger
    ) {
        let eventType: String
        switch event.type {
        case .setup:
            eventType = "setup"
        case .import:
            eventType = "import"
        case .export:
            eventType = "export"
        @unknown default:
            eventType = "unknown"
        }

        let formatter = ISO8601DateFormatter()
        let startDate = formatter.string(from: event.startDate)
        let endDate = event.endDate.map(formatter.string(from:))
        let isCompleted = endDate != nil

        guard isCompleted else {
            let inserted = activeCloudKitEventIDs.insert(event.identifier).inserted
            guard inserted else { return }

            let saveCorrelation: String
            if let lastLocalSave,
               event.startDate.timeIntervalSince(lastLocalSave.date) >= -1,
               event.startDate.timeIntervalSince(lastLocalSave.date) <= 60 {
                saveCorrelation = "correlatedSaveID=\(lastLocalSave.id.uuidString)"
            } else {
                saveCorrelation = "correlatedSaveID=<none>"
            }

            logDiagnostic(
                "CloudKit event STARTED, identifier=\(event.identifier.uuidString), "
                    + "type=\(eventType), startDate=\(startDate), \(saveCorrelation)",
                logger: logger
            )
            return
        }

        activeCloudKitEventIDs.remove(event.identifier)
        let nsError = event.error as NSError?
        let errorSummary = nsError.map {
            "domain=\($0.domain), code=\($0.code), description=\($0.localizedDescription)"
        } ?? "<nil>"

        logDiagnostic(
            "CloudKit event COMPLETED, identifier=\(event.identifier.uuidString), "
                + "type=\(eventType), startDate=\(startDate), "
                + "endDate=\(endDate ?? "<nil>"), succeeded=\(event.succeeded), error=\(errorSummary)",
            logger: logger
        )

        if let error = event.error {
            logErrorChain(error, logger: logger)
        }
    }

    private static func logDiagnostic(_ message: String, logger: Logger) {
        logger.fault("[ModelContainerDiagnostics] \(message, privacy: .public)")
        print("[ModelContainerDiagnostics] \(message)")
    }

    private static func logErrorChain(_ error: Error, logger: Logger) {
        var visitedErrors = Set<ObjectIdentifier>()
        logError(
            error,
            level: 0,
            path: "root",
            logger: logger,
            visitedErrors: &visitedErrors
        )
    }

    private static func logError(
        _ error: Error,
        level: Int,
        path: String,
        logger: Logger,
        visitedErrors: inout Set<ObjectIdentifier>
    ) {
        guard level <= diagnosticMaximumDepth else {
            logDiagnostic("Error level \(level) omitted at \(path): maximum depth reached", logger: logger)
            return
        }

        let nsError = error as NSError
        let errorIdentity = ObjectIdentifier(nsError)
        guard visitedErrors.insert(errorIdentity).inserted else {
            logDiagnostic("Error level \(level) at \(path) omitted: cycle or duplicate reference", logger: logger)
            return
        }

        logDiagnostic("Error level \(level) [\(path)]", logger: logger)
        logDiagnostic("type: \(String(reflecting: error))", logger: logger)
        logDiagnostic("domain: \(nsError.domain)", logger: logger)
        logDiagnostic("code: \(nsError.code)", logger: logger)
        logDiagnostic("description: \(nsError.localizedDescription)", logger: logger)
        logDiagnostic("failureReason: \(nsError.localizedFailureReason ?? "<nil>")", logger: logger)
        logDiagnostic("recoverySuggestion: \(nsError.localizedRecoverySuggestion ?? "<nil>")", logger: logger)

        let userInfoKeys = nsError.userInfo.keys.map { String(describing: $0) }.sorted()
        logDiagnostic("userInfo keys: [\(userInfoKeys.joined(separator: ", "))]", logger: logger)
        for key in userInfoKeys {
            guard let value = nsError.userInfo.first(where: { String(describing: $0.key) == key })?.value else {
                continue
            }
            logDiagnostic("userInfo[\(key)]: \(safeDiagnosticDescription(value))", logger: logger)
        }

        if let underlying = nsError.userInfo[NSUnderlyingErrorKey] {
            logDiagnostic("NSUnderlyingErrorKey: \(safeDiagnosticDescription(underlying))", logger: logger)
        }
        if let detailedErrors = nsError.userInfo[NSDetailedErrorsKey] {
            logDiagnostic("NSDetailedErrorsKey: \(safeDiagnosticDescription(detailedErrors))", logger: logger)
        }

        guard level < diagnosticMaximumDepth else { return }
        logErrorAssociatedValues(
            of: error,
            level: level + 1,
            path: "\(path).swiftError",
            logger: logger,
            visitedErrors: &visitedErrors
        )
        for (key, value) in nsError.userInfo {
            logNestedErrors(
                in: value,
                level: level + 1,
                path: "\(path).userInfo[\(key)]",
                logger: logger,
                visitedErrors: &visitedErrors
            )
        }
    }

    private static func logErrorAssociatedValues(
        of error: Error,
        level: Int,
        path: String,
        logger: Logger,
        visitedErrors: inout Set<ObjectIdentifier>
    ) {
        let mirror = Mirror(reflecting: error)
        for (index, child) in mirror.children.enumerated() {
            logNestedErrors(
                in: child.value,
                level: level,
                path: "\(path)[\(child.label ?? String(index))]",
                logger: logger,
                visitedErrors: &visitedErrors
            )
        }
    }

    private static func logNestedErrors(
        in value: Any,
        level: Int,
        path: String,
        logger: Logger,
        visitedErrors: inout Set<ObjectIdentifier>
    ) {
        guard level <= diagnosticMaximumDepth else { return }

        if let nestedError = value as? NSError {
            logError(
                nestedError,
                level: level,
                path: path,
                logger: logger,
                visitedErrors: &visitedErrors
            )
            return
        }
        if let nestedError = value as? Error {
            logError(
                nestedError,
                level: level,
                path: path,
                logger: logger,
                visitedErrors: &visitedErrors
            )
            return
        }

        let mirror = Mirror(reflecting: value)
        guard mirror.displayStyle == .collection
            || mirror.displayStyle == .dictionary
            || mirror.displayStyle == .set
            || mirror.displayStyle == .tuple
            || mirror.displayStyle == .optional
            || mirror.displayStyle == .enum
            || mirror.displayStyle == .struct else {
            return
        }

        for (index, child) in mirror.children.enumerated() {
            logNestedErrors(
                in: child.value,
                level: level,
                path: "\(path)[\(child.label ?? String(index))]",
                logger: logger,
                visitedErrors: &visitedErrors
            )
        }
    }

    private static func safeDiagnosticDescription(_ value: Any) -> String {
        if value is NSError || value is Error {
            return "<nested error; expanded recursively>"
        }
        if let data = value as? Data {
            return "<Data length=\(data.count)>"
        }
        if let values = value as? any Collection {
            return "<\(String(reflecting: type(of: value))) count=\(values.count); nested errors expanded recursively>"
        }
        switch value {
        case is String, is NSString, is NSNumber, is URL:
            return String(reflecting: value)
        default:
            return "<\(String(reflecting: type(of: value)))>"
        }
    }
    #endif

#if DEBUG
    /// Test-only container. It never opens the production store or contacts
    /// CloudKit, which keeps the existing DEBUG test harness deterministic.
    static func makeInMemoryContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )
        return try ModelContainer(for: schema, configurations: [configuration])
    }
#endif
}
