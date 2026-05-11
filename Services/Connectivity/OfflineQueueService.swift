import Foundation
import Combine


actor OfflineQueueService {
    static let shared = OfflineQueueService()

    private let fileName = "offline_queue.json"
    private var items: [QueuedOperation] = []
    private var loaded = false
    private var isDraining = false

    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let fileManager = FileManager.default

    private init() {
        encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
    }

    static func bootstrap(replayHandlers: ReplayHandlers) {
        Task { await shared.configure(replay: replayHandlers) }
    }

    func enqueue(_ op: QueuedOperation) {
        loadIfNeeded()
        // Coalescing en la entrada también: si llega un updateProduct y ya
        // hay un createProduct pendiente para el mismo productId, mergeamos.
        if case .updateProduct(let pid, let newProduct, _) = op,
           let createIdx = items.firstIndex(where: {
               if case .createProduct(_, let p, _) = $0, p.id == pid { return true }
               return false
           }) {
            if case .createProduct(let clientId, _, let createdAt) = items[createIdx] {
                items[createIdx] = .createProduct(clientId: clientId, product: newProduct, enqueuedAt: createdAt)
                persist()
                #if DEBUG
                print("[OfflineQueue] coalesced update into pending create for \(newProduct.name)")
                #endif
                return
            }
        }
        items.append(op)
        persist()
        #if DEBUG
        print("[OfflineQueue] enqueued \(op.description) · depth=\(items.count)")
        #endif
    }

    /// Aplica una edición sobre un producto que todavía no se sincronizó —
    /// es decir, hay una `createProduct` pendiente para `productId`. En vez
    /// de encolar una segunda operación (que daría 404 en el backend porque
    /// el producto no existe aún), reemplazamos el `product` dentro de la
    /// `createProduct` encolada para que cuando drene tenga ya los cambios.
    ///
    /// Caso esquinado: si por alguna razón no encontramos el create pendiente
    /// (debería ser imposible pero igual), encolamos un updateProduct normal
    /// como fallback — peor caso el backend falla y lo reintentamos.
    func coalesceEdit(productId: UUID, newProduct: Product) {
        loadIfNeeded()
        if let idx = items.firstIndex(where: {
            if case .createProduct(_, let p, _) = $0, p.id == productId { return true }
            return false
        }) {
            if case .createProduct(let clientId, _, let createdAt) = items[idx] {
                items[idx] = .createProduct(
                    clientId: clientId,
                    product: newProduct,
                    enqueuedAt: createdAt
                )
                persist()
                #if DEBUG
                print("[OfflineQueue] coalesced edit into pending create for \(newProduct.name)")
                #endif
                return
            }
        }

        // Fallback defensivo
        items.append(.updateProduct(productId: productId, product: newProduct, enqueuedAt: Date()))
        persist()
        #if DEBUG
        print("[OfflineQueue] coalesceEdit: no pending create found — fallback to updateProduct queue entry")
        #endif
    }

    /// Si el usuario borra un producto que todavía está pendiente de
    /// crearse, simplemente removemos la `createProduct` de la cola — no
    /// tiene sentido crearlo en el backend para luego borrarlo.
    /// Devuelve `true` si removió un create pendiente (caller no necesita
    /// encolar un delete).
    func dropPendingCreate(productId: UUID) -> Bool {
        loadIfNeeded()
        let countBefore = items.count
        items.removeAll {
            if case .createProduct(_, let p, _) = $0, p.id == productId { return true }
            return false
        }
        if items.count != countBefore {
            persist()
            #if DEBUG
            print("[OfflineQueue] dropped pending create for product \(productId.uuidString.prefix(8))")
            #endif
            return true
        }
        return false
    }

    func pending() -> [QueuedOperation] {
        loadIfNeeded()
        return items
    }

    func pendingCount() -> Int {
        loadIfNeeded()
        return items.count
    }

    func clear() {
        items.removeAll()
        persist()
    }

    struct ReplayHandlers {
        var createProduct: (Product) async throws -> Product
        var updateProduct: (UUID, Product) async throws -> Product
        var deleteProduct: (UUID) async throws -> Void
    }

    private var handlers: ReplayHandlers?
    private var cancellables: Set<AnyCancellable> = []

    private func configure(replay: ReplayHandlers) {
        self.handlers = replay
        ConnectivityService.shared.onTransition
            .receive(on: DispatchQueue.main)
            .sink { [weak self] online in
                guard online, let self else { return }
                Task { await self.drain() }
            }
            .store(in: &cancellables)
    }

    private func drain() async {
        guard !isDraining, let handlers else { return }
        isDraining = true
        defer { isDraining = false }
        loadIfNeeded()
        guard !items.isEmpty else { return }
        #if DEBUG
        print("[OfflineQueue] draining \(items.count) operation(s)")
        #endif

        var remaining: [QueuedOperation] = []
        var syncedProductIds: [UUID] = []
        for op in items {
            do {
                switch op {
                case .createProduct(_, let product, _):
                    _ = try await handlers.createProduct(product)
                    syncedProductIds.append(product.id)
                case .updateProduct(let id, let product, _):
                    _ = try await handlers.updateProduct(id, product)
                    syncedProductIds.append(product.id)
                case .deleteProduct(let id, _):
                    try await handlers.deleteProduct(id)
                    syncedProductIds.append(id)
                }
            } catch {
                #if DEBUG
                print("[OfflineQueue] replay failed for \(op.description): \(error). Will retry.")
                #endif
                remaining.append(op)
            }
        }
        items = remaining
        persist()

        // Notifica a las view-models para que marquen los productos como
        // `.synced`. El payload es el array de productIds que sí drenaron.
        if !syncedProductIds.isEmpty {
            await MainActor.run {
                NotificationCenter.default.post(
                    name: .inventoryDidSync,
                    object: nil,
                    userInfo: ["syncedProductIds": syncedProductIds]
                )
            }
        }
    }

    private func loadIfNeeded() {
        guard !loaded else { return }
        defer { loaded = true }
        let url = storageURL()
        guard fileManager.fileExists(atPath: url.path) else { return }
        do {
            let data = try Data(contentsOf: url)
            items = try decoder.decode([QueuedOperation].self, from: data)
        } catch {
            #if DEBUG
            print("[OfflineQueue] load failed, resetting: \(error)")
            #endif
            items = []
        }
    }

    private func persist() {
        let url = storageURL()
        do {
            let data = try encoder.encode(items)
            try data.write(to: url, options: .atomic)
        } catch {
            #if DEBUG
            print("[OfflineQueue] persist failed: \(error)")
            #endif
        }
    }

    private func storageURL() -> URL {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        if !fileManager.fileExists(atPath: base.path) {
            try? fileManager.createDirectory(at: base, withIntermediateDirectories: true)
        }
        return base.appendingPathComponent(fileName)
    }
}
