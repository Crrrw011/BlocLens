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

        // Media endpoint requires API key — append as query param so AsyncImage can fetch without custom header
        // The redirect target (lh3.googleusercontent.com) does not require the key
        var components = URLComponents(string: "https://places.googleapis.com/v1/\(photoName)/media")
        components?.queryItems = [
            URLQueryItem(name: "maxWidthPx", value: "\(width)"),
            URLQueryItem(name: "key", value: client.apiKeyForMediaURL)
        ]
        guard let photoURL = components?.url else {
            throw RepositoryError.invalidConfiguration
        }
        return GymPhoto(imageURL: photoURL, attribution: attribution, attributionHTML: nil)
    }
}
