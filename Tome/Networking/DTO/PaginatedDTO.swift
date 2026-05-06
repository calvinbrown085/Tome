import Foundation

nonisolated struct PaginatedDTO<T: Decodable & Sendable>: Decodable, Sendable {
    let results: [T]
    let total: Int?
    let limit: Int?
    let page: Int?
    let sortBy: String?
    let sortDesc: Bool?
    let filterBy: String?
    let mediaType: String?
    let minified: Bool?
}
