import XCTest

final class BlocLensLocalRemoteUITests: XCTestCase {
    private let fixturePassword = "BlocLensLocalTest1!"

    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    @MainActor
    func testLocalAuthEstablishesRealSession() throws {
        let app = try launchLocal()
        try signIn(app, email: "fixture-climber-1@bloclens.invalid")
        XCTAssertTrue(app.descendants(matching: .any)["profile-signed-in"].exists)
    }

    @MainActor
    func testProtectedAddIntentResumesAfterLocalSignIn() throws {
        let app = try launchLocal()
        try ensureSignedOut(app)
        app.tabBars.buttons["Add"].tap()
        app.buttons["Add a new route"].tap()
        try completeSignInGate(app, email: "fixture-climber-1@bloclens.invalid")
        XCTAssertTrue(app.navigationBars["Add a new route"].waitForExistence(timeout: 8))
    }

    @MainActor
    func testRemoteAddRouteSucceedsAndCanBeReadBack() throws {
        let app = try launchLocal()
        try signIn(app, email: "fixture-climber-1@bloclens.invalid")
        let colour = "D4R Cobalt \(UUID().uuidString.prefix(6))"
        app.tabBars.buttons["Add"].tap()
        app.buttons["Add a new route"].tap()
        let field = app.textFields["add-route-colour-field"]
        XCTAssertTrue(field.waitForExistence(timeout: 8))
        field.tap()
        field.typeText(colour)
        app.keyboards.buttons["return"].tap()
        app.buttons["add-contribution-submit"].tap()
        XCTAssertFalse(app.navigationBars["Add a new route"].waitForExistence(timeout: 5))

        openDefaultAddRouteZone(in: app)
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText(colour)
        XCTAssertTrue(app.staticTexts[colour].waitForExistence(timeout: 8))
    }

    @MainActor
    func testRemoteContributionFailureShowsErrorWithoutSuccess() throws {
        let app = try launchLocal()
        try signIn(app, email: "fixture-climber-1@bloclens.invalid")
        app.tabBars.buttons["Add"].tap()
        app.buttons["Share beta link"].tap()
        fill(app.textFields["share-beta-url-field"], with: "http://example.com/beta")
        fill(app.textFields["share-beta-original-url-field"], with: "http://example.com/post")
        fill(app.textFields["share-beta-author-field"], with: "Local Fixture")
        app.keyboards.buttons["return"].tap()
        app.buttons["add-contribution-submit"].tap()
        XCTAssertTrue(app.staticTexts["Use a public HTTPS link and include the original attribution."].waitForExistence(timeout: 8))
        XCTAssertTrue(app.navigationBars["Share beta link"].exists)
    }

    @MainActor
    func testFollowThenBlockClearsFollowAndSupportsUnblock() throws {
        let app = try launchLocal()
        try signIn(app, email: "fixture-climber-1@bloclens.invalid")
        app.buttons["profile-contributors-link"].tap()
        let target = "90000000-0000-4000-8000-000000000002"
        let follow = app.buttons["relationship-follow-\(target)"]
        XCTAssertTrue(follow.waitForExistence(timeout: 8))
        follow.tap()
        XCTAssertTrue(app.buttons["relationship-follow-\(target)"].waitForExistence(timeout: 5))
        app.buttons["relationship-block-\(target)"].tap()
        let unblock = app.buttons["relationship-block-\(target)"]
        XCTAssertTrue(unblock.waitForExistence(timeout: 8))
        XCTAssertEqual(unblock.label, "Unblock")
        XCTAssertFalse(app.buttons["relationship-follow-\(target)"].isEnabled)
        unblock.tap()
        XCTAssertTrue(app.buttons["relationship-follow-\(target)"].waitForExistence(timeout: 8))
        XCTAssertEqual(app.buttons["relationship-follow-\(target)"].label, "Follow")
    }

    @MainActor
    func testBlockShowsOnlyBlockedManagementActionsForTarget() throws {
        let app = try launchLocal()
        try signIn(app, email: "fixture-climber-3@bloclens.invalid")
        app.buttons["profile-contributors-link"].tap()
        let target = "90000000-0000-4000-8000-000000000002"
        let block = app.buttons["relationship-block-\(target)"]
        XCTAssertTrue(block.waitForExistence(timeout: 8))
        block.tap()
        let unblock = app.buttons["relationship-block-\(target)"]
        XCTAssertTrue(unblock.waitForExistence(timeout: 8))
        XCTAssertEqual(unblock.label, "Unblock")
        XCTAssertFalse(app.buttons["relationship-follow-\(target)"].isEnabled)
        unblock.tap()
    }

    @MainActor
    func testVerifiedGymShowsOnlyGymCapability() throws {
        let app = try launchLocal()
        try signIn(app, email: "fixture-gym-official@bloclens.invalid")
        XCTAssertTrue(app.descendants(matching: .any)["profile-verified-gym-access"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.descendants(matching: .any)["profile-moderation-access"].exists)
    }

    @MainActor
    func testNormalUserDoesNotShowPrivilegedCapabilities() throws {
        let app = try launchLocal()
        try signIn(app, email: "fixture-climber-3@bloclens.invalid")
        XCTAssertFalse(app.descendants(matching: .any)["profile-verified-gym-access"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["profile-moderation-access"].exists)
    }

    @MainActor
    private func launchLocal() throws -> XCUIApplication {
        let environment = ProcessInfo.processInfo.environment
        let url = try XCTUnwrap(environment["BLOCLENS_SUPABASE_URL"])
        XCTAssertTrue(url.contains("127.0.0.1") || url.contains("localhost"))
        XCTAssertFalse(url.contains(".supabase.co"))
        let key = try XCTUnwrap(environment["BLOCLENS_SUPABASE_ANON_KEY"])
        let app = XCUIApplication()
        app.launchArguments = ["--skip-onboarding", "--local-supabase"]
        app.launchEnvironment["BLOCLENS_SUPABASE_URL"] = url
        app.launchEnvironment["BLOCLENS_SUPABASE_ANON_KEY"] = key
        app.launch()
        return app
    }

    @MainActor
    private func signIn(_ app: XCUIApplication, email: String) throws {
        app.tabBars.buttons["Profile"].tap()
        if app.descendants(matching: .any)["profile-signed-in"].waitForExistence(timeout: 2) {
            try signOut(app)
        }
        XCTAssertTrue(app.buttons["profile-sign-in-button"].waitForExistence(timeout: 8))
        app.buttons["profile-sign-in-button"].tap()
        try completeSignInGate(app, email: email)
        XCTAssertTrue(app.descendants(matching: .any)["profile-signed-in"].waitForExistence(timeout: 8))
    }

    @MainActor
    private func ensureSignedOut(_ app: XCUIApplication) throws {
        app.tabBars.buttons["Profile"].tap()
        if app.descendants(matching: .any)["profile-signed-in"].waitForExistence(timeout: 2) {
            try signOut(app)
        }
    }

    @MainActor
    private func signOut(_ app: XCUIApplication) throws {
        app.buttons["profile-settings-link"].tap()
        let signOutButton = app.buttons["settings-debug-sign-out"]
        for _ in 0..<4 where !signOutButton.exists {
            app.swipeUp()
        }
        XCTAssertTrue(signOutButton.waitForExistence(timeout: 5))
        signOutButton.tap()
        let back = app.navigationBars.buttons["Profile"]
        if back.waitForExistence(timeout: 3) {
            back.tap()
        }
        XCTAssertTrue(app.descendants(matching: .any)["profile-signed-out"].waitForExistence(timeout: 8))
    }

    @MainActor
    private func completeSignInGate(_ app: XCUIApplication, email: String) throws {
        fill(app.textFields["auth-email-field"], with: email)
        fill(app.secureTextFields["auth-password-field"], with: fixturePassword)
        app.buttons["auth-email-sign-in-button"].tap()
    }

    @MainActor
    private func fill(_ field: XCUIElement, with value: String) {
        XCTAssertTrue(field.waitForExistence(timeout: 8))
        field.tap()
        field.typeText(value)
    }

    @MainActor
    private func openDefaultAddRouteZone(in app: XCUIApplication) {
        app.tabBars.buttons["Map"].tap()
        let annotation = app.buttons["gym-annotation-10000000-0000-4000-8000-000000000003"]
        XCTAssertTrue(annotation.waitForExistence(timeout: 12))
        annotation.tap()
        app.buttons["open-gym-button"].tap()
        let zone = app.buttons["wall-zone-row-20000000-0000-4000-8000-000000000007"]
        XCTAssertTrue(zone.waitForExistence(timeout: 8))
        zone.tap()
    }
}
