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
    // FIX: Local Storage (UserDefaults) — persistimos el último filtro y
    // categoría seleccionados para que el usuario no tenga que reconfigurar
    // su vista cada vez que abre la app. Usamos `didSet` con un guard de
    // `loadingPreferences` para evitar escrituras durante el restore.
    @Published var selectedFilter: StockFilter = .all {
        didSet {
            guard !loadingPreferences else { return }
            UserDefaults.standard.set(selectedFilter.rawValue, forKey: Self.inventoryFilterKey)
        }
    }
    @Published var selectedCategory: ProductCategory? {
        didSet {
            guard !loadingPreferences else { return }
            if let cat = selectedCategory {
                UserDefaults.standard.set(cat.rawValue, forKey: Self.inventoryCategoryKey)
            } else {
                UserDefaults.standard.removeObject(forKey: Self.inventoryCategoryKey)
            }
        }
    }
    private var loadingPreferences = false
    private static let inventoryFilterKey = "inventory.selectedFilter"
    private static let inventoryCategoryKey = "inventory.selectedCategory"

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
    private var syncObserver: Any?
    private var cancellables: Set<AnyCancellable> = []

    // MARK: - Sprint 4 micro-optimization: folded-string cache
    //
    // El search del catálogo llamaba `localizedCaseInsensitiveContains` 4
    // veces por producto, por cada keystroke. Esa función hace folding
    // case + diacritic en CADA invocación, y es la parte cara del filtro.
    // Cacheamos la versión folded de los campos (name/sku/category.rawValue)
    // por hashValue del string original; los productos rara vez cambian de
    // nombre, así que los hits son muy altos en estado estable.
    private var foldedCache: [Int: String] = [:]
    private let foldedCacheCap = 1024

    /// Devuelve la versión "case + diacritic insensitive" de `s`, cacheando
    /// el resultado. Cap en 1024 entradas: si se excede, se vacía completo
    /// (LRU sería overkill para este uso).
    private func folded(_ s: String) -> String {
        let key = s.hashValue
        if let v = foldedCache[key] { return v }
        if foldedCache.count >= foldedCacheCap {
            foldedCache.removeAll(keepingCapacity: true)
        }
        let f = s.folding(
            options: [.caseInsensitive, .diacriticInsensitive],
            locale: nil
        )
        foldedCache[key] = f
        return f
    }

    enum StockFilter: String, CaseIterable {
        case all = "Todos"
        case inStock = "En Stock"
        case lowStock = "Stock Bajo"
        case outOfStock = "Agotado"
        case expiring = "Por Vencer"
    }

    init() {
        // FIX: Local Storage (UserDefaults) — restauramos preferencias del
        // usuario ANTES de exponer cualquier @Published para evitar
        // notificaciones espurias a SwiftUI.
        loadingPreferences = true
        if let raw = UserDefaults.standard.string(forKey: Self.inventoryFilterKey),
           let filter = StockFilter(rawValue: raw) {
            selectedFilter = filter
        }
        if let raw = UserDefaults.standard.string(forKey: Self.inventoryCategoryKey),
           let cat = ProductCategory(rawValue: raw) {
            selectedCategory = cat
        }
        loadingPreferences = false

        // Don't load data here — storeId may not be available yet.
        // Data is loaded when MainTabView appears (after login).
        logoutObserver = NotificationCenter.default.addObserver(
            forName: .userDidLogout, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.clearData() }
        }
        // Cuando la cola offline drena exitosamente, marca los productos
        // que entraron como `.synced` para que la UI quite el badge "⏳".
        syncObserver = NotificationCenter.default.addObserver(
            forName: .inventoryDidSync, object: nil, queue: .main
        ) { [weak self] note in
            guard let ids = note.userInfo?["syncedProductIds"] as? [UUID] else { return }
            Task { @MainActor in self?.markProductsSynced(ids: ids) }
        }

        // Belt-and-suspenders del auto-sync. `OfflineQueueService` ya escucha
        // `onTransition` y dispara su propio `drain` apenas vuelve la red.
        // Aquí agregamos un SEGUNDO trigger explícito 1.5s después de la
        // transición, por si la primera pasada del replay falló y/o si la
        // suscripción del store nunca llegó a configurarse (p.ej. después de
        // un cold start con la cola ya cargada). `flushNow` es idempotente:
        // si la cola está vacía, no hace nada.
        ConnectivityService.shared.onTransition
            .filter { $0 }
            .receive(on: DispatchQueue.main)
            .sink { _ in
                Task {
                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                    await OfflineQueueService.shared.flushNow()
                }
            }
            .store(in: &cancellables)
    }

    deinit {
        if let observer = logoutObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = syncObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    /// Actualiza el `syncStatus` de los productos cuyos IDs vienen en `ids`
    /// a `.synced`. Llamado desde el observer de `inventoryDidSync` cuando
    /// la cola offline drena.
    private func markProductsSynced(ids: [UUID]) {
        var changed = false
        for id in ids {
            if let i = products.firstIndex(where: { $0.id == id }),
               products[i].syncStatus != .synced {
                products[i].syncStatus = .synced
                changed = true
            }
        }
        if changed {
            persistence.saveProducts(products)
            updateStats()
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
            // Sprint 4 micro-optimization: foldeamos el needle UNA vez por
            // keystroke (vs 4 veces × N productos como antes) y usamos
            // `contains` plano sobre los campos ya folded y cacheados.
            // En un catálogo de 200 productos: ~600 invocaciones caras → 1.
            let needle = searchText.folding(
                options: [.caseInsensitive, .diacriticInsensitive],
                locale: nil
            )
            result = result.filter { p in
                folded(p.name).contains(needle) ||
                folded(p.sku).contains(needle) ||
                p.barcode.contains(searchText) ||
                folded(p.category.rawValue).contains(needle)
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
        // Marca el syncStatus de entrada según conectividad: si estamos
        // offline arranca como pendingCreate y se va a la cola; si estamos
        // online queda pendingUpdate hasta que el backend confirme.
        var local = product
        local.syncStatus = ConnectivityService.shared.isOnline ? .pendingUpdate : .pendingCreate
        local.lastUpdated = Date()
        products.append(local)
        persistence.saveProducts(products)
        generateAlerts(for: local)
        updateStats()
        HapticManager.notification(.success)

        Task.detached(priority: .utility) {
            await UsageTrackingService.shared.record(
                kind: .productCreated,
                attributes: [
                    "productId": local.id.uuidString,
                    "category": local.category.rawValue,
                    "location": local.location
                ]
            )
        }

        // Disparamos inventoryDidChange inmediatamente para que analytics refresque
        NotificationCenter.default.post(name: .inventoryDidChange, object: nil)

        Task {
            if await !ConnectivityService.shared.isOnline {
                //offline path: encolar y asumir éxito local.
                //cuando vuelva la conexión offlineQueueService ejecutará el createProduct real.
                await OfflineQueueService.shared.enqueue(
                    .createProduct(clientId: UUID(), product: local, enqueuedAt: Date())
                )
                return
            }
            do {
                let token = await PipelineLogger.shared.start(.storage)
                let created = try await productRepo.createProduct(local)
                await PipelineLogger.shared.end(token)

                if let index = products.firstIndex(where: { $0.id == local.id }) {
                    var fresh = created
                    fresh.syncStatus = .synced
                    products[index] = fresh
                    persistence.saveProducts(products)
                }
                NotificationCenter.default.post(name: .inventoryDidChange, object: nil)
            } catch {
                #if DEBUG
                print("[InventoryVM] create backend failed: \(error) — enqueuing for replay")
                #endif
                // Falló online: el producto pasa a pendingCreate y se encola
                if let index = products.firstIndex(where: { $0.id == local.id }) {
                    products[index].syncStatus = .pendingCreate
                    persistence.saveProducts(products)
                }
                await OfflineQueueService.shared.enqueue(
                    .createProduct(clientId: UUID(), product: local, enqueuedAt: Date())
                )
            }
        }

        logAudit(action: "Producto Agregado", entityType: "Product", entityId: local.id, entityName: local.name, details: "SKU: \(local.sku), Cantidad: \(local.quantity)")
    }

    func updateProduct(_ product: Product) {
        guard let index = products.firstIndex(where: { $0.id == product.id }) else { return }
        let oldProduct = products[index]

        // Optimistic update: cambios visibles inmediatamente. Si el producto
        // todavía no se sincronizó (pendingCreate), conserva ese estado en
        // memoria — la edición se mergeará con la operación encolada.
        var updated = product
        if oldProduct.syncStatus == .pendingCreate {
            updated.syncStatus = .pendingCreate
        } else if !ConnectivityService.shared.isOnline {
            updated.syncStatus = .pendingUpdate
        }
        updated.lastUpdated = Date()
        products[index] = updated
        persistence.saveProducts(products)
        generateAlerts(for: updated)
        updateStats()

        // Analytics refresca inmediatamente con el cambio local
        NotificationCenter.default.post(name: .inventoryDidChange, object: nil)

        Task {
            // CASO 1: el producto aún no existe en el backend (creado offline
            // y todavía sin sincronizar). NO hacemos PATCH — eso daría 404.
            // Le decimos al `OfflineQueueService` que mergee este edit con
            // la `createProduct` ya encolada.
            if oldProduct.syncStatus == .pendingCreate {
                await OfflineQueueService.shared.coalesceEdit(
                    productId: updated.id,
                    newProduct: updated
                )
                await MainActor.run {
                    self.error = "Cambios guardados localmente. Sincronizaremos al volver online."
                }
                return
            }

            // CASO 2: estamos offline pero el producto sí existe en el backend.
            // Encolamos un updateProduct para drenar cuando vuelva la red.
            if !ConnectivityService.shared.isOnline {
                await OfflineQueueService.shared.enqueue(
                    .updateProduct(productId: updated.id, product: updated, enqueuedAt: Date())
                )
                await MainActor.run {
                    self.error = "Cambios guardados localmente. Sincronizaremos al volver online."
                }
                return
            }

            // CASO 3: estamos online y el producto está en el backend → PATCH
            // directo. Marcamos pendingUpdate hasta que la respuesta confirme.
            let token = await PipelineLogger.shared.start(.storage)
            do {
                let synced = try await productRepo.updateProduct(id: updated.id.apiString, updated)
                await PipelineLogger.shared.end(token)
                await MainActor.run {
                    if let i = self.products.firstIndex(where: { $0.id == synced.id }) {
                        var fresh = synced
                        fresh.syncStatus = .synced
                        self.products[i] = fresh
                        self.persistence.saveProducts(self.products)
                    }
                }
                NotificationCenter.default.post(name: .inventoryDidChange, object: nil)
            } catch {
                #if DEBUG
                print("[InventoryVM] Update backend failed: \(error) — queued for replay")
                #endif
                await OfflineQueueService.shared.enqueue(
                    .updateProduct(productId: updated.id, product: updated, enqueuedAt: Date())
                )
                await MainActor.run {
                    self.error = "Cambios guardados localmente. Reintentaremos en segundo plano."
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
            // CASO 1: el producto nunca llegó al backend (pendingCreate). En
            // vez de encolar una delete que daría 404, simplemente removemos
            // la `createProduct` pendiente de la cola.
            if product.syncStatus == .pendingCreate {
                let removed = await OfflineQueueService.shared.dropPendingCreate(productId: product.id)
                if removed { return }
            }

            // CASO 2: offline — encolar el delete para drenar después.
            if await !ConnectivityService.shared.isOnline {
                await OfflineQueueService.shared.enqueue(
                    .deleteProduct(productId: product.id, enqueuedAt: Date())
                )
                return
            }

            // CASO 3: online — intentar delete directo.
            do {
                try await productRepo.deleteProduct(id: product.id.apiString)
                NotificationCenter.default.post(name: .inventoryDidChange, object: nil)
            } catch {
                #if DEBUG
                print("[InventoryVM] ⚠️ Delete backend failed: \(error) — queued for replay")
                #endif
                await OfflineQueueService.shared.enqueue(
                    .deleteProduct(productId: product.id, enqueuedAt: Date())
                )
                await MainActor.run {
                    self.error = "Eliminado localmente. Reintentaremos al volver online."
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
