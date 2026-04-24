import Foundation

enum BQCacheKey: String {
    case products
    case alerts
    case dashboard
    case latencySummary
    case peakScreensSummary
}

actor BQCacheService {
    static let shared = BQCacheService()

    static let defaultTTL: [BQCacheKey: TimeInterval] = [
        .products: 5 * 60,
        .alerts: 10 * 60,
        .dashboard: 10 * 60,
        .latencySummary: 2 * 60,
        .peakScreensSummary: 5 * 60
    ]

    private struct Entry: Codable {
        let payload: Data        // pal json
        let expiresAt: Date
        let writtenAt: Date
    }

    //dictionary + access-order array
    private var memory: [String: Entry] = [:]
    private var order: [String] = []
    private let capacity = 32

    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let fileManager = FileManager.default

    private init() {
        encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
    }


    func get<T: Decodable>(_ type: T.Type, for key: BQCacheKey) async -> T? {
        if let entry = memory[key.rawValue], entry.expiresAt > Date() {
            touch(key.rawValue)
            return try? decoder.decode(T.self, from: entry.payload)
        } else {
            if memory[key.rawValue] != nil { invalidate(key.rawValue) }
        }

        if let entry = readDiskEntry(key: key), entry.expiresAt > Date() {
            memory[key.rawValue] = entry
            touch(key.rawValue)
            return try? decoder.decode(T.self, from: entry.payload)
        }
        return nil
    }

    ///stores value under `key`
    func put<T: Encodable>(_ value: T, for key: BQCacheKey, ttl: TimeInterval? = nil) async {
        let effectiveTTL = ttl ?? Self.defaultTTL[key] ?? 300
        guard let data = try? encoder.encode(value) else { return }
        let entry = Entry(
            payload: data,
            expiresAt: Date().addingTimeInterval(effectiveTTL),
            writtenAt: Date()
        )
        memory[key.rawValue] = entry
        touch(key.rawValue)
        evictIfNeeded()
        writeDiskEntry(key: key, entry: entry)
    }

    ///drops both layers for key. Used on data mutations
    func remove(_ key: BQCacheKey) {
        invalidate(key.rawValue)
        try? fileManager.removeItem(at: diskURL(for: key))
    }

    func removeAll() {
        memory.removeAll()
        order.removeAll()
        for key in BQCacheKey.allCases {
            try? fileManager.removeItem(at: diskURL(for: key))
        }
    }

    private func touch(_ key: String) {
        order.removeAll { $0 == key }
        order.append(key)
    }

    private func invalidate(_ key: String) {
        memory.removeValue(forKey: key)
        order.removeAll { $0 == key }
    }

    private func evictIfNeeded() {
        while memory.count > capacity, let oldest = order.first {
            memory.removeValue(forKey: oldest)
            order.removeFirst()
        }
    }

    private func diskURL(for key: BQCacheKey) -> URL {
        let base = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("bq_cache", isDirectory: true)
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir.appendingPathComponent("\(key.rawValue).json")
    }

    private func readDiskEntry(key: BQCacheKey) -> Entry? {
        let url = diskURL(for: key)
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        return try? decoder.decode(Entry.self, from: Data(contentsOf: url))
    }

    private func writeDiskEntry(key: BQCacheKey, entry: Entry) {
        let url = diskURL(for: key)
        if let data = try? encoder.encode(entry) {
            try? data.write(to: url, options: .atomic)
        }
    }
}

extension BQCacheKey: CaseIterable {}
