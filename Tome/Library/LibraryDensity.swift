import Foundation
import Observation

enum LibraryDensity: String, CaseIterable, Identifiable, Sendable {
    case compact
    case regular
    case list

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .compact: return "Compact"
        case .regular: return "Regular"
        case .list: return "List"
        }
    }

    var systemImage: String {
        switch self {
        case .compact: return "square.grid.3x3.fill"
        case .regular: return "square.grid.2x2.fill"
        case .list: return "list.bullet"
        }
    }

    var next: LibraryDensity {
        switch self {
        case .compact: return .regular
        case .regular: return .list
        case .list: return .compact
        }
    }

    /// Adaptive grid minimum width — unused for `.list`.
    var gridMinimum: CGFloat {
        switch self {
        case .compact: return 76
        case .regular: return 96
        case .list: return 0
        }
    }
}

@Observable
@MainActor
final class LibraryDensityStore {
    private static let key = "tome.libraryDensity"
    private let defaults: UserDefaults

    var density: LibraryDensity {
        didSet { defaults.set(density.rawValue, forKey: Self.key) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let raw = defaults.string(forKey: Self.key),
           let stored = LibraryDensity(rawValue: raw) {
            self.density = stored
        } else {
            self.density = .regular
        }
    }
}
