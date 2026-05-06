import Foundation

nonisolated struct SeriesDTO: Decodable, Sendable, Identifiable {
    let id: String
    let name: String
    let nameIgnorePrefix: String?
    let description: String?
    let addedAt: Int64?
    let updatedAt: Int64?
    let libraryItemIds: [String]?
    let books: [LibraryItemDTO]?
    let numBooks: Int?
}
