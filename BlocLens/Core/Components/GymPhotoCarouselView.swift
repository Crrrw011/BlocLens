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
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor

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
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityLabel(Text("Photo of \(gymName)"))
                    .accessibilityIdentifier("gym-photo-placeholder")
            } else {
                carouselContent
            }
        }
        .aspectRatio(aspectRatio, contentMode: .fit)
        .frame(maxWidth: .infinity)
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
        TabView(selection: $viewModel.selectedIndex) {
            ForEach(0..<viewModel.displayCount, id: \.self) { index in
                photoPage(at: index)
                    .tag(index)
                    .accessibilityIdentifier("gym-photo-page-\(index)")
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: viewModel.selectedIndex)
        .overlay(alignment: .bottom) {
            if viewModel.shouldShowIndicator {
                pageIndicator
                    .padding(.bottom, 12)
                    .allowsHitTesting(false)
            }
        }
    }

    private var pageIndicator: some View {
        HStack(spacing: 6) {
            ForEach(0..<viewModel.displayCount, id: \.self) { index in
                Circle()
                    .fill(indicatorDotFill(isSelected: index == viewModel.selectedIndex))
                    .frame(width: index == viewModel.selectedIndex ? 7 : 6, height: index == viewModel.selectedIndex ? 7 : 6)
                    .overlay {
                        if index == viewModel.selectedIndex {
                            Circle().stroke(Color.black.opacity(0.12), lineWidth: 0.5)
                        } else if differentiateWithoutColor {
                            Circle().stroke(Color.white.opacity(0.65), lineWidth: 0.6)
                        }
                    }
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background {
            Capsule()
                .fill(indicatorBackground)
                .overlay { Capsule().fill(Color.black.opacity(indicatorBackgroundOpacity)) }
        }
        .overlay { Capsule().stroke(.white.opacity(0.18), lineWidth: 0.5) }
        .shadow(color: .black.opacity(0.18), radius: 6, y: 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("Photo \(viewModel.selectedIndex + 1) of \(viewModel.displayCount)"))
        .accessibilityValue(Text("Photo \(viewModel.selectedIndex + 1) of \(viewModel.displayCount)"))
        .accessibilityAddTraits(.isImage)
        .accessibilityIdentifier("gym-photo-indicator")
    }

    private func indicatorDotFill(isSelected: Bool) -> Color {
        if isSelected { return .white }
        return Color.white.opacity(0.45)
    }

    private var indicatorBackground: Material {
        reduceTransparency ? .regularMaterial : .ultraThinMaterial
    }

    private var indicatorBackgroundOpacity: Double {
        reduceTransparency ? 0.08 : 0.12
    }

    @ViewBuilder
    private func photoPage(at index: Int) -> some View {
        ZStack {
            switch viewModel.states[index] {
            case .idle, .loading, .none:
                placeholder
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .overlay { ProgressView().tint(.white).accessibilityIdentifier("gym-photo-loading-\(index)") }
            case .loaded(let photo):
                Group {
                    if photo.imageURL.absoluteString.contains("picsum.photos") || photo.imageURL.absoluteString.contains("example.com") {
                        // Mock/seed image – deterministic color fallback, real URIs will be googleusercontent and take else branch
                        Rectangle()
                            .fill(Color(hue: Double(index + 1) * 0.2, saturation: 0.55, brightness: 0.85))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .overlay {
                                VStack(spacing: 6) {
                                    Image(systemName: "photo.on.rectangle")
                                        .font(.system(size: 28))
                                        .foregroundStyle(.white.opacity(0.85))
                                    if let attr = photo.attribution {
                                        Text(attr).font(.caption2.weight(.medium)).foregroundStyle(.white.opacity(0.9))
                                    }
                                }
                            }
                    } else {
                        AsyncImage(url: photo.imageURL) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable().scaledToFill()
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .clipped()
                            case .failure:
                                errorView(at: index)
                            case .empty:
                                placeholder
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .overlay { ProgressView().tint(.white) }
                            @unknown default:
                                placeholder.frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                .overlay(alignment: .bottomLeading) {
                    if let attr = photo.attribution, !photo.imageURL.absoluteString.contains("picsum.photos") {
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
                placeholder.frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay {
                Image(systemName: "building.2.crop.circle")
                    .font(.system(size: 48))
                    .foregroundStyle(.white.opacity(0.6))
                    .accessibilityHidden(true)
            }
            .clipped()
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .accessibilityLabel(Text("Photo failed to load"))
    }
}

#Preview("Carousel - 1 photo") {
    let photo = GymPhoto(imageURL: URL(string: "https://picsum.photos/seed/preview1/800/600")!, attribution: "Test", attributionHTML: nil)
    let loader = MockGymPhotoLoader(photosByPlaceID: ["test-place": [photo]])
    GymPhotoCarouselView(placeID: "test-place", gymName: "Test Gym", loader: loader)
        .frame(height: 200)
        .padding()
}

#Preview("Carousel - 4 photos") {
    let photos = (1...4).map { GymPhoto(imageURL: URL(string: "https://picsum.photos/seed/preview\($0)/800/600")!, attribution: "Attr \($0)", attributionHTML: nil) }
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
    let photos = [GymPhoto(imageURL: URL(string: "https://picsum.photos/seed/error/800/600")!, attribution: nil, attributionHTML: nil)]
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
