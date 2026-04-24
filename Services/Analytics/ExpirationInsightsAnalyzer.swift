import Foundation



final class ExpirationInsightsAnalyzer {
    static let shared = ExpirationInsightsAnalyzer()
    private init() {}

    /// Produces the BQ4 dashboard. Products without an `expirationDate` or
    /// that are already far from expiring (> 30 days remaining) are excluded
    /// from the output.
    func compute(products: [Product], now: Date = Date()) async -> ExpirationInsightsDashboard {
        let start = Date()

        let advice: [ExpirationAdvice] = await withTaskGroup(
            of: ExpirationAdvice?.self
        ) { group in
            for product in products where product.isActive && product.expirationDate != nil {
                group.addTask(priority: .userInitiated) {
                    Self.adviceFor(product: product, now: now)
                }
            }
            var acc: [ExpirationAdvice] = []
            for await row in group { if let row { acc.append(row) } }
            return acc
        }

        var byUrgency: [ExpirationUrgency: [ExpirationAdvice]] = [:]
        for urgency in ExpirationUrgency.allCases { byUrgency[urgency] = [] }
        for a in advice {
            byUrgency[a.urgency, default: []].append(a)
        }
        // Sort each bucket so the most urgent items appear first.
        for urgency in ExpirationUrgency.allCases {
            byUrgency[urgency] = (byUrgency[urgency] ?? []).sorted { $0.daysRemaining < $1.daysRemaining }
        }

        let totalAtRisk = advice.count
        let totalUnits = advice.reduce(0) { $0 + $1.quantity }

        return ExpirationInsightsDashboard(
            byUrgency: byUrgency,
            totalAtRisk: totalAtRisk,
            totalUnitsAtRisk: totalUnits,
            computedAt: Date(),
            durationMs: Date().timeIntervalSince(start) * 1000
        )
    }

    // MARK: - Decision logic (pure function)

    private static func adviceFor(product: Product, now: Date) -> ExpirationAdvice? {
        guard let expiry = product.expirationDate else { return nil }

        let seconds = expiry.timeIntervalSince(now)
        let daysRemaining = Int((seconds / 86_400).rounded(.towardZero))

        guard let urgency = ExpirationUrgency.bucket(for: daysRemaining) else {
            return nil // > 30 days away — not at risk yet.
        }

        let (action, rationale) = recommend(
            product: product,
            urgency: urgency,
            daysRemaining: daysRemaining
        )

        return ExpirationAdvice(
            productId: product.id,
            productName: product.name,
            category: product.category,
            quantity: product.quantity,
            daysRemaining: daysRemaining,
            urgency: urgency,
            action: action,
            rationale: rationale
        )
    }

    /// Returns the recommended action and a short Spanish rationale. Takes
    /// stock volume and profit margin into account so the recommendation
    /// lines up with the smartAnalysis already surfaced elsewhere in the app.
    private static func recommend(
        product: Product,
        urgency: ExpirationUrgency,
        daysRemaining: Int
    ) -> (ExpirationAction, String) {
        switch urgency {
        case .expired:
            return (
                .withdraw,
                "Ya venció. Retíralo del inventario y registra la merma."
            )

        case .critical:
            if product.quantity == 0 {
                return (
                    .monitor,
                    "Vence en \(daysRemaining) días pero no hay stock. Sólo vigílalo."
                )
            }
            if product.marginHealth == .loss {
                return (
                    .sellNow,
                    "Vence en \(daysRemaining) días y se vende bajo costo. Liquídalo con promoción fuerte para recuperar caja."
                )
            }
            return (
                .sellNow,
                "Vence en \(daysRemaining) días. Prioriza su venta con promoción o descuento agresivo."
            )

        case .warning:
            if product.quantity > product.minStock * 2 {
                return (
                    .discount,
                    "\(product.quantity) uds con \(daysRemaining) días restantes. Aplica descuento para acelerar rotación."
                )
            }
            return (
                .relocate,
                "Vence en \(daysRemaining) días. Muévelo a la zona más visible y comunica descuento suave."
            )

        case .watch:
            if product.stockTrend == .up {
                return (
                    .relocate,
                    "Stock alto (\(product.quantity) uds) y \(daysRemaining) días de vida. Adelanta su rotación ubicándolo al frente."
                )
            }
            return (
                .monitor,
                "\(daysRemaining) días de vida. Sigue su movimiento semanalmente antes de tomar acción."
            )
        }
    }
}
