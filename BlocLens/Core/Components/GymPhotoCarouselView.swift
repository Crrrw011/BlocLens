import SwiftUI

// MARK: - Shared Metrics (single source of truth for visual ratio)

enum GymPhotoCarouselMetrics {
    static let aspectRatio: CGFloat = 16.0 / 10.0 // width : height = 16 : 10 ≈ 1.6
    static let indicatorBottomPadding: CGFloat = 12
}

enum GymPhotoCarouselStyle {
    case home
    case detail
}

struct GymPhotoCarouselView: View {
    let placeID: String?
    let gymName: String
    let loader: any GymPhotoLoader
    var width: Int = 800
    var aspectRatio: CGFloat = GymPhotoCarouselMetrics.aspectRatio
    var cornerRadius: CGFloat = BlocRadius.container
    var onTap: (() -> Void)? = nil

    @StateObject private var viewModel: GymPhotoCarouselViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.displayScale) private var displayScale
    @State private var virtualIndex: Int = 500
    @State private var autoTask: Task<Void, Never>?
    @State private var containerWidth: CGFloat = 0

    private var bufferedCount: Int {
        guard viewModel.displayCount > 1 else { return viewModel.displayCount }
        return viewModel.displayCount * 3
    }
    private var middleStart: Int {
        guard viewModel.displayCount > 0 else { return 0 }
        return viewModel.displayCount
    }

    init(placeID: String?, gymName: String, loader: any GymPhotoLoader, width: Int = 800, aspectRatio: CGFloat = GymPhotoCarouselMetrics.aspectRatio, cornerRadius: CGFloat = BlocRadius.container, onTap: (() -> Void)? = nil) {
        self.placeID = placeID
        self.gymName = gymName
        self.loader = loader
        self.width = width
        self.aspectRatio = aspectRatio
        self.cornerRadius = cornerRadius
        self.onTap = onTap
        _viewModel = StateObject(wrappedValue: GymPhotoCarouselViewModel(placeID: placeID, gymName: gymName, loader: loader))
    }

    private var actualIndex: Int {
        guard viewModel.displayCount > 0 else { return 0 }
        return ((virtualIndex % viewModel.displayCount) + viewModel.displayCount) % viewModel.displayCount
    }

    private var shouldAutoPlay: Bool {
        !reduceMotion && viewModel.displayCount > 1
    }

    @ViewBuilder
    private var carouselContainer: some View {
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }

    var body: some View {
        GeometryReader { proxy in
            let pointWidth = proxy.size.width
            let bucket = GymPhotoBucket.bucket(for: Int(pointWidth * displayScale))
            carouselContainer
                .task(id: bucket) {
                    await viewModel.initialLoad(width: bucket)
                    if viewModel.displayCount > 0 {
                        virtualIndex = middleStart
                        viewModel.selectedIndex = actualIndex
                        Task { await viewModel.onSelectedIndexChanged(actualIndex) }
                        if shouldAutoPlay { startAuto() }
                    }
                }
                .onAppear { containerWidth = pointWidth }
                .onChange(of: pointWidth) { _, new in containerWidth = new }
        }
        .aspectRatio(GymPhotoCarouselMetrics.aspectRatio, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .accessibilityIdentifier("gym-photo-carousel")
        .overlay(alignment: .bottom) {
            if viewModel.shouldShowIndicator {
                pageIndicator
                    .padding(.bottom, GymPhotoCarouselMetrics.indicatorBottomPadding)
                    .allowsHitTesting(false)
            }
        }
        .onDisappear {
            viewModel.onDisappear()
            stopAuto()
        }
        .onChange(of: viewModel.displayCount) { _, newCount in
            if newCount > 0 {
                virtualIndex = newCount // middleStart for new count
            }
        }
        .onChange(of: virtualIndex) { _, newVirtual in
            guard viewModel.displayCount > 0 else { return }
            let actual = ((newVirtual % viewModel.displayCount) + viewModel.displayCount) % viewModel.displayCount
            viewModel.selectedIndex = actual
            Task { await viewModel.onSelectedIndexChanged(actual) }
            if newVirtual <= 0 || newVirtual >= bufferedCount - 1 {
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 750_000_000)
                    if virtualIndex == newVirtual {
                        withAnimation(nil) {
                            virtualIndex = middleStart + actual
                        }
                    }
                }
            } else if newVirtual < middleStart || newVirtual >= middleStart + viewModel.displayCount {
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 750_000_000)
                    if virtualIndex == newVirtual {
                        withAnimation(nil) {
                            virtualIndex = middleStart + actual
                        }
                    }
                }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                if shouldAutoPlay { startAuto() }
            } else {
                stopAuto()
            }
        }
        .onChange(of: reduceMotion) { _, isReduced in
            if isReduced { stopAuto() } else if shouldAutoPlay { startAuto() }
        }
    }

    private func startAuto() {
        guard shouldAutoPlay else { return }
        stopAuto()
        autoTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 4_000_000_000)
                if Task.isCancelled { break }
                if reduceMotion { continue }
                if viewModel.displayCount <= 1 { continue }
                let nextActual = ((virtualIndex + 1) % viewModel.displayCount + viewModel.displayCount) % viewModel.displayCount
                let nextState = viewModel.states[nextActual]
                let isReady: Bool = {
                    if case .loaded = nextState { return true }
                    return false
                }()
                if !isReady {
                    Task { await viewModel.onSelectedIndexChanged(nextActual) }
                    continue
                }
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.72)) {
                    virtualIndex += 1
                }
            }
        }
    }

    private func stopAuto() {
        autoTask?.cancel()
        autoTask = nil
    }

    @ViewBuilder
    private var carouselContent: some View {
        if viewModel.displayCount == 1 {
            photoPage(at: 0)
                .accessibilityIdentifier("gym-photo-page-0")
        } else {
            TabView(selection: $virtualIndex) {
                ForEach(0..<bufferedCount, id: \.self) { vIdx in
                    let actual = ((vIdx % viewModel.displayCount) + viewModel.displayCount) % viewModel.displayCount
                    photoPage(at: actual)
                        .tag(vIdx)
                        .accessibilityIdentifier("gym-photo-page-\(actual)")
                        .accessibilityHidden(vIdx != virtualIndex)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.72), value: virtualIndex)
            .simultaneousGesture(DragGesture(minimumDistance: 10).onChanged { _ in
                stopAuto()
            }.onEnded { _ in
                if shouldAutoPlay {
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 500_000_000)
                        startAuto()
                    }
                }
            })
        }
    }

    private var pageIndicator: some View {
        HStack(spacing: 6) {
            ForEach(0..<viewModel.displayCount, id: \.self) { index in
                Circle()
                    .fill(indicatorDotFill(isSelected: index == actualIndex))
                    .frame(width: index == actualIndex ? 7 : 6, height: index == actualIndex ? 7 : 6)
                    .overlay {
                        if index == actualIndex {
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
        .accessibilityLabel(Text("Photo \(actualIndex + 1) of \(viewModel.displayCount)"))
        .accessibilityValue(Text("Photo \(actualIndex + 1) of \(viewModel.displayCount)"))
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
                CachedGymPhotoView(photo: photo, loader: loader, index: index)
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
                    .onTapGesture { onTap?() }
            case .error:
                errorView(at: index)
            case .empty:
                placeholder.frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }

    private struct CachedGymPhotoView: View {
        let photo: GymPhoto
        let loader: any GymPhotoLoader
        let index: Int
        @State private var memoryImage: UIImage?
        var body: some View {
            Group {
                if let img = memoryImage {
                    Image(uiImage: img).resizable().scaledToFill()
                        .frame(maxWidth: .infinity, maxHeight: .infinity).clipped()
                } else if photo.imageURL.absoluteString.hasPrefix("file://") {
                    AsyncImage(url: photo.imageURL) { phase in
                        switch phase {
                        case .success(let image): image.resizable().scaledToFill().frame(maxWidth: .infinity, maxHeight: .infinity).clipped()
                        case .failure: Color.clear
                        case .empty: ProgressView().tint(.white)
                        @unknown default: Color.clear
                        }
                    }.frame(maxWidth: .infinity, maxHeight: .infinity).clipped()
                } else if photo.imageURL.absoluteString.contains("picsum.photos") || photo.imageURL.absoluteString.contains("example.com") {
                    Rectangle().fill(Color(hue: Double(index + 1) * 0.2, saturation: 0.55, brightness: 0.85))
                        .overlay {
                            VStack(spacing: 6) {
                                Image(systemName: "photo.on.rectangle").font(.system(size: 28)).foregroundStyle(.white.opacity(0.85))
                                if let attr = photo.attribution { Text(attr).font(.caption2.weight(.medium)).foregroundStyle(.white.opacity(0.9)) }
                            }
                        }
                } else if photo.imageURL.scheme == "memory" {
                    AsyncImage(url: photo.imageURL) { _ in Color.clear }
                        .task {
                            if let name = photo.photoName, let img = await loader.cachedImage(for: name) {
                                memoryImage = img
                            }
                        }
                } else {
                    AsyncImage(url: photo.imageURL) { phase in
                        switch phase {
                        case .success(let image): image.resizable().scaledToFill().frame(maxWidth: .infinity, maxHeight: .infinity).clipped()
                        case .failure: Color.clear
                        case .empty: ProgressView().tint(.white)
                        @unknown default: Color.clear
                        }
                    }.frame(maxWidth: .infinity, maxHeight: .infinity).clipped()
                }
            }
            .task {
                if let name = photo.photoName, let img = await loader.cachedImage(for: name) {
                    memoryImage = img
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
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
        .frame(width: 360)
        .padding()
}

#Preview("Carousel - 4 photos") {
    let photos = (1...4).map { GymPhoto(imageURL: URL(string: "https://picsum.photos/seed/preview\($0)/800/600")!, attribution: "Attr \($0)", attributionHTML: nil) }
    let loader = MockGymPhotoLoader(photosByPlaceID: ["test-place": photos])
    GymPhotoCarouselView(placeID: "test-place", gymName: "Test Gym", loader: loader)
        .frame(width: 360)
        .padding()
}

#Preview("Carousel - Loading") {
    let loader = MockGymPhotoLoader(photosByPlaceID: ["test-place": []], delayNanoseconds: 2_000_000_000)
    GymPhotoCarouselView(placeID: "test-place", gymName: "Test Gym", loader: loader)
        .frame(width: 360)
        .padding()
}

#Preview("Carousel - Error") {
    let photos = [GymPhoto(imageURL: URL(string: "https://picsum.photos/seed/error/800/600")!, attribution: nil, attributionHTML: nil)]
    let loader = MockGymPhotoLoader(photosByPlaceID: ["test-place": photos])
    GymPhotoCarouselView(placeID: "test-place", gymName: "Test Gym", loader: loader)
        .frame(width: 360)
        .padding()
}

#Preview("Carousel - Empty") {
    let loader = MockGymPhotoLoader(photosByPlaceID: [:])
    GymPhotoCarouselView(placeID: nil, gymName: "No Place", loader: loader)
        .frame(width: 360)
        .padding()
}
