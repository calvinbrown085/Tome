import SwiftUI

enum LibraryRoute: Hashable {
    case book(itemID: String)
    case author(authorID: String, libraryID: String?)
    case series(seriesID: String, libraryID: String, name: String)
    case browse(libraryID: String)
}

extension View {
    /// Registers detail screens for any NavigationStack in the app.
    func libraryNavigationDestinations() -> some View {
        navigationDestination(for: LibraryRoute.self) { route in
            switch route {
            case .book(let id):
                BookDetailView(itemID: id)
            case .author(let id, let lib):
                AuthorDetailView(authorID: id, libraryID: lib)
            case .series(let id, let libraryID, let name):
                SeriesDetailView(seriesID: id, libraryID: libraryID, name: name)
            case .browse(let libraryID):
                BrowseView(libraryID: libraryID)
            }
        }
    }
}
