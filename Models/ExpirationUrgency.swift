import SwiftUI

// ─────────────────────────────────────────────────────────────────────────────
// ExpirationUrgency — urgency bucket for BQ4 ("products near expiration and
// what action should we take with them").
// ─────────────────────────────────────────────────────────────────────────────

enum ExpirationUrgency: String, Codable, Hashable, Sendable, CaseIterable {
    case expired      // already past expirationDate
    case critical     // ≤ 7 days
    case warning      // 8–14 days
    case watch        // 15–30 days

    var label: String {
        switch self {
        case .expired:  return "Vencido"
        case .critical: return "Crítico (≤7 días)"
        case .warning:  return "Atención (8–14 días)"
        case .watch:    return "Vigilar (15–30 días)"
        }
    }

    var color: Color {
        switch self {
        case .expired:  return Color(red: 0.55, green: 0.00, blue: 0.00)
        case .critical: return Color(red: 0.91, green: 0.30, blue: 0.24)
        case .warning:  return Color(red: 0.95, green: 0.61, blue: 0.07)
        case .watch:    return Color(red: 0.04, green: 0.52, blue: 1.00)
        }
    }

    var systemIcon: String {
        switch self {
        case .expired:  return "xmark.octagon.fill"
        case .critical: return "exclamationmark.triangle.fill"
        case .warning:  return "clock.badge.exclamationmark"
        case .watch:    return "eye.trianglebadge.exclamationmark"
        }
    }

    static func bucket(for daysRemaining: Int) -> ExpirationUrgency? {
        if daysRemaining < 0 { return .expired }
        if daysRemaining <= 7 { return .critical }
        if daysRemaining <= 14 { return .warning }
        if daysRemaining <= 30 { return .watch }
        return nil
    }
}

/// One of the suggested actions BQ4 can recommend for a product near expiry.
enum ExpirationAction: String, Codable, Hashable, Sendable {
    case sellNow           // promoción / descuento agresivo
    case discount          // descuento moderado
    case relocate          // mover a ubicación visible
    case withdraw          // retirar del inventario
    case monitor           // sólo vigilar

    var label: String {
        switch self {
        case .sellNow:   return "Vender con promoción"
        case .discount:  return "Aplicar descuento"
        case .relocate:  return "Mover a zona visible"
        case .withdraw:  return "Retirar del inventario"
        case .monitor:   return "Vigilar"
        }
    }

    var systemIcon: String {
        switch self {
        case .sellNow:  return "tag.fill"
        case .discount: return "percent"
        case .relocate: return "arrow.up.and.down.and.arrow.left.and.right"
        case .withdraw: return "trash.fill"
        case .monitor:  return "eye"
        }
    }
}

/// One product × its urgency + suggested action + reason string.
struct ExpirationAdvice: Identifiable, Hashable, Sendable {
    let productId: UUID
    let productName: String
    let category: ProductCategory
    let quantity: Int
    let daysRemaining: Int
    let urgency: ExpirationUrgency
    let action: ExpirationAction
    let rationale: String

    var id: UUID { productId }
}

/// Top-level BQ4 dashboard payload.
struct ExpirationInsightsDashboard: Sendable {
    let byUrgency: [ExpirationUrgency: [ExpirationAdvice]]
    let totalAtRisk: Int
    let totalUnitsAtRisk: Int
    let computedAt: Date
    let durationMs: Double

    func advice(for urgency: ExpirationUrgency) -> [ExpirationAdvice] {
        byUrgency[urgency] ?? []
    }
}
