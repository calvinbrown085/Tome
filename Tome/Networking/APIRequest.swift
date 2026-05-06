import Foundation

nonisolated struct APIRequest: Sendable {
    enum Method: String, Sendable {
        case GET, POST, PATCH, PUT, DELETE
    }

    var path: String
    var method: Method = .GET
    var query: [URLQueryItem] = []
    var body: Data? = nil
    var contentType: String? = nil
    var requiresAuth: Bool = true

    func makeURLRequest(baseURL: URL, accessToken: String?) throws -> URLRequest {
        let pathURL = baseURL.appending(path: path)
        guard var components = URLComponents(url: pathURL, resolvingAgainstBaseURL: false) else {
            throw APIError.invalidURL
        }
        if !query.isEmpty {
            components.queryItems = (components.queryItems ?? []) + query
        }
        guard let url = components.url else { throw APIError.invalidURL }

        var req = URLRequest(url: url)
        req.httpMethod = method.rawValue
        if let body {
            req.httpBody = body
            req.setValue(contentType ?? "application/json", forHTTPHeaderField: "Content-Type")
        }
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if requiresAuth, let accessToken {
            req.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }
        return req
    }

    static func json<T: Encodable & Sendable>(
        path: String,
        method: Method = .POST,
        body: T,
        requiresAuth: Bool = true
    ) throws -> APIRequest {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try encoder.encode(body)
        return APIRequest(
            path: path,
            method: method,
            body: data,
            contentType: "application/json",
            requiresAuth: requiresAuth
        )
    }
}
