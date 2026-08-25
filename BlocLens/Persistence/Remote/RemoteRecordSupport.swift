import Foundation

nonisolated enum RemoteMappingError: Error, Equatable, Sendable {
    case invalidUUID(field: String, value: String)
    case invalidURL(field: String, value: String)
    case unsupportedValue(field: String, value: String)
    case inconsistentData(String)
}

nonisolated enum RemoteJSONCoding {
    static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)

            let fractional = ISO8601DateFormatter()
            fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = fractional.date(from: value) {
                return date
            }

            let wholeSeconds = ISO8601DateFormatter()
            wholeSeconds.formatOptions = [.withInternetDateTime]
            if let date = wholeSeconds.date(from: value) {
                return date
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Expected an ISO 8601 timestamptz value."
            )
        }
        return decoder
    }

    static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder in
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            var container = encoder.singleValueContainer()
            try container.encode(formatter.string(from: date))
        }
        return encoder
    }
}

nonisolated enum RemoteIdentifier {
    static func domainString(_ value: UUID) -> String {
        value.uuidString.lowercased()
    }

    static func uuid<Tag>(from value: EntityID<Tag>, field: String) throws -> UUID {
        guard let uuid = UUID(uuidString: value.rawValue) else {
            throw RemoteMappingError.invalidUUID(field: field, value: value.rawValue)
        }
        return uuid
    }
}

nonisolated enum RemoteGrade {
    static func domain(_ value: Int?, field: String) throws -> VGrade? {
        guard let value else { return nil }
        guard let grade = VGrade(rawValue: value), grade != .unknown else {
            throw RemoteMappingError.unsupportedValue(field: field, value: String(value))
        }
        return grade
    }
}
