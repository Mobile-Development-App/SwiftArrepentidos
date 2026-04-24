import SwiftUI
import Combine

@MainActor
final class Sprint3BQsViewModel: ObservableObject {

    @Published private(set) var latency: LatencySummary?
    @Published private(set) var peakScreens: PeakScreensSummary?
    @Published private(set) var scanAccuracy: ScanAccuracySummary?
    @Published private(set) var featureUsage: FeatureUsageSummary?

    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let logger = PipelineLogger.shared
    private let events = AnalyticsLogService.shared
    private let cache = BQCacheService.shared

    func refresh(forceFresh: Bool = false) async {
        isLoading = true
        defer { isLoading = false }

        async let l = computeLatency(forceFresh: forceFresh)
        async let p = computePeakScreens(forceFresh: forceFresh)
        async let s = computeScanAccuracy(forceFresh: forceFresh)
        async let f = computeFeatureUsage(forceFresh: forceFresh)
        let (lv, pv, sv, fv) = await (l, p, s, f)

        self.latency = lv
        self.peakScreens = pv
        self.scanAccuracy = sv
        self.featureUsage = fv
    }


    private func computeLatency(forceFresh: Bool) async -> LatencySummary {
        if !forceFresh,
           let cached: CachedLatency = await cache.get(CachedLatency.self, for: .latencySummary) {
            return cached.value
        }
        let samples = await logger.recentSamples()
        let summary = await DataProcessingService.averageLatencies(samples: samples)
        await cache.put(CachedLatency(value: summary), for: .latencySummary)
        return summary
    }

    private func computePeakScreens(forceFresh: Bool) async -> PeakScreensSummary {
        if !forceFresh,
           let cached: CachedPeakScreens = await cache.get(CachedPeakScreens.self, for: .peakScreensSummary) {
            return cached.value
        }
        let recent = await events.recentEvents()
        let summary = await DataProcessingService.peakScreens(events: recent)
        await cache.put(CachedPeakScreens(value: summary), for: .peakScreensSummary)
        return summary
    }

    private func computeScanAccuracy(forceFresh _: Bool) async -> ScanAccuracySummary {
        let recent = await events.recentEvents()
        return await DataProcessingService.scanAccuracy(events: recent)
    }

    private func computeFeatureUsage(forceFresh _: Bool) async -> FeatureUsageSummary {
        let recent = await events.recentEvents()
        return await DataProcessingService.featureUsage(events: recent)
    }
}


private struct CachedLatency: Codable {
    let stages: [CodableStageStat]
    let totalSamples: Int
    let overallAverageMs: Double
    let computedAt: Date
    let durationMs: Double

    init(value: LatencySummary) {
        stages = value.stages.map { CodableStageStat(stage: $0.stage.rawValue, count: $0.count, averageMs: $0.averageMs) }
        totalSamples = value.totalSamples
        overallAverageMs = value.overallAverageMs
        computedAt = value.computedAt
        durationMs = value.durationMs
    }

    var value: LatencySummary {
        LatencySummary(
            stages: stages.map { StageStat(stage: .init(rawValue: $0.stage) ?? .ingestion,
                                           count: $0.count,
                                           averageMs: $0.averageMs) },
            totalSamples: totalSamples,
            overallAverageMs: overallAverageMs,
            computedAt: computedAt,
            durationMs: durationMs
        )
    }
}

private struct CodableStageStat: Codable {
    let stage: String
    let count: Int
    let averageMs: Double
}

private struct CachedPeakScreens: Codable {
    let rows: [Row]
    let computedAt: Date
    let durationMs: Double

    struct Row: Codable {
        let screen: String
        let total: Int
        let peakHour: Int
        let peakHourCount: Int
    }

    init(value: PeakScreensSummary) {
        rows = value.rows.map { .init(screen: $0.screen, total: $0.total, peakHour: $0.peakHour, peakHourCount: $0.peakHourCount) }
        computedAt = value.computedAt
        durationMs = value.durationMs
    }

    var value: PeakScreensSummary {
        PeakScreensSummary(
            rows: rows.map { ScreenPeak(screen: $0.screen, total: $0.total, peakHour: $0.peakHour, peakHourCount: $0.peakHourCount) },
            computedAt: computedAt,
            durationMs: durationMs
        )
    }
}
