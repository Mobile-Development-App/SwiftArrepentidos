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

    // FIX: Caching — NSCache con countLimit y totalCostLimit explícitos.
    //
    // El usuario escanea el mismo barcode varias veces (por error, por
    // demo, por edición del mismo producto). Sin caché, cada scan dispara
    // un round-trip de ~200ms a Open Food Facts. Con NSCache:
    //   • countLimit: 128 productos — cubre un día de scans en una tienda
    //   • totalCostLimit: 2 MB — los DTOs son chicos (~1-3 KB cada uno),
    //                            esto deja margen para imágenes embebidas
    //   • NSCache responde a memory warnings del OS automáticamente
    //   • thread-safe nativo, no necesitamos serializar manualmente
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

    /// Looks up a product by its barcode.
    /// - Returns: `OpenFoodFactsProduct` if found, `nil` if the barcode is not in the database.
    /// - Throws: `APIError.offline` if there's no network,
    ///           `APIError.invalidURL` if the URL cannot be built,
    ///           `APIError.networkError` on request failure,
    ///           `APIError.invalidResponse` if the response is not HTTP,
    ///           `APIError.serverError` on non-2xx status codes,
    ///           `APIError.decodingError` on malformed responses.
    func lookup(barcode: String) async throws -> OpenFoodFactsProduct? {
        // Validación: solo dígitos, máx 32 chars (previene URL injection)
        let trimmed = barcode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              trimmed.count <= 32,
              trimmed.allSatisfy({ $0.isNumber }) else {
            throw APIError.invalidURL
        }

        // FIX: Caching — chequeo de caché ANTES del network. Esto cubre el
        // modo offline si ya vimos el barcode antes (TTL 24h), y elimina
        // ~200ms de latencia + un round-trip por scan repetido.
        let key = trimmed as NSString
        if let cached = lookupCache.object(forKey: key),
           Date().timeIntervalSince(cached.cachedAt) < cacheTTL {
            return cached.product
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

            // FIX: Caching — guardamos en NSCache con cost = tamaño del JSON
            // crudo. Eso permite que `totalCostLimit` haga eviction inteligente
            // basada en memoria real ocupada, no sólo en número de entradas.
            let boxed = CachedOFFProduct(product: product, cachedAt: Date())
            lookupCache.setObject(boxed, forKey: key, cost: data.count)

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
