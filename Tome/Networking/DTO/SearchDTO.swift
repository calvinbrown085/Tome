import Foundation

nonisolated struct SearchResultDTO: Decodable, Sendable {
    let book: [SearchItemHitDTO]?
    let podcast: [SearchItemHitDTO]?
    let tags: [String]?
    let authors: [AuthorDTO]?
    let series: [SearchSeriesHitDTO]?
}

nonisolated struct SearchItemHitDTO: Decodable, Sendable {
    let libraryItem: LibraryItemDTO
    let matchKey: String?
    let matchText: String?
}

nonisolated struct SearchSeriesHitDTO: Decodable, Sendable {
    let series: SeriesDTO
    let books: [LibraryItemDTO]?
}
