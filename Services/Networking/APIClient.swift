import Foundation

/// Backend response wrapper for list endpoints: { data: T, hasMore, nextCursor }
/// Some endpoints return data directly without a wrapper.
struct DataWrapper<T: Decodable>: Decodable {
    let data: T
    let hasMore: Bool?
    let nextCursor: String?
}

struct APIErrorBody: Decodable {
    let code: String?
    let message: String?
    let error: String?

    var displayMessage: String {
        message ?? error ?? "Error desconocido"
    }
}

struct APIPagination {
    let hasMore: Bool
    let nextCursor: String?
}

/// Firestore Timestamp format from backend: { "_seconds": Int, "_nanoseconds": Int }
struct FirestoreTimestamp: Decodable {
    let _seconds: Int
    let _nanoseconds: Int

    var date: Date {
        Date(timeIntervalSince1970: TimeInterval(_seconds))
    }
}

final class APIClient {
    static let shared = APIClient()

    private(set) var authToken: String?
    private let session: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        session = URLSession(configuration: config)

        encoder = JSONEncoder()
        decoder = JSONDecoder()
        // Dates are Firestore Timestamps, handled manually in DTOs
    }

    // MARK: - Token Management

    func setAuthToken(_ token: String) {
        authToken = token
    }

    func clearAuthToken() {
        authToken = nil
    }

    // MARK: - Generic Request

    /// Decodes response trying: 1) { data: T } wrapper, 2) direct T decode
    func request<T: Decodable>(
        _ endpoint: APIEndpoint,
        method: HTTPMethod? = nil,
        body: [String: Any]? = nil,
        queryParams: [String: String]? = nil
    ) async throws -> T {
        let data = try await rawRequest(endpoint, method: method, body: body, queryParams: queryParams)

        let rawString = String(data: data, encoding: .utf8) ?? "binary"
        print("[APIClient] \(endpoint.path) response (\(data.count) bytes): \(rawString.prefix(300))")

        // Strategy 1: Try { data: T } wrapper (used by /products, /alerts, /analytics/*)
        if let wrapped = try? decoder.decode(DataWrapper<T>.self, from: data) {
            print("[APIClient] \(endpoint.path) decoded via DataWrapper")
            return wrapped.data
        }

        // Strategy 2: Try direct decode (used by /auth/login, /analytics/dashboard)
        do {
            let result = try decoder.decode(T.self, from: data)
            print("[APIClient] \(endpoint.path) decoded directly")
            return result
        } catch {
            print("[APIClient] ❌ Decode failed for \(endpoint.path): \(error)")
            print("[APIClient] Full raw response: \(rawString.prefix(1000))")
            throw APIError.decodingError(error)
        }
    }

    /// Request that also returns pagination info (for list endpoints with { data, hasMore, nextCursor })
    func requestPaginated<T: Decodable>(
        _ endpoint: APIEndpoint,
        method: HTTPMethod? = nil,
        body: [String: Any]? = nil,
        queryParams: [String: String]? = nil
    ) async throws -> (data: T, pagination: APIPagination?) {
        let data = try await rawRequest(endpoint, method: method, body: body, queryParams: queryParams)

        // List endpoints always use { data: T, hasMore, nextCursor }
        let wrapped = try decoder.decode(DataWrapper<T>.self, from: data)
        let pagination = APIPagination(
            hasMore: wrapped.hasMore ?? false,
            nextCursor: wrapped.nextCursor
        )
        return (wrapped.data, pagination)
    }

    /// Raw request returning Data (for exports, file downloads)
    func requestRaw(
        _ endpoint: APIEndpoint,
        method: HTTPMethod? = nil,
        body: [String: Any]? = nil,
        queryParams: [String: String]? = nil
    ) async throws -> Data {
        try await rawRequest(endpoint, method: method, body: body, queryParams: queryParams)
    }

    // MARK: - Private

    private func rawRequest(
        _ endpoint: APIEndpoint,
        method: HTTPMethod?,
        body: [String: Any]?,
        queryParams: [String: String]?
    ) async throws -> Data {
        let httpMethod = method ?? endpoint.method
        var urlString = APIConfig.baseURL + endpoint.path

        // Add query parameters
        if let queryParams, !queryParams.isEmpty {
            var components = URLComponents(string: urlString)!
            components.queryItems = queryParams.map { URLQueryItem(name: $0.key, value: $0.value) }
            urlString = components.url!.absoluteString
        }

        guard let url = URL(string: urlString) else {
            throw APIError.unknown("URL invalida: \(urlString)")
        }

        var request = URLRequest(url: url)
        request.httpMethod = httpMethod.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Auth header (all endpoints except /auth/register and /health)
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        // Store ID header
        if let storeId = APIConfig.storeId {
            request.setValue(storeId, forHTTPHeaderField: "X-Store-Id")
        }

        // Body
        if let body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.unknown("Respuesta no HTTP")
        }

        // Handle error status codes
        if httpResponse.statusCode < 200 || httpResponse.statusCode >= 300 {
            // Try to parse error body
            let errorMessage: String?
            if let errorBody = try? decoder.decode(APIErrorBody.self, from: data) {
                errorMessage = errorBody.displayMessage
            } else {
                errorMessage = String(data: data, encoding: .utf8)
            }

            let apiError = APIError.from(statusCode: httpResponse.statusCode, message: errorMessage)

            // Post notification for 401 so AuthViewModel can handle logout
            if httpResponse.statusCode == 401 {
                NotificationCenter.default.post(name: .authTokenExpired, object: nil)
            }

            throw apiError
        }

        return data
    }
}

extension Notification.Name {
    static let authTokenExpired = Notification.Name("authTokenExpired")
    static let userDidLogout = Notification.Name("userDidLogout")
    static let inventoryDidChange = Notification.Name("inventoryDidChange")
}
