import SwiftUI
import Combine

@MainActor
class InventoryViewModel: ObservableObject {
    @Published var products: [Product] = []
    @Published var alerts: [InventoryAlert] = []
    @Published var orders: [Order] = []
    @Published var suppliers: [Supplier] = []
    @Published var dashboardStats = DashboardStats(totalProducts: 0, lowStockCount: 0, outOfStockCount: 0, totalStockValue: 0, totalSalesToday: 0, totalOrders: 0, expiringCount: 0, activeAlerts: 0)

    // Loading/Error states
    @Published var isLoading = false
    @Published var error: String?
    @Published var isOfflineMode = false

    // Search and Filter
    @Published var searchText = ""
    @Published var selectedFilter: StockFilter = .all
    @Published var selectedCategory: ProductCategory?

    // Product Form
    @Published var editingProduct: Product?
    @Published var showingAddProduct = false
    @Published var productSaved = false

    // Scan
    @Published var scannedProduct: ScannedProductResult?
    @Published var isScanning = false

    private let productRepo = ProductRepository()
    private let alertRepo = AlertRepository()
    private let analyticsRepo = AnalyticsRepository()
    private let persistence = PersistenceService.shared
    private let networkMonitor = NetworkMonitor.shared
    private var logoutObserver: Any?

    enum StockFilter: String, CaseIterable {
        case all = "Todos"
        case inStock = "En Stock"
        case lowStock = "Stock Bajo"
        case outOfStock = "Agotado"
        case expiring = "Por Vencer"
    }

    init() {
        // Don't load data here — storeId may not be available yet.
        // Data is loaded when MainTabView appears (after login).
        logoutObserver = NotificationCenter.default.addObserver(
            forName: .userDidLogout, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.clearData() }
        }
    }

    deinit {
        if let observer = logoutObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }


    func loadData() {
        // Load cached data immediately for fast UI
        products = persistence.loadProducts()
        alerts = persistence.loadAlerts()
        orders = persistence.loadOrders()
        suppliers = persistence.loadSuppliers()
        updateStats()

        // Then fetch from API if online
        Task {
            await fetchFromAPI()
        }
    }

    private func fetchFromAPI() async {
        guard networkMonitor.isConnected else {
            isOfflineMode = true
            return
        }

        // Wait briefly for auth token to be restored if session is being resumed
        if APIClient.shared.authToken == nil {
            try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5s max wait
            guard APIClient.shared.authToken != nil else {
                // Still no token — can't fetch, stay with cached data
                return
            }
        }

        isLoading = true
        error = nil

        do {
            async let productsResult = productRepo.fetchProducts()
            async let alertsResult = alertRepo.fetchAlerts()
            async let dashboardResult = analyticsRepo.fetchDashboard()

            let (prodResult, alertResult, dashboard) = try await (productsResult, alertsResult, dashboardResult)

            self.products = prodResult.products
            self.alerts = alertResult.alerts
            self.dashboardStats = dashboard
            self.isOfflineMode = false
            updateStats()
        } catch let apiError as APIError where apiError.errorDescription == APIError.offline.errorDescription {
            self.isOfflineMode = true
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }


    var filteredProducts: [Product] {
        var result = products

        if !searchText.isEmpty {
            result = result.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.sku.localizedCaseInsensitiveContains(searchText) ||
                $0.barcode.contains(searchText) ||
                $0.category.rawValue.localizedCaseInsensitiveContains(searchText)
            }
        }

        switch selectedFilter {
        case .all: break
        case .inStock: result = result.filter { $0.stockStatus == .inStock }
        case .lowStock: result = result.filter { $0.stockStatus == .lowStock }
        case .outOfStock: result = result.filter { $0.stockStatus == .outOfStock }
        case .expiring: result = result.filter { $0.isExpired || $0.isExpiringSoon }
        }

        if let category = selectedCategory {
            result = result.filter { $0.category == category }
        }
        return result
    }

    var filterCounts: [StockFilter: Int] {
        [
            .all: products.count,
            .inStock: products.filter { $0.stockStatus == .inStock }.count,
            .lowStock: products.filter { $0.stockStatus == .lowStock }.count,
            .outOfStock: products.filter { $0.stockStatus == .outOfStock }.count,
            .expiring: products.filter { $0.isExpired || $0.isExpiringSoon }.count
        ]
    }

    var unreadAlertCount: Int { alerts.filter { !$0.isRead }.count }

    var totalStockValue: Double { products.reduce(0) { $0 + $1.stockValue } }

    var restockNeeded: [Product] {
        products.filter {
            $0.isActive &&
            $0.quantity < $0.minStock  // Estricto: excluye los que están exactamente en el mínimo
        }
        .sorted { $0.quantity < $1.quantity }
    }

    var expiringProducts: [Product] {
        products.filter { $0.isExpiringSoon }
            .sorted { ($0.expirationDate ?? .distantFuture) < ($1.expirationDate ?? .distantFuture) }
    }


    func addProduct(_ product: Product) {
        // Optimistic update: el producto se ve inmediatamente
        products.append(product)
        persistence.saveProducts(products)
        generateAlerts(for: product)
        updateStats()
        HapticManager.notification(.success)

        // Sprint 3 BQ6: log the product creation for the peak-activity
        // histogram. Fire-and-forget; the tracker is an actor and handles
        // its own persistence off the main thread.
        Task.detached(priority: .utility) {
            await UsageTrackingService.shared.record(
                kind: .productCreated,
                attributes: [
                    "productId": product.id.uuidString,
                    "category": product.category.rawValue,
                    "location": product.location
                ]
            )
        }

        // Disparamos inventoryDidChange inmediatamente para que analytics refresque
        NotificationCenter.default.post(name: .inventoryDidChange, object: nil)

        Task {
            do {
                let created = try await productRepo.createProduct(product)
                // Reemplazar el producto local con la versión del server (tiene el ID correcto del backend)
                if let index = products.firstIndex(where: { $0.id == product.id }) {
                    products[index] = created
                    persistence.saveProducts(products)
                }
                NotificationCenter.default.post(name: .inventoryDidChange, object: nil)
            } catch {
                #if DEBUG
                print("[InventoryVM] ⚠️ Create backend failed: \(error) — kept locally")
                #endif
                // No rollback: local state preservado.
                // El producto existirá localmente; en el próximo restart podría desaparecer si backend no lo tiene.
                await MainActor.run {
                    self.error = "Guardado localmente. No se pudo sincronizar con el servidor."
                }
            }
        }

        logAudit(action: "Producto Agregado", entityType: "Product", entityId: product.id, entityName: product.name, details: "SKU: \(product.sku), Cantidad: \(product.quantity)")
    }

    func updateProduct(_ product: Product) {
        guard let index = products.firstIndex(where: { $0.id == product.id }) else { return }
        let oldProduct = products[index]

        // Optimistic update: cambios visibles inmediatamente
        products[index] = product
        persistence.saveProducts(products)
        generateAlerts(for: product)
        updateStats()

        // Analytics refresca inmediatamente con el cambio local
        NotificationCenter.default.post(name: .inventoryDidChange, object: nil)

        Task {
            do {
                _ = try await productRepo.updateProduct(id: product.id.apiString, product)
                NotificationCenter.default.post(name: .inventoryDidChange, object: nil)
            } catch {
                #if DEBUG
                print("[InventoryVM] ⚠️ Update backend failed: \(error) — kept locally")
                #endif
                // No rollback: el cambio del usuario gana
                await MainActor.run {
                    self.error = "Cambios guardados localmente. Sincronizará cuando el servidor responda."
                }
            }
        }

        var changes: [String] = []
        if oldProduct.quantity != product.quantity { changes.append("Cantidad: \(oldProduct.quantity) -> \(product.quantity)") }
        if oldProduct.salePrice != product.salePrice { changes.append("Precio: \(oldProduct.salePrice.currencyFormatted) -> \(product.salePrice.currencyFormatted)") }
        logAudit(action: "Producto Actualizado", entityType: "Product", entityId: product.id, entityName: product.name, details: changes.joined(separator: ", "))
    }

    func deleteProduct(_ product: Product) {
        // Optimistic delete: producto desaparece inmediatamente
        products.removeAll { $0.id == product.id }
        persistence.saveProducts(products)
        updateStats()
        HapticManager.notification(.success)

        NotificationCenter.default.post(name: .inventoryDidChange, object: nil)

        Task {
            do {
                try await productRepo.deleteProduct(id: product.id.apiString)
                NotificationCenter.default.post(name: .inventoryDidChange, object: nil)
            } catch {
                #if DEBUG
                print("[InventoryVM] ⚠️ Delete backend failed: \(error) — kept locally deleted")
                #endif
                // No rollback: el usuario quiso eliminarlo
                await MainActor.run {
                    self.error = "Eliminado localmente. Podría reaparecer si el servidor no lo recibió."
                }
            }
        }

        logAudit(action: "Producto Eliminado", entityType: "Product", entityId: product.id, entityName: product.name, details: "Eliminado del inventario")
    }

    func recordSale(productId: UUID, quantity: Int) {
        // Validación: cantidad positiva y no exceder stock
        guard quantity > 0, quantity <= 1_000_000 else {
            self.error = "Cantidad de venta inválida"
            return
        }
        guard let index = products.firstIndex(where: { $0.id == productId }) else { return }
        guard quantity <= products[index].quantity else {
            self.error = "No hay suficiente stock para esta venta"
            HapticManager.notification(.error)
            return
        }

        let product = products[index]

        // Operación incremental: el usuario vendió algo físicamente.
        // El local state gana — aunque el backend falle, la venta se registró.
        products[index].quantity = max(0, product.quantity - quantity)
        products[index].lastUpdated = Date()
        persistence.saveProducts(products)
        generateAlerts(for: products[index])
        updateStats()

        Task {
            do {
                let salesRepo = SalesRepository()
                try await salesRepo.recordSale(
                    productId: productId.apiString,
                    quantity: quantity,
                    unitPrice: product.salePrice
                )
                NotificationCenter.default.post(name: .inventoryDidChange, object: nil)
            } catch {
                #if DEBUG
                print("[InventoryVM] ⚠️ Sale backend failed: \(error) — local state preserved")
                #endif
                // No rollback: el local state preserva la intención del usuario
                await MainActor.run {
                    self.error = "Venta guardada localmente. Sincronizará cuando haya conexión."
                }
            }
        }

        logAudit(action: "Venta Registrada", entityType: "Product", entityId: productId, entityName: products[index].name, details: "Cantidad vendida: \(quantity)")
    }

    func restockProduct(productId: UUID, quantity: Int) {
        guard quantity > 0, quantity <= 1_000_000 else {
            self.error = "Cantidad de restock inválida"
            return
        }
        guard let index = products.firstIndex(where: { $0.id == productId }) else { return }

        // Operación incremental: el usuario reabasteció físicamente.
        // El local state gana — no revertimos aunque el backend falle.
        products[index].quantity += quantity
        products[index].lastUpdated = Date()
        persistence.saveProducts(products)
        updateStats()
        HapticManager.notification(.success)

        Task {
            let body: [String: Any] = [
                "productId": productId.apiString,
                "type": "RESTOCK",
                "quantity": quantity,
                "reason": "Reabastecimiento desde app"
            ]
            do {
                _ = try await APIClient.shared.requestRaw(
                    .inventoryMovements,
                    method: .POST,
                    body: body
                )
                NotificationCenter.default.post(name: .inventoryDidChange, object: nil)
            } catch {
                #if DEBUG
                print("[InventoryVM] ⚠️ Restock backend failed: \(error) — local state preserved")
                #endif
                // No rollback: el local state preserva la intención del usuario
                await MainActor.run {
                    self.error = "Reabastecimiento guardado localmente. Sincronizará cuando haya conexión."
                }
            }
        }

        logAudit(action: "Reabastecimiento", entityType: "Product", entityId: productId, entityName: products[index].name, details: "Cantidad: +\(quantity)")
    }

    func findProduct(byBarcode barcode: String) -> Product? {
        products.first { $0.barcode == barcode }
    }

    func findDuplicates(name: String, barcode: String) -> [Product] {
        products.filter { $0.barcode == barcode || $0.name.localizedCaseInsensitiveContains(name) }
    }


    func markAlertAsRead(_ alert: InventoryAlert) {
        if let index = alerts.firstIndex(where: { $0.id == alert.id }) {
            alerts[index].isRead = true
            persistence.saveAlerts(alerts)

            Task {
                try? await alertRepo.markAsRead(id: alert.id.apiString)
            }
        }
    }

    func markAllAlertsAsRead() {
        for i in alerts.indices { alerts[i].isRead = true }
        persistence.saveAlerts(alerts)

        Task {
            try? await alertRepo.markAllAsRead()
        }
    }

    private func generateAlerts(for product: Product) {
        // Local alert generation as fallback when offline
        if product.stockStatus == .lowStock {
            let exists = alerts.contains { $0.productId == product.id && $0.type == .lowStock && !$0.isRead }
            if !exists {
                let alert = InventoryAlert(id: UUID(), title: "Stock Bajo", message: "\(product.name) tiene solo \(product.quantity) unidades (min: \(product.minStock))", type: .lowStock, priority: .high, productId: product.id, productName: product.name, isRead: false, createdAt: Date())
                alerts.insert(alert, at: 0)
                persistence.saveAlerts(alerts)
            }
        }
        if product.stockStatus == .outOfStock {
            let exists = alerts.contains { $0.productId == product.id && $0.type == .outOfStock && !$0.isRead }
            if !exists {
                let alert = InventoryAlert(id: UUID(), title: "Producto Agotado", message: "\(product.name) se ha agotado completamente", type: .outOfStock, priority: .high, productId: product.id, productName: product.name, isRead: false, createdAt: Date())
                alerts.insert(alert, at: 0)
                persistence.saveAlerts(alerts)
            }
        }
        if product.isExpiringSoon {
            let exists = alerts.contains { $0.productId == product.id && $0.type == .expiringSoon && !$0.isRead }
            if !exists {
                let daysLeft = Int((product.expirationDate?.timeIntervalSinceNow ?? 0) / 86400)
                let alert = InventoryAlert(id: UUID(), title: "Por Vencer", message: "\(product.name) vence en \(daysLeft) dias", type: .expiringSoon, priority: .medium, productId: product.id, productName: product.name, isRead: false, createdAt: Date())
                alerts.insert(alert, at: 0)
                persistence.saveAlerts(alerts)
            }
        }
    }

    // MARK: - Refresh

    func refreshData() {
        Task {
            await fetchFromAPI()
        }
    }

    /// Clear all in-memory data (called on logout to prevent stale data from another account)
    func clearData() {
        products = []
        alerts = []
        orders = []
        suppliers = []
        dashboardStats = DashboardStats(totalProducts: 0, lowStockCount: 0, outOfStockCount: 0, totalStockValue: 0, totalSalesToday: 0, totalOrders: 0, expiringCount: 0, activeAlerts: 0)
        error = nil
        isOfflineMode = false
    }

    private func updateStats() {
        dashboardStats = DashboardStats(
            totalProducts: products.count,
            lowStockCount: products.filter { $0.stockStatus == .lowStock }.count,
            outOfStockCount: products.filter { $0.stockStatus == .outOfStock }.count,
            totalStockValue: totalStockValue,
            totalSalesToday: dashboardStats.totalSalesToday,
            totalOrders: orders.count,
            expiringCount: products.filter { $0.isExpiringSoon }.count,
            activeAlerts: alerts.filter { !$0.isRead }.count
        )
    }

    private func logAudit(action: String, entityType: String, entityId: UUID?, entityName: String?, details: String) {
        let event = AuditEvent(userId: UUID(), userName: "Usuario", action: action, entityType: entityType, entityId: entityId, entityName: entityName, details: details)
        persistence.logAuditEvent(event)
    }
}

// MARK: - Scan Result
struct ScannedProductResult {
    var name: String
    var brand: String
    var category: ProductCategory
    var barcode: String
    var suggestedPrice: Double
    var confidence: Double
    var isDuplicate: Bool
    var similarProducts: [Product]
}
