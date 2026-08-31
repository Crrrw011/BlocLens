import Foundation

nonisolated struct GymPhoto: Equatable, Sendable {
    let imageURL: URL
    let attribution: String?
    let attributionHTML: String?
}

nonisolated protocol GymPhotoService: Sendable {
    func fetchPhoto(for placeID: String, width: Int) async throws -> GymPhoto
}

struct NoopGymPhotoService: GymPhotoService, Sendable {
    func fetchPhoto(for placeID: String, width: Int) async throws -> GymPhoto {
        throw RepositoryError.invalidConfiguration
    }
}

actor RemoteGymPhotoService: GymPhotoService {
    private let client: GooglePlacesClient

    init(client: GooglePlacesClient) {
        self.client = client
    }

    func fetchPhoto(for placeID: String, width: Int) async throws -> GymPhoto {
        let json = try await client.fetchPlaceDetails(placeID: placeID, fields: "photos.name,photos.authorAttributions")

        guard let photos = json["photos"] as? [[String: Any]],
              let firstPhoto = photos.first,
              let photoName = firstPhoto["name"] as? String else {
            throw RepositoryError.decodingFailure
        }

        let attribution = (firstPhoto["authorAttributions"] as? [[String: Any]])?
            .compactMap { $0["displayName"] as? String }
            .joined(separator: ", ")

        // Fetch photoUri via skipHttpRedirect to avoid requiring bundle header on AsyncImage
        var mediaComponents = URLComponents(string: "https://places.googleapis.com/v1/\(photoName)/media")
        mediaComponents?.queryItems = [
            URLQueryItem(name: "maxWidthPx", value: "\(width)"),
            URLQueryItem(name: "skipHttpRedirect", value: "true")
        ]
        guard let mediaURL = mediaComponents?.url else {
            throw RepositoryError.invalidConfiguration
        }
        var mediaRequest = URLRequest(url: mediaURL)
        mediaRequest.setValue(client.apiKeyForMediaURL, forHTTPHeaderField: "X-Goog-Api-Key")
        if let bundleID = Bundle.main.bundleIdentifier {
            mediaRequest.setValue(bundleID, forHTTPHeaderField: "X-Ios-Bundle-Identifier")
        }
        let (mediaData, mediaResponse) = try await URLSession.shared.data(for: mediaRequest)
        guard let http = mediaResponse as? HTTPURLResponse, (200..<300).contains(http.statusCode),
              let mediaJson = try JSONSerialization.jsonObject(with: mediaData) as? [String: Any],
              let photoUri = mediaJson["photoUri"] as? String,
              let photoURL = URL(string: photoUri) else {
            throw RepositoryError.decodingFailure
        }
        return GymPhoto(imageURL: photoURL, attribution: attribution, attributionHTML: nil)
    }
}
