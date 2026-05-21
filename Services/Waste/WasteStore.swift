import Foundation

// ─────────────────────────────────────────────────────────────────────────────
// WasteStore — Sprint 4. Persistencia local de los eventos de merma.
//
// `actor` con backing en un JSON append-only en Application Support
// (`waste_events.json`). Mismo patrón offline-first que `RestockCycleStore`:
// la actor-isolation serializa los escritores concurrentes y la I/O de disco
// queda fuera del @MainActor.
//
// Eventual connectivity: 100% local. Registrar una merma funciona sin red;
// el dato persiste en disco y queda disponible para el reporte y la BQ10
// aunque el dispositivo esté en modo avión.
// ─────────────────────────────────────────────────────────────────────────────

actor WasteStore {
    static let shared = WasteStore()

    private let fileName = "waste_events.json"
    private var events: [WasteEvent] = []
    private var loaded = false
    private let cap = 5_000

    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let fileManager = FileManager.default

    private init() {
        encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
    }

    // MARK: - Public API

    /// Registra una merma y persiste. Append-only con rollover.
    func record(_ event: WasteEvent) {
        loadIfNeeded()
        events.append(event)
        if events.count > cap { events.removeFirst(events.count - cap / 2) }
        persist()
        #if DEBUG
        print("[WasteStore] recorded \(event.productName) x\(event.quantity) (\(event.reason.rawValue))")
        #endif
    }

    /// Eventos dentro de los últimos `days` días, más recientes primero.
    func recentEvents(within days: Int = 30) -> [WasteEvent] {
        loadIfNeeded()
        let cutoff = Date().addingTimeInterval(-Double(days) * 86_400)
        return events
            .filter { $0.recordedAt >= cutoff }
            .sorted { $0.recordedAt > $1.recordedAt }
    }

    /// Todos los eventos registrados.
    func allEvents() -> [WasteEvent] {
        loadIfNeeded()
        return events.sorted { $0.recordedAt > $1.recordedAt }
    }

    func clear() {
        events.removeAll()
        try? fileManager.removeItem(at: storageURL())
    }

    // MARK: - Disk I/O

    private func loadIfNeeded() {
        guard !loaded else { return }
        defer { loaded = true }
        let url = storageURL()
        guard fileManager.fileExists(atPath: url.path) else { return }
        if let data = try? Data(contentsOf: url),
           let decoded = try? decoder.decode([WasteEvent].self, from: data) {
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
