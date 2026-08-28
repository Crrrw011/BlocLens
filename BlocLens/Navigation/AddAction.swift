import SwiftUI

enum BetaMediaSource: Equatable {
    case externalPublicLink
}

enum AddAction: String, CaseIterable, Identifiable {
    case publishBetaLink
    case addNewRoute
    case recordCompletedRoute
    case identifyOrMarkRoute

    var id: Self { self }

    static var menuCases: [AddAction] {
        [.publishBetaLink, .recordCompletedRoute, .identifyOrMarkRoute]
    }

    var title: LocalizedStringResource {
        switch self {
        case .publishBetaLink: L10n.Add.publishBetaLink
        case .addNewRoute: L10n.Add.addNewRoute
        case .recordCompletedRoute: L10n.Add.recordCompletedRoute
        case .identifyOrMarkRoute: L10n.Add.identifyOrMarkRoute
        }
    }

    var systemImage: String {
        switch self {
        case .publishBetaLink: "link"
        case .addNewRoute: "plus.rectangle.on.rectangle"
        case .recordCompletedRoute: "checkmark.circle"
        case .identifyOrMarkRoute: "viewfinder"
        }
    }

    var betaMediaSource: BetaMediaSource? {
        self == .publishBetaLink ? .externalPublicLink : nil
    }

    var representsDirectVideoUpload: Bool { false }
}
