import Foundation
import Observation
import os

@Observable
final class AuthSession {
    enum State: Sendable, Equatable {
        case unknown
        case loggedOut
        case loggedIn(serverURL: URL, username: String)
    }

    var state: State = .unknown

    private let tokenStore: TokenStore
    private let client: ABSClient

    init(tokenStore: TokenStore, client: ABSClient) {
        self.tokenStore = tokenStore
        self.client = client
    }

    func bootstrap() async {
        let hasCreds = await tokenStore.hasStoredCredentials()
        guard hasCreds else {
            state = .loggedOut
            return
        }
        let urlString = try? await tokenStore.loadServerURL()
        let username = (try? await tokenStore.loadUsername()) ?? ""
        if let urlString, let url = URL(string: urlString) {
            await client.setBaseURL(url)
            state = .loggedIn(serverURL: url, username: username)
            Log.auth.info("Restored session for \(username, privacy: .public)")
        } else {
            await tokenStore.clear()
            state = .loggedOut
        }
    }

    func login(serverURL: URL, username: String, password: String) async throws {
        let response = try await client.login(serverURL: serverURL, username: username, password: password)
        let resolvedName = response.user.username
        state = .loggedIn(serverURL: serverURL, username: resolvedName)
        Log.auth.info("Login succeeded for \(resolvedName, privacy: .public)")
    }

    func logout() async {
        await tokenStore.clear()
        state = .loggedOut
        Log.auth.info("Logged out")
    }
}
