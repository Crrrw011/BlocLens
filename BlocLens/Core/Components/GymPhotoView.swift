import SwiftUI

struct GymPhotoView: View {
    let placeID: String?
    let gymName: String
    let photoService: any GymPhotoService
    var width: Int = 800
    var aspectRatio: CGFloat = 16 / 9

    @State private var state: PhotoState = .idle

    enum PhotoState: Equatable {
        case idle
        case loading
        case loaded(GymPhoto)
        case noPhoto
        case error
    }

    var body: some View {
        ZStack {
            switch state {
            case .idle, .loading:
                placeholder
                    .overlay { ProgressView().tint(.white) }
            case .loaded(let photo):
                photoContent(photo)
            case .noPhoto, .error:
                placeholder
            }
        }
        .accessibilityLabel(Text("Photo of \(gymName)"))
        .aspectRatio(aspectRatio, contentMode: .fill)
        .clipShape(RoundedRectangle(cornerRadius: BlocRadius.container, style: .continuous))
        .task(id: placeID) {
            await loadPhoto()
        }
    }

    @ViewBuilder
    private func photoContent(_ photo: GymPhoto) -> some View {
        AsyncImage(url: photo.imageURL) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
            case .failure:
                placeholder
            case .empty:
                placeholder.overlay { ProgressView() }
            @unknown default:
                placeholder
            }
        }
        .overlay(alignment: .bottomLeading) {
            attributionOverlay(photo)
        }
    }

    private var placeholder: some View {
        Rectangle()
            .fill(BlocColor.opticBlueTint)
            .overlay {
                Image(systemName: "building.2.crop.circle")
                    .font(.system(size: 48))
                    .foregroundStyle(.white.opacity(0.6))
            }
    }

    private func attributionOverlay(_ photo: GymPhoto) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            if let attribution = photo.attribution {
                Text(attribution)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.8))
            }
            Text(L10n.GymPhoto.fromGoogle)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.8))
        }
        .padding(6)
    }

    private func loadPhoto() async {
        guard let placeID else {
            state = .noPhoto
            return
        }
        state = .loading
        do {
            let photo = try await photoService.fetchPhoto(for: placeID, width: width)
            state = .loaded(photo)
        } catch {
            state = .error
        }
    }
}

#Preview("Loading") {
    GymPhotoView(placeID: nil, gymName: "Preview Gym", photoService: NoopGymPhotoService())
        .frame(width: 320)
}

#Preview("Placeholder") {
    GymPhotoView(placeID: nil, gymName: "No Place", photoService: NoopGymPhotoService())
        .frame(width: 320)
}
