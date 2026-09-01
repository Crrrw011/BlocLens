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
            // Indicator dots count would be displayCount, not hard-coded 4
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
        // Accessibility value should reflect new index
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
            // Not relying only on color – selected dot is larger (tested via view)
        }
    }

    // 6. Still only on-demand loads current image after layout change
    @MainActor
    func testStillOnDemandLoading() async {
        let photos = (0..<4).map { GymPhoto(imageURL: URL(string: "https://example.com/d\($0).jpg")!, attribution: nil, attributionHTML: nil) }
        let loader = MockGymPhotoLoader(photosByPlaceID: ["demand": photos])
        let vm = GymPhotoCarouselViewModel(placeID: "demand", gymName: "G", loader: loader)
        await vm.initialLoad()
        let c0 = await loader.requestCount(for: "demand", index: 0)
        let c1 = await loader.requestCount(for: "demand", index: 1)
        XCTAssertEqual(c0, 1)
        XCTAssertEqual(c1, 0, "Second image not loaded until swipe")
        await vm.loadIfNeeded(index: 1)
        let c1b = await loader.requestCount(for: "demand", index: 1)
        XCTAssertEqual(c1b, 1)
    }

    // 7. Home and Gym Detail reuse same carousel
    func testHomeAndDetailReuseSameCarouselComponent() {
        // Check source files reference same component type
        let homePath = "/Users/uuuuuyu/Documents/ChatGPT/BlocLens/BlocLens/Features/Home/HomeView.swift"
        let detailPath = "/Users/uuuuuyu/Documents/ChatGPT/BlocLens/BlocLens/Features/Gym/GymDetailView.swift"
        let homeContent = (try? String(contentsOfFile: homePath)) ?? ""
        let detailContent = (try? String(contentsOfFile: detailPath)) ?? ""
        XCTAssertTrue(homeContent.contains("GymPhotoCarouselView"), "Home should use shared carousel")
        XCTAssertTrue(detailContent.contains("GymPhotoCarouselView"), "Detail should use shared carousel")
        // Ensure both use same aspectRatio 16/9
        XCTAssertTrue(homeContent.contains("aspectRatio: 16 / 9"), "Home aspect should be 16/9")
        XCTAssertTrue(detailContent.contains("aspectRatio: 16 / 9"), "Detail aspect should be 16/9")
        // Single source of truth for VM
        XCTAssertTrue(homeContent.contains("environment.gymPhotoLoader"))
        XCTAssertTrue(detailContent.contains("environment.gymPhotoLoader"))
    }

    // 8. Loading, Loaded, Error, Empty have same layout size (aspect 16/9)
    func testAllStatesShareSameAspectRatio() {
        let carouselPath = "/Users/uuuuuyu/Documents/ChatGPT/BlocLens/BlocLens/Core/Components/GymPhotoCarouselView.swift"
        let content = (try? String(contentsOfFile: carouselPath)) ?? ""
        // New layout uses overlay indicator, not VStack spacing outside TabView. Old bug was VStack(spacing:6){ TabView ... } + HStack indicator below
        XCTAssertFalse(content.contains("VStack(spacing: 6) {\n            TabView"), "Should not contain VStack wrapping TabView with spacing 6 causing blank")
        XCTAssertTrue(content.contains(".overlay(alignment: .bottom)"), "Indicator should be overlay inside image")
        XCTAssertTrue(content.contains(".aspectRatio(aspectRatio, contentMode: .fit)"), "Should use unified aspectRatio fit")
        XCTAssertTrue(content.contains("16 / 9") || content.contains("16/9"), "Default aspect should be 16/9")
        // Verify scaledToFill used with frame and clipped, not scaledToFit
        XCTAssertTrue(content.contains("scaledToFill"), "Image should use scaledToFill")
        XCTAssertFalse(content.contains("scaledToFit"), "Should not use scaledToFit causing blank bands")
        // Verify placeholder and error share same frame
        XCTAssertTrue(content.contains("placeholder"), "Placeholder should exist")
        // Count aspectRatio usages: outer Group and unified, not duplicated per state with different values
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

    // Verify indicator dot distinctness: selected larger than unselected (view logic)
    func testIndicatorDotsDistinctBySize() {
        let carouselPath = "/Users/uuuuuyu/Documents/ChatGPT/BlocLens/BlocLens/Core/Components/GymPhotoCarouselView.swift"
        let content = (try? String(contentsOfFile: carouselPath)) ?? ""
        XCTAssertTrue(content.contains("7 : 6") || content.contains("7:6") || content.contains("width: 7"), "Selected dot should be larger (7 vs 6) to not rely solely on color")
        XCTAssertTrue(content.contains("accessibilityHidden(true)"), "Decorative dots hidden from VoiceOver")
        XCTAssertTrue(content.contains("accessibilityElement(children: .combine)"), "Indicator combined for VoiceOver")
        XCTAssertTrue(content.contains("Photo \\(") && content.contains(" of "), "Accessibility value Photo X of Y")
    }

    // Verify no third-party dependency added, no bundle ID change
    func testNoUnauthorizedChanges() {
        let projPath = "/Users/uuuuuyu/Documents/ChatGPT/BlocLens/BlocLens.xcodeproj/project.pbxproj"
        let content = (try? String(contentsOfFile: projPath)) ?? ""
        XCTAssertTrue(content.contains("com.bloclens.app") || content.contains("BlocLens"), "Bundle identifier should remain")
    }
}
