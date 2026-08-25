import XCTest

final class BlocLensUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    @MainActor
    func testRouteDiscoveryAndQuickLogbookVerticalSlice() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--skip-onboarding"]
        app.launch()
        openFixtureRoute(in: app)

        let reveal = app.buttons["reveal-beta-button"]
        XCTAssertTrue(reveal.waitForExistence(timeout: 8))
        reveal.tap()
        XCTAssertTrue(app.navigationBars["Sign In"].waitForExistence(timeout: 5))
        app.buttons["mock-sign-in-button"].tap()
        let safety = app.buttons["acknowledge-beta-safety-button"].firstMatch
        XCTAssertTrue(safety.waitForExistence(timeout: 10))
        safety.tap()
        XCTAssertTrue(app.staticTexts["Original Author"].waitForExistence(timeout: 8))

        let projecting = app.buttons["logbook-status-projecting"]
        XCTAssertTrue(scrollBackToElement(projecting, in: app, maximumSwipes: 6))
        projecting.tap()
        let saveDetails = app.buttons["save-logbook-details-button"]
        XCTAssertTrue(saveDetails.waitForExistence(timeout: 5))
        saveDetails.tap()

        app.tabBars.buttons["Home"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["home-projects-section"].waitForExistence(timeout: 8))
        XCTAssertTrue(scrollToElement(app.staticTexts["Projecting"], in: app, maximumSwipes: 3))

        app.tabBars.buttons["Logbook"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["logbook-dashboard"].waitForExistence(timeout: 8))
        XCTAssertTrue(scrollToElement(app.staticTexts["Projecting"], in: app, maximumSwipes: 8))

        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "BlocLens Route Discovery Vertical Slice"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testFirstLaunchOnboardingEndsOnMap() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--reset-onboarding"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Find climbing gyms"].waitForExistence(timeout: 8))
        app.buttons["onboarding-continue-button"].tap()
        XCTAssertTrue(app.staticTexts["Find the right beta"].waitForExistence(timeout: 5))
        app.buttons["onboarding-continue-button"].tap()
        XCTAssertTrue(app.staticTexts["Track your climbing"].waitForExistence(timeout: 5))
        app.buttons["onboarding-explore-map-button"].tap()
        XCTAssertTrue(app.navigationBars["Map"].waitForExistence(timeout: 8))
    }

    @MainActor
    func testOnboardingActionsRemainUsableAtAccessibilityTextSize() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "--reset-onboarding",
            "-UIPreferredContentSizeCategoryName",
            "UICTContentSizeCategoryAccessibilityExtraExtraLarge"
        ]
        app.launch()

        let continueButton = app.buttons["onboarding-continue-button"]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 8))
        XCTAssertTrue(continueButton.isHittable)
        XCTAssertTrue(app.buttons["onboarding-skip-button"].isHittable)
    }

    @MainActor
    func testGuestCanBrowseRouteBeforeSignInGate() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--skip-onboarding"]
        app.launch()
        openFixtureRoute(in: app)

        XCTAssertTrue(app.navigationBars["Route Detail"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["reveal-beta-button"].exists)
        XCTAssertFalse(app.navigationBars["Sign In"].exists)
    }

    @MainActor
    func testDebugEmptyAndOfflineStates() throws {
        let emptyApp = XCUIApplication()
        emptyApp.launchArguments = ["--skip-onboarding", "--mock-empty"]
        emptyApp.launch()
        emptyApp.tabBars.buttons["Map"].tap()
        XCTAssertTrue(emptyApp.staticTexts["No Gyms Available"].waitForExistence(timeout: 8))
        emptyApp.terminate()

        let offlineApp = XCUIApplication()
        offlineApp.launchArguments = ["--skip-onboarding", "--mock-offline-cached"]
        offlineApp.launch()
        XCTAssertTrue(offlineApp.staticTexts["You are offline. Showing cached development data."].waitForExistence(timeout: 8))
        offlineApp.tabBars.buttons["Map"].tap()
        XCTAssertTrue(offlineApp.buttons["gym-annotation-urban-climb-west-end"].waitForExistence(timeout: 12))
    }

    @MainActor
    func testLightAndDarkAppearancesLaunch() throws {
        let lightApp = XCUIApplication()
        lightApp.launchArguments = ["--skip-onboarding", "-AppleInterfaceStyle", "Light"]
        lightApp.launch()
        XCTAssertTrue(lightApp.navigationBars["Home"].waitForExistence(timeout: 8))
        lightApp.terminate()

        let darkApp = XCUIApplication()
        darkApp.launchArguments = ["--skip-onboarding", "-AppleInterfaceStyle", "Dark"]
        darkApp.launch()
        XCTAssertTrue(darkApp.navigationBars["Home"].waitForExistence(timeout: 8))
    }

    @MainActor
    func testRouteDetailRemainsScrollableAtAccessibilityTextSize() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "--skip-onboarding",
            "-UIPreferredContentSizeCategoryName",
            "UICTContentSizeCategoryAccessibilityExtraLarge"
        ]
        app.launch()
        openFixtureRoute(in: app)

        let routeDetail = app.scrollViews.firstMatch
        XCTAssertTrue(routeDetail.waitForExistence(timeout: 8))
        routeDetail.swipeUp()
        let reveal = app.buttons["reveal-beta-button"]
        if !reveal.isHittable { routeDetail.swipeUp() }
        XCTAssertTrue(reveal.isHittable)
    }

    @MainActor
    func testArchivedRouteIsPresentedAsHistoryNotCurrent() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--skip-onboarding", "--mock-authenticated"]
        app.launch()
        app.tabBars.buttons["Map"].tap()

        let annotation = app.buttons["gym-annotation-nine-degrees-enoggera"]
        XCTAssertTrue(annotation.waitForExistence(timeout: 12))
        annotation.tap()
        XCTAssertTrue(app.buttons["open-gym-button"].waitForExistence(timeout: 5))
        app.buttons["open-gym-button"].tap()

        let zone = app.buttons["wall-zone-row-enoggera-main"]
        XCTAssertTrue(scrollToElement(zone, in: app, maximumSwipes: 6))
        zone.tap()

        let archiveGroup = app.buttons["Archived Routes"]
        XCTAssertTrue(scrollToElement(archiveGroup, in: app, maximumSwipes: 4))
        archiveGroup.tap()
        let archivedRoute = app.buttons["route-row-enoggera-main-r3"]
        XCTAssertTrue(archivedRoute.waitForExistence(timeout: 5))
        archivedRoute.tap()

        XCTAssertTrue(app.staticTexts["Archived Route"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["This route is read-only history. Beta links, grades and Logbook records are preserved."].exists)
        XCTAssertFalse(app.staticTexts["Current"].exists)
    }

    @MainActor
    private func openFixtureRoute(in app: XCUIApplication) {
        app.tabBars.buttons["Map"].tap()
        let annotation = app.buttons["gym-annotation-urban-climb-west-end"]
        XCTAssertTrue(annotation.waitForExistence(timeout: 12))
        annotation.tap()

        let openGym = app.buttons["open-gym-button"]
        XCTAssertTrue(openGym.waitForExistence(timeout: 5))
        openGym.tap()

        let zone = app.buttons["wall-zone-row-west-end-slab"]
        XCTAssertTrue(scrollToElement(zone, in: app, maximumSwipes: 4))
        zone.tap()

        let route = app.buttons["route-row-west-end-slab-r1"]
        XCTAssertTrue(route.waitForExistence(timeout: 8))
        route.tap()
    }

    @MainActor
    private func scrollToElement(_ element: XCUIElement, in app: XCUIApplication, maximumSwipes: Int) -> Bool {
        if element.waitForExistence(timeout: 2) { return true }
        for _ in 0 ..< maximumSwipes {
            app.swipeUp()
            if element.waitForExistence(timeout: 1) { return true }
        }
        return false
    }

    @MainActor
    private func scrollBackToElement(_ element: XCUIElement, in app: XCUIApplication, maximumSwipes: Int) -> Bool {
        if element.waitForExistence(timeout: 2) { return true }
        for _ in 0 ..< maximumSwipes {
            app.swipeDown()
            if element.waitForExistence(timeout: 1) { return true }
        }
        return false
    }
}
