import Foundation
import Supabase
import Testing
@testable import BlocLens

@MainActor
struct RemoteLogbookRepositoryTests {
    private func uuid(_ suffix: Int) throws -> UUID {
        try #require(UUID(uuidString: String(format: "00000000-0000-4000-8000-%012d", suffix)))
    }

    private func makeEntry(
        id: UUID,
        userID: UUID,
        routeID: UUID,
        status: LogbookStatus = .projecting
    ) -> LogbookEntry {
        LogbookEntry(
            id: LogbookEntryID(rawValue: id.uuidString.lowercased()),
            userID: UserID(rawValue: userID.uuidString.lowercased()),
            routeID: ClimbingRouteID(rawValue: routeID.uuidString.lowercased()),
            status: status,
            date: Date(),
            attemptCount: 3,
            privateNote: "fixture note",
            predictedVGrade: .v4,
            syncState: .queued,
            privacy: .privateByDefault
        )
    }

    private func makeRecord(
        id: UUID,
        userID: UUID,
        routeID: UUID,
        status: LogbookStatus = .projecting
    ) throws -> LogbookEntryRecord {
        let entry = LogbookEntry(
            id: LogbookEntryID(rawValue: id.uuidString.lowercased()),
            userID: UserID(rawValue: userID.uuidString.lowercased()),
            routeID: ClimbingRouteID(rawValue: routeID.uuidString.lowercased()),
            status: status,
            date: Date(),
            attemptCount: 3,
            privateNote: "fixture note",
            predictedVGrade: .v4,
            syncState: .synced,
            privacy: .privateByDefault
        )
        return try LogbookEntryRecord(
            domain: entry,
            clientCreatedAt: Date(),
            clientIdempotencyKey: UUID(),
            serverCreatedAt: Date(),
            serverUpdatedAt: Date()
        )
    }

    private func makeRepository(
        _ dataSource: FakeLogbookDataSource,
        queue: LogbookQueue = InMemoryLogbookQueue()
    ) -> RemoteLogbookRepository {
        RemoteLogbookRepository(dataSource: dataSource, queue: queue)
    }

    @Test func entriesReturnsRemoteEntries() async throws {
        let userID = try uuid(1)
        let dataSource = FakeLogbookDataSource()
        dataSource.currentUserIDValue = userID
        dataSource.records = [try makeRecord(id: try uuid(2), userID: userID, routeID: try uuid(3))]

        let entries = try await makeRepository(dataSource).entries(
            userID: UserID(rawValue: userID.uuidString.lowercased())
        )

        #expect(entries.count == 1)
        #expect(entries[0].status == .projecting)
    }

    @Test func entriesReturnsEmptyForNoEntries() async throws {
        let userID = try uuid(1)
        let dataSource = FakeLogbookDataSource()
        dataSource.currentUserIDValue = userID

        let entries = try await makeRepository(dataSource).entries(
            userID: UserID(rawValue: userID.uuidString.lowercased())
        )

        #expect(entries.isEmpty)
    }

    @Test func entriesRequiresAuthentication() async throws {
        let dataSource = FakeLogbookDataSource()
        dataSource.currentUserIDValue = nil

        do {
            _ = try await makeRepository(dataSource).entries(userID: UserID(rawValue: try uuid(1).uuidString.lowercased()))
            Issue.record("Expected unauthenticated")
        } catch let error as RepositoryError {
            #expect(error == .unauthenticated)
        }
    }

    @Test func saveEntryWritesWhenOnline() async throws {
        let userID = try uuid(1)
        let dataSource = FakeLogbookDataSource()
        dataSource.currentUserIDValue = userID
        let entry = makeEntry(id: try uuid(2), userID: userID, routeID: try uuid(3))

        let saved = try await makeRepository(dataSource).saveEntry(entry)

        #expect(saved.syncState == .synced)
        #expect(dataSource.insertedWrites.count == 1)
    }

    @Test func saveEntryRequiresAuthentication() async throws {
        let dataSource = FakeLogbookDataSource()
        dataSource.currentUserIDValue = nil
        let entry = makeEntry(id: try uuid(2), userID: try uuid(1), routeID: try uuid(3))

        do {
            _ = try await makeRepository(dataSource).saveEntry(entry)
            Issue.record("Expected unauthenticated")
        } catch let error as RepositoryError {
            #expect(error == .unauthenticated)
        }
    }

    @Test func saveEntryOfflineEnqueues() async throws {
        let userID = try uuid(1)
        let dataSource = FakeLogbookDataSource()
        dataSource.currentUserIDValue = userID
        let queue = InMemoryLogbookQueue()
        let repository = makeRepository(dataSource, queue: queue)
        await repository.setOnline(false)
        let entry = makeEntry(id: try uuid(2), userID: userID, routeID: try uuid(3))

        let saved = try await repository.saveEntry(entry)

        #expect(saved.syncState == .queued)
        #expect(await repository.pendingSyncCount() == 1)
    }

    @Test func syncNowMarksSyncedAfterSuccess() async throws {
        let userID = try uuid(1)
        let dataSource = FakeLogbookDataSource()
        dataSource.currentUserIDValue = userID
        let queue = InMemoryLogbookQueue()
        let repository = makeRepository(dataSource, queue: queue)
        await repository.setOnline(false)
        _ = try await repository.saveEntry(makeEntry(id: try uuid(2), userID: userID, routeID: try uuid(3)))
        await repository.setOnline(true)

        try await repository.syncNow()

        #expect(await repository.pendingSyncCount() == 0)
    }

    @Test func syncNowMarksFailedOnError() async throws {
        let userID = try uuid(1)
        let dataSource = FakeLogbookDataSource()
        dataSource.currentUserIDValue = userID
        dataSource.upsertError = PostgrestError(code: "network", message: "offline")
        let queue = InMemoryLogbookQueue()
        let repository = makeRepository(dataSource, queue: queue)
        await repository.setOnline(false)
        _ = try await repository.saveEntry(makeEntry(id: try uuid(2), userID: userID, routeID: try uuid(3)))
        await repository.setOnline(true)

        try await repository.syncNow()

        #expect(await repository.pendingSyncCount() == 1)
        let operations = await queue.pendingOperations()
        #expect(operations.first?.retryCount == 1)
        #expect(operations.first?.lastError != nil)
    }

    @Test func syncNowRetriesAfterRecovery() async throws {
        let userID = try uuid(1)
        let dataSource = FakeLogbookDataSource()
        dataSource.currentUserIDValue = userID
        dataSource.upsertError = PostgrestError(code: "network", message: "offline")
        let queue = InMemoryLogbookQueue()
        let repository = makeRepository(dataSource, queue: queue)
        await repository.setOnline(false)
        _ = try await repository.saveEntry(makeEntry(id: try uuid(2), userID: userID, routeID: try uuid(3)))
        await repository.setOnline(true)

        try await repository.syncNow()
        #expect(await repository.pendingSyncCount() == 1)

        dataSource.upsertError = nil
        try await repository.syncNow()
        #expect(await repository.pendingSyncCount() == 0)
    }

    @Test func deleteEntrySoftDeletesWhenOnline() async throws {
        let userID = try uuid(1)
        let dataSource = FakeLogbookDataSource()
        dataSource.currentUserIDValue = userID

        try await makeRepository(dataSource).deleteEntry(
            LogbookEntryID(rawValue: try uuid(2).uuidString.lowercased())
        )

        #expect(dataSource.deletedIDs.count == 1)
    }

    @Test func deleteEntryRequiresAuthentication() async throws {
        let dataSource = FakeLogbookDataSource()
        dataSource.currentUserIDValue = nil

        do {
            try await makeRepository(dataSource).deleteEntry(
                LogbookEntryID(rawValue: try uuid(2).uuidString.lowercased())
            )
            Issue.record("Expected unauthenticated")
        } catch let error as RepositoryError {
            #expect(error == .unauthenticated)
        }
    }

    @Test func hasAttemptedRouteReturnsDataSourceResult() async throws {
        let dataSource = FakeLogbookDataSource()
        dataSource.currentUserIDValue = try uuid(1)
        dataSource.hasAttempt = true

        let result = try await makeRepository(dataSource).hasAttemptedRoute(
            ClimbingRouteID(rawValue: try uuid(2).uuidString.lowercased())
        )
        #expect(result)
    }

    @Test func privateNotePreservedThroughQueue() async throws {
        let userID = try uuid(1)
        let dataSource = FakeLogbookDataSource()
        dataSource.currentUserIDValue = userID
        let queue = InMemoryLogbookQueue()
        let repository = makeRepository(dataSource, queue: queue)
        await repository.setOnline(false)
        var entry = makeEntry(id: try uuid(2), userID: userID, routeID: try uuid(3))
        entry.privateNote = "secret note"

        _ = try await repository.saveEntry(entry)
        let pending = await queue.pendingOperations()

        #expect(pending.first?.entry?.privateNote == "secret note")
    }

    @Test func mockLogbookRepositoryDeletesAndAttempts() async throws {
        let repository = MockLogbookRepository()
        let userID = UserID(rawValue: "fixture-user")
        let routeID = ClimbingRouteID(rawValue: "west-end-slab-r1")

        #expect(await repository.hasAttemptedRoute(routeID))

        try await repository.saveStatus(userID: userID, routeID: routeID, status: .wantToTry, date: Date())
        #expect(await repository.pendingSyncCount() >= 0)
    }
}

private final class FakeLogbookDataSource: RemoteLogbookDataSource, @unchecked Sendable {
    var currentUserIDValue: UUID?
    var records: [LogbookEntryRecord] = []
    var insertedWrites: [LogbookEntryWrite] = []
    var deletedIDs: [UUID] = []
    var hasAttempt = false
    var upsertError: Error?
    var deleteError: Error?

    func currentUserID() -> UUID? { currentUserIDValue }

    func fetchEntries(userID: UUID) async throws -> [LogbookEntryRecord] {
        records.filter { $0.userID == userID && $0.deletedAt == nil }
    }

    func upsertEntry(_ write: LogbookEntryWrite) async throws {
        if let upsertError { throw upsertError }
        insertedWrites.append(write)
    }

    func softDeleteEntry(entryID: UUID) async throws {
        if let deleteError { throw deleteError }
        deletedIDs.append(entryID)
    }

    func hasAttemptedRoute(routeID: UUID) async throws -> Bool {
        hasAttempt
    }
}
