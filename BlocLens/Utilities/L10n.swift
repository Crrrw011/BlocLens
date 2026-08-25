import SwiftUI

enum L10n {
    enum Common {
        static let cancel: LocalizedStringResource = "common.cancel"
        static let close: LocalizedStringResource = "common.close"
        static let notNow: LocalizedStringResource = "common.notNow"
        static let ok: LocalizedStringResource = "common.ok"
        static let tryAgain: LocalizedStringResource = "common.tryAgain"
    }

    enum Tab {
        static let home: LocalizedStringResource = "tab.home"
        static let map: LocalizedStringResource = "tab.map"
        static let add: LocalizedStringResource = "tab.add"
        static let logbook: LocalizedStringResource = "tab.logbook"
        static let profile: LocalizedStringResource = "tab.profile"
    }

    enum Add {
        static let menuTitle: LocalizedStringResource = "add.menu.title"
        static let menuMessage: LocalizedStringResource = "add.menu.message"
        static let publishBetaLink: LocalizedStringResource = "add.publishBetaLink"
        static let addNewRoute: LocalizedStringResource = "add.addNewRoute"
        static let recordCompletedRoute: LocalizedStringResource = "add.recordCompletedRoute"
        static let identifyOrMarkRoute: LocalizedStringResource = "add.identifyOrMarkRoute"
        static let placeholderMessage: LocalizedStringResource = "add.placeholder.message"
        static let done: LocalizedStringResource = "add.done"
    }

    enum Home {
        static let title: LocalizedStringResource = "home.title"
        static let emptyTitle: LocalizedStringResource = "home.empty.title"
        static let emptyMessage: LocalizedStringResource = "home.empty.message"
        static let currentGym: LocalizedStringResource = "home.currentGym"
        static let noFrequentGym: LocalizedStringResource = "home.noFrequentGym"
        static let activeProjects: LocalizedStringResource = "home.activeProjects"
        static let noProjects: LocalizedStringResource = "home.noProjects"
        static let latestResets: LocalizedStringResource = "home.latestResets"
        static let recentRecords: LocalizedStringResource = "home.recentRecords"
        static let contributionTitle: LocalizedStringResource = "home.contribution.title"
        static let contributionMessage: LocalizedStringResource = "home.contribution.message"
        static let contributionAction: LocalizedStringResource = "home.contribution.action"
    }

    enum Map {
        static let title: LocalizedStringResource = "map.title"
        static let nearbyGyms: LocalizedStringResource = "map.nearbyGyms"
        static let locationUnavailableTitle: LocalizedStringResource = "map.locationUnavailable.title"
        static let locationUnavailableMessage: LocalizedStringResource = "map.locationUnavailable.message"
        static let emptyFixtureTitle: LocalizedStringResource = "map.emptyFixture.title"
        static let emptyFixtureMessage: LocalizedStringResource = "map.emptyFixture.message"
    }

    enum Search {
        static let title: LocalizedStringResource = "search.title"
        static let prompt: LocalizedStringResource = "search.prompt"
        static let routePrompt: LocalizedStringResource = "search.routePrompt"
        static let clear: LocalizedStringResource = "search.clear"
        static let emptyTitle: LocalizedStringResource = "search.empty.title"
        static let emptyMessage: LocalizedStringResource = "search.empty.message"
    }

    enum Filter {
        static let grade: LocalizedStringResource = "filter.grade"
        static let showHistory: LocalizedStringResource = "filter.showHistory"
    }

    enum Gym {
        static let detailTitle: LocalizedStringResource = "gym.detail.title"
        static let openGym: LocalizedStringResource = "gym.openGym"
        static let verified: LocalizedStringResource = "gym.verified"
        static let developmentFixture: LocalizedStringResource = "gym.developmentFixture"
        static let currentRoutesAndZones: LocalizedStringResource = "gym.currentRoutesAndZones"
        static let latestReset: LocalizedStringResource = "gym.latestReset"
        static let resetDate: LocalizedStringResource = "gym.resetDate"
        static let fixtureResetNotice: LocalizedStringResource = "gym.fixtureResetNotice"
        static let noResetData: LocalizedStringResource = "gym.noResetData"
        static let hardSoftIndex: LocalizedStringResource = "gym.hardSoftIndex"
        static let overall: LocalizedStringResource = "gym.overall"
        static let fixtureBandSummary: LocalizedStringResource = "gym.fixtureBandSummary"
        static let communityEstimateNotice: LocalizedStringResource = "gym.communityEstimateNotice"
        static let operatingInformation: LocalizedStringResource = "gym.operatingInformation"
        static let operatingFixtureMessage: LocalizedStringResource = "gym.operatingFixtureMessage"
        static let facilities: LocalizedStringResource = "gym.facilities"
    }

    enum WallZone {
        static let emptyTitle: LocalizedStringResource = "wallZone.empty.title"
        static let emptyMessage: LocalizedStringResource = "wallZone.empty.message"
    }

    enum RouteList {
        static let emptyTitle: LocalizedStringResource = "routeList.empty.title"
        static let emptyMessage: LocalizedStringResource = "routeList.empty.message"
    }

    enum Route {
        static let detailTitle: LocalizedStringResource = "route.detail.title"
        static let archived: LocalizedStringResource = "route.archived"
        static let archivedHistoryMessage: LocalizedStringResource = "route.archivedHistoryMessage"
        static let hiddenReviewMessage: LocalizedStringResource = "route.hiddenReviewMessage"
        static let photoPlaceholder: LocalizedStringResource = "route.photoPlaceholder"
        static let estimatedArchive: LocalizedStringResource = "route.estimatedArchive"
        static let communityGradeTitle: LocalizedStringResource = "route.communityGrade.title"
        static let communityShortLabel: LocalizedStringResource = "route.communityGrade.shortLabel"
        static let communityGradeHidden: LocalizedStringResource = "route.communityGrade.hidden"
        static let validVotesSuffix: LocalizedStringResource = "route.communityGrade.validVotesSuffix"
        static let commentsTitle: LocalizedStringResource = "route.comments.title"
        static let commentsPlaceholder: LocalizedStringResource = "route.comments.placeholder"
    }

    enum Beta {
        static let title: LocalizedStringResource = "beta.title"
        static let hiddenUntilReveal: LocalizedStringResource = "beta.hiddenUntilReveal"
        static let reveal: LocalizedStringResource = "beta.reveal"
        static let safetyTitle: LocalizedStringResource = "beta.safety.title"
        static let safetyMessage: LocalizedStringResource = "beta.safety.message"
        static let acknowledgeAndReveal: LocalizedStringResource = "beta.safety.acknowledge"
        static let platform: LocalizedStringResource = "beta.platform"
        static let originalAuthor: LocalizedStringResource = "beta.originalAuthor"
        static let originalPost: LocalizedStringResource = "beta.originalPost"
        static let helpfulSuffix: LocalizedStringResource = "beta.helpfulSuffix"
        static let inlineFutureMessage: LocalizedStringResource = "beta.inlineFutureMessage"
        static let openSource: LocalizedStringResource = "beta.openSource"
        static let brokenLink: LocalizedStringResource = "beta.brokenLink"
        static let emptyMessage: LocalizedStringResource = "beta.empty.message"
        static let offlineMessage: LocalizedStringResource = "beta.offline.message"
    }

    enum Logbook {
        static let title: LocalizedStringResource = "logbook.title"
        static let emptyTitle: LocalizedStringResource = "logbook.empty.title"
        static let emptyMessage: LocalizedStringResource = "logbook.empty.message"
        static let quickStateTitle: LocalizedStringResource = "logbook.quickState.title"
        static let savedPrivate: LocalizedStringResource = "logbook.savedPrivate"
        static let queued: LocalizedStringResource = "logbook.queued"
        static let optionalDetails: LocalizedStringResource = "logbook.optionalDetails"
        static let date: LocalizedStringResource = "logbook.date"
        static let attempts: LocalizedStringResource = "logbook.attempts"
        static let predictedGrade: LocalizedStringResource = "logbook.predictedGrade"
        static let privateNote: LocalizedStringResource = "logbook.privateNote"
        static let privateNotePrompt: LocalizedStringResource = "logbook.privateNote.prompt"
        static let privateByDefaultMessage: LocalizedStringResource = "logbook.privateByDefault.message"
        static let saveDetails: LocalizedStringResource = "logbook.saveDetails"
        static let statistics: LocalizedStringResource = "logbook.statistics"
        static let climbingCount: LocalizedStringResource = "logbook.climbingCount"
        static let sentCount: LocalizedStringResource = "logbook.sentCount"
        static let flashCount: LocalizedStringResource = "logbook.flashCount"
        static let highestGrade: LocalizedStringResource = "logbook.highestGrade"
        static let projects: LocalizedStringResource = "logbook.projects"
        static let recentRecords: LocalizedStringResource = "logbook.recentRecords"
    }

    enum Grade {
        static let unknown: LocalizedStringResource = "grade.unknown"
    }

    enum Profile {
        static let title: LocalizedStringResource = "profile.title"
        static let emptyTitle: LocalizedStringResource = "profile.empty.title"
        static let emptyMessage: LocalizedStringResource = "profile.empty.message"
    }

    enum State {
        static let loading: LocalizedStringResource = "state.loading"
        static let errorTitle: LocalizedStringResource = "state.error.title"
        static let fixtureErrorMessage: LocalizedStringResource = "state.fixtureError.message"
        static let offlineTitle: LocalizedStringResource = "state.offline.title"
        static let offlineCachedMessage: LocalizedStringResource = "state.offline.cachedMessage"
        static let offlineNoCacheMessage: LocalizedStringResource = "state.offline.noCacheMessage"
    }

    enum Contribution {
        static let privacyNote: LocalizedStringResource = "contribution.privacyNote"
    }

    static func gradeBand(_ band: GradeBand) -> LocalizedStringResource {
        switch band {
        case .all: "gradeBand.all"
        case .v0ToV2: "gradeBand.v0ToV2"
        case .v3ToV5: "gradeBand.v3ToV5"
        case .v6Plus: "gradeBand.v6Plus"
        }
    }

    static func hardSoft(_ summary: HardSoftSummary) -> LocalizedStringResource {
        switch summary {
        case .soft: "hardSoft.soft"
        case .balanced: "hardSoft.balanced"
        case .hard: "hardSoft.hard"
        case .insufficientData: "hardSoft.insufficientData"
        }
    }

    static func facility(_ facility: GymFacility) -> LocalizedStringResource {
        switch facility {
        case .parking: "facility.parking"
        case .showers: "facility.showers"
        case .trainingBoard: "facility.trainingBoard"
        case .cafe: "facility.cafe"
        case .lockers: "facility.lockers"
        case .accessibleEntry: "facility.accessibleEntry"
        }
    }

    static func facilityIcon(_ facility: GymFacility) -> String {
        switch facility {
        case .parking: "parkingsign.circle"
        case .showers: "shower"
        case .trainingBoard: "figure.climbing"
        case .cafe: "cup.and.saucer"
        case .lockers: "lock.square"
        case .accessibleEntry: "figure.roll"
        }
    }

    static func wallType(_ type: WallType) -> LocalizedStringResource {
        switch type {
        case .slab: "wallType.slab"
        case .vertical: "wallType.vertical"
        case .overhang: "wallType.overhang"
        case .cave: "wallType.cave"
        case .mixed: "wallType.mixed"
        }
    }

    static func wallAvailability(_ availability: WallZoneAvailability) -> LocalizedStringResource {
        switch availability {
        case .active: "wallAvailability.active"
        case .temporarilyUnavailable: "wallAvailability.temporarilyUnavailable"
        case .archived: "wallAvailability.archived"
        }
    }

    static func logbookStatus(_ status: LogbookStatus) -> LocalizedStringResource {
        switch status {
        case .wantToTry: "logbookStatus.wantToTry"
        case .projecting: "logbookStatus.projecting"
        case .sent: "logbookStatus.sent"
        case .flash: "logbookStatus.flash"
        }
    }

    static func betaPlatform(_ platform: BetaPlatform) -> LocalizedStringResource {
        switch platform {
        case .youtube: "betaPlatform.youtube"
        case .instagram: "betaPlatform.instagram"
        case .tiktok: "betaPlatform.tiktok"
        case .vimeo: "betaPlatform.vimeo"
        case .other: "betaPlatform.other"
        }
    }

    static func betaTag(_ tag: BetaTag) -> LocalizedStringResource {
        switch tag {
        case .fullSolution: "betaTag.fullSolution"
        case .crux: "betaTag.crux"
        case .staticMovement: "betaTag.static"
        case .dynamicMovement: "betaTag.dynamic"
        case .shortPersonBeta: "betaTag.shortPerson"
        case .tallLongReachBeta: "betaTag.tallLongReach"
        }
    }
}
