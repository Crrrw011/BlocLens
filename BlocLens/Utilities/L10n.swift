import SwiftUI

enum L10n {
    enum Common {
        static let cancel: LocalizedStringResource = "common.cancel"
        static let notNow: LocalizedStringResource = "common.notNow"
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
        static let cardTitle: LocalizedStringResource = "home.card.title"
        static let cardMessage: LocalizedStringResource = "home.card.message"
        static let contributionTitle: LocalizedStringResource = "home.contribution.title"
        static let contributionMessage: LocalizedStringResource = "home.contribution.message"
        static let contributionAction: LocalizedStringResource = "home.contribution.action"
    }

    enum Map {
        static let title: LocalizedStringResource = "map.title"
        static let emptyTitle: LocalizedStringResource = "map.empty.title"
        static let emptyMessage: LocalizedStringResource = "map.empty.message"
    }

    enum Logbook {
        static let title: LocalizedStringResource = "logbook.title"
        static let emptyTitle: LocalizedStringResource = "logbook.empty.title"
        static let emptyMessage: LocalizedStringResource = "logbook.empty.message"
    }

    enum Profile {
        static let title: LocalizedStringResource = "profile.title"
        static let emptyTitle: LocalizedStringResource = "profile.empty.title"
        static let emptyMessage: LocalizedStringResource = "profile.empty.message"
    }

    enum State {
        static let loading: LocalizedStringResource = "state.loading"
        static let errorTitle: LocalizedStringResource = "state.error.title"
    }

    enum Contribution {
        static let privacyNote: LocalizedStringResource = "contribution.privacyNote"
    }
}
