import SwiftUI

// ─────────────────────────────────────────────────────────────────────────────
// ProductInsights — per-product classifiers and smart analysis used by the
// Sprint 3 BQ cards. Mirrors the Flutter `MarginHealth` / `StockTrend` /
// `SmartProductAnalysis` types but lives as a Product extension so we don't
// touch the core model.
// ─────────────────────────────────────────────────────────────────────────────

enum MarginHealth: String, Codable, Hashable, Sendable {
    case loss
    case low
    case medium
    case high

    var label: String {
        switch self {
        case .loss:   return "Pérdida"
        case .low:    return "Margen bajo"
        case .medium: return "Margen medio"
        case .high:   return "Margen alto"
        }
    }

    var color: Color {
        switch self {
        case .loss:   return Color(red: 0.91, green: 0.30, blue: 0.24)
        case .low:    return Color(red: 0.95, green: 0.61, blue: 0.07)
        case .medium: return Color(red: 0.04, green: 0.52, blue: 1.00)
        case .high:   return Color(red: 0.18, green: 0.80, blue: 0.44)
        }
    }

    var systemIcon: String {
        switch self {
        case .loss:   return "arrow.down.right.circle.fill"
        case .low:    return "exclamationmark.triangle.fill"
        case .medium: return "chart.line.uptrend.xyaxis"
        case .high:   return "arrow.up.right.circle.fill"
        }
    }
}

enum StockTrend: String, Codable, Hashable, Sendable {
    case down
    case stable
    case up

    var label: String {
        switch self {
        case .down:   return "Baja"
        case .stable: return "Estable"
        case .up:     return "Alta"
        }
    }

    var color: Color {
        switch self {
        case .down:   return Color(red: 0.91, green: 0.30, blue: 0.24)
        case .stable: return Color(red: 0.04, green: 0.52, blue: 1.00)
        case .up:     return Color(red: 0.18, green: 0.80, blue: 0.44)
        }
    }

    var systemIcon: String {
        switch self {
        case .down:   return "arrow.down"
        case .stable: return "minus"
        case .up:     return "arrow.up"
        }
    }
}

struct SmartProductAnalysis: Hashable, Sendable {
    let marginHealth: MarginHealth
    let stockTrend: StockTrend
    let headline: String
    let message: String
}

// MARK: - Product extensions

extension Product {
    var markupPercentage: Double {
        salePrice > 0 ? ((salePrice - costPrice) / salePrice) * 100 : 0
    }

    var profitPerUnit: Double { salePrice - costPrice }
    var profitValue: Double   { profitPerUnit * Double(quantity) }

    var stockCoverageRatio: Double {
        minStock <= 0 ? Double(quantity) : Double(quantity) / Double(minStock)
    }

    var marginHealth: MarginHealth {
        if profitPerUnit < 0    { return .loss }
        if profitMargin < 10    { return .low }
        if profitMargin < 25    { return .medium }
        return .high
    }

    var stockTrend: StockTrend {
        if quantity <= 0 || quantity <= minStock { return .down }
        if stockCoverageRatio >= 2.5             { return .up }
        return .stable
    }

    /// Spanish-language automatic recommendation for a single product, taking
    /// both margin and stock trend into account.
    var smartAnalysis: SmartProductAnalysis {
        if marginHealth == .loss {
            return SmartProductAnalysis(
                marginHealth: .loss,
                stockTrend: .down,
                headline: "Venta con pérdida",
                message: "El precio de venta está por debajo del costo. Ajusta el precio antes de reponer."
            )
        }
        if stockTrend == .down && marginHealth == .high {
            return SmartProductAnalysis(
                marginHealth: marginHealth,
                stockTrend: stockTrend,
                headline: "Alta demanda detectada",
                message: "Buen margen, pero el stock está cerca del mínimo. Conviene reabastecer pronto."
            )
        }
        if stockTrend == .down {
            return SmartProductAnalysis(
                marginHealth: marginHealth,
                stockTrend: stockTrend,
                headline: "Riesgo de quiebre",
                message: "El inventario va a la baja. Revisa compras o sube el stock mínimo para evitar faltantes."
            )
        }
        if marginHealth == .low {
            return SmartProductAnalysis(
                marginHealth: marginHealth,
                stockTrend: stockTrend,
                headline: "Margen ajustado",
                message: "Se vende con utilidad baja. Evalúa precio, costo o promociones para mejorar rentabilidad."
            )
        }
        if stockTrend == .up && marginHealth == .high {
            return SmartProductAnalysis(
                marginHealth: marginHealth,
                stockTrend: stockTrend,
                headline: "Producto saludable",
                message: "Tiene buen margen y stock suficiente. Es un producto estable para priorizar."
            )
        }
        return SmartProductAnalysis(
            marginHealth: marginHealth,
            stockTrend: stockTrend,
            headline: "Desempeño estable",
            message: "El producto mantiene un equilibrio razonable entre margen y disponibilidad."
        )
    }
}
