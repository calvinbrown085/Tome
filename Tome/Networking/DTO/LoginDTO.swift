import Foundation

nonisolated struct LoginRequestDTO: Encodable, Sendable {
    let username: String
    let password: String
}

nonisolated struct LoginResponseDTO: Decodable, Sendable {
    struct User: Decodable, Sendable {
        let id: String
        let username: String
        let type: String?
        let token: String
    }

    let user: User
    let userDefaultLibraryId: String?
    let accessToken: String?
    let refreshToken: String?

    func resolvedAccessToken() -> String? {
        accessToken ?? user.token
    }
}

nonisolated struct RefreshRequestDTO: Encodable, Sendable {
    let refreshToken: String
}

nonisolated struct RefreshResponseDTO: Decodable, Sendable {
    let accessToken: String
    let refreshToken: String?
}
