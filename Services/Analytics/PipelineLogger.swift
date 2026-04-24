import Foundation

struct LatencySample: Codable, Hashable {
    enum Stage: String, Codable, CaseIterable {
        case ingestion
        case storage
        case processing
        case computation
    }

    let stage: Stage
    let durationMs: Double
    let timestamp: Date
}

actor PipelineLogger {
    static let shared = PipelineLogger()

    struct Token {
        let stage: LatencySample.Stage
        let start: Date
    }

    private let fileName = "pipeline_latencies.json"
    private var samples: [LatencySample] = []
    private var loaded = false
    private let cap = 2_000

    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let fileManager = FileManager.default

    private init() {
        encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
    }

    func start(_ stage: LatencySample.Stage) -> Token {
        Token(stage: stage, start: Date())
    }

    func end(_ token: Token) {
        loadIfNeeded()
        let ms = Date().timeIntervalSince(token.start) * 1000
        samples.append(LatencySample(stage: token.stage, durationMs: ms, timestamp: Date()))
        if samples.count > cap { samples.removeFirst(samples.count - cap / 2) }
        persist()
    }

    func recordExternal(stage: LatencySample.Stage, durationMs: Double) {
        loadIfNeeded()
        samples.append(LatencySample(stage: stage, durationMs: durationMs, timestamp: Date()))
        if samples.count > cap { samples.removeFirst(samples.count - cap / 2) }
        persist()
    }

    func recentSamples(within days: Int = 30) -> [LatencySample] {
        loadIfNeeded()
        let cutoff = Date().addingTimeInterval(-Double(days) * 86_400)
        return samples.filter { $0.timestamp >= cutoff }
    }

    func clear() {
        samples.removeAll()
        let url = storageURL()
        try? fileManager.removeItem(at: url)
    }

    private func loadIfNeeded() {
        guard !loaded else { return }
        defer { loaded = true }
        let url = storageURL()
        guard fileManager.fileExists(atPath: url.path) else { return }
        if let data = try? Data(contentsOf: url),
           let decoded = try? decoder.decode([LatencySample].self, from: data) {
            samples = decoded
        }
    }

    private func persist() {
        let url = storageURL()
        if let data = try? encoder.encode(samples) {
            try? data.write(to: url, options: .atomic)
        }
    }

    private func storageURL() -> URL {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        if !fileManager.fileExists(atPath: base.path) {
            try? fileManager.createDirectory(at: base, withIntermediateDirectories: true)
        }
        return base.appendingPathComponent(fileName)
    }
}
