import SwiftUI

enum AppTab: String, CaseIterable, Identifiable {
    case home
    case map
    case add
    case logbook
    case profile

    static let defaultSelected: AppTab = .home

    var id: Self { self }

    var title: LocalizedStringResource {
        switch self {
        case .home: L10n.Tab.home
        case .map: L10n.Tab.map
        case .add: L10n.Tab.add
        case .logbook: L10n.Tab.logbook
        case .profile: L10n.Tab.profile
        }
    }

    var systemImage: String {
        switch self {
        case .home: "house"
        case .map: "map"
        case .add: "plus.circle.fill"
        case .logbook: "book.closed"
        case .profile: "person.crop.circle"
        }
    }
}
