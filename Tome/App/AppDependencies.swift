import Foundation
import Observation

@Observable
final class AppDependencies {
    let keychain: KeychainStore
    let tokenStore: TokenStore
    let client: ABSClient
    let auth: AuthSession

    init() {
        let keychain = KeychainStore()
        let tokenStore = TokenStore(keychain: keychain)
        let client = ABSClient(tokenStore: tokenStore)
        let auth = AuthSession(tokenStore: tokenStore, client: client)
        self.keychain = keychain
        self.tokenStore = tokenStore
        self.client = client
        self.auth = auth
    }

    func bootstrap() async {
        await client.bindRefreshHandler()
        await auth.bootstrap()
    }
}
