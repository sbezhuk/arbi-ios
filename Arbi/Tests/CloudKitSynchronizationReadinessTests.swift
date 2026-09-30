import Foundation

@MainActor
public enum CloudKitSynchronizationReadinessTests {
    public static func runAllTests() throws {
        print("--- Running CloudKitSynchronizationReadinessTests ---")
        try testEmptyStoreWithImportPendingShowsRestoringState()
        try testImportCompletesWithDataShowsNormalContent()
        try testImportCompletesWithoutDataShowsNormalEmptyState()
        try testExistingLocalDataShowsContentImmediately()
        try testImportFailureDoesNotRemainStuck()
        try testSetupFailureDoesNotRemainStuck()
        try testUnavailableAccountKeepsLocalAppUsable()
        try testSetupCompletionWaitsForInitialImport()
        print("--- All CloudKitSynchronizationReadinessTests Passed Successfully! ---")
    }

    public static func testEmptyStoreWithImportPendingShowsRestoringState() throws {
        let readiness = CloudKitSynchronizationReadiness(observeNotifications: false)

        assert(
            readiness.shouldShowRestoring(localStoreIsEmpty: true),
            "An empty local store must show restoring while initial sync is pending"
        )
        print("✓ testEmptyStoreWithImportPendingShowsRestoringState passed")
    }

    public static func testImportCompletesWithDataShowsNormalContent() throws {
        let readiness = CloudKitSynchronizationReadiness(observeNotifications: false)
        readiness.handle(eventType: .import, phase: .started)
        readiness.handle(eventType: .import, phase: .completed(succeeded: true))

        assert(
            !readiness.shouldShowRestoring(localStoreIsEmpty: false),
            "Imported local data must show the normal content UI"
        )
        print("✓ testImportCompletesWithDataShowsNormalContent passed")
    }

    public static func testImportCompletesWithoutDataShowsNormalEmptyState() throws {
        let readiness = CloudKitSynchronizationReadiness(observeNotifications: false)
        readiness.handle(eventType: .import, phase: .started)
        readiness.handle(eventType: .import, phase: .completed(succeeded: true))

        assert(
            !readiness.shouldShowRestoring(localStoreIsEmpty: true),
            "A completed empty import must show the normal empty state"
        )
        print("✓ testImportCompletesWithoutDataShowsNormalEmptyState passed")
    }

    public static func testExistingLocalDataShowsContentImmediately() throws {
        let readiness = CloudKitSynchronizationReadiness(observeNotifications: false)

        assert(
            !readiness.shouldShowRestoring(localStoreIsEmpty: false),
            "Existing local data must bypass the restoring UI"
        )
        print("✓ testExistingLocalDataShowsContentImmediately passed")
    }

    public static func testImportFailureDoesNotRemainStuck() throws {
        let readiness = CloudKitSynchronizationReadiness(observeNotifications: false)
        readiness.handle(eventType: .import, phase: .started)
        readiness.handle(eventType: .import, phase: .completed(succeeded: false))

        assert(
            !readiness.shouldShowRestoring(localStoreIsEmpty: true),
            "A failed import must fall back to the normal local empty state"
        )
        print("✓ testImportFailureDoesNotRemainStuck passed")
    }

    public static func testSetupFailureDoesNotRemainStuck() throws {
        let readiness = CloudKitSynchronizationReadiness(observeNotifications: false)
        readiness.handle(eventType: .setup, phase: .started)
        readiness.handle(eventType: .setup, phase: .completed(succeeded: false))

        assert(
            !readiness.shouldShowRestoring(localStoreIsEmpty: true),
            "A failed setup must fall back to the normal local empty state"
        )
        print("✓ testSetupFailureDoesNotRemainStuck passed")
    }

    public static func testUnavailableAccountKeepsLocalAppUsable() throws {
        let readiness = CloudKitSynchronizationReadiness(observeNotifications: false)
        readiness.accountStateChanged(.noAccount)

        assert(
            !readiness.shouldShowRestoring(localStoreIsEmpty: true),
            "A missing iCloud account must not block the local app"
        )
        print("✓ testUnavailableAccountKeepsLocalAppUsable passed")
    }

    public static func testSetupCompletionWaitsForInitialImport() throws {
        let readiness = CloudKitSynchronizationReadiness(observeNotifications: false)
        readiness.handle(eventType: .setup, phase: .completed(succeeded: true))
        assert(
            readiness.shouldShowRestoring(localStoreIsEmpty: true),
            "Successful setup must wait for the initial import to resolve"
        )

        readiness.handle(eventType: .import, phase: .started)
        assert(
            readiness.shouldShowRestoring(localStoreIsEmpty: true),
            "The first import must keep restoring state while it is running"
        )
        print("✓ testSetupCompletionWaitsForInitialImport passed")
    }
}
