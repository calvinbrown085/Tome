import Foundation

nonisolated enum APIError: Error, Sendable {
    case invalidURL
    case transport(URLError)
    case noResponse
    case http(status: Int, body: Data?)
    case decoding(message: String)
    case unauthorized

    var isUnauthorized: Bool {
        switch self {
        case .unauthorized: return true
        case .http(let status, _): return status == 401
        default: return false
        }
    }
}

extension APIError: CustomStringConvertible {
    var description: String {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .transport(let err): return "Transport error: \(err.localizedDescription)"
        case .noResponse: return "No response"
        case .http(let status, _): return "HTTP \(status)"
        case .decoding(let msg): return "Decoding failed: \(msg)"
        case .unauthorized: return "Unauthorized"
        }
    }
}
