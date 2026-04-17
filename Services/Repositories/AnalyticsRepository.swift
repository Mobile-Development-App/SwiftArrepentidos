import Foundation

protocol AnalyticsRepositoryProtocol {
    func fetchDashboard() async throws -> DashboardStats
    func fetchSalesTrend(days: Int) async throws -> [SalesDataPoint]
    func fetchStockByCategory() async throws -> [StockLevelData]
    func fetchMargins() async throws -> [CategoryDistribution]
    func exportReport(type: String, format: String, dateFrom: String?, dateTo: String?) async throws -> ExportResponseDTO
}

final class AnalyticsRepository: AnalyticsRepositoryProtocol {
    private let apiClient = APIClient.shared
    private let networkMonitor = NetworkMonitor.shared

    func fetchDashboard() async throws -> DashboardStats {
        guard networkMonitor.isConnected else {
            // Compute from cached products
            let products = PersistenceService.shared.loadProducts()
            let alerts = PersistenceService.shared.loadAlerts()
            return DashboardStats(
                totalProducts: products.count,
                lowStockCount: products.filter { $0.stockStatus == .lowStock }.count,
                outOfStockCount: products.filter { $0.stockStatus == .outOfStock }.count,
                totalStockValue: products.reduce(0) { $0 + $1.stockValue },
                totalSalesToday: 0,
                totalOrders: 0,
                expiringCount: products.filter { $0.isExpiringSoon }.count,
                activeAlerts: alerts.filter { !$0.isRead }.count
            )
        }

        let dto: DashboardDTO = try await apiClient.request(.analyticsDashboard)
        return dto.toDomain()
    }

    func fetchSalesTrend(days: Int = 30) async throws -> [SalesDataPoint] {
        guard networkMonitor.isConnected else {
            throw APIError.offline
        }

        print("[AnalyticsRepo] Fetching sales trend for \(days) days...")
        let dtos: [SalesTrendItemDTO] = try await apiClient.request(
            .analyticsSalesTrend,
            queryParams: ["days": String(days)]
        )
        print("[AnalyticsRepo] Got \(dtos.count) sales trend DTOs")
        if let first = dtos.first {
            print("[AnalyticsRepo] Sample: date=\(first.date ?? "nil"), sales=\(first.sales ?? -1), revenue=\(first.revenue ?? -1)")
        }
        return dtos.map { $0.toDomain() }
    }

    func fetchStockByCategory() async throws -> [StockLevelData] {
        guard networkMonitor.isConnected else {
            throw APIError.offline
        }

        print("[AnalyticsRepo] Fetching stock by category...")
        let dtos: [StockByCategoryDTO] = try await apiClient.request(.analyticsStockByCategory)
        print("[AnalyticsRepo] Got \(dtos.count) stock category DTOs")
        for dto in dtos {
            print("[AnalyticsRepo] Category: \(dto.category ?? dto.categoryId ?? "nil"), totalStock=\(dto.totalStock ?? -1), productCount=\(dto.productCount ?? -1)")
        }
        return dtos.map { $0.toDomain() }
    }

    func fetchMargins() async throws -> [CategoryDistribution] {
        guard networkMonitor.isConnected else {
            throw APIError.offline
        }

        print("[AnalyticsRepo] Fetching margins (via stock-by-category)...")
        // Use stock-by-category data to build category distribution (grouped, not per-product)
        let dtos: [StockByCategoryDTO] = try await apiClient.request(.analyticsStockByCategory)
        print("[AnalyticsRepo] Got \(dtos.count) DTOs for category distribution")
        let totalCount = dtos.reduce(0) { $0 + ($1.productCount ?? $1.totalStock ?? $1.inStock ?? 0) }
        return dtos.map { dto in
            let count = dto.productCount ?? dto.totalStock ?? dto.inStock ?? 0
            let name = dto.category ?? dto.categoryId ?? "Otros"
            // Capitalize first letter for display
            let displayName = name.prefix(1).uppercased() + name.dropFirst()
            return CategoryDistribution(
                category: displayName,
                count: count,
                percentage: totalCount > 0 ? (Double(count) / Double(totalCount)) * 100 : 0,
                value: dto.totalValue ?? Double(count)
            )
        }
    }

    func exportReport(type: String, format: String, dateFrom: String? = nil, dateTo: String? = nil) async throws -> ExportResponseDTO {
        guard networkMonitor.isConnected else {
            throw APIError.offline
        }

        var body: [String: Any] = [
            "type": type,
            "format": format
        ]
        if let dateFrom { body["dateFrom"] = dateFrom }
        if let dateTo { body["dateTo"] = dateTo }

        return try await apiClient.request(
            .exports,
            method: .POST,
            body: body
        )
    }
}
