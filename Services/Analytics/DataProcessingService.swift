import Foundation

enum DataProcessingService {

    //BQ1
    static func averageLatencies(samples: [LatencySample]) async -> LatencySummary {
        await Task.detached(priority: .userInitiated) {
            let start = Date()
            var sums: [LatencySample.Stage: Double] = [:]
            var counts: [LatencySample.Stage: Int] = [:]
            for s in samples {
                sums[s.stage, default: 0] += s.durationMs
                counts[s.stage, default: 0] += 1
            }
            let stages: [StageStat] = LatencySample.Stage.allCases.map { stage in
                let count = counts[stage] ?? 0
                let avg = count > 0 ? (sums[stage] ?? 0) / Double(count) : 0
                return StageStat(stage: stage, count: count, averageMs: avg)
            }
            let total = samples.count
            let overallAvg = total > 0 ? (samples.reduce(0) { $0 + $1.durationMs } / Double(total)) : 0
            return LatencySummary(
                stages: stages,
                totalSamples: total,
                overallAverageMs: overallAvg,
                computedAt: Date(),
                durationMs: Date().timeIntervalSince(start) * 1000
            )
        }.value
    }

    //BQ5
    static func peakScreens(events: [AnalyticsEvent]) async -> PeakScreensSummary {
        await Task.detached(priority: .userInitiated) {
            let start = Date()
            var byScreen: [String: [Int]] = [:]
            for e in events where e.kind == .screenViewed {
                let screen = e.attributes["screen"] ?? "unknown"
                var bucket = byScreen[screen] ?? [Int](repeating: 0, count: 24)
                bucket[e.hourOfDay] += 1
                byScreen[screen] = bucket
            }
            let rows: [ScreenPeak] = byScreen.map { screen, buckets in
                let peak = buckets.enumerated().max(by: { $0.element < $1.element })
                return ScreenPeak(
                    screen: screen,
                    total: buckets.reduce(0, +),
                    peakHour: peak?.offset ?? 0,
                    peakHourCount: peak?.element ?? 0
                )
            }
            .sorted { $0.total > $1.total }
            return PeakScreensSummary(
                rows: rows,
                computedAt: Date(),
                durationMs: Date().timeIntervalSince(start) * 1000
            )
        }.value
    }

    //BQ7
    static func scanAccuracy(events: [AnalyticsEvent]) async -> ScanAccuracySummary {
        await Task.detached(priority: .userInitiated) {
            let start = Date()
            var cameraOk = 0, cameraFail = 0, manualOk = 0, manualFail = 0
            for e in events where e.kind == .scanAttempt {
                let ok = e.attributes["success"] == "1"
                let source = e.attributes["source"] ?? "camera"
                switch (source, ok) {
                case ("camera", true):  cameraOk += 1
                case ("camera", false): cameraFail += 1
                case ("manual", true):  manualOk += 1
                case ("manual", false): manualFail += 1
                default: break
                }
            }
            let cameraTotal = cameraOk + cameraFail
            let manualTotal = manualOk + manualFail
            return ScanAccuracySummary(
                cameraAttempts: cameraTotal,
                cameraAccuracy: cameraTotal > 0 ? Double(cameraOk) / Double(cameraTotal) : 0,
                manualAttempts: manualTotal,
                manualAccuracy: manualTotal > 0 ? Double(manualOk) / Double(manualTotal) : 0,
                computedAt: Date(),
                durationMs: Date().timeIntervalSince(start) * 1000
            )
        }.value
    }

    //BQ8
    static func featureUsage(events: [AnalyticsEvent]) async -> FeatureUsageSummary {
        await Task.detached(priority: .userInitiated) {
            let start = Date()
            var byFeature: [String: [Int: Int]] = [:]
            for e in events where e.kind == .featureAccessed {
                let feature = e.attributes["feature"] ?? "unknown"
                var weeks = byFeature[feature] ?? [:]
                weeks[e.isoWeek, default: 0] += 1
                byFeature[feature] = weeks
            }
            let rows: [FeatureUsageRow] = byFeature.map { feature, weekMap in
                FeatureUsageRow(
                    feature: feature,
                    totalAccesses: weekMap.values.reduce(0, +),
                    weeklyCounts: weekMap
                        .map { WeekCount(week: $0.key, count: $0.value) }
                        .sorted { $0.week < $1.week }
                )
            }
            .sorted { $0.totalAccesses > $1.totalAccesses }
            return FeatureUsageSummary(
                rows: rows,
                computedAt: Date(),
                durationMs: Date().timeIntervalSince(start) * 1000
            )
        }.value
    }
}

//result types structures 
struct StageStat: Identifiable, Hashable, Sendable {
    let stage: LatencySample.Stage
    let count: Int
    let averageMs: Double
    var id: LatencySample.Stage { stage }
}

struct LatencySummary: Sendable {
    let stages: [StageStat]
    let totalSamples: Int
    let overallAverageMs: Double
    let computedAt: Date
    let durationMs: Double
}

struct ScreenPeak: Identifiable, Hashable, Sendable {
    let screen: String
    let total: Int
    let peakHour: Int
    let peakHourCount: Int
    var id: String { screen }
}

struct PeakScreensSummary: Sendable {
    let rows: [ScreenPeak]
    let computedAt: Date
    let durationMs: Double
}

struct ScanAccuracySummary: Sendable {
    let cameraAttempts: Int
    let cameraAccuracy: Double   
    let manualAttempts: Int
    let manualAccuracy: Double   
    let computedAt: Date
    let durationMs: Double
}

struct WeekCount: Identifiable, Hashable, Sendable {
    let week: Int
    let count: Int
    var id: Int { week }
}

struct FeatureUsageRow: Identifiable, Hashable, Sendable {
    let feature: String
    let totalAccesses: Int
    let weeklyCounts: [WeekCount]
    var id: String { feature }
}

struct FeatureUsageSummary: Sendable {
    let rows: [FeatureUsageRow]
    let computedAt: Date
    let durationMs: Double
}
