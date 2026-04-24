import Foundation

// ─────────────────────────────────────────────────────────────────────────────
// UsageTrackingService — Sprint 3 (Local Storage + Multi-threading)
//
// Responsibility
//   • Append-only log of `UsageEvent`s, persisted as a single JSON file in
//     Application Support. The file is the source of truth for BQ6 (peak
//     activity hours) and feeds BQ computations off the main thread.
//
// Why an `actor`?
//   • Every call site (the inventory view-model, analytics refresh, etc.)
//     runs on @MainActor. Moving the write path onto a dedicated actor keeps
//     disk I/O and event mutation off the UI thread without the caller
//     having to think about dispatch queues.
//   • Actor isolation also gives us a free guarantee that the in-memory
//     buffer and the on-disk file stay consistent: concurrent writers are
//     serialized automatically.
//
// Storage layout
//   Application Support/usage_events.json   →  [UsageEvent]
//   Rolled over at `maxEvents = 2 000` by dropping the oldest half. The app
//   only needs a rolling window anyway (30-day lookback) and this keeps the
//   read path cheap.
//
// Eventual connectivity
//   This service has zero network dependency. It works whether the phone is
//   online or in airplane mode, which is the whole point: the BQs that read
//   from it stay answerable offline.
// ─────────────────────────────────────────────────────────────────────────────

actor UsageTrackingService {
    static let shared = UsageTrackingService()

    private let fileName = "usage_events.json"
    private let maxEvents = 2_000

    private var events: [UsageEvent] = []
    private var loaded = false

    private let fileManager = FileManager.default
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    private init() {
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    // MARK: - Public API

    /// Appends an event to the log and persists asynchronously.
    func record(_ event: UsageEvent) {
        loadIfNeeded()
        events.append(event)
        if events.count > maxEvents {
            events.removeFirst(events.count - maxEvents / 2)
        }
        persist()
    }

    /// Convenience wrapper that builds the event for the caller.
    func record(kind: UsageEvent.Kind, attributes: [String: String] = [:]) {
        record(UsageEvent(kind: kind, attributes: attributes))
    }

    /// Snapshot of the log filtered to the last `days` days. Returned by
    /// value so callers can post-process on a detached task without holding
    /// the actor.
    func recentEvents(within days: Int = 30) -> [UsageEvent] {
        loadIfNeeded()
        let cutoff = Date().addingTimeInterval(-Double(days) * 86_400)
        return events.filter { $0.timestamp >= cutoff }
    }

    /// Full log. Avoid unless you really need it (hands out a copy).
    func allEvents() -> [UsageEvent] {
        loadIfNeeded()
        return events
    }

    /// Wipes the log. Called on logout so events don't bleed across accounts.
    func clear() {
        events.removeAll()
        let url = storageURL()
        try? fileManager.removeItem(at: url)
    }

    // MARK: - Internal helpers

    private func loadIfNeeded() {
        guard !loaded else { return }
        defer { loaded = true }
        let url = storageURL()
        guard fileManager.fileExists(atPath: url.path) else { return }
        do {
            let data = try Data(contentsOf: url)
            events = try decoder.decode([UsageEvent].self, from: data)
        } catch {
            #if DEBUG
            print("[UsageTracking] load failed, resetting log: \(error)")
            #endif
            events = []
        }
    }

    private func persist() {
        let url = storageURL()
        do {
            let data = try encoder.encode(events)
            try data.write(to: url, options: .atomic)
        } catch {
            #if DEBUG
            print("[UsageTracking] persist failed: \(error)")
            #endif
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
