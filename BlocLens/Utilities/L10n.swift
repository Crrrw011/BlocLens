import SwiftUI

enum L10n {
    enum Common {
        static let cancel: LocalizedStringResource = "common.cancel"
        static let close: LocalizedStringResource = "common.close"
        static let notNow: LocalizedStringResource = "common.notNow"
        static let ok: LocalizedStringResource = "common.ok"
        static let tryAgain: LocalizedStringResource = "common.tryAgain"
        static let continueButton: LocalizedStringResource = "common.continue"
        static let selected: LocalizedStringResource = "common.selected"
        static let notSelected: LocalizedStringResource = "common.notSelected"
        static let all: LocalizedStringResource = "common.all"
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
        static let markRouteComingLater: LocalizedStringResource = "add.markRoute.comingLater"
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
        static let privateLogbookMessage: LocalizedStringResource = "home.privateLogbook.message"
        static let privateLogbookAction: LocalizedStringResource = "home.privateLogbook.action"
    }

    enum Map {
        static let title: LocalizedStringResource = "map.title"
        static let nearbyGyms: LocalizedStringResource = "map.nearbyGyms"
        static let locationUnavailableTitle: LocalizedStringResource = "map.locationUnavailable.title"
        static let locationUnavailableMessage: LocalizedStringResource = "map.locationUnavailable.message"
        static let emptyFixtureTitle: LocalizedStringResource = "map.emptyFixture.title"
        static let emptyFixtureMessage: LocalizedStringResource = "map.emptyFixture.message"
    }

    enum MapFilter {
        static let title: LocalizedStringResource = "mapFilter.title"
        static let openNow: LocalizedStringResource = "mapFilter.openNow"
        static let openNowNotice: LocalizedStringResource = "mapFilter.openNow.notice"
        static let hasBeta: LocalizedStringResource = "mapFilter.hasBeta"
        static let recentlyReset: LocalizedStringResource = "mapFilter.recentlyReset"
        static let clear: LocalizedStringResource = "mapFilter.clear"
        static let showResults: LocalizedStringResource = "mapFilter.showResults"
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
        static let hasBeta: LocalizedStringResource = "filter.hasBeta"
        static let sort: LocalizedStringResource = "filter.sort"
    }

    enum Gym {
        static let detailTitle: LocalizedStringResource = "gym.detail.title"
        static let openGym: LocalizedStringResource = "gym.openGym"
        static let viewGym: LocalizedStringResource = "gym.viewGym"
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
        static let contactDetails: LocalizedStringResource = "gym.contactDetails"
        static let contactFixtureMessage: LocalizedStringResource = "gym.contactFixtureMessage"
        static let contributionTitle: LocalizedStringResource = "gym.contribution.title"
        static let contributionMessage: LocalizedStringResource = "gym.contribution.message"
    }

    enum WallZone {
        static let emptyTitle: LocalizedStringResource = "wallZone.empty.title"
        static let emptyMessage: LocalizedStringResource = "wallZone.empty.message"
    }

    enum RouteList {
        static let emptyTitle: LocalizedStringResource = "routeList.empty.title"
        static let emptyMessage: LocalizedStringResource = "routeList.empty.message"
        static let currentRoutes: LocalizedStringResource = "routeList.currentRoutes"
        static let archivedRoutes: LocalizedStringResource = "routeList.archivedRoutes"
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
        static let gymGrade: LocalizedStringResource = "route.gymGrade"
        static let photoContributionTitle: LocalizedStringResource = "route.photoContribution.title"
        static let photoContributionMessage: LocalizedStringResource = "route.photoContribution.message"
        static let addPhoto: LocalizedStringResource = "route.addPhoto"
        static let accuracyTitle: LocalizedStringResource = "route.accuracy.title"
        static let suggestCorrection: LocalizedStringResource = "route.suggestCorrection"
        static let reportRoute: LocalizedStringResource = "route.reportRoute"
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
        static let embedPlaceholder: LocalizedStringResource = "beta.embedPlaceholder"
        static let openOriginalPost: LocalizedStringResource = "beta.openOriginalPost"
        static let helpful: LocalizedStringResource = "beta.helpful"
        static let reportIssue: LocalizedStringResource = "beta.reportIssue"
        static let wrongRoute: LocalizedStringResource = "beta.wrongRoute"
        static let unsafeContent: LocalizedStringResource = "beta.unsafeContent"
        static let externalHandoffTitle: LocalizedStringResource = "beta.externalHandoff.title"
        static let externalHandoffMessage: LocalizedStringResource = "beta.externalHandoff.message"
        static let feedbackPlaceholderTitle: LocalizedStringResource = "beta.feedbackPlaceholder.title"
        static let feedbackPlaceholderMessage: LocalizedStringResource = "beta.feedbackPlaceholder.message"
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
        static let signInTitle: LocalizedStringResource = "logbook.signIn.title"
        static let signInMessage: LocalizedStringResource = "logbook.signIn.message"
        static let filters: LocalizedStringResource = "logbook.filters"
        static let statusFilter: LocalizedStringResource = "logbook.statusFilter"
        static let lastThirtyDays: LocalizedStringResource = "logbook.lastThirtyDays"
        static let noMatchingRecords: LocalizedStringResource = "logbook.noMatchingRecords"
    }

    enum Grade {
        static let unknown: LocalizedStringResource = "grade.unknown"
    }

    enum Profile {
        static let title: LocalizedStringResource = "profile.title"
        static let emptyTitle: LocalizedStringResource = "profile.empty.title"
        static let emptyMessage: LocalizedStringResource = "profile.empty.message"
        static let signedOutTitle: LocalizedStringResource = "profile.signedOut.title"
        static let signedOutMessage: LocalizedStringResource = "profile.signedOut.message"
        static let avatarPlaceholder: LocalizedStringResource = "profile.avatarPlaceholder"
        static let mockAccountLabel: LocalizedStringResource = "profile.mockAccountLabel"
        static let climbingProfile: LocalizedStringResource = "profile.climbingProfile"
        static let height: LocalizedStringResource = "profile.height"
        static let armSpan: LocalizedStringResource = "profile.armSpan"
        static let regularGrade: LocalizedStringResource = "profile.regularGrade"
        static let favouriteGym: LocalizedStringResource = "profile.favouriteGym"
        static let contributorStatus: LocalizedStringResource = "profile.contributorStatus"
        static let trustedContributor: LocalizedStringResource = "profile.trustedContributor"
        static let contributorInProgress: LocalizedStringResource = "profile.contributorInProgress"
        static let helpfulProgressSuffix: LocalizedStringResource = "profile.helpfulProgressSuffix"
        static let support: LocalizedStringResource = "profile.support"
        static let notProvided: LocalizedStringResource = "profile.notProvided"
    }

    enum Onboarding {
        static let findGymsTitle: LocalizedStringResource = "onboarding.findGyms.title"
        static let findGymsMessage: LocalizedStringResource = "onboarding.findGyms.message"
        static let findBetaTitle: LocalizedStringResource = "onboarding.findBeta.title"
        static let findBetaMessage: LocalizedStringResource = "onboarding.findBeta.message"
        static let trackTitle: LocalizedStringResource = "onboarding.track.title"
        static let trackMessage: LocalizedStringResource = "onboarding.track.message"
        static let skip: LocalizedStringResource = "onboarding.skip"
        static let continueButton: LocalizedStringResource = "onboarding.continue"
        static let exploreMap: LocalizedStringResource = "onboarding.exploreMap"
    }

    enum Authentication {
        static let navigationTitle: LocalizedStringResource = "authentication.navigationTitle"
        static let gateTitle: LocalizedStringResource = "authentication.gate.title"
        static let apple: LocalizedStringResource = "authentication.apple"
        static let google: LocalizedStringResource = "authentication.google"
        static let mockAccount: LocalizedStringResource = "authentication.mockAccount"
        static let mockNotice: LocalizedStringResource = "authentication.mockNotice"
        static let providerUnavailableHint: LocalizedStringResource = "authentication.providerUnavailableHint"
        static let revealReason: LocalizedStringResource = "authentication.reason.reveal"
        static let logbookReason: LocalizedStringResource = "authentication.reason.logbook"
        static let contributionReason: LocalizedStringResource = "authentication.reason.contribution"
        static let helpfulReason: LocalizedStringResource = "authentication.reason.helpful"
        static let accountReason: LocalizedStringResource = "authentication.reason.account"
        static let signIn: LocalizedStringResource = "authentication.signIn"
    }

    enum Settings {
        static let title: LocalizedStringResource = "settings.title"
        static let appearance: LocalizedStringResource = "settings.appearance"
        static let language: LocalizedStringResource = "settings.language"
        static let englishAustralian: LocalizedStringResource = "settings.language.englishAustralian"
        static let korean: LocalizedStringResource = "settings.language.korean"
        static let simplifiedChinese: LocalizedStringResource = "settings.language.simplifiedChinese"
        static let notifications: LocalizedStringResource = "settings.notifications"
        static let projectRemoval: LocalizedStringResource = "settings.notifications.projectRemoval"
        static let gymResets: LocalizedStringResource = "settings.notifications.gymResets"
        static let newBetaProjects: LocalizedStringResource = "settings.notifications.newBetaProjects"
        static let followedContributors: LocalizedStringResource = "settings.notifications.followedContributors"
        static let notificationMockNotice: LocalizedStringResource = "settings.notifications.mockNotice"
        static let privacy: LocalizedStringResource = "settings.privacy"
        static let safety: LocalizedStringResource = "settings.safety"
        static let helpCentre: LocalizedStringResource = "settings.helpCentre"
        static let sendFeedback: LocalizedStringResource = "settings.sendFeedback"
        static let development: LocalizedStringResource = "settings.development"
        static let resetOnboarding: LocalizedStringResource = "settings.resetOnboarding"
        static let resetBetaSafety: LocalizedStringResource = "settings.resetBetaSafety"
        static let mockSignOut: LocalizedStringResource = "settings.mockSignOut"
        static let placeholderMessage: LocalizedStringResource = "settings.placeholderMessage"
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

    static func routeSort(_ sort: RouteSort) -> LocalizedStringResource {
        switch sort {
        case .newest: "routeSort.newest"
        case .grade: "routeSort.grade"
        case .mostBeta: "routeSort.mostBeta"
        }
    }

    static func appearance(_ preference: AppearancePreference) -> LocalizedStringResource {
        switch preference {
        case .system: "appearance.system"
        case .light: "appearance.light"
        case .dark: "appearance.dark"
        }
    }
}
