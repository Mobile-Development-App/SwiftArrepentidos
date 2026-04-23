import Foundation

protocol OpenFoodFactsRepositoryProtocol {
    func lookup(barcode: String) async throws -> OpenFoodFactsProduct?
}


/// Used as a fallback when a scanned barcode doesn't exist in our own backend,
/// to pre-fill the Add Product form with real data (name, brand, image).
final class OpenFoodFactsRepository: OpenFoodFactsRepositoryProtocol {

    private let baseURL = "https://world.openfoodfacts.org/api/v0/product"
    private let networkMonitor = NetworkMonitor.shared
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    /// Looks up a product by its barcode.
    /// - Returns: `OpenFoodFactsProduct` if found, `nil` if the barcode is not in the database.
    /// - Throws: `APIError.offline` if there's no network,
    ///           `APIError.invalidURL` if the URL cannot be built,
    ///           `APIError.networkError` on request failure,
    ///           `APIError.invalidResponse` if the response is not HTTP,
    ///           `APIError.serverError` on non-2xx status codes,
    ///           `APIError.decodingError` on malformed responses.
    func lookup(barcode: String) async throws -> OpenFoodFactsProduct? {
        guard networkMonitor.isConnected else {
            throw APIError.offline
        }

        // Validación: solo dígitos, máx 32 chars (previene URL injection)
        let trimmed = barcode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              trimmed.count <= 32,
              trimmed.allSatisfy({ $0.isNumber }) else {
            throw APIError.invalidURL
        }

        // Construir URL de forma segura (sin string interpolation directa)
        guard var components = URLComponents(string: baseURL) else {
            throw APIError.invalidURL
        }
        components.path += "/\(trimmed).json"
        guard let url = components.url else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("InventarIA-iOS/1.0", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 10

        let data: Data
        let response: URLResponse
        do {
            let result = try await session.data(for: request)
            data = result.0
            response = result.1
        } catch {
            throw APIError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.serverError(statusCode: httpResponse.statusCode, message: nil)
        }

        // Rechazar respuestas absurdamente grandes (>1MB) para evitar memory abuse
        guard data.count < 1_000_000 else {
            throw APIError.serverError(statusCode: 413, message: "Response too large")
        }

        do {
            let decoded = try JSONDecoder().decode(OpenFoodFactsResponse.self, from: data)
            // status = 0 means the product is not in the database
            guard decoded.status == 1, let productDTO = decoded.product else {
                return nil
            }
            return productDTO.toDomain(barcode: trimmed)
        } catch {
            throw APIError.decodingError(error)
        }
    }
}
