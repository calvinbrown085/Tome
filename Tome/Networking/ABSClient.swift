import Foundation
import os

actor ABSClient {
    private let session: URLSession
    private let tokenStore: TokenStore
    private var baseURL: URL?

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()

    init(session: URLSession = .shared, tokenStore: TokenStore, baseURL: URL? = nil) {
        self.session = session
        self.tokenStore = tokenStore
        self.baseURL = baseURL
    }

    /// Wires `TokenStore.refreshHandler` to call `/auth/refresh` via this client.
    /// Call once at app composition time after both are constructed.
    func bindRefreshHandler() async {
        await tokenStore.setRefreshHandler { [weak self] refreshToken in
            guard let self else { throw APIError.noResponse }
            return try await self.rawRefresh(refreshToken: refreshToken)
        }
    }

    func setBaseURL(_ url: URL) {
        self.baseURL = url
    }

    func currentBaseURL() -> URL? { baseURL }

    // MARK: - Endpoints

    // MARK: - Library

    func listLibraries() async throws -> [LibraryDTO] {
        let response: LibrariesResponseDTO = try await perform(APIRequest(path: "/api/libraries"))
        return response.libraries
    }

    func libraryItems(
        libraryID: String,
        limit: Int = 50,
        page: Int = 0,
        sort: String? = nil,
        desc: Bool? = nil,
        filter: String? = nil,
        minified: Bool = true
    ) async throws -> PaginatedDTO<LibraryItemDTO> {
        var query: [URLQueryItem] = [
            .init(name: "limit", value: String(limit)),
            .init(name: "page", value: String(page))
        ]
        if minified { query.append(.init(name: "minified", value: "1")) }
        if let sort { query.append(.init(name: "sort", value: sort)) }
        if let desc { query.append(.init(name: "desc", value: desc ? "1" : "0")) }
        if let filter { query.append(.init(name: "filter", value: filter)) }
        return try await perform(APIRequest(path: "/api/libraries/\(libraryID)/items", query: query))
    }

    func librarySeries(
        libraryID: String,
        limit: Int = 50,
        page: Int = 0,
        sort: String? = nil,
        desc: Bool? = nil
    ) async throws -> PaginatedDTO<SeriesDTO> {
        var query: [URLQueryItem] = [
            .init(name: "limit", value: String(limit)),
            .init(name: "page", value: String(page))
        ]
        if let sort { query.append(.init(name: "sort", value: sort)) }
        if let desc { query.append(.init(name: "desc", value: desc ? "1" : "0")) }
        return try await perform(APIRequest(path: "/api/libraries/\(libraryID)/series", query: query))
    }

    func libraryItem(id: String, expanded: Bool = true, includeProgress: Bool = true) async throws -> LibraryItemDTO {
        var query: [URLQueryItem] = []
        if expanded { query.append(.init(name: "expanded", value: "1")) }
        if includeProgress { query.append(.init(name: "include", value: "progress")) }
        return try await perform(APIRequest(path: "/api/items/\(id)", query: query))
    }

    func author(id: String, libraryID: String? = nil, includeItems: Bool = true) async throws -> AuthorDTO {
        var query: [URLQueryItem] = []
        if includeItems { query.append(.init(name: "include", value: "items")) }
        if let libraryID { query.append(.init(name: "library", value: libraryID)) }
        return try await perform(APIRequest(path: "/api/authors/\(id)", query: query))
    }

    func search(libraryID: String, query: String, limit: Int = 12) async throws -> SearchResultDTO {
        let q: [URLQueryItem] = [
            .init(name: "q", value: query),
            .init(name: "limit", value: String(limit))
        ]
        return try await perform(APIRequest(path: "/api/libraries/\(libraryID)/search", query: q))
    }

    func coverArtData(itemID: String) async throws -> Data {
        try await performData(APIRequest(path: "/api/items/\(itemID)/cover"))
    }

    // MARK: - Playback sessions

    func openPlaybackSession(
        itemID: String,
        deviceInfo: PlaySessionDeviceInfoDTO?,
        forceDirectPlay: Bool = true,
        supportedMimeTypes: [String] = ["audio/mpeg", "audio/mp4", "audio/aac", "audio/flac", "audio/ogg", "audio/x-m4a", "audio/x-m4b"]
    ) async throws -> PlaybackSessionDTO {
        let body = PlaySessionRequestDTO(
            deviceInfo: deviceInfo,
            forceDirectPlay: forceDirectPlay,
            forceTranscode: false,
            supportedMimeTypes: supportedMimeTypes,
            mediaPlayer: "AVPlayer"
        )
        let request = try APIRequest.jsonCamelCase(path: "/api/items/\(itemID)/play", method: .POST, body: body)
        return try await perform(request)
    }

    func syncPlaybackSession(id: String, currentTime: Double, timeListened: Double, duration: Double) async throws {
        let body = PlaySessionSyncRequestDTO(currentTime: currentTime, timeListened: timeListened, duration: duration)
        let request = try APIRequest.jsonCamelCase(path: "/api/session/\(id)/sync", method: .POST, body: body)
        try await perform(request)
    }

    func closePlaybackSession(id: String, currentTime: Double, timeListened: Double, duration: Double) async throws {
        let body = PlaySessionSyncRequestDTO(currentTime: currentTime, timeListened: timeListened, duration: duration)
        let request = try APIRequest.jsonCamelCase(path: "/api/session/\(id)/close", method: .POST, body: body)
        try await perform(request)
    }

    // MARK: - Auth

    func login(serverURL: URL, username: String, password: String) async throws -> LoginResponseDTO {
        self.baseURL = serverURL
        let request = try APIRequest.json(
            path: "/login",
            method: .POST,
            body: LoginRequestDTO(username: username, password: password),
            requiresAuth: false
        )
        let response: LoginResponseDTO = try await perform(request)
        try await tokenStore.save(tokens: .init(accessToken: response.user.token, refreshToken: response.user.token))
        try await tokenStore.saveServerURL(serverURL.absoluteString)
        try await tokenStore.saveUsername(username)
        return response
    }

    /// Raw refresh — does NOT use the perform() retry path. Avoids recursion.
    private func rawRefresh(refreshToken: String) async throws -> TokenStore.Tokens {
        guard let baseURL else { throw APIError.invalidURL }
        let req = try APIRequest.json(
            path: "/auth/refresh",
            method: .POST,
            body: RefreshRequestDTO(refreshToken: refreshToken),
            requiresAuth: false
        ).makeURLRequest(baseURL: baseURL, accessToken: nil)

        let (data, response) = try await dataTask(for: req)
        try ensure2xx(response: response, data: data)
        do {
            let dto = try decoder.decode(RefreshResponseDTO.self, from: data)
            return TokenStore.Tokens(
                accessToken: dto.accessToken,
                refreshToken: dto.refreshToken ?? refreshToken
            )
        } catch {
            throw APIError.decoding(message: String(describing: error))
        }
    }

    // MARK: - Generic perform

    func perform<T: Decodable & Sendable>(_ request: APIRequest) async throws -> T {
        let data = try await performRaw(request)
        
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decoding(message: String(describing: error))
        }
    }

    func perform(_ request: APIRequest) async throws {
        _ = try await performRaw(request)
    }

    func performData(_ request: APIRequest) async throws -> Data {
        try await performRaw(request)
    }

    private func performRaw(_ request: APIRequest) async throws -> Data {
        guard let baseURL else { throw APIError.invalidURL }

        let token: String? = request.requiresAuth ? try await tokenStore.currentAccessToken() : nil
        let urlRequest = try request.makeURLRequest(baseURL: baseURL, accessToken: token)

        let (data, response) = try await dataTask(for: urlRequest)
        let http = try httpResponse(response)
        Log.net.debug("\(request.method.rawValue, privacy: .public) \(request.path, privacy: .public) → \(http.statusCode, privacy: .public)")

        if http.statusCode == 401 && request.requiresAuth {
            let newToken = try await tokenStore.forceRefresh()
            let retryRequest = try request.makeURLRequest(baseURL: baseURL, accessToken: newToken)
            let (retryData, retryResponse) = try await dataTask(for: retryRequest)
            let retryHTTP = try httpResponse(retryResponse)
            if retryHTTP.statusCode == 401 { throw APIError.unauthorized }
            try ensure2xx(response: retryResponse, data: retryData)
            return retryData
        }

        try ensure2xx(response: response, data: data)
        return data
    }

    // MARK: - Helpers

    private func dataTask(for request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: request)
        } catch let urlError as URLError {
            throw APIError.transport(urlError)
        } catch {
            throw APIError.transport(URLError(.unknown))
        }
    }

    private func httpResponse(_ response: URLResponse) throws -> HTTPURLResponse {
        guard let http = response as? HTTPURLResponse else { throw APIError.noResponse }
        return http
    }

    private func ensure2xx(response: URLResponse, data: Data) throws {
        let http = try httpResponse(response)
        guard (200..<300).contains(http.statusCode) else {
            throw APIError.http(status: http.statusCode, body: data)
        }
    }
}
