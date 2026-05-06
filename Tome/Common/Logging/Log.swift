import Foundation
import os

nonisolated enum Log {
    private static let subsystem = "BrownGames.Tome"

    static let net = Logger(subsystem: subsystem, category: "net")
    static let auth = Logger(subsystem: subsystem, category: "auth")
    static let player = Logger(subsystem: subsystem, category: "player")
    static let db = Logger(subsystem: subsystem, category: "db")
    static let ui = Logger(subsystem: subsystem, category: "ui")
}
