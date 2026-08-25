import Foundation

nonisolated enum LogbookOperationKind: String, Codable, Sendable {
    case upsert
    case delete
}

nonisolated struct PendingLogbookOperation: Codable, Equatable, Sendable {
    let id: UUID
    let kind: LogbookOperationKind
    let entry: LogbookEntry?
    let entryID: LogbookEntryID?
    let timestamp: Date
    var retryCount: Int
    var lastError: String?
}

nonisolated protocol LogbookQueue: Sendable {
    func pendingOperations() async -> [PendingLogbookOperation]
    func pendingCount() async -> Int
    func enqueue(_ operation: PendingLogbookOperation) async throws
    func update(_ operation: PendingLogbookOperation) async throws
    func remove(operationID: UUID) async throws
}

actor FileBackedLogbookQueue: LogbookQueue {
    private var operations: [PendingLogbookOperation]
    private let fileURL: URL

    init(fileURL: URL) {
        self.fileURL = fileURL
        operations = Self.load(from: fileURL) ?? []
    }

    func pendingOperations() -> [PendingLogbookOperation] {
        operations
    }

    func pendingCount() -> Int {
        operations.count
    }

    func enqueue(_ operation: PendingLogbookOperation) throws {
        operations.append(operation)
        try persist()
    }

    func update(_ operation: PendingLogbookOperation) throws {
        if let index = operations.firstIndex(where: { $0.id == operation.id }) {
            operations[index] = operation
            try persist()
        }
    }

    func remove(operationID: UUID) throws {
        operations.removeAll { $0.id == operationID }
        try persist()
    }

    private func persist() throws {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(operations)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            throw RepositoryError.persistenceError
        }
    }

    private static func load(from url: URL) -> [PendingLogbookOperation]? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode([PendingLogbookOperation].self, from: data)
    }
}

actor InMemoryLogbookQueue: LogbookQueue {
    private var operations: [PendingLogbookOperation] = []

    func pendingOperations() -> [PendingLogbookOperation] {
        operations
    }

    func pendingCount() -> Int {
        operations.count
    }

    func enqueue(_ operation: PendingLogbookOperation) throws {
        operations.append(operation)
    }

    func update(_ operation: PendingLogbookOperation) throws {
        if let index = operations.firstIndex(where: { $0.id == operation.id }) {
            operations[index] = operation
        }
    }

    func remove(operationID: UUID) throws {
        operations.removeAll { $0.id == operationID }
    }
}
