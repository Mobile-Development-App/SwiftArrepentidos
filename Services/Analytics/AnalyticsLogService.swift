import Foundation

actor AnalyticsLogService {
    static let shared = AnalyticsLogService()

    private let fileName = "analytics_events.json"
    private let maxEvents = 5_000

    private var events: [AnalyticsEvent] = []
    private var loaded = false

    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let fileManager = FileManager.default

    private init() {
        encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
    }

    func record(_ event: AnalyticsEvent) {
        loadIfNeeded()
        events.append(event)
        if events.count > maxEvents {
            events.removeFirst(events.count - maxEvents / 2)
        }
        persist()
    }

    func record(kind: AnalyticsEvent.Kind, attributes: [String: String] = [:]) {
        record(AnalyticsEvent(kind: kind, attributes: attributes))
    }

    func recentEvents(within days: Int = 30) -> [AnalyticsEvent] {
        loadIfNeeded()
        let cutoff = Date().addingTimeInterval(-Double(days) * 86_400)
        return events.filter { $0.timestamp >= cutoff }
    }

    func clear() {
        events.removeAll()
        let url = storageURL()
        try? fileManager.removeItem(at: url)
    }

    private func loadIfNeeded() {
        guard !loaded else { return }
        defer { loaded = true }
        let url = storageURL()
        guard fileManager.fileExists(atPath: url.path) else { return }
        if let data = try? Data(contentsOf: url),
           let decoded = try? decoder.decode([AnalyticsEvent].self, from: data) {
            events = decoded
        }
    }

    private func persist() {
        let url = storageURL()
        if let data = try? encoder.encode(events) {
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
