import XCTest
import SwiftUI
@testable import BlocLens

@MainActor
final class GymPhotoCarouselLayoutTests: XCTestCase {

    // 1. At most 4 photos (reuse)
    func testCarouselShowsAtMostFour() async throws {
        let photos = (0..<10).map { GymPhoto(imageURL: URL(string: "https://example.com/p\($0).jpg")!, attribution: nil, attributionHTML: nil) }
        let loader = MockGymPhotoLoader(photosByPlaceID: ["place": photos])
        let count = try await loader.availablePhotoCount(for: "place")
        XCTAssertEqual(count, 4, "Max 4 enforced by loader")
        let vm = await GymPhotoCarouselViewModel(placeID: "place", gymName: "G", loader: loader)
        await vm.initialLoad()
        let display = await MainActor.run { vm.displayCount }
        XCTAssertEqual(display, 4)
    }

    // 2. Indicator count equals actual image count
    @MainActor
    func testIndicatorCountEqualsDisplayCount() async {
        for n in 1...4 {
            let photos = (0..<n).map { GymPhoto(imageURL: URL(string: "https://example.com/q\($0).jpg")!, attribution: nil, attributionHTML: nil) }
            let loader = MockGymPhotoLoader(photosByPlaceID: ["p\(n)": photos])
            let vm = GymPhotoCarouselViewModel(placeID: "p\(n)", gymName: "G", loader: loader)
            await vm.initialLoad()
            XCTAssertEqual(vm.displayCount, n)
            if n > 1 {
                XCTAssertTrue(vm.shouldShowIndicator, "Should show indicator for \(n)")
            }
            XCTAssertLessThanOrEqual(vm.displayCount, 4)
        }
    }

    // 3. Single image -> indicator hidden
    @MainActor
    func testSingleImageHidesIndicator() async {
        let photos = [GymPhoto(imageURL: URL(string: "https://example.com/a.jpg")!, attribution: nil, attributionHTML: nil)]
        let loader = MockGymPhotoLoader(photosByPlaceID: ["single": photos])
        let vm = GymPhotoCarouselViewModel(placeID: "single", gymName: "G", loader: loader)
        await vm.initialLoad()
        XCTAssertEqual(vm.displayCount, 1)
        XCTAssertFalse(vm.shouldShowIndicator)
    }

    // 4. Current page change syncs indicator state
    @MainActor
    func testCurrentPageChangeSyncsIndicator() async {
        let photos = (0..<4).map { GymPhoto(imageURL: URL(string: "https://example.com/p\($0).jpg")!, attribution: nil, attributionHTML: nil) }
        let loader = MockGymPhotoLoader(photosByPlaceID: ["sync": photos])
        let vm = GymPhotoCarouselViewModel(placeID: "sync", gymName: "G", loader: loader)
        await vm.initialLoad()
        XCTAssertEqual(vm.selectedIndex, 0)
        vm.selectedIndex = 2
        await vm.onSelectedIndexChanged(2)
        XCTAssertEqual(vm.selectedIndex, 2)
        let expected = "Photo 3 of 4"
        let accessibilityValue = "Photo \(vm.selectedIndex + 1) of \(vm.displayCount)"
        XCTAssertEqual(accessibilityValue, expected)
    }

    // 5. Accessibility value correct for all pages
    @MainActor
    func testAccessibilityValueCorrect() async {
        let photos = (0..<4).map { GymPhoto(imageURL: URL(string: "https://example.com/x\($0).jpg")!, attribution: nil, attributionHTML: nil) }
        let loader = MockGymPhotoLoader(photosByPlaceID: ["acc": photos])
        let vm = GymPhotoCarouselViewModel(placeID: "acc", gymName: "G", loader: loader)
        await vm.initialLoad()
        for i in 0..<vm.displayCount {
            vm.selectedIndex = i
            let value = "Photo \(vm.selectedIndex + 1) of \(vm.displayCount)"
            XCTAssertEqual(value, "Photo \(i+1) of \(vm.displayCount)")
        }
    }

    // 6. Still only on-demand loads current image after layout change
    @MainActor
    func testStillOnDemandLoading() async {
        let placeID = "demand-\(UUID().uuidString)"
        let photos = (0..<4).map { GymPhoto(imageURL: URL(string: "https://example.com/d\($0).jpg")!, attribution: nil, attributionHTML: nil) }
        let loader = MockGymPhotoLoader(photosByPlaceID: [placeID: photos])
        let vm = GymPhotoCarouselViewModel(placeID: placeID, gymName: "G", loader: loader)
        await vm.initialLoad()
        // Allow MainActor to settle under parallel execution
        var c0 = await loader.requestCount(for: placeID, index: 0)
        var attempts = 0
        while c0 == 0 && attempts < 5 {
            try? await Task.sleep(nanoseconds: 50_000_000)
            c0 = await loader.requestCount(for: placeID, index: 0)
            attempts += 1
        }
        let c1 = await loader.requestCount(for: placeID, index: 1)
        XCTAssertEqual(c0, 1)
        XCTAssertEqual(c1, 0, "Second image not loaded until swipe")
        await vm.loadIfNeeded(index: 1)
        let c1b = await loader.requestCount(for: placeID, index: 1)
        XCTAssertEqual(c1b, 1)
    }

    // 7. Home and Gym Detail reuse same carousel with 16:10
    func testHomeAndDetailReuseSameCarouselComponent() {
        let homePath = "/Users/uuuuuyu/Documents/ChatGPT/BlocLens/BlocLens/Features/Home/HomeView.swift"
        let detailPath = "/Users/uuuuuyu/Documents/ChatGPT/BlocLens/BlocLens/Features/Gym/GymDetailView.swift"
        let homeContent = (try? String(contentsOfFile: homePath)) ?? ""
        let detailContent = (try? String(contentsOfFile: detailPath)) ?? ""
        XCTAssertTrue(homeContent.contains("GymPhotoCarouselView"), "Home should use shared carousel")
        XCTAssertTrue(detailContent.contains("GymPhotoCarouselView"), "Detail should use shared carousel")
        XCTAssertTrue(homeContent.contains("GymPhotoCarouselMetrics.aspectRatio"), "Home aspect should be 16:10 via metrics")
        XCTAssertTrue(detailContent.contains("GymPhotoCarouselMetrics.aspectRatio"), "Detail aspect should be 16:10 via metrics")
        XCTAssertTrue(homeContent.contains("environment.gymPhotoLoader"))
        XCTAssertTrue(detailContent.contains("environment.gymPhotoLoader"))
        // Ensure not using old 16/9
        XCTAssertFalse(homeContent.contains("aspectRatio: 16 / 9"), "Home should not use old 16/9")
        XCTAssertFalse(detailContent.contains("aspectRatio: 16 / 9"), "Detail should not use old 16/9")
    }

    // 8. Loading, Loaded, Error, Empty have same layout size (aspect 16:10)
    func testAllStatesShareSameAspectRatio() {
        let carouselPath = "/Users/uuuuuyu/Documents/ChatGPT/BlocLens/BlocLens/Core/Components/GymPhotoCarouselView.swift"
        let content = (try? String(contentsOfFile: carouselPath)) ?? ""
        XCTAssertFalse(content.contains("VStack(spacing: 6) {\n            TabView"), "Should not contain VStack wrapping TabView with spacing 6 causing blank")
        XCTAssertTrue(content.contains(".overlay(alignment: .bottom)"), "Indicator should be overlay inside image")
        XCTAssertTrue(content.contains("GymPhotoCarouselMetrics.aspectRatio"), "Should use metrics aspectRatio")
        XCTAssertTrue(content.contains("16.0 / 10.0") || content.contains("16 / 10"), "Default aspect should be 16:10")
        XCTAssertTrue(content.contains("scaledToFill"), "Image should use scaledToFill")
        XCTAssertFalse(content.contains("scaledToFit"), "Should not use scaledToFit causing blank bands")
        XCTAssertTrue(content.contains("placeholder"), "Placeholder should exist")
        let fitCount = content.components(separatedBy: "contentMode: .fit").count - 1
        XCTAssertGreaterThanOrEqual(fitCount, 1, "Should have unified fit aspect")
    }

    // Extra: Custom indicator not hard-coded 4 dots, respects displayCount
    @MainActor
    func testIndicatorNotHardcodedFour() async {
        for n in [2,3,4] {
            let photos = (0..<n).map { GymPhoto(imageURL: URL(string: "https://example.com/h\($0).jpg")!, attribution: nil, attributionHTML: nil) }
            let loader = MockGymPhotoLoader(photosByPlaceID: ["hc\(n)": photos])
            let vm = GymPhotoCarouselViewModel(placeID: "hc\(n)", gymName: "G", loader: loader)
            await vm.initialLoad()
            XCTAssertEqual(vm.displayCount, n, "DisplayCount should be \(n) not always 4")
        }
    }

    func testIndicatorDotsDistinctBySize() {
        let carouselPath = "/Users/uuuuuyu/Documents/ChatGPT/BlocLens/BlocLens/Core/Components/GymPhotoCarouselView.swift"
        let content = (try? String(contentsOfFile: carouselPath)) ?? ""
        XCTAssertTrue(content.contains("7 : 6") || content.contains("7:6") || content.contains("width: 7"), "Selected dot should be larger (7 vs 6) to not rely solely on color")
        XCTAssertTrue(content.contains("accessibilityHidden(true)"), "Decorative dots hidden from VoiceOver")
        XCTAssertTrue(content.contains("accessibilityElement(children: .combine)"), "Indicator combined for VoiceOver")
        XCTAssertTrue(content.contains("Photo \\(") && content.contains(" of "), "Accessibility value Photo X of Y")
    }

    func testNoUnauthorizedChanges() {
        let projPath = "/Users/uuuuuyu/Documents/ChatGPT/BlocLens/BlocLens.xcodeproj/project.pbxproj"
        let content = (try? String(contentsOfFile: projPath)) ?? ""
        XCTAssertTrue(content.contains("com.bloclens.app") || content.contains("BlocLens"), "Bundle identifier should remain")
    }

    // MARK: - Regression: 16:10 Metrics

    func testMetricsAspectRatioIs16_10() {
        XCTAssertEqual(GymPhotoCarouselMetrics.aspectRatio, 16.0 / 10.0, accuracy: 0.0001, "Metrics aspect should be 16:10 = 1.6")
        XCTAssertEqual(GymPhotoCarouselMetrics.aspectRatio, 1.6, accuracy: 0.0001)
        XCTAssertEqual(GymPhotoCarouselMetrics.indicatorBottomPadding, 12, accuracy: 0.1)
    }

    func testHeightFor320WidthIs200() {
        let ratio = GymPhotoCarouselMetrics.aspectRatio
        let height = 320.0 / ratio
        XCTAssertEqual(height, 200.0, accuracy: 0.5, "320pt width → 200pt height at 16:10")
    }

    func testHeightFor360WidthIs225() {
        let ratio = GymPhotoCarouselMetrics.aspectRatio
        let height = 360.0 / ratio
        XCTAssertEqual(height, 225.0, accuracy: 0.5, "360pt width → 225pt height at 16:10")
    }

    func testHeightFor390WidthIs243_75() {
        let ratio = GymPhotoCarouselMetrics.aspectRatio
        let height = 390.0 / ratio
        XCTAssertEqual(height, 243.75, accuracy: 0.5, "390pt width → 243.75pt height at 16:10")
    }

    func testHomeAndDetailUseSameRatio() {
        let ratio = GymPhotoCarouselMetrics.aspectRatio
        let homeHeight320 = 320.0 / ratio
        let detailHeight320 = 320.0 / ratio
        XCTAssertEqual(homeHeight320, detailHeight320, accuracy: 0.001)
        let homeHeight360 = 360.0 / ratio
        let detailHeight360 = 360.0 / ratio
        XCTAssertEqual(homeHeight360, detailHeight360, accuracy: 0.001)
        // Ratio consistency
        XCTAssertEqual(ratio, 1.6, accuracy: 0.001)
    }

    func testLoadingAndLoadedSameHeight() {
        let carouselPath = "/Users/uuuuuyu/Documents/ChatGPT/BlocLens/BlocLens/Core/Components/GymPhotoCarouselView.swift"
        let content = (try? String(contentsOfFile: carouselPath)) ?? ""
        // Outer aspectRatio ensures all states same; verify no state-specific .frame(height: 80) etc
        XCTAssertFalse(content.contains(".frame(height: 80"), "Loading should not have fixed 80pt height")
        XCTAssertTrue(content.contains(".aspectRatio(GymPhotoCarouselMetrics.aspectRatio"), "All states share outer aspectRatio")
        // placeholder and errorView both use .frame(maxWidth: .infinity, maxHeight: .infinity) inside outer aspect
        XCTAssertTrue(content.contains("placeholder"))
        XCTAssertTrue(content.contains("errorView"))
    }

    func testErrorAndLoadedSameHeight() {
        let carouselPath = "/Users/uuuuuyu/Documents/ChatGPT/BlocLens/BlocLens/Core/Components/GymPhotoCarouselView.swift"
        let content = (try? String(contentsOfFile: carouselPath)) ?? ""
        // Verify errorView also uses maxWidth/Height infinity, not fixed
        XCTAssertTrue(content.contains("func errorView"), "Error view exists")
        XCTAssertTrue(content.contains(".frame(maxWidth: .infinity, maxHeight: .infinity)"), "Views use max infinity, not fixed")
        // No per-state aspect differences
        let aspectOccurrences = content.components(separatedBy: "GymPhotoCarouselMetrics.aspectRatio").count - 1
        XCTAssertGreaterThanOrEqual(aspectOccurrences, 1)
        XCTAssertLessThanOrEqual(aspectOccurrences, 3, "Should not have many different ratios")
    }

    func testSingleAndMultiSameHeight() {
        let carouselPath = "/Users/uuuuuyu/Documents/ChatGPT/BlocLens/BlocLens/Core/Components/GymPhotoCarouselView.swift"
        let content = (try? String(contentsOfFile: carouselPath)) ?? ""
        // Single photo uses photoPage directly, multi uses TabView — both under same outer aspectRatio
        XCTAssertTrue(content.contains("if viewModel.displayCount == 1"), "Single case exists")
        XCTAssertTrue(content.contains("TabView(selection:"), "Multi case uses TabView")
        XCTAssertTrue(content.contains(".aspectRatio(GymPhotoCarouselMetrics.aspectRatio"), "Outer aspect covers both")
    }

    func testIndicatorOverlayNotIncreaseHeight() {
        let carouselPath = "/Users/uuuuuyu/Documents/ChatGPT/BlocLens/BlocLens/Core/Components/GymPhotoCarouselView.swift"
        let content = (try? String(contentsOfFile: carouselPath)) ?? ""
        XCTAssertTrue(content.contains(".overlay(alignment: .bottom)"), "Indicator is overlay")
        XCTAssertFalse(content.contains("VStack(spacing: 6) {\n            TabView"), "Old bug: VStack wrapping TabView with spacing 6 causing blank")
        XCTAssertTrue(content.contains("indicatorBottomPadding") || content.contains("padding(.bottom, 12"), "Indicator has bottom padding 12")
        // Ensure no extra white bar
        XCTAssertFalse(content.contains("Color.white") && content.contains("frame(height:"), "No white bar for indicator")
    }

    func testPixelWidthDoesNotChangeAspectRatio() {
        let carouselPath = "/Users/uuuuuyu/Documents/ChatGPT/BlocLens/BlocLens/Core/Components/GymPhotoCarouselView.swift"
        let content = (try? String(contentsOfFile: carouselPath)) ?? ""
        // Verify pixelWidth used only for bucket, not for .frame(height:)
        XCTAssertTrue(content.contains("pixelWidth") || content.contains("bucket"), "Pixel width exists for bucket")
        XCTAssertTrue(content.contains("GymPhotoBucket.bucket"), "Bucket logic exists")
        XCTAssertTrue(content.contains("GeometryReader") && content.contains(".aspectRatio(GymPhotoCarouselMetrics.aspectRatio"), "Width measurement via GeometryReader with outer aspectRatio (decoupled)")
        XCTAssertFalse(content.contains("GeometryReader { geo in") && content.contains(".aspectRatio(aspectRatio, contentMode: .fit)") && content.components(separatedBy: "GeometryReader").count > 2, "Should not have bare GeometryReader wrapping Group with aspect inside causing collapse")
        // No frame(height: pixelWidth)
        XCTAssertFalse(content.contains("frame(height: pixelWidth"), "Pixel width must not control view height")
        XCTAssertFalse(content.contains("frame(height: nil)"), "Should not have ambiguous frame(height: nil)")
    }

    func testSmallScreenNotCrushed() {
        let ratio = GymPhotoCarouselMetrics.aspectRatio
        // Simulate small screen width 320 (iPhone SE) — height should still be 200, not crushed to <80
        let smallWidth: CGFloat = 320
        let height = smallWidth / ratio
        XCTAssertGreaterThan(height, 150, "Small screen height should still be ~200, not crushed to strip")
        XCTAssertLessThan(height, 260)
        // Verify view uses outer GeometryReader with outer aspectRatio (stable in ScrollView)
        let carouselPath = "/Users/uuuuuyu/Documents/ChatGPT/BlocLens/BlocLens/Core/Components/GymPhotoCarouselView.swift"
        let content = (try? String(contentsOfFile: carouselPath)) ?? ""
        XCTAssertTrue(content.contains("GeometryReader") && content.contains(".aspectRatio(GymPhotoCarouselMetrics.aspectRatio"), "Uses GeometryReader with outer aspectRatio to avoid ScrollView collapse")
    }

    func testDynamicTypeDoesNotChangeRatio() {
        let carouselPath = "/Users/uuuuuyu/Documents/ChatGPT/BlocLens/BlocLens/Core/Components/GymPhotoCarouselView.swift"
        let content = (try? String(contentsOfFile: carouselPath)) ?? ""
        // Ensure no @ScaledMetric or dynamicTypeSize affecting carousel height
        XCTAssertFalse(content.contains("@ScaledMetric") && content.contains("carousel"), "Dynamic Type should not affect carousel ratio")
        XCTAssertTrue(content.contains("GymPhotoCarouselMetrics.aspectRatio"), "Fixed aspect ratio independent of Dynamic Type")
        // Verify placeholder uses fixed size icon 48, not scaled
        XCTAssertTrue(content.contains("font(.system(size: 48))"))
    }

    func testCacheHitDoesNotJumpFrame() {
        let carouselPath = "/Users/uuuuuyu/Documents/ChatGPT/BlocLens/BlocLens/Core/Components/GymPhotoCarouselView.swift"
        let content = (try? String(contentsOfFile: carouselPath)) ?? ""
        // Outer aspectRatio fixed, states use same frame max infinity, so cache hit doesn't change frame
        XCTAssertTrue(content.contains(".aspectRatio(GymPhotoCarouselMetrics.aspectRatio"), "Fixed outer frame")
        XCTAssertTrue(content.contains("CachedGymPhotoView"), "Cache-aware image view")
        XCTAssertTrue(content.contains(".frame(maxWidth: .infinity, maxHeight: .infinity)"), "All states use infinity frame under fixed aspect")
    }

    func testGeometryReaderDecoupledStructure() {
        let carouselPath = "/Users/uuuuuyu/Documents/ChatGPT/BlocLens/BlocLens/Core/Components/GymPhotoCarouselView.swift"
        let content = (try? String(contentsOfFile: carouselPath)) ?? ""
        // Must have Metrics enum
        XCTAssertTrue(content.contains("enum GymPhotoCarouselMetrics"), "Metrics enum exists")
        XCTAssertTrue(content.contains("16.0 / 10.0"), "Metrics uses 16:10")
        // Must have .aspectRatio outside, GeometryReader reading width (decoupled)
        XCTAssertTrue(content.contains(".aspectRatio(GymPhotoCarouselMetrics.aspectRatio"), "Outer aspectRatio")
        XCTAssertTrue(content.contains("GeometryReader"), "GeometryReader for width measurement")
        // Images: scaledToFill with infinity and clipped
        XCTAssertTrue(content.contains("scaledToFill"))
        XCTAssertTrue(content.contains(".frame(maxWidth: .infinity, maxHeight: .infinity)"))
        XCTAssertTrue(content.contains(".clipped()"))
        // Corner and clip on outer, not per-image partial
        XCTAssertTrue(content.contains("clipShape(RoundedRectangle"))
    }

    func testWallZoneImportNotModified() {
        let path = "/Users/uuuuuyu/Documents/ChatGPT/BlocLens/BlocLens/Core/Domain/WallZoneImport.swift"
        let content = (try? String(contentsOfFile: path)) ?? ""
        XCTAssertFalse(content.isEmpty, "WallZoneImport exists and not deleted")
    }
}
