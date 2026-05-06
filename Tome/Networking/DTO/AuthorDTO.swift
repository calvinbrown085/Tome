import Foundation

nonisolated struct AuthorDTO: Decodable, Sendable, Identifiable {
    let id: String
    let libraryId: String?
    let name: String
    let description: String?
    let imagePath: String?
    let addedAt: Int64?
    let updatedAt: Int64?
    let numBooks: Int?
    let libraryItems: [LibraryItemDTO]?
}
