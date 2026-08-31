import SwiftUI

struct GymPhotoCarouselView: View {
    let placeID: String?
    let gymName: String
    let loader: any GymPhotoLoader
    var width: Int = 800
    var aspectRatio: CGFloat = 16 / 9
    var cornerRadius: CGFloat = BlocRadius.container
    var onTap: (() -> Void)? = nil

    @StateObject private var viewModel: GymPhotoCarouselViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(placeID: String?, gymName: String, loader: any GymPhotoLoader, width: Int = 800, aspectRatio: CGFloat = 16/9, cornerRadius: CGFloat = BlocRadius.container, onTap: (() -> Void)? = nil) {
        self.placeID = placeID
        self.gymName = gymName
        self.loader = loader
        self.width = width
        self.aspectRatio = aspectRatio
        self.cornerRadius = cornerRadius
        self.onTap = onTap
        _viewModel = StateObject(wrappedValue: GymPhotoCarouselViewModel(placeID: placeID, gymName: gymName, loader: loader))
    }

    var body: some View {
        Group {
            if !viewModel.hasContent {
                placeholder
                    .accessibilityLabel(Text("Photo of \(gymName)"))
                    .accessibilityIdentifier("gym-photo-placeholder")
            } else {
                carouselContent
            }
        }
        .aspectRatio(aspectRatio, contentMode: .fill)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .task {
            await viewModel.onAppear()
        }
        .onDisappear {
            viewModel.onDisappear()
        }
        .onChange(of: viewModel.selectedIndex) { _, newIndex in
            Task { await viewModel.onSelectedIndexChanged(newIndex) }
        }
    }

    @ViewBuilder
    private var carouselContent: some View {
        VStack(spacing: 6) {
            TabView(selection: $viewModel.selectedIndex) {
                ForEach(0..<viewModel.displayCount, id: \.self) { index in
                    photoPage(at: index)
                        .tag(index)
                        .accessibilityIdentifier("gym-photo-page-\(index)")
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: viewModel.selectedIndex)
            .frame(height: nil)

            if viewModel.shouldShowIndicator {
                HStack(spacing: 6) {
                    ForEach(0..<viewModel.displayCount, id: \.self) { index in
                        Circle()
                            .fill(index == viewModel.selectedIndex ? DesignColour.brandPrimary : DesignColour.separator)
                            .frame(width: 6, height: 6)
                            .animation(reduceMotion ? nil : .easeInOut(duration: 0.15), value: viewModel.selectedIndex)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(Text("Photo \(viewModel.selectedIndex + 1) of \(viewModel.displayCount)"))
                .accessibilityIdentifier("gym-photo-indicator")
            }
        }
    }

    @ViewBuilder
    private func photoPage(at index: Int) -> some View {
        ZStack {
            switch viewModel.states[index] {
            case .idle, .loading, .none:
                placeholder
                    .overlay { ProgressView().tint(.white).accessibilityIdentifier("gym-photo-loading-\(index)") }
            case .loaded(let photo):
                AsyncImage(url: photo.imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .failure:
                        errorView(at: index)
                    case .empty:
                        placeholder.overlay { ProgressView() }
                    @unknown default:
                        placeholder
                    }
                }
                .overlay(alignment: .bottomLeading) {
                    if let attr = photo.attribution {
                        Text(attr)
                            .font(.system(size: 8, weight: .regular))
                            .foregroundStyle(.white.opacity(0.7))
                            .lineLimit(1)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                    }
                }
                .onTapGesture {
                    onTap?()
                }
            case .error:
                errorView(at: index)
            case .empty:
                placeholder
            }
        }
        .clipped()
        .task {
            // Ensure this page's photo is loaded when it becomes visible via paging
            // Only for initial page this is redundant but safe due to deduplication
            if index == viewModel.selectedIndex {
                await viewModel.loadIfNeeded(index: index)
            }
        }
        .onAppear {
            // For pagination, load will be triggered by selectedIndex change
            // This onAppear handles prefetch avoidance: we don't auto-load offscreen pages except selected
        }
    }

    private var placeholder: some View {
        Rectangle()
            .fill(BlocColor.opticBlueTint)
            .overlay {
                Image(systemName: "building.2.crop.circle")
                    .font(.system(size: 48))
                    .foregroundStyle(.white.opacity(0.6))
                    .accessibilityHidden(true)
            }
    }

    private func errorView(at index: Int) -> some View {
        ZStack {
            placeholder
            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(.white)
                Text(L10n.GymPhoto.error)
                    .font(DesignTypography.caption)
                    .foregroundStyle(.white)
                Button(L10n.Common.tryAgain) {
                    Task { await viewModel.retry(index: index) }
                }
                .buttonStyle(SecondaryButtonStyle())
                .frame(width: 120)
                .accessibilityIdentifier("gym-photo-retry-\(index)")
            }
            .padding()
        }
        .accessibilityLabel(Text("Photo failed to load"))
    }
}

#Preview("Carousel - 1 photo") {
    let photo = GymPhoto(imageURL: URL(string: "https://example.com/p1.jpg")!, attribution: "Test", attributionHTML: nil)
    let loader = MockGymPhotoLoader(photosByPlaceID: ["test-place": [photo]])
    GymPhotoCarouselView(placeID: "test-place", gymName: "Test Gym", loader: loader)
        .frame(height: 200)
        .padding()
}

#Preview("Carousel - 4 photos") {
    let photos = (1...4).map { GymPhoto(imageURL: URL(string: "https://example.com/p\($0).jpg")!, attribution: "Attr \($0)", attributionHTML: nil) }
    let loader = MockGymPhotoLoader(photosByPlaceID: ["test-place": photos])
    GymPhotoCarouselView(placeID: "test-place", gymName: "Test Gym", loader: loader)
        .frame(height: 200)
        .padding()
}

#Preview("Carousel - Loading") {
    let loader = MockGymPhotoLoader(photosByPlaceID: ["test-place": []], delayNanoseconds: 2_000_000_000)
    GymPhotoCarouselView(placeID: "test-place", gymName: "Test Gym", loader: loader)
        .frame(height: 200)
        .padding()
}

#Preview("Carousel - Error") {
    let photos = [GymPhoto(imageURL: URL(string: "https://example.com/p1.jpg")!, attribution: nil, attributionHTML: nil)]
    let loader = MockGymPhotoLoader(photosByPlaceID: ["test-place": photos])
    GymPhotoCarouselView(placeID: "test-place", gymName: "Test Gym", loader: loader)
        .frame(height: 200)
        .padding()
}

#Preview("Carousel - Empty") {
    let loader = MockGymPhotoLoader(photosByPlaceID: [:])
    GymPhotoCarouselView(placeID: nil, gymName: "No Place", loader: loader)
        .frame(height: 200)
        .padding()
}
