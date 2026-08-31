import Foundation

nonisolated struct GooglePlaceResult: Equatable, Sendable {
    let placeID: String
    let name: String
    let streetAddress: String?
    let latitude: Double
    let longitude: Double
}

nonisolated protocol GooglePlacesClient: Sendable {
    var apiKeyForMediaURL: String { get }
    func searchText(_ query: String) async throws -> [GooglePlaceResult]
    func fetchPlaceDetails(placeID: String, fields: String) async throws -> [String: Any]
}

struct RemoteGooglePlacesClient: GooglePlacesClient, Sendable {
    let apiKey: String
    var apiKeyForMediaURL: String { apiKey }
    private let endpoint = URL(string: "https://places.googleapis.com/v1/places:searchText")!

    func searchText(_ query: String) async throws -> [GooglePlaceResult] {
        guard !apiKey.isEmpty, apiKey != "YOUR_GOOGLE_PLACES_API_KEY" else {
            throw RepositoryError.invalidConfiguration
        }
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "X-Goog-Api-Key")
        request.setValue(
            "places.id,places.displayName,places.formattedAddress,places.location",
            forHTTPHeaderField: "X-Goog-FieldMask"
        )
        let body: [String: Any] = [
            "textQuery": query,
            "includedType": "rock_climbing"
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200 ..< 300).contains(http.statusCode) else {
            throw RepositoryError.externalServiceError
        }
        return try Self.decode(data)
    }

    private static func decode(_ data: Data) throws -> [GooglePlaceResult] {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let places = json["places"] as? [[String: Any]] else {
            throw RepositoryError.decodingFailure
        }
        return places.compactMap { place in
            guard let id = place["id"] as? String,
                  let name = (place["displayName"] as? [String: Any])?["text"] as? String,
                  let location = place["location"] as? [String: Any],
                  let lat = location["latitude"] as? Double,
                  let lng = location["longitude"] as? Double else {
                return nil
            }
            return GooglePlaceResult(
                placeID: id,
                name: name,
                streetAddress: place["formattedAddress"] as? String,
                latitude: lat,
                longitude: lng
            )
        }
    }

    func fetchPlaceDetails(placeID: String, fields: String) async throws -> [String: Any] {
        guard !apiKey.isEmpty, apiKey != "YOUR_GOOGLE_PLACES_API_KEY" else {
            throw RepositoryError.invalidConfiguration
        }
        guard let url = URL(string: "https://places.googleapis.com/v1/places/\(placeID)?fields=\(fields)") else {
            throw RepositoryError.invalidConfiguration
        }
        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "X-Goog-Api-Key")
        request.setValue(fields, forHTTPHeaderField: "X-Goog-FieldMask")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw RepositoryError.externalServiceError
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw RepositoryError.decodingFailure
        }
        return json
    }
}

struct NoopGooglePlacesClient: GooglePlacesClient, Sendable {
    var apiKeyForMediaURL: String { "" }
    func searchText(_ query: String) async throws -> [GooglePlaceResult] {
        []
    }

    func fetchPlaceDetails(placeID: String, fields: String) async throws -> [String: Any] {
        [:]
    }
}

enum GooglePlacesClientFactory {
    static func makeFromBundle() -> any GooglePlacesClient {
        let key = Bundle.main.object(forInfoDictionaryKey: "GooglePlacesAPIKey") as? String ?? ""
        guard !key.isEmpty, key != "YOUR_GOOGLE_PLACES_API_KEY" else {
            return NoopGooglePlacesClient()
        }
        return RemoteGooglePlacesClient(apiKey: key)
    }
}
