import Foundation
import Observation
#if canImport(UIKit)
import UIKit
#endif

@Observable
final class AppDependencies {
    let keychain: KeychainStore
    let tokenStore: TokenStore
    let client: ABSClient
    let auth: AuthSession
    let sessionService: PlaybackSessionService
    @MainActor let librarySelection: LibrarySelection
    @MainActor let libraryDensity: LibraryDensityStore
    @MainActor let playerEngine: PlayerEngine

    @MainActor
    init() {
        let keychain = KeychainStore()
        let tokenStore = TokenStore(keychain: keychain)
        let client = ABSClient(tokenStore: tokenStore)
        let auth = AuthSession(tokenStore: tokenStore, client: client)

        let deviceID: String = {
            #if canImport(UIKit)
            return UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
            #else
            return UUID().uuidString
            #endif
        }()
        let deviceInfo = PlaySessionDeviceInfoDTO.makeForCurrentDevice(deviceID: deviceID)
        let sessionService = PlaybackSessionService(client: client, deviceInfo: deviceInfo)

        let assetLoader = AuthenticatingAssetLoader(
            tokenProvider: { [tokenStore] in try await tokenStore.currentAccessToken() },
            tokenRefresher: { [tokenStore] in try await tokenStore.forceRefresh() }
        )

        self.keychain = keychain
        self.tokenStore = tokenStore
        self.client = client
        self.auth = auth
        self.sessionService = sessionService
        self.librarySelection = LibrarySelection()
        self.libraryDensity = LibraryDensityStore()
        self.playerEngine = PlayerEngine(sessionService: sessionService, assetLoader: assetLoader)
    }

    func bootstrap() async {
        await client.bindRefreshHandler()
        await auth.bootstrap()
    }
}
