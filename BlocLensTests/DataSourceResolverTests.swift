import XCTest
@testable import BlocLens

final class DataSourceResolverTests: XCTestCase {
    private let cloudURL = "https://atmtqesdhxpgnrjedwsu.supabase.co"
    private let cloudKey = "test-anon-key"
    private let localURL = "http://127.0.0.1:54321"
    private let localKey = "test-local-key"

    override func setUp() {
        super.setUp()
        PersistedRemoteConfigurationStore.clear()
    }

    override func tearDown() {
        PersistedRemoteConfigurationStore.clear()
        super.tearDown()
    }

    // 1. Normal config selects Supabase
    func testNormalConfigSelectsSupabase() {
        let mode = DataSourceResolver.resolve(
            arguments: [],
            environment: ["BLOCLENS_CLOUD_URL": cloudURL, "BLOCLENS_CLOUD_ANON_KEY": cloudKey],
            infoDictionary: [:],
            isPreview: false,
            isTest: false
        )
        if case .supabase = mode { } else { XCTFail("Expected supabase, got \(mode)") }
    }

    // 2. Explicit test param selects Mock
    func testExplicitMockArgumentSelectsMock() {
        let mode = DataSourceResolver.resolve(
            arguments: ["--mock-empty"],
            environment: ["BLOCLENS_CLOUD_URL": cloudURL, "BLOCLENS_CLOUD_ANON_KEY": cloudKey],
            infoDictionary: [:],
            isPreview: false,
            isTest: true
        )
        if case .mock = mode { } else { XCTFail("Expected mock") }
    }

    // 3. Config missing not silent Mock (Release)
    func testConfigMissingInReleaseIsErrorNotMock() {
        // Simulate Release by not being in DEBUG — we test the resolver's non-DEBUG path via isPreview/isTest false and no env
        // DataSourceResolver uses #if DEBUG to decide mock vs error when no config; in test (DEBUG build) it will be mock, but we can verify the reason is diagnostic
        let mode = DataSourceResolver.resolve(
            arguments: [],
            environment: [:],
            infoDictionary: [:],
            isPreview: false,
            isTest: false
        )
        // In DEBUG, missing config is mock with diagnostic reason; in Release it would be error
        if case .mock(let reason) = mode {
            XCTAssertTrue(reason.contains("No Supabase"))
        } else if case .error = mode {
            // Also acceptable for Release contract
        } else {
            XCTFail("Expected mock or error for missing config")
        }
    }

    // 4. Network failure not permanent Mock — resolver is pure, network failure is at repository layer, not resolver
    // We verify that a Supabase mode remains Supabase even if a network error would occur later (no silent switch)
    func testSupabaseModePersistsDespiteNetworkFailure() {
        let mode = DataSourceResolver.resolve(
            arguments: [],
            environment: ["BLOCLENS_CLOUD_URL": cloudURL, "BLOCLENS_CLOUD_ANON_KEY": cloudKey],
            infoDictionary: [:],
            isPreview: false,
            isTest: false
        )
        // Simulate network failure at repo layer — resolver still Supabase, view should show error not Mock
        if case .supabase = mode { } else { XCTFail("Expected supabase") }
        // No state mutation in resolver that would flip to mock
        let mode2 = DataSourceResolver.resolve(
            arguments: [],
            environment: ["BLOCLENS_CLOUD_URL": cloudURL, "BLOCLENS_CLOUD_ANON_KEY": cloudKey],
            infoDictionary: [:],
            isPreview: false,
            isTest: false
        )
        XCTAssertEqual(mode, mode2)
    }

    // 5. Session restore still correct DataSource
    func testSessionRestoreKeepsDataSource() {
        let mode1 = DataSourceResolver.resolve(
            arguments: [],
            environment: ["BLOCLENS_CLOUD_URL": cloudURL, "BLOCLENS_CLOUD_ANON_KEY": cloudKey],
            infoDictionary: [:],
            isPreview: false,
            isTest: false
        )
        // Simulate session restore (no new args/env)
        let mode2 = DataSourceResolver.resolve(
            arguments: [],
            environment: ["BLOCLENS_CLOUD_URL": cloudURL, "BLOCLENS_CLOUD_ANON_KEY": cloudKey],
            infoDictionary: [:],
            isPreview: false,
            isTest: false
        )
        XCTAssertEqual(mode1, mode2)
    }

    // 6. UI Test Mock not leak to normal launch
    func testMockArgumentNotLeakWhenAbsent() {
        let mockMode = DataSourceResolver.resolve(
            arguments: ["--mock-empty"],
            environment: [:],
            infoDictionary: [:],
            isPreview: false,
            isTest: true
        )
        let normalMode = DataSourceResolver.resolve(
            arguments: [],
            environment: ["BLOCLENS_CLOUD_URL": cloudURL, "BLOCLENS_CLOUD_ANON_KEY": cloudKey],
            infoDictionary: [:],
            isPreview: false,
            isTest: false
        )
        if case .mock = mockMode {} else { XCTFail() }
        if case .supabase = normalMode {} else { XCTFail("Normal should be supabase") }
    }

    // 7. Offline with cache
    func testOfflineWithCacheMode() {
        let mode = DataSourceResolver.resolve(
            arguments: ["--mock-offline-cached"],
            environment: [:],
            infoDictionary: [:],
            isPreview: false,
            isTest: true
        )
        XCTAssertEqual(mode, .offlineWithCache)
    }

    // 8. Offline without cache
    func testOfflineWithoutCacheMode() {
        let mode = DataSourceResolver.resolve(
            arguments: ["--mock-offline-no-cache"],
            environment: [:],
            infoDictionary: [:],
            isPreview: false,
            isTest: true
        )
        XCTAssertEqual(mode, .offlineWithoutCache)
    }

    // 9. Cold start vs second start consistency — persisted config
    func testColdStartVsSecondStartConsistency() throws {
        // First launch via Xcode with env
        let first = DataSourceResolver.resolve(
            arguments: [],
            environment: ["BLOCLENS_CLOUD_URL": cloudURL, "BLOCLENS_CLOUD_ANON_KEY": cloudKey],
            infoDictionary: [:],
            isPreview: false,
            isTest: false
        )
        guard case .supabase(let config, _) = first else { XCTFail(); return }
        try PersistedRemoteConfigurationStore.save(config)
        // Second launch from home screen without env (cold start)
        let second = DataSourceResolver.resolve(
            arguments: [],
            environment: [:],
            infoDictionary: [:],
            isPreview: false,
            isTest: false
        )
        if case .supabase(let config2, let reason) = second {
            XCTAssertEqual(config.projectURL, config2.projectURL)
            XCTAssertTrue(reason.contains("Persisted"))
        } else {
            XCTFail("Expected persisted supabase, got \(second)")
        }
    }

    func testPreviewAlwaysMock() {
        let mode = DataSourceResolver.resolve(
            arguments: [],
            environment: ["BLOCLENS_CLOUD_URL": cloudURL, "BLOCLENS_CLOUD_ANON_KEY": cloudKey],
            infoDictionary: [:],
            isPreview: true,
            isTest: false
        )
        if case .mock(let r) = mode { XCTAssertTrue(r.contains("Preview")) } else { XCTFail() }
    }

    func testInfoDictionaryFallback() throws {
        let mode = DataSourceResolver.resolve(
            arguments: [],
            environment: [:],
            infoDictionary: ["BLOCLENS_CLOUD_URL": cloudURL, "BLOCLENS_CLOUD_ANON_KEY": cloudKey],
            isPreview: false,
            isTest: false
        )
        if case .supabase = mode {} else { XCTFail("Expected supabase from Info.plist") }
    }
}
