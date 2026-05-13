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


    private let lookupCache: NSCache<NSString, CachedOFFProduct> = {
        let cache = NSCache<NSString, CachedOFFProduct>()
        cache.countLimit = 128
        cache.totalCostLimit = 2 * 1024 * 1024
        cache.name = "openFoodFacts.lookup"
        return cache
    }()

    /// TTL: el catálogo de Open Food Facts es estable — un producto
    /// reportado hoy tiene los mismos datos mañana. 24 h de caché es
    /// razonable y permite trabajo offline contra barcodes vistos.
    private let cacheTTL: TimeInterval = 24 * 60 * 60

    init(session: URLSession = .shared) {
        self.session = session
    }

    func lookup(barcode: String) async throws -> OpenFoodFactsProduct? {
        // Validación: solo dígitos, máx 32 chars (previene URL injection)
        let trimmed = barcode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              trimmed.count <= 32,
              trimmed.allSatisfy({ $0.isNumber }) else {
            throw APIError.invalidURL
        }

        // FIX: Caching — chequeo de caché L1 (in-memory) ANTES del network.
        // Cubre re-scans dentro de la misma sesión sin hopear más allá.
        let key = trimmed as NSString
        if let cached = lookupCache.object(forKey: key),
           Date().timeIntervalSince(cached.cachedAt) < cacheTTL {
            return cached.product
        }


        let kvKey = "openFoodFacts.\(trimmed)"
        if let stored: OpenFoodFactsProduct = await MainActor.run(
            body: { LocalKeyValueStore.shared.get(kvKey, as: OpenFoodFactsProduct.self) }
        ) {
            // Hidratamos también L1 para que el siguiente lookup en sesión
            // sea instantáneo.
            let boxed = CachedOFFProduct(product: stored, cachedAt: Date())
            lookupCache.setObject(boxed, forKey: key, cost: 1024)
            return stored
        }

        guard networkMonitor.isConnected else {
            throw APIError.offline
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
            let product = productDTO.toDomain(barcode: trimmed)

            let boxed = CachedOFFProduct(product: product, cachedAt: Date())
            lookupCache.setObject(boxed, forKey: key, cost: data.count)

            let kvKey = "openFoodFacts.\(trimmed)"
            await MainActor.run {
                LocalKeyValueStore.shared.set(product, for: kvKey, ttl: cacheTTL)
            }

            return product
        } catch {
            throw APIError.decodingError(error)
        }
    }
}

/// Wrapper de referencia para `NSCache`, que sólo acepta `AnyObject`. Lleva
/// `cachedAt` para que el caller pueda decidir TTL sin re-pegar al disco.
private final class CachedOFFProduct {
    let product: OpenFoodFactsProduct
    let cachedAt: Date
    init(product: OpenFoodFactsProduct, cachedAt: Date) {
        self.product = product
        self.cachedAt = cachedAt
    }
}
