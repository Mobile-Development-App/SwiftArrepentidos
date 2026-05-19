import Foundation

// ─────────────────────────────────────────────────────────────────────────────
// StockCountService — Sprint 4. Motor de reconciliación del conteo físico.
//
// Multithreading strategy (feature de Juan Felipe)
// ────────────────────────────────────────────────
// Reconciliar un conteo significa, para cada categoría, agregar las
// discrepancias de todos sus productos. Con catálogos grandes esto es
// CPU-bound. La estrategia:
//
//   • `withTaskGroup` fan-out: un child task por categoría. Cada task
//     recorre su slice de ítems y produce un `CategoryAccuracy`.
//   • Cada child corre a `priority: .userInitiated` en el cooperative
//     thread pool — fuera del @MainActor.
//   • La función de agregación `accuracyFor` es `static` y pura (sin estado
//     capturado), así es segura de ejecutar dentro del task group.
//   • El fan-in (`for await`) reúne los resultados; el reducer final corre
//     en el thread donde termine el grupo, sin estado mutable compartido.
//
// Se mide `durationMs` y se expone en `StockCountSummary` para tener
// evidencia visible en la UI de que el cómputo concurrente trabaja.
//
// Eventual connectivity
// ─────────────────────
// Opera 100% sobre datos locales (los ítems del conteo, ya en SwiftData).
// No toca red — el conteo físico funciona en modo avión sin degradación.
// ─────────────────────────────────────────────────────────────────────────────

enum StockCountService {

    /// Reconciliación concurrente de una sesión de conteo.
    ///
    /// - Parameter items: renglones del conteo (idealmente ya con
    ///   `countedQuantity` registrada; los no contados se ignoran en los
    ///   agregados de exactitud).
    /// - Returns: el `StockCountSummary` con totales y desglose por categoría.
    static func reconcile(items: [StockCountItem]) async -> StockCountSummary {
        let start = Date()

        // Indexamos por categoría una sola vez, en el thread del caller —
        // más barato que tener cada child re-escaneando la lista completa.
        let byCategory: [ProductCategory: [StockCountItem]] =
            Dictionary(grouping: items, by: \.category)

        // Fan-out: un child task por categoría.
        let perCategory: [CategoryAccuracy] = await withTaskGroup(
            of: CategoryAccuracy?.self
        ) { group in
            for (category, slice) in byCategory {
                group.addTask(priority: .userInitiated) {
                    Self.accuracyFor(category: category, items: slice)
                }
            }
            // Fan-in.
            var acc: [CategoryAccuracy] = []
            acc.reserveCapacity(byCategory.count)
            for await row in group {
                if let row { acc.append(row) }
            }
            return acc
        }

        // Reducer final — sólo value types, sin estado compartido.
        let sorted = perCategory.sorted { $0.absoluteValueImpact > $1.absoluteValueImpact }
        let counted = items.filter { $0.isCounted }
        let withDiscrepancy = counted.filter { $0.hasDiscrepancy }
        let netUnits = counted.reduce(0) { $0 + ($1.discrepancy ?? 0) }
        let absImpact = counted.reduce(0.0) { $0 + abs($1.valueImpact) }
        let elapsed = Date().timeIntervalSince(start) * 1000

        return StockCountSummary(
            totalItems: items.count,
            countedItems: counted.count,
            itemsWithDiscrepancy: withDiscrepancy.count,
            netUnitDiscrepancy: netUnits,
            absoluteValueImpact: absImpact,
            perCategory: sorted,
            computedAt: Date(),
            durationMs: elapsed
        )
    }

    // MARK: - Pure aggregation

    /// Función pura — `static`, sin estado capturado — segura para correr
    /// dentro de un child task del `withTaskGroup`. Sólo cuenta los ítems
    /// que ya fueron contados; los pendientes no afectan la exactitud.
    private static func accuracyFor(category: ProductCategory,
                                    items: [StockCountItem]) -> CategoryAccuracy? {
        let counted = items.filter { $0.isCounted }
        guard !counted.isEmpty else { return nil }

        let withDiscrepancy = counted.filter { $0.hasDiscrepancy }
        let netUnits = counted.reduce(0) { $0 + ($1.discrepancy ?? 0) }
        let absImpact = counted.reduce(0.0) { $0 + abs($1.valueImpact) }

        return CategoryAccuracy(
            category: category,
            countedItems: counted.count,
            itemsWithDiscrepancy: withDiscrepancy.count,
            netUnitDiscrepancy: netUnits,
            absoluteValueImpact: absImpact
        )
    }
}
