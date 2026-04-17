import Foundation

/// Dashboard response from /analytics/dashboard
/// Backend returns: { totalProducts, totalStockValue, lowStockCount, outOfStockCount, todaySales, todayRevenue, activeAlerts }
struct DashboardDTO: Decodable {
    let totalProducts: Int?
    let totalStockValue: Double?
    let totalValue: Double?  // fallback field name
    let lowStockCount: Int?
    let outOfStockCount: Int?
    let expiringCount: Int?
    let todaySales: Int?
    let todayRevenue: Double?
    let todayOrders: Int?
    let activeAlerts: Int?

    func toDomain() -> DashboardStats {
        DashboardStats(
            totalProducts: totalProducts ?? 0,
            lowStockCount: lowStockCount ?? 0,
            outOfStockCount: outOfStockCount ?? 0,
            totalStockValue: totalStockValue ?? totalValue ?? 0,
            totalSalesToday: todayRevenue ?? Double(todaySales ?? 0),
            totalOrders: todaySales ?? todayOrders ?? 0,
            expiringCount: expiringCount ?? 0,
            activeAlerts: activeAlerts ?? 0
        )
    }
}

/// Sales trend data from /analytics/sales-trend
struct SalesTrendDTO: Decodable {
    let date: String // ISO date string or Firestore timestamp
    let totalSales: Double?
    let totalOrders: Int?

    func toDomain() -> SalesDataPoint {
        let parsedDate: Date
        if let ts = try? JSONDecoder().decode(FirestoreTimestamp.self, from: Data(date.utf8)) {
            parsedDate = ts.date
        } else {
            let formatter = ISO8601DateFormatter()
            parsedDate = formatter.date(from: date) ?? Date()
        }

        return SalesDataPoint(
            date: parsedDate,
            sales: totalSales ?? 0,
            orders: totalOrders ?? 0
        )
    }
}

/// Alternative: sales trend where date comes as a simple string like "2024-01-15"
/// Backend returns: { date: "2026-03-15", sales: 6, revenue: 29300 }
/// - `sales` = number of sale transactions (count)
/// - `revenue` = total money earned (COP)
struct SalesTrendItemDTO: Decodable {
    let date: String?
    let sales: Int?
    let revenue: Double?
    let orders: Int?
    let totalSales: Double?
    let totalOrders: Int?

    func toDomain() -> SalesDataPoint {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let parsedDate = date.flatMap { dateFormatter.date(from: $0) } ?? Date()

        return SalesDataPoint(
            date: parsedDate,
            sales: revenue ?? totalSales ?? Double(sales ?? 0),
            orders: sales ?? orders ?? totalOrders ?? 0
        )
    }
}

/// Stock by category from /analytics/stock-by-category
/// Backend returns: { categoryId, productCount, totalStock, totalValue }
struct StockByCategoryDTO: Decodable {
    let categoryId: String?
    let category: String?
    let productCount: Int?
    let totalStock: Int?
    let totalValue: Double?
    let inStock: Int?
    let lowStock: Int?
    let outOfStock: Int?

    func toDomain() -> StockLevelData {
        let name = category ?? categoryId ?? "Otros"
        return StockLevelData(
            category: name,
            inStock: inStock ?? totalStock ?? 0,
            lowStock: lowStock ?? 0,
            outOfStock: outOfStock ?? 0
        )
    }
}

/// Product margin from /analytics/margins
/// Backend returns: { productId, productName, costPrice, sellingPrice, margin }
struct ProductMarginDTO: Decodable {
    let productId: String?
    let productName: String?
    let costPrice: Double?
    let sellingPrice: Double?
    let margin: Double?
}

/// Sales summary from /sales/summary
struct SalesSummaryDTO: Decodable {
    let totalSales: Double?
    let totalOrders: Int?
    let averageOrderValue: Double?
    let period: String?
}

/// Export response from /exports
struct ExportResponseDTO: Decodable {
    let url: String
    let filename: String
}
