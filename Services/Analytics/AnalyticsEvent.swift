import Foundation

struct AnalyticsEvent: Codable, Identifiable, Hashable {
    let id: UUID
    let kind: Kind
    let timestamp: Date
    let attributes: [String: String]

    enum Kind: String, Codable, CaseIterable {
        case screenViewed

        case scanAttempt

        case featureAccessed
    }

    init(kind: Kind, timestamp: Date = Date(), attributes: [String: String] = [:]) {
        self.id = UUID()
        self.kind = kind
        self.timestamp = timestamp
        self.attributes = attributes
    }

    var hourOfDay: Int { Calendar.current.component(.hour, from: timestamp) }

    var isoWeek: Int {
        Calendar.current.component(.weekOfYear, from: timestamp)
    }
}
