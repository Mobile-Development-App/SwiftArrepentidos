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

        let dtos: [StockByCategoryDTO] = try await apiClient.request(.analyticsStockByCategory)
        let raw = dtos.map { $0.toDomain() }

        // Dedupe + merge por nombre canónico (el backend devuelve "snacks" y "Snacks" por separado)
        var merged: [String: StockLevelData] = [:]
        for item in raw {
            let key = Self.canonicalCategoryName(item.category)
            if var existing = merged[key] {
                existing.inStock += item.inStock
                existing.lowStock += item.lowStock
                existing.outOfStock += item.outOfStock
                merged[key] = existing
            } else {
                var normalized = item
                normalized.category = key
                merged[key] = normalized
            }
        }
        return Array(merged.values).sorted { $0.category < $1.category }
    }

    func fetchMargins() async throws -> [CategoryDistribution] {
        guard networkMonitor.isConnected else {
            throw APIError.offline
        }

        // Reutilizamos stock-by-category, pero deduplicando estrictamente para el pie chart
        let dtos: [StockByCategoryDTO] = try await apiClient.request(.analyticsStockByCategory)

        // Merge por nombre canónico
        var merged: [String: (count: Int, value: Double)] = [:]
        for dto in dtos {
            let rawName = dto.category ?? dto.categoryId ?? "Otros"
            let key = Self.canonicalCategoryName(rawName)
            let count = dto.productCount ?? dto.totalStock ?? dto.inStock ?? 0
            let value = dto.totalValue ?? Double(count)
            if let existing = merged[key] {
                merged[key] = (count: existing.count + count, value: existing.value + value)
            } else {
                merged[key] = (count: count, value: value)
            }
        }

        let totalCount = merged.values.reduce(0) { $0 + $1.count }
        return merged.map { (key, val) in
            CategoryDistribution(
                category: key,
                count: val.count,
                percentage: totalCount > 0 ? (Double(val.count) / Double(totalCount)) * 100 : 0,
                value: val.value
            )
        }
        .sorted { $0.count > $1.count }  // más grande primero para mejor visual
    }

    /// Normaliza nombres de categoría: combina variantes de idioma y capitalización
    /// en un único nombre canónico en español.
    /// Ej: "snacks" / "Snacks" / "SNACKS" → "Snacks"
    ///     "dairy" / "lacteos" / "lácteos" → "Lácteos"
    ///     "other" / "otros" → "Otros"
    static func canonicalCategoryName(_ rawName: String) -> String {
        let lower = rawName.lowercased().trimmingCharacters(in: .whitespaces)
        let mapping: [String: String] = [
            "snacks": "Snacks",
            "otros": "Otros",
            "other": "Otros",
            "bebidas": "Bebidas",
            "beverages": "Bebidas",
            "lacteos": "Lácteos",
            "lácteos": "Lácteos",
            "dairy": "Lácteos",
            "limpieza": "Limpieza",
            "cleaning": "Limpieza",
            "cuidado personal": "Cuidado Personal",
            "personalcare": "Cuidado Personal",
            "higiene": "Cuidado Personal",
            "granos": "Granos",
            "grains": "Granos",
            "frutas y verduras": "Frutas y Verduras",
            "frutas": "Frutas y Verduras",
            "fruits": "Frutas y Verduras",
            "carnes": "Carnes",
            "meat": "Carnes",
            "panaderia": "Panadería",
            "panadería": "Panadería",
            "bakery": "Panadería",
            "congelados": "Congelados",
            "frozen": "Congelados",
            "condimentos": "Condimentos",
            "condiments": "Condimentos"
        ]
        if let mapped = mapping[lower] { return mapped }
        // Fallback: capitalize la primera letra
        return rawName.prefix(1).uppercased() + rawName.dropFirst()
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
