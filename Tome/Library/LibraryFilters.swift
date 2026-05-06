import Foundation

enum LibrarySort: String, CaseIterable, Identifiable, Sendable {
    case recentlyAdded
    case title
    case author
    case duration

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .recentlyAdded: return "Recently Added"
        case .title: return "Title"
        case .author: return "Author"
        case .duration: return "Duration"
        }
    }

    var sortField: String {
        switch self {
        case .recentlyAdded: return "addedAt"
        case .title: return "media.metadata.title"
        case .author: return "media.metadata.authorName"
        case .duration: return "media.duration"
        }
    }

    var descending: Bool {
        switch self {
        case .recentlyAdded, .duration: return true
        case .title, .author: return false
        }
    }
}

enum LibraryFilter: String, CaseIterable, Identifiable, Sendable {
    case all
    case inProgress
    case notFinished
    case finished

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .all: return "All"
        case .inProgress: return "In Progress"
        case .notFinished: return "Unfinished"
        case .finished: return "Finished"
        }
    }

    /// ABS expects filter values as `<name>.<base64(value)>`.
    var apiValue: String? {
        switch self {
        case .all: return nil
        case .inProgress: return "progress." + Self.b64("in-progress")
        case .notFinished: return "progress." + Self.b64("not-finished")
        case .finished: return "progress." + Self.b64("finished")
        }
    }

    private static func b64(_ s: String) -> String {
        Data(s.utf8).base64EncodedString()
    }
}
