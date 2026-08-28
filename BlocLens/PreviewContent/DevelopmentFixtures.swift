import Foundation

nonisolated enum DevelopmentFixtures {
    static let currentUserID: UserID = "fixture-user"

    static let mockProfile = UserProfile(
        userID: currentUserID,
        username: "Alex",
        heightCentimetres: 170,
        armSpanCentimetres: 171,
        regularGrade: .v4,
        gradeSystem: .vScale,
        ydsGrade: nil,
        favouriteGymID: "urban-climb-west-end",
        isTrustedContributor: false,
        helpfulVotes: 23
    )

    static let wallZones: [WallZone] = [
        zone("west-end-slab", gym: "urban-climb-west-end", name: "River Slab", location: "Near the river-side entry", kind: .regularSetWall, order: 0, reset: date(2026, 8, 18), betaCount: 4),
        zone("west-end-cave", gym: "urban-climb-west-end", name: "Main Cave", location: "Central steep section", kind: .regularSetWall, order: 1, reset: date(2026, 8, 11), betaCount: 1),
        zone("west-end-comp", gym: "urban-climb-west-end", name: "Competition Wall", location: "Beside the spectator area", kind: .compWall, order: 2, reset: date(2026, 8, 22), betaCount: 0),
        zone("newstead-island", gym: "urban-climb-newstead", name: "The Island", location: "Freestanding centre wall", kind: .regularSetWall, order: 0, reset: date(2026, 8, 20), betaCount: 1),
        zone("newstead-steep", gym: "urban-climb-newstead", name: "Steep Bay", location: "Rear overhanging bay", kind: .sprayWall, order: 1, reset: date(2026, 8, 14), betaCount: 0),
        zone("newstead-vertical", gym: "urban-climb-newstead", name: "North Vertical", location: "Along the northern wall", kind: .regularSetWall, order: 2, reset: date(2026, 8, 7), betaCount: 0),
        zone("enoggera-slab", gym: "nine-degrees-enoggera", name: "Front Slab", location: "Immediately left of reception", kind: .regularSetWall, order: 0, reset: date(2026, 8, 19), betaCount: 0),
        zone("enoggera-cave", gym: "nine-degrees-enoggera", name: "Back Cave", location: "Rear corner steep section", kind: .regularSetWall, order: 1, reset: date(2026, 8, 12), betaCount: 0),
        zone("enoggera-main", gym: "nine-degrees-enoggera", name: "Main Wall", location: "Long wall through the centre", kind: .sprayWall, order: 2, reset: date(2026, 8, 5), betaCount: 0)
    ]

    static let gyms: [Gym] = [
        Gym(
            id: "urban-climb-west-end",
            name: "Urban Climb West End",
            brandName: "Urban Climb",
            coordinate: GeoCoordinate(latitude: -27.4808, longitude: 153.0096),
            suburb: "West End",
            state: "QLD",
            isVerified: true,
            betaCount: 5,
            latestResetDate: date(2026, 8, 22),
            overallHardSoftSummary: .balanced,
            facilities: [.parking, .showers, .trainingBoard, .cafe, .lockers, .accessibleEntry],
            wallZoneIDs: zoneIDs(for: "urban-climb-west-end"),
            operatingSummary: .developmentFixture,
            dataSourceState: .developmentFixture
        ),
        Gym(
            id: "urban-climb-newstead",
            name: "Urban Climb Newstead",
            brandName: "Urban Climb",
            coordinate: GeoCoordinate(latitude: -27.4494, longitude: 153.0441),
            suburb: "Newstead",
            state: "QLD",
            isVerified: true,
            betaCount: 1,
            latestResetDate: date(2026, 8, 20),
            overallHardSoftSummary: .hard,
            facilities: [.parking, .showers, .trainingBoard, .cafe, .lockers, .accessibleEntry],
            wallZoneIDs: zoneIDs(for: "urban-climb-newstead"),
            operatingSummary: .developmentFixture,
            dataSourceState: .developmentFixture
        ),
        Gym(
            id: "nine-degrees-enoggera",
            name: "9 Degrees Enoggera",
            brandName: "9 Degrees",
            coordinate: GeoCoordinate(latitude: -27.4193, longitude: 152.9917),
            suburb: "Enoggera",
            state: "QLD",
            isVerified: false,
            betaCount: 0,
            latestResetDate: date(2026, 8, 19),
            overallHardSoftSummary: .soft,
            facilities: [.parking, .trainingBoard, .cafe, .lockers],
            wallZoneIDs: zoneIDs(for: "nine-degrees-enoggera"),
            operatingSummary: .developmentFixture,
            dataSourceState: .developmentFixture
        )
    ]

    static let routes: [ClimbingRoute] = makeRoutes()

    static let betaLinks: [BetaLink] = [
        beta(
            "beta-west-end-1-a",
            route: "west-end-slab-r1",
            url: "https://www.youtube.com/watch?v=fixture-one",
            platform: .youtube,
            author: "Development Fixture Author A",
            tags: [.fullSolution, .staticMovement, .shortPersonBeta],
            helpful: 21,
            height: 165,
            armSpan: 164,
            embed: .supported
        ),
        beta(
            "beta-west-end-1-b",
            route: "west-end-slab-r1",
            url: "https://www.instagram.com/p/development-fixture/",
            platform: .instagram,
            author: "Development Fixture Author B",
            tags: [.crux, .dynamicMovement, .tallLongReachBeta],
            helpful: 34,
            height: 184,
            armSpan: 190,
            embed: .sourcePlatformOnly
        ),
        beta(
            "beta-west-end-1-broken",
            route: "west-end-slab-r1",
            url: "https://example.com/development-fixture-broken",
            platform: .other,
            author: "Development Fixture Author C",
            tags: [.crux],
            helpful: 2,
            height: nil,
            armSpan: nil,
            health: .broken,
            embed: .sourcePlatformOnly
        ),
        beta(
            "beta-west-end-1-hidden",
            route: "west-end-slab-r1",
            url: "https://example.com/development-fixture-hidden",
            platform: .other,
            author: "Development Fixture Author D",
            tags: [.fullSolution],
            helpful: 99,
            height: 170,
            armSpan: 170,
            moderation: .temporarilyHidden,
            embed: .sourcePlatformOnly
        ),
        beta(
            "beta-west-end-cave-1",
            route: "west-end-cave-r2",
            url: "https://vimeo.com/123456789",
            platform: .vimeo,
            author: "Development Fixture Author E",
            tags: [.fullSolution, .dynamicMovement],
            helpful: 12,
            height: 174,
            armSpan: 176,
            embed: .supported
        ),
        beta(
            "beta-newstead-1",
            route: "newstead-island-r3",
            url: "https://www.tiktok.com/@fixture/video/123456789",
            platform: .tiktok,
            author: "Development Fixture Author F",
            tags: [.fullSolution, .tallLongReachBeta],
            helpful: 17,
            height: 181,
            armSpan: 187,
            embed: .sourcePlatformOnly
        )
    ]

    static let logbookEntries: [LogbookEntry] = [
        LogbookEntry(
            id: "fixture-log-projecting",
            userID: currentUserID,
            routeID: "west-end-slab-r1",
            status: .projecting,
            date: date(2026, 8, 24),
            attemptCount: 4,
            privateNote: "Fixture-only private note",
            predictedVGrade: .v3,
            syncState: .synced,
            privacy: .privateByDefault
        ),
        LogbookEntry(
            id: "fixture-log-sent",
            userID: currentUserID,
            routeID: "west-end-cave-r2",
            status: .sent,
            date: date(2026, 8, 23),
            attemptCount: 6,
            privateNote: nil,
            predictedVGrade: .v5,
            syncState: .synced,
            privacy: .privateByDefault
        ),
        LogbookEntry(
            id: "fixture-log-flash",
            userID: currentUserID,
            routeID: "newstead-island-r3",
            status: .flash,
            date: date(2026, 8, 22),
            attemptCount: 1,
            privateNote: nil,
            predictedVGrade: .v2,
            syncState: .synced,
            privacy: .privateByDefault
        )
    ]

    static let resets: [ResetSummary] = [
        ResetSummary(target: .gym("urban-climb-west-end"), resetDate: date(2026, 8, 22), source: .official, confirmationCount: 0, isEstimated: false),
        ResetSummary(target: .gym("urban-climb-newstead"), resetDate: date(2026, 8, 20), source: .communityConfirmed, confirmationCount: 3, isEstimated: false),
        ResetSummary(target: .gym("nine-degrees-enoggera"), resetDate: date(2026, 8, 19), source: .estimated, confirmationCount: 1, isEstimated: true)
    ]

    private static func makeRoutes() -> [ClimbingRoute] {
        let grades: [VGrade] = [
            .vb, .v0, .v2, .v1, .v3, .v5, .v2, .v4, .v6,
            .vb, .v3, .v7, .v0, .v4, .v8, .v1, .v5, .v7,
            .vb, .v2, .v4, .v1, .v3, .v6, .v0, .v5, .v8
        ]
        let colours = ["Blue", "Red", "Yellow", "Green", "Purple", "Black", "Pink", "White", "Orange"]
        let terrains: [RouteTerrain] = [.slab, .vertical, .overhang, .roof, .cave, .mixed]

        return wallZones.enumerated().flatMap { zoneIndex, zone in
            (0 ..< 3).map { routeIndex in
                let index = zoneIndex * 3 + routeIndex
                let grade = grades[index]
                let routeID = ClimbingRouteID(rawValue: "\(zone.id.rawValue)-r\(routeIndex + 1)")
                let lifecycle: RouteLifecycle = index == 26 ? .archived : (index == 23 ? .temporarilyHidden : .active)
                let votes = index.isMultiple(of: 4) ? [grade, grade] : [grade, grade, grade]
                return ClimbingRoute(
                    id: routeID,
                    gymID: zone.gymID,
                    wallZoneID: zone.id,
                    colour: colours[index % colours.count],
                    terrain: terrains[index % terrains.count],
                    styles: index.isMultiple(of: 2) ? [.staticMovement] : [.dynamic, .technical],
                    subjectiveGrade: grade,
                    officialGrade: nil,
                    communityGradeSummary: CommunityGradeSummary(votes: votes),
                    resetDate: zone.latestResetDate,
                    expectedArchiveDate: index == 2 ? date(2026, 9, 1) : nil,
                    isArchiveDateEstimated: index == 2,
                    lifecycle: lifecycle,
                    photoReference: index.isMultiple(of: 2)
                        ? RoutePhotoReference(referenceID: "fixture-photo-\(index)", accessibilityDescription: nil)
                        : nil,
                    betaCount: betaCount(for: routeID)
                )
            }
        }
    }

    private static func betaCount(for routeID: ClimbingRouteID) -> Int {
        switch routeID.rawValue {
        case "west-end-slab-r1": 4
        case "west-end-cave-r2", "newstead-island-r3": 1
        default: 0
        }
    }

    private static func zone(
        _ id: WallZoneID,
        gym: GymID,
        name: String,
        location: String,
        kind: WallKind,
        order: Int,
        reset: Date,
        betaCount: Int
    ) -> WallZone {
        WallZone(
            id: id,
            gymID: gym,
            name: name,
            locationDescription: location,
            wallKind: kind,
            surfaceMaterial: .plywood,
            surfaceTexture: .lightlyTextured,
            hasBoltHoles: true,
            createdBy: nil,
            latestResetDate: reset,
            routeCount: 3,
            betaCount: betaCount,
            availability: .active,
            sortOrder: order
        )
    }

    private static func zoneIDs(for gymID: GymID) -> [WallZoneID] {
        wallZones.filter { $0.gymID == gymID }.sorted { $0.sortOrder < $1.sortOrder }.map(\.id)
    }

    private static func beta(
        _ id: BetaLinkID,
        route: ClimbingRouteID,
        url: String,
        platform: BetaPlatform,
        author: String,
        tags: [BetaTag],
        helpful: Int,
        height: Double?,
        armSpan: Double?,
        health: BetaLinkHealth = .healthy,
        moderation: BetaModerationState = .visible,
        embed: BetaEmbedSupport
    ) -> BetaLink {
        let sourceURL = URL(string: url) ?? URL(fileURLWithPath: "/invalid-development-fixture")
        return BetaLink(
            id: id,
            routeID: route,
            sourceURL: sourceURL,
            platform: platform,
            originalAuthor: author,
            originalPostURL: sourceURL,
            tags: tags,
            helpfulCount: helpful,
            contributorHeightCentimetres: height,
            contributorArmSpanCentimetres: armSpan,
            linkHealth: health,
            moderationState: moderation,
            embedSupport: embed,
            createdDate: date(2026, 8, 20)
        )
    }

    private static func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone(secondsFromGMT: 0)
        components.year = year
        components.month = month
        components.day = day
        return components.date ?? Date(timeIntervalSince1970: 0)
    }
}
