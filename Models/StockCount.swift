import Foundation

// ─────────────────────────────────────────────────────────────────────────────
// StockCount — Sprint 4 (Feature: Conteo Físico de Inventario / Stocktake)
//
// Modela una sesión de conteo físico: el comerciante recorre sus productos y
// registra la cantidad real en estantería. La app reconcilia ese conteo
// contra el stock que tiene registrado el sistema y calcula la discrepancia
// y su impacto monetario.
//
// Estos son los tipos de dominio (value types, `Sendable`). La persistencia
// relacional vive en `Models/LocalDatabase/StockCountSessionEntry` y
// `StockCountItemEntry` (SwiftData). El cómputo concurrente de la
// reconciliación está en `Services/StockCount/StockCountService`.
// ─────────────────────────────────────────────────────────────────────────────

/// Estado de una sesión de conteo.
enum StockCountStatus: String, Codable, Sendable {
    /// El usuario sigue ingresando cantidades.
    case inProgress
    /// El conteo se cerró y se calculó la reconciliación.
    case completed
}

/// Un renglón del conteo: un producto con su cantidad de sistema y la contada.
struct StockCountItem: Identifiable, Hashable, Sendable {
    let id: UUID
    let productId: UUID
    let productName: String
    let category: ProductCategory
    /// Cantidad que el sistema cree que hay.
    let systemQuantity: Int
    /// Cantidad física contada. `nil` mientras el usuario no la registra.
    var countedQuantity: Int?
    /// Costo unitario — usado para valorar la discrepancia.
    let costPrice: Double

    /// Diferencia contada − sistema. Positiva: hay de más; negativa: falta.
    /// `nil` mientras no se cuente.
    var discrepancy: Int? {
        guard let counted = countedQuantity else { return nil }
        return counted - systemQuantity
    }

    /// Impacto monetario de la discrepancia (en valor de costo).
    var valueImpact: Double {
        guard let diff = discrepancy else { return 0 }
        return Double(diff) * costPrice
    }

    /// `true` si ya fue contado.
    var isCounted: Bool { countedQuantity != nil }

    /// `true` si fue contado y el conteo no coincide con el sistema.
    var hasDiscrepancy: Bool {
        guard let diff = discrepancy else { return false }
        return diff != 0
    }
}

/// Discrepancia agregada para una categoría de productos.
struct CategoryAccuracy: Identifiable, Hashable, Sendable {
    let category: ProductCategory
    let countedItems: Int
    let itemsWithDiscrepancy: Int
    let netUnitDiscrepancy: Int
    let absoluteValueImpact: Double

    var id: String { category.rawValue }

    /// Porcentaje de exactitud: ítems sin discrepancia / ítems contados.
    var accuracyPct: Double {
        guard countedItems > 0 else { return 100 }
        let exact = countedItems - itemsWithDiscrepancy
        return (Double(exact) / Double(countedItems)) * 100
    }
}

/// Resultado de reconciliar una sesión de conteo completa.
struct StockCountSummary: Sendable {
    let totalItems: Int
    let countedItems: Int
    let itemsWithDiscrepancy: Int
    /// Suma de discrepancias en unidades (con signo).
    let netUnitDiscrepancy: Int
    /// Suma del valor absoluto del impacto — cuánta plata "baila".
    let absoluteValueImpact: Double
    let perCategory: [CategoryAccuracy]
    let computedAt: Date
    /// Tiempo de cómputo en ms — evidencia visible del trabajo concurrente.
    let durationMs: Double

    /// Exactitud global del inventario: ítems exactos / ítems contados.
    var overallAccuracyPct: Double {
        guard countedItems > 0 else { return 100 }
        let exact = countedItems - itemsWithDiscrepancy
        return (Double(exact) / Double(countedItems)) * 100
    }

    static let empty = StockCountSummary(
        totalItems: 0, countedItems: 0, itemsWithDiscrepancy: 0,
        netUnitDiscrepancy: 0, absoluteValueImpact: 0, perCategory: [],
        computedAt: Date(), durationMs: 0
    )
}
