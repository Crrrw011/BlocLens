import Foundation

actor RemoteLogbookRepository: LogbookRepository {
    private let dataSource: any RemoteLogbookDataSource
    private let queue: any LogbookQueue
    private var online = true

    init(dataSource: any RemoteLogbookDataSource, queue: any LogbookQueue) {
        self.dataSource = dataSource
        self.queue = queue
    }

    func entries(userID: UserID) async throws -> [LogbookEntry] {
        guard let currentUserID = dataSource.currentUserID() else {
            throw RepositoryError.unauthenticated
        }
        do {
            let records = try await dataSource.fetchEntries(userID: currentUserID)
            let remote = try records.map { try Self.domain($0) }
            let pending = await pendingEntries()
            return Self.merge(remote, with: pending)
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as RepositoryError {
            throw error
        } catch {
            throw RemoteErrorMapping.map(error)
        }
    }

    func entry(userID: UserID, routeID: ClimbingRouteID) async throws -> LogbookEntry? {
        let all = try await entries(userID: userID)
        return all.first { $0.routeID == routeID }
    }

    func saveStatus(
        userID: UserID,
        routeID: ClimbingRouteID,
        status: LogbookStatus,
        date: Date
    ) async throws -> LogbookEntry {
        let entry = LogbookEntry(
            id: LogbookEntryID(rawValue: UUID().uuidString.lowercased()),
            userID: userID,
            routeID: routeID,
            status: status,
            date: date,
            attemptCount: nil,
            privateNote: nil,
            predictedVGrade: nil,
            syncState: .queued,
            privacy: .privateByDefault
        )
        return try await saveEntry(entry)
    }

    func updateDetails(entryID: LogbookEntryID, details: LogbookDetails) async throws -> LogbookEntry {
        guard let userID = dataSource.currentUserID() else {
            throw RepositoryError.unauthenticated
        }
        let all = try await entries(userID: UserID(rawValue: userID.uuidString.lowercased()))
        guard var existing = all.first(where: { $0.id == entryID }) else {
            throw RepositoryError.notFound
        }
        existing.date = details.date
        existing.attemptCount = details.attemptCount
        existing.privateNote = details.privateNote
        existing.predictedVGrade = details.predictedVGrade
        return try await saveEntry(existing)
    }

    func projects(userID: UserID) async throws -> [LogbookEntry] {
        let all = try await entries(userID: userID)
        return all.filter { $0.status == .projecting }
    }

    func setOnline(_ isOnline: Bool) async {
        online = isOnline
    }

    func isOnline() async -> Bool {
        online
    }

    func synchroniseQueuedEntries() async throws -> [LogbookEntry] {
        try await syncNow()
        return await pendingEntries()
    }

    func hasAttemptedRoute(_ routeID: ClimbingRouteID) async throws -> Bool {
        guard let uuid = UUID(uuidString: routeID.rawValue) else {
            return false
        }
        do {
            return try await dataSource.hasAttemptedRoute(routeID: uuid)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw RemoteErrorMapping.map(error)
        }
    }

    func saveEntry(_ entry: LogbookEntry) async throws -> LogbookEntry {
        guard let userID = dataSource.currentUserID() else {
            throw RepositoryError.unauthenticated
        }
        let idempotencyKey = UUID(uuidString: entry.id.rawValue) ?? UUID()
        if online {
            do {
                try await writeEntry(entry, userID: userID, idempotencyKey: idempotencyKey)
                var synced = entry
                synced.syncState = .synced
                return synced
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                var queued = entry
                queued.syncState = .queued
                try await queue.enqueue(Self.pendingOperation(entry: queued, idempotencyKey: idempotencyKey))
                return queued
            }
        }
        var queued = entry
        queued.syncState = .queued
        try await queue.enqueue(Self.pendingOperation(entry: queued, idempotencyKey: idempotencyKey))
        return queued
    }

    func deleteEntry(_ entryID: LogbookEntryID) async throws {
        guard dataSource.currentUserID() != nil else {
            throw RepositoryError.unauthenticated
        }
        guard let uuid = UUID(uuidString: entryID.rawValue) else {
            throw RepositoryError.notFound
        }
        let operation = PendingLogbookOperation(
            id: UUID(),
            kind: .delete,
            entry: nil,
            entryID: entryID,
            timestamp: Date(),
            retryCount: 0,
            lastError: nil
        )
        if online {
            do {
                try await dataSource.softDeleteEntry(entryID: uuid)
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                try await queue.enqueue(operation)
            }
        } else {
            try await queue.enqueue(operation)
        }
    }

    func pendingSyncCount() async -> Int {
        await queue.pendingCount()
    }

    func syncNow() async throws {
        let operations = await queue.pendingOperations()
        for operation in operations {
            do {
                switch operation.kind {
                case .upsert:
                    if let entry = operation.entry {
                        guard let userID = dataSource.currentUserID() else {
                            try await queue.update(Self.failed(operation, error: "unauthenticated"))
                            continue
                        }
                        let idempotencyKey = UUID(uuidString: entry.id.rawValue) ?? operation.id
                        try await writeEntry(entry, userID: userID, idempotencyKey: idempotencyKey)
                    }
                case .delete:
                    if let entryID = operation.entryID,
                       let uuid = UUID(uuidString: entryID.rawValue) {
                        try await dataSource.softDeleteEntry(entryID: uuid)
                    }
                }
                try await queue.remove(operationID: operation.id)
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                try await queue.update(Self.failed(operation, error: String(describing: error)))
            }
        }
    }

    private func writeEntry(
        _ entry: LogbookEntry,
        userID: UUID,
        idempotencyKey: UUID
    ) async throws {
        guard let routeUUID = UUID(uuidString: entry.routeID.rawValue) else {
            throw RepositoryError.notFound
        }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let write = LogbookEntryWrite(
            userID: userID.uuidString,
            routeID: routeUUID.uuidString,
            status: Self.databaseStatus(entry.status),
            climbedAt: formatter.string(from: entry.date),
            attempts: entry.attemptCount,
            privateNote: entry.privateNote,
            predictedVGrade: entry.predictedVGrade?.rawValue,
            clientCreatedAt: formatter.string(from: Date()),
            clientIdempotencyKey: idempotencyKey.uuidString
        )
        try await dataSource.upsertEntry(write)
    }

    private func pendingEntries() async -> [LogbookEntry] {
        let operations = await queue.pendingOperations()
        return operations.compactMap { operation in
            guard operation.kind == .upsert, var entry = operation.entry else { return nil }
            entry.syncState = operation.retryCount > 0 ? .failed : .queued
            return entry
        }
    }

    private static func pendingOperation(
        entry: LogbookEntry,
        idempotencyKey: UUID
    ) -> PendingLogbookOperation {
        PendingLogbookOperation(
            id: idempotencyKey,
            kind: .upsert,
            entry: entry,
            entryID: nil,
            timestamp: Date(),
            retryCount: 0,
            lastError: nil
        )
    }

    private static func failed(
        _ operation: PendingLogbookOperation,
        error: String
    ) -> PendingLogbookOperation {
        var copy = operation
        copy.retryCount += 1
        copy.lastError = error
        return copy
    }

    private static func databaseStatus(_ status: LogbookStatus) -> String {
        switch status {
        case .wantToTry: "want_to_try"
        case .projecting: "projecting"
        case .sent: "sent"
        case .flash: "flash"
        }
    }

    private static func domain(_ record: LogbookEntryRecord) throws -> LogbookEntry {
        do {
            return try record.domain()
        } catch {
            throw RepositoryError.decodingFailure
        }
    }

    private static func merge(_ remote: [LogbookEntry], with pending: [LogbookEntry]) -> [LogbookEntry] {
        var result = remote
        let remoteIDs = Set(remote.map(\.id))
        for entry in pending where !remoteIDs.contains(entry.id) {
            result.append(entry)
        }
        return result.sorted { $0.date > $1.date }
    }
}
