import Foundation

// ─────────────────────────────────────────────────────────────────────────────
// UsageEvent — append-only log of user interactions used by Sprint 3 BQs.
//
// Stored locally (never leaves the device) so the BQs keep working offline
// and so we don't leak PII to the backend.
// ─────────────────────────────────────────────────────────────────────────────

/// One datapoint in the local usage log. Immutable once created.
struct UsageEvent: Codable, Identifiable, Hashable {
    let id: UUID
    let kind: Kind
    let timestamp: Date
    /// Free-form payload. Callers put small primitives here (productId, screen
    /// name, durationMs). Kept as `[String: String]` so the codec stays cheap.
    let attributes: [String: String]

    enum Kind: String, Codable, CaseIterable {
        /// User added a product (any entry-point — form, scan, import).
        case productCreated
        /// User navigated to a screen. `attributes["screen"]` carries the name.
        case screenViewed
        /// User ran a barcode scan. `attributes["success"]` is "1" / "0".
        case scanCompleted
    }

    init(kind: Kind, timestamp: Date = Date(), attributes: [String: String] = [:]) {
        self.id = UUID()
        self.kind = kind
        self.timestamp = timestamp
        self.attributes = attributes
    }

    /// Hour of day (0–23) the event occurred in, using the device's current
    /// calendar. Used by BQ6 to bucket activity.
    var hourOfDay: Int {
        Calendar.current.component(.hour, from: timestamp)
    }
}
