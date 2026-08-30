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
    let apiKey: String
    private let session: URLSession

    init(apiKey: String, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.session = session
    }

    func fetchPhoto(for placeID: String, width: Int) async throws -> GymPhoto {
        guard !apiKey.isEmpty, apiKey != "YOUR_GOOGLE_PLACES_API_KEY" else {
            throw RepositoryError.invalidConfiguration
        }

        let detailsURL = URL(string: "https://places.googleapis.com/v1/places/\(placeID)?fields=photos")!
        var detailsRequest = URLRequest(url: detailsURL)
        detailsRequest.setValue(apiKey, forHTTPHeaderField: "X-Goog-Api-Key")
        detailsRequest.setValue("photos.name,photos.authorAttributions", forHTTPHeaderField: "X-Goog-FieldMask")

        let (detailsData, detailsResponse) = try await session.data(for: detailsRequest)
        guard let http = detailsResponse as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw RepositoryError.externalServiceError
        }

        guard let json = try JSONSerialization.jsonObject(with: detailsData) as? [String: Any],
              let photos = json["photos"] as? [[String: Any]],
              let firstPhoto = photos.first,
              let photoName = firstPhoto["name"] as? String else {
            throw RepositoryError.decodingFailure
        }

        let attribution = (firstPhoto["authorAttributions"] as? [[String: Any]])?
            .compactMap { $0["displayName"] as? String }
            .joined(separator: ", ")

        let photoURL = URL(string: "https://places.googleapis.com/v1/\(photoName)/media?maxWidthPx=\(width)")!
        return GymPhoto(imageURL: photoURL, attribution: attribution, attributionHTML: nil)
    }
}
