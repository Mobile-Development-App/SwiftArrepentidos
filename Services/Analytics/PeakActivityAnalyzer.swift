import Foundation

// ─────────────────────────────────────────────────────────────────────────────
// PeakActivityAnalyzer — Sprint 3 BQ6 backend.
//
// Business question (Juan Felipe — Type 2, usage pattern):
//   "¿A qué hora del día añade el usuario productos más frecuentemente
//    durante los últimos 30 días?"
//
// Input
//   A snapshot of `UsageEvent`s from `UsageTrackingService`.
// Output
//   24-bucket histogram (one bucket per hour-of-day) plus summary stats.
//
// Multi-threading (Sprint 3 requirement)
//   Histogram computation runs on a detached task at `.userInitiated`
//   priority so the main thread stays free while the view-model is awaiting.
//   For the sizes we expect (≤ 2 000 events) the work is trivial in ms —
//   the point is that we never touch UIKit/SwiftUI state from the worker.
// ─────────────────────────────────────────────────────────────────────────────

struct HourBucket: Identifiable, Hashable, Sendable {
    /// Hour of day in 0…23.
    let hour: Int
    /// Number of tracked events that fell in this hour across the window.
    let count: Int

    var id: Int { hour }

    /// "08:00" — used as the chart axis label.
    var label: String { String(format: "%02d:00", hour) }
}

struct PeakActivitySummary: Sendable {
    let buckets: [HourBucket]        // length 24, hour 0…23
    let totalEvents: Int
    let peakHour: Int?               // nil if no events
    let averagePerActiveHour: Double
    /// Covers only events of kind `.productCreated`. The analyzer can be
    /// reused for other kinds later by passing a different filter.
    let windowDays: Int
    let computedAt: Date
    let durationMs: Double
}

enum PeakActivityAnalyzer {

    /// Builds the histogram asynchronously off the main thread.
    ///
    /// - Parameters:
    ///   - events:      input log, usually the result of
    ///                  `UsageTrackingService.recentEvents(within:)`.
    ///   - kinds:       event kinds to include. Defaults to product creations
    ///                  since that's what BQ6 asks about.
    ///   - windowDays:  stored on the summary so the UI can label the card.
    static func analyze(events: [UsageEvent],
                        kinds: Set<UsageEvent.Kind> = [.productCreated],
                        windowDays: Int = 30) async -> PeakActivitySummary {
        // Detach so the histogram loop can't end up on @MainActor even if
        // the caller awaits us from the main queue.
        return await Task.detached(priority: .userInitiated) {
            let start = Date()
            var counts = [Int](repeating: 0, count: 24)
            var total = 0
            for e in events where kinds.contains(e.kind) {
                counts[e.hourOfDay] += 1
                total += 1
            }
            let buckets = counts.enumerated().map { HourBucket(hour: $0.offset, count: $0.element) }
            let peak = counts.enumerated().max(by: { $0.element < $1.element })
            let activeHours = counts.filter { $0 > 0 }.count
            let avg = activeHours > 0 ? Double(total) / Double(activeHours) : 0
            let elapsed = Date().timeIntervalSince(start) * 1000
            return PeakActivitySummary(
                buckets: buckets,
                totalEvents: total,
                peakHour: (peak?.element ?? 0) > 0 ? peak?.offset : nil,
                averagePerActiveHour: avg,
                windowDays: windowDays,
                computedAt: Date(),
                durationMs: elapsed
            )
        }.value
    }
}
