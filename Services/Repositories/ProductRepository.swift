import Foundation

protocol ProductRepositoryProtocol {
    func fetchProducts(search: String?, category: String?, stockStatus: String?, limit: Int?, cursor: String?) async throws -> (products: [Product], nextCursor: String?)
    func getProduct(id: String) async throws -> Product
    func createProduct(_ product: Product) async throws -> Product
    func updateProduct(id: String, _ product: Product) async throws -> Product
    func deleteProduct(id: String) async throws
    func fetchLowStock() async throws -> [Product]
    func fetchOutOfStock() async throws -> [Product]
    func fetchExpiringSoon(days: Int) async throws -> [Product]
}

final class ProductRepository: ProductRepositoryProtocol {
    private let apiClient = APIClient.shared
    private let cache = PersistenceService.shared
    private let networkMonitor = NetworkMonitor.shared

    func fetchProducts(search: String? = nil, category: String? = nil, stockStatus: String? = nil, limit: Int? = nil, cursor: String? = nil) async throws -> (products: [Product], nextCursor: String?) {
        guard networkMonitor.isConnected else {
            return (cache.loadProducts(), nil)
        }

        var params: [String: String] = [:]
        if let search, !search.isEmpty { params["search"] = search }
        if let category { params["category"] = category }
        if let stockStatus { params["stockStatus"] = stockStatus }
        if let limit { params["limit"] = String(limit) }
        if let cursor { params["startAfter"] = cursor }

        let (dtos, pagination): ([ProductDTO], APIPagination?) = try await apiClient.requestPaginated(
            .products,
            queryParams: params.isEmpty ? nil : params
        )

        let products = dtos.map { $0.toDomain() }

        // Update cache only on full fetch (no cursor = first page)
        if cursor == nil {
            cache.saveProducts(products)
        }

        return (products, pagination?.nextCursor)
    }

    func getProduct(id: String) async throws -> Product {
        guard networkMonitor.isConnected else {
            if let cached = cache.loadProducts().first(where: { $0.id == UUID(deterministicFrom: id) }) {
                return cached
            }
            throw APIError.offline
        }

        let dto: ProductDTO = try await apiClient.request(.product(id: id))
        return dto.toDomain()
    }

    func createProduct(_ product: Product) async throws -> Product {
        guard networkMonitor.isConnected else {
            throw APIError.offline
        }

        let token = await PipelineLogger.shared.start(.ingestion)
        let dto: ProductDTO = try await apiClient.request(
            .products,
            method: .POST,
            body: product.toCreateRequest()
        )
        await PipelineLogger.shared.end(token)

        let created = dto.toDomain()

        var products = cache.loadProducts()
        products.append(created)
        cache.saveProducts(products)

        return created
    }

    func updateProduct(id: String, _ product: Product) async throws -> Product {
        guard networkMonitor.isConnected else {
            throw APIError.offline
        }

        let token = await PipelineLogger.shared.start(.ingestion)
        let dto: ProductDTO = try await apiClient.request(
            .product(id: id),
            method: .PATCH,
            body: product.toUpdateRequest()
        )
        await PipelineLogger.shared.end(token)

        let updated = dto.toDomain()

        var products = cache.loadProducts()
        if let index = products.firstIndex(where: { $0.id == updated.id }) {
            products[index] = updated
        }
        cache.saveProducts(products)

        return updated
    }

    func deleteProduct(id: String) async throws {
        guard networkMonitor.isConnected else {
            throw APIError.offline
        }

        let _: ProductDTO = try await apiClient.request(
            .product(id: id),
            method: .DELETE
        )

        // Update cache
        var products = cache.loadProducts()
        products.removeAll { $0.id == UUID(deterministicFrom: id) }
        cache.saveProducts(products)
    }

    func fetchLowStock() async throws -> [Product] {
        guard networkMonitor.isConnected else {
            return cache.loadProducts().filter { $0.stockStatus == .lowStock }
        }

        let dtos: [ProductDTO] = try await apiClient.request(.lowStock)
        return dtos.map { $0.toDomain() }
    }

    func fetchOutOfStock() async throws -> [Product] {
        guard networkMonitor.isConnected else {
            return cache.loadProducts().filter { $0.stockStatus == .outOfStock }
        }

        let dtos: [ProductDTO] = try await apiClient.request(.outOfStock)
        return dtos.map { $0.toDomain() }
    }

    func fetchExpiringSoon(days: Int = 30) async throws -> [Product] {
        guard networkMonitor.isConnected else {
            return cache.loadProducts().filter { $0.isExpiringSoon }
        }

        let dtos: [ProductDTO] = try await apiClient.request(
            .expiringSoon,
            queryParams: ["days": String(days)]
        )
        return dtos.map { $0.toDomain() }
    }
}
