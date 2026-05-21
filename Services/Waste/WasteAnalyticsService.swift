import Foundation


/// Wrapper de referencia para guardar `WasteReport` (struct) en `NSCache`.
private final class CachedWasteReport {
    let report: WasteReport
    let cachedAt: Date
    init(_ report: WasteReport) {
        self.report = report
        self.cachedAt = Date()
    }
}

final class WasteAnalyticsService {

    static let shared = WasteAnalyticsService()

    // Caching — capa de memoria con countLimit explícito.
    private let cache: NSCache<NSString, CachedWasteReport> = {
        let c = NSCache<NSString, CachedWasteReport>()
        c.countLimit = 16          // pocas ventanas distintas (7/30/90 días)
        c.name = "waste.report"
        return c
    }()

    /// TTL de respaldo. Aunque el fingerprint coincida, un reporte más viejo
    /// que esto se recomputa.
    private let ttl: TimeInterval = 5 * 60

    private init() {}

    func report(events: [WasteEvent], windowDays: Int) async -> WasteReport {
        let key = fingerprint(events: events, windowDays: windowDays) as NSString

        // Cache hit (con chequeo de TTL).
        if let cached = cache.object(forKey: key),
           Date().timeIntervalSince(cached.cachedAt) < ttl {
            // Marcamos `fromCache: true` para que la UI lo evidencie.
            let r = cached.report
            return WasteReport(
                totalEvents: r.totalEvents, totalUnitsLost: r.totalUnitsLost,
                totalValueLost: r.totalValueLost, byCategory: r.byCategory,
                byReason: r.byReason, windowDays: r.windowDays,
                computedAt: r.computedAt, durationMs: 0, fromCache: true
            )
        }

        // Cache miss -> cómputo concurrente fuera del main.
        let computed = await Task.detached(priority: .userInitiated) {
            Self.compute(events: events, windowDays: windowDays)
        }.value

        cache.setObject(CachedWasteReport(computed), forKey: key)
        return computed
    }

    /// Invalida la caché. Lo llama el view-model cuando se registra una
    /// merma nueva, para que el siguiente `report` sea fresco.
    func invalidate() {
        cache.removeAllObjects()
    }

    /// Huella barata del contenido: si cambia el número de eventos o el
    /// último timestamp, la key cambia y la caché deja de hacer hit.
    private func fingerprint(events: [WasteEvent], windowDays: Int) -> String {
        let latest = events.map(\.recordedAt).max() ?? .distantPast
        return "waste_\(windowDays)_\(events.count)_\(Int(latest.timeIntervalSince1970))"
    }

    /// Función pura — `static`, sin estado capturado — segura para correr en
    /// el `Task.detached`.
    private static func compute(events allEvents: [WasteEvent],
                                windowDays: Int) -> WasteReport {
        let start = Date()
        let cutoff = Date().addingTimeInterval(-Double(windowDays) * 86_400)
        let events = allEvents.filter { $0.recordedAt >= cutoff }

        // Agregación por categoría.
        var catMap: [ProductCategory: (events: Int, units: Int, value: Double)] = [:]
        for e in events {
            var agg = catMap[e.category] ?? (0, 0, 0)
            agg.events += 1
            agg.units += e.quantity
            agg.value += e.valueLost
            catMap[e.category] = agg
        }
        let byCategory = catMap
            .map { WasteCategoryBreakdown(category: $0.key, events: $0.value.events,
                                          unitsLost: $0.value.units, valueLost: $0.value.value) }
            .sorted { $0.valueLost > $1.valueLost }

        // Agregación por causa.
        var reasonMap: [WasteReason: (events: Int, units: Int, value: Double)] = [:]
        for e in events {
            var agg = reasonMap[e.reason] ?? (0, 0, 0)
            agg.events += 1
            agg.units += e.quantity
            agg.value += e.valueLost
            reasonMap[e.reason] = agg
        }
        let byReason = reasonMap
            .map { WasteReasonBreakdown(reason: $0.key, events: $0.value.events,
                                        unitsLost: $0.value.units, valueLost: $0.value.value) }
            .sorted { $0.valueLost > $1.valueLost }

        let totalUnits = events.reduce(0) { $0 + $1.quantity }
        let totalValue = events.reduce(0.0) { $0 + $1.valueLost }
        let elapsed = Date().timeIntervalSince(start) * 1000

        return WasteReport(
            totalEvents: events.count,
            totalUnitsLost: totalUnits,
            totalValueLost: totalValue,
            byCategory: byCategory,
            byReason: byReason,
            windowDays: windowDays,
            computedAt: Date(),
            durationMs: elapsed,
            fromCache: false
        )
    }
}
