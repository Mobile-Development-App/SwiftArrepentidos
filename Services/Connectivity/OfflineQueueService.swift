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
        items.append(op)
        persist()
        #if DEBUG
        print("[OfflineQueue] enqueued \(op.description) · depth=\(items.count)")
        #endif
    }

    func pending() -> [QueuedOperation] {
        loadIfNeeded()
        return items
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
        for op in items {
            do {
                switch op {
                case .createProduct(_, let product, _):
                    _ = try await handlers.createProduct(product)
                case .updateProduct(let id, let product, _):
                    _ = try await handlers.updateProduct(id, product)
                case .deleteProduct(let id, _):
                    try await handlers.deleteProduct(id)
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
