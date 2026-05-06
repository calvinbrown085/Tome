import Foundation

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

    func login(serverURL: URL, username: String, password: String) async throws -> LoginResponseDTO {
        self.baseURL = serverURL
        let request = try APIRequest.json(
            path: "/login",
            method: .POST,
            body: LoginRequestDTO(username: username, password: password),
            requiresAuth: false
        )
        let response: LoginResponseDTO = try await perform(request)
        guard let access = response.resolvedAccessToken(),
              let refresh = response.refreshToken else {
            throw APIError.decoding(message: "login response missing tokens")
        }
        try await tokenStore.save(tokens: .init(accessToken: access, refreshToken: refresh))
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

    private func performRaw(_ request: APIRequest) async throws -> Data {
        guard let baseURL else { throw APIError.invalidURL }

        let token: String? = request.requiresAuth ? try await tokenStore.currentAccessToken() : nil
        let urlRequest = try request.makeURLRequest(baseURL: baseURL, accessToken: token)

        let (data, response) = try await dataTask(for: urlRequest)
        let http = try httpResponse(response)

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
