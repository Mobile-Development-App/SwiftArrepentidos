import Foundation
import SwiftData

@Model
final class AnalyticsEventSample {
    @Attribute(.unique) var id: UUID
    var kind: String           // raw value of AnalyticsEvent.Kind
    var timestamp: Date
    var attributesJSON: String // [String: String] serialized

    init(id: UUID = UUID(),
         kind: String,
         timestamp: Date = Date(),
         attributesJSON: String = "{}") {
        self.id = id
        self.kind = kind
        self.timestamp = timestamp
        self.attributesJSON = attributesJSON
    }

    var attributes: [String: String] {
        guard let data = attributesJSON.data(using: .utf8),
              let dict = try? JSONDecoder().decode([String: String].self, from: data) else {
            return [:]
        }
        return dict
    }

    var hourOfDay: Int {
        Calendar.current.component(.hour, from: timestamp)
    }
}
