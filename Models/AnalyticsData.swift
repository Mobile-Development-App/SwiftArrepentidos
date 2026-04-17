import Foundation

struct SalesDataPoint: Identifiable {
    let id = UUID()
    var date: Date
    var sales: Double
    var orders: Int
}

struct StockLevelData: Identifiable {
    let id = UUID()
    var category: String
    var inStock: Int
    var lowStock: Int
    var outOfStock: Int
}

struct CategoryDistribution: Identifiable {
    let id = UUID()
    var category: String
    var count: Int
    var percentage: Double
    var value: Double
}

struct DashboardStats {
    var totalProducts: Int
    var lowStockCount: Int
    var outOfStockCount: Int
    var totalStockValue: Double
    var totalSalesToday: Double
    var totalOrders: Int
    var expiringCount: Int
    var activeAlerts: Int
}
