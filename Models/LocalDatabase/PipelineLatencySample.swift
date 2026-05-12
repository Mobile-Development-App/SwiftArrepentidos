import Foundation
import SwiftData



@Model
final class PipelineLatencySample {
    @Attribute(.unique) var id: UUID
    var stage: String         // raw value of LatencySample.Stage
    var durationMs: Double
    var timestamp: Date

    init(id: UUID = UUID(),
         stage: String,
         durationMs: Double,
         timestamp: Date = Date()) {
        self.id = id
        self.stage = stage
        self.durationMs = durationMs
        self.timestamp = timestamp
    }
}
