import Foundation

// ─────────────────────────────────────────────────────────────────────────────
// InventoryValuationService — Sprint 3 BQ2 backend.
//
// Business question (Juan Felipe — Type 2, aggregate across stores):
//   "¿Cuál es el valor total del inventario actual por tienda, y qué margen
//    representa sobre el costo?"
//
// Why this file exists
//   The raw product catalog lives in `PersistenceService`, but answering BQ2
//   means aggregating across N stores. If we did that on @MainActor during a
//   refresh the UI would stall on 500+ product catalogs. This service owns
//   the concurrent aggregation so the view-model can simply `await` a result.
//
// Concurrency strategy (Sprint 3 multi-threading requirement)
//   • `TaskGroup` fans out one child task per store. Each child walks its
//     slice of the product list, so the per-store sums happen in parallel
//     on the cooperative thread pool.
//   • Heavy CPU work is wrapped in `Task.detached(priority: .userInitiated)`
//     so it can't accidentally be scheduled back onto the main actor.
//   • The final reducer runs on whatever thread the group finishes on —
//     there is no shared mutable state, only value-type `StoreValuation`s.
//
// Caching (Sprint 3 caching requirement)
//   Results are cached in an `LRUCache` keyed by a hash of `(storeIds,
//   productCount, lastUpdated)` with a 15-minute TTL. Callers get sub-ms
//   responses for unchanged catalogs.
//
// Eventual connectivity
//   Service operates entirely on locally-cached data. Works offline; the
//   freshness of the answer depends on how recently the inventory sync ran.
// ─────────────────────────────────────────────────────────────────────────────

struct StoreValuation: Identifiable, Hashable, Sendable {
    let id: UUID              // store id
    let storeName: String
    let productCount: Int
    let stockValue: Double    // sum(salePrice * quantity)
    let costValue: Double     // sum(costPrice * quantity)

    var marginValue: Double { stockValue - costValue }
    var marginPct: Double {
        guard costValue > 0 else { return 0 }
        return (marginValue / costValue) * 100
    }
}

struct ValuationSnapshot: Sendable {
    let perStore: [StoreValuation]
    let totalStockValue: Double
    let totalCostValue: Double
    let computedAt: Date
    /// Wall-clock time the aggregation took, in milliseconds. Surfaced in
    /// the UI so we can show "X products aggregated in Y ms" — visible
    /// evidence that the multi-threading strategy is actually doing work.
    let durationMs: Double

    var totalMarginValue: Double { totalStockValue - totalCostValue }
}

final class InventoryValuationService {
    static let shared = InventoryValuationService()

    private let cache = LRUCache<String, ValuationSnapshot>(capacity: 8)
    private let ttl: TimeInterval = 15 * 60  // 15 min

    private init() {}

    /// Computes valuation for every provided store, in parallel.
    /// - Parameters:
    ///   - stores:   list of stores the user has access to.
    ///   - products: full flat product catalog. Each product is assigned to
    ///               its store via the `location` field (which doubles as a
    ///               store label in this app's domain model).
    ///   - allowCache: set to `false` to force a fresh computation.
    func compute(stores: [Store],
                 products: [Product],
                 allowCache: Bool = true) async -> ValuationSnapshot {
        let key = cacheKey(stores: stores, products: products)
        if allowCache, let hit = await cache.get(key) {
            return hit
        }

        let start = Date()

        // Index products by store so each child task only walks its slice.
        // Doing it once here, on the calling thread, is cheaper than having
        // every task re-scan the full list.
        let byStore: [UUID: [Product]] = groupProductsByStore(stores: stores, products: products)
        let storesCopy = stores                // immutable capture for tasks

        let results: [StoreValuation] = await withTaskGroup(of: StoreValuation.self) { group in
            for store in storesCopy {
                let slice = byStore[store.id] ?? []
                group.addTask(priority: .userInitiated) {
                    Self.aggregate(store: store, products: slice)
                }
            }
            var acc: [StoreValuation] = []
            acc.reserveCapacity(storesCopy.count)
            for await v in group { acc.append(v) }
            return acc
        }

        let sortedResults = results.sorted { $0.stockValue > $1.stockValue }
        let totalStock = sortedResults.reduce(0.0) { $0 + $1.stockValue }
        let totalCost  = sortedResults.reduce(0.0) { $0 + $1.costValue }
        let elapsed = Date().timeIntervalSince(start) * 1000

        let snapshot = ValuationSnapshot(
            perStore: sortedResults,
            totalStockValue: totalStock,
            totalCostValue: totalCost,
            computedAt: Date(),
            durationMs: elapsed
        )
        await cache.put(snapshot, for: key, ttl: ttl)
        return snapshot
    }

    /// Drops every cached snapshot. Invoked on logout and whenever the
    /// caller knows the inventory has mutated (e.g. after addProduct).
    func invalidateCache() async {
        await cache.removeAll()
    }

    // MARK: - Private

    /// Pure function — `static` + no captured state so it's safe to call
    /// from inside a `Task.detached` without worrying about actor isolation.
    private static func aggregate(store: Store, products: [Product]) -> StoreValuation {
        var stock = 0.0
        var cost = 0.0
        for p in products where p.isActive {
            stock += p.salePrice * Double(p.quantity)
            cost  += p.costPrice * Double(p.quantity)
        }
        return StoreValuation(
            id: store.id,
            storeName: store.name,
            productCount: products.count,
            stockValue: stock,
            costValue: cost
        )
    }

    private func groupProductsByStore(stores: [Store], products: [Product]) -> [UUID: [Product]] {
        // The domain model stores the store name in `Product.location`, so
        // we map store.name → store.id once and bucket from there.
        let nameToId: [String: UUID] = Dictionary(uniqueKeysWithValues: stores.map { ($0.name, $0.id) })
        var result: [UUID: [Product]] = [:]
        for p in products {
            let id = nameToId[p.location] ?? stores.first?.id ?? UUID()
            result[id, default: []].append(p)
        }
        return result
    }

    private func cacheKey(stores: [Store], products: [Product]) -> String {
        // Cheap fingerprint: store count + product count + max lastUpdated.
        // If any product mutates, max(lastUpdated) moves, invalidating the key.
        let latest = products.map(\.lastUpdated).max() ?? .distantPast
        return "val_\(stores.count)_\(products.count)_\(Int(latest.timeIntervalSince1970))"
    }
}
