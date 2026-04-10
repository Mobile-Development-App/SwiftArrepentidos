import Foundation

enum APIConfig {
    static var projectId: String {
        "inventaria-app-ae5ce"
    }

    static var region: String { "us-central1" }

    static var baseURL: String {
        "https://\(region)-\(projectId).cloudfunctions.net/api"
    }

    static var storeId: String? {
        get { UserDefaults.standard.string(forKey: "currentStoreId") }
        set { UserDefaults.standard.set(newValue, forKey: "currentStoreId") }
    }
}

enum HTTPMethod: String {
    case GET, POST, PATCH, DELETE
}

enum APIEndpoint {
    // Auth
    case authRegister
    case authLogin

    // Products
    case products
    case product(id: String)
    case productBatches(productId: String)
    case lowStock
    case outOfStock
    case expiringSoon
    case deadStock
    case productVariants(productId: String)
    case productMerge(productId: String)

    // Sales
    case sales
    case salesSummary

    // Inventory
    case inventoryMovements
    case inventoryAdjust
    case inventoryHistory(productId: String)

    // Alerts
    case alerts
    case alertsSummary
    case alertRead(id: String)
    case alertsMarkAllRead

    // Batches
    case batches(productId: String)
    case batchUpdate(id: String)
    case batchAction(id: String)
    case batchesExpiring

    // Reservations
    case reservations
    case reservation(id: String)

    // Restock
    case restockSuggestions
    case purchaseLists
    case purchaseList(id: String)
    case purchaseListVerify(id: String)

    // Cycle Count
    case cycleCountSessions
    case cycleCountSession(id: String)
    case cycleCountItem(sessionId: String, itemId: String)
    case cycleCountComplete(id: String)

    // Analytics
    case analyticsDashboard
    case analyticsSalesTrend
    case analyticsStockByCategory
    case analyticsRotation
    case analyticsMargins
    case analyticsWaste

    // Exports
    case exports

    // Audit
    case auditLogs

    // Telemetry
    case telemetryEvents

    // Pricing
    case pricingRecalculate

    // Health
    case health

    var path: String {
        switch self {
        case .authRegister: return "/auth/register"
        case .authLogin: return "/auth/login"

        case .products: return "/products"
        case .product(let id): return "/products/\(id)"
        case .productBatches(let id): return "/products/\(id)/batches"
        case .lowStock: return "/products/low-stock"
        case .outOfStock: return "/products/out-of-stock"
        case .expiringSoon: return "/products/expiring-soon"
        case .deadStock: return "/products/dead-stock"
        case .productVariants(let id): return "/products/\(id)/variants"
        case .productMerge(let id): return "/products/\(id)/merge"

        case .sales: return "/sales"
        case .salesSummary: return "/sales/summary"

        case .inventoryMovements: return "/inventory/movements"
        case .inventoryAdjust: return "/inventory/adjust"
        case .inventoryHistory(let id): return "/inventory/history/\(id)"

        case .alerts: return "/alerts"
        case .alertsSummary: return "/alerts/summary"
        case .alertRead(let id): return "/alerts/\(id)/read"
        case .alertsMarkAllRead: return "/alerts/mark-all-read"

        case .batches(let id): return "/products/\(id)/batches"
        case .batchUpdate(let id): return "/batches/\(id)"
        case .batchAction(let id): return "/batches/\(id)/action"
        case .batchesExpiring: return "/batches/expiring"

        case .reservations: return "/reservations"
        case .reservation(let id): return "/reservations/\(id)"

        case .restockSuggestions: return "/restock/suggestions"
        case .purchaseLists: return "/restock/purchase-lists"
        case .purchaseList(let id): return "/restock/purchase-lists/\(id)"
        case .purchaseListVerify(let id): return "/restock/purchase-lists/\(id)/verify"

        case .cycleCountSessions: return "/cycle-count/sessions"
        case .cycleCountSession(let id): return "/cycle-count/sessions/\(id)"
        case .cycleCountItem(let sid, let iid): return "/cycle-count/sessions/\(sid)/items/\(iid)"
        case .cycleCountComplete(let id): return "/cycle-count/sessions/\(id)/complete"

        case .analyticsDashboard: return "/analytics/dashboard"
        case .analyticsSalesTrend: return "/analytics/sales-trend"
        case .analyticsStockByCategory: return "/analytics/stock-by-category"
        case .analyticsRotation: return "/analytics/rotation"
        case .analyticsMargins: return "/analytics/margins"
        case .analyticsWaste: return "/analytics/waste"

        case .exports: return "/exports"
        case .auditLogs: return "/audit/logs"
        case .telemetryEvents: return "/telemetry/events"
        case .pricingRecalculate: return "/pricing/recalculate"
        case .health: return "/health"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .authRegister, .authLogin, .sales, .inventoryMovements, .inventoryAdjust,
             .alertsMarkAllRead, .productVariants, .productMerge,
             .purchaseLists, .purchaseListVerify,
             .cycleCountSessions, .cycleCountComplete,
             .exports, .telemetryEvents, .pricingRecalculate,
             .reservations, .batchAction:
            return .POST

        case .product, .alertRead, .batchUpdate,
             .purchaseList, .reservation,
             .cycleCountItem:
            return .PATCH

        default:
            return .GET
        }
    }
}
