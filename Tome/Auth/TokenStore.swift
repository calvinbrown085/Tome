import Foundation
import os

actor TokenStore {
    struct Tokens: Sendable, Equatable {
        var accessToken: String
        var refreshToken: String
    }

    enum AccountKey {
        static let accessToken = "access-token"
        static let refreshToken = "refresh-token"
        static let serverURL = "server-url"
        static let username = "username"
    }

    enum TokenError: Error, Sendable {
        case notLoggedIn
        case refreshHandlerNotSet
    }

    typealias RefreshHandler = @Sendable (_ refreshToken: String) async throws -> Tokens

    private let keychain: KeychainStore
    private var cached: Tokens?
    private var loadedFromKeychain: Bool = false
    private var inFlightRefresh: Task<String, Error>?
    private var refreshHandler: RefreshHandler?

    init(keychain: KeychainStore) {
        self.keychain = keychain
    }

    func setRefreshHandler(_ handler: @escaping RefreshHandler) {
        self.refreshHandler = handler
    }

    func currentAccessToken() async throws -> String {
        try await ensureLoaded()
        guard let tokens = cached else { throw TokenError.notLoggedIn }
        return tokens.accessToken
    }

    func hasStoredCredentials() async -> Bool {
        try? await ensureLoaded()
        return cached != nil
    }

    func save(tokens: Tokens) async throws {
        cached = tokens
        loadedFromKeychain = true
        try await keychain.writeString(tokens.accessToken, account: AccountKey.accessToken)
        try await keychain.writeString(tokens.refreshToken, account: AccountKey.refreshToken)
    }

    func saveServerURL(_ url: String) async throws {
        try await keychain.writeString(url, account: AccountKey.serverURL)
    }

    func loadServerURL() async throws -> String? {
        try await keychain.readString(account: AccountKey.serverURL)
    }

    func saveUsername(_ username: String) async throws {
        try await keychain.writeString(username, account: AccountKey.username)
    }

    func loadUsername() async throws -> String? {
        try await keychain.readString(account: AccountKey.username)
    }

    func clear() async {
        cached = nil
        loadedFromKeychain = true
        try? await keychain.delete(account: AccountKey.accessToken)
        try? await keychain.delete(account: AccountKey.refreshToken)
        try? await keychain.delete(account: AccountKey.serverURL)
        try? await keychain.delete(account: AccountKey.username)
    }

    func forceRefresh() async throws -> String {
        if let inFlight = inFlightRefresh {
            return try await inFlight.value
        }
        let task = Task<String, Error> { [weak self] in
            guard let self else { throw TokenError.refreshHandlerNotSet }
            return try await self.runRefresh()
        }
        inFlightRefresh = task
        do {
            let value = try await task.value
            inFlightRefresh = nil
            return value
        } catch {
            inFlightRefresh = nil
            throw error
        }
    }

    private func runRefresh() async throws -> String {
        try await ensureLoaded()
        guard let tokens = cached else { throw TokenError.notLoggedIn }
        guard let handler = refreshHandler else { throw TokenError.refreshHandlerNotSet }
        do {
            let new = try await handler(tokens.refreshToken)
            try await save(tokens: new)
            Log.auth.info("Token refresh succeeded")
            return new.accessToken
        } catch {
            Log.auth.error("Token refresh failed: \(String(describing: error), privacy: .public)")
            await clear()
            throw error
        }
    }

    private func ensureLoaded() async throws {
        if loadedFromKeychain { return }
        let access = try await keychain.readString(account: AccountKey.accessToken)
        let refresh = try await keychain.readString(account: AccountKey.refreshToken)
        if let access, let refresh {
            cached = Tokens(accessToken: access, refreshToken: refresh)
        }
        loadedFromKeychain = true
    }
}
