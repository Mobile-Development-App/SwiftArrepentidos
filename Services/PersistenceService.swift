import Foundation
import Combine

//persistencia
class PersistenceService: ObservableObject {
    static let shared = PersistenceService()

    private let fileManager = FileManager.default
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private var documentsDirectory: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private init() {
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    //crud basico

    func save<T: Codable>(_ items: [T], to filename: String) {
        let url = documentsDirectory.appendingPathComponent("\(filename).json")
        do {
            let data = try encoder.encode(items)
            try data.write(to: url, options: .atomic)
        } catch {
            print("[PersistenceService] Error saving \(filename): \(error)")
        }
    }

    func load<T: Codable>(from filename: String) -> [T] {
        let url = documentsDirectory.appendingPathComponent("\(filename).json")
        guard fileManager.fileExists(atPath: url.path) else { return [] }
        do {
            let data = try Data(contentsOf: url)
            return try decoder.decode([T].self, from: data)
        } catch {
            print("[PersistenceService] Error loading \(filename): \(error)")
            return []
        }
    }

    func saveSingle<T: Codable>(_ item: T, to filename: String) {
        let url = documentsDirectory.appendingPathComponent("\(filename).json")
        do {
            let data = try encoder.encode(item)
            try data.write(to: url, options: .atomic)
        } catch {
            print("[PersistenceService] Error saving \(filename): \(error)")
        }
    }

    func loadSingle<T: Codable>(from filename: String) -> T? {
        let url = documentsDirectory.appendingPathComponent("\(filename).json")
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        do {
            let data = try Data(contentsOf: url)
            return try decoder.decode(T.self, from: data)
        } catch {
            print("[PersistenceService] Error loading \(filename): \(error)")
            return nil
        }
    }

    func exists(_ filename: String) -> Bool {
        let url = documentsDirectory.appendingPathComponent("\(filename).json")
        return fileManager.fileExists(atPath: url.path)
    }

    func delete(_ filename: String) {
        let url = documentsDirectory.appendingPathComponent("\(filename).json")
        try? fileManager.removeItem(at: url)
    }

    
    // Products
    func saveProducts(_ products: [Product]) { save(products, to: "products") }
    func loadProducts() -> [Product] { load(from: "products") }

    // Stores
    func saveStores(_ stores: [Store]) { save(stores, to: "stores") }
    func loadStores() -> [Store] { load(from: "stores") }

    // Employees
    func saveEmployees(_ employees: [Employee]) { save(employees, to: "employees") }
    func loadEmployees() -> [Employee] { load(from: "employees") }

    // Alerts
    func saveAlerts(_ alerts: [InventoryAlert]) { save(alerts, to: "alerts") }
    func loadAlerts() -> [InventoryAlert] { load(from: "alerts") }

    // Orders
    func saveOrders(_ orders: [Order]) { save(orders, to: "orders") }
    func loadOrders() -> [Order] { load(from: "orders") }

    // Suppliers
    func saveSuppliers(_ suppliers: [Supplier]) { save(suppliers, to: "suppliers") }
    func loadSuppliers() -> [Supplier] { load(from: "suppliers") }

    // User session
    func saveUser(_ user: User) { saveSingle(user, to: "current_user") }
    func loadUser() -> User? { loadSingle(from: "current_user") }
    func clearUser() { delete("current_user") }

    // Audit trail
    func logAuditEvent(_ event: AuditEvent) {
        var events: [AuditEvent] = load(from: "audit_log")
        events.append(event)
        if events.count > 1000 {
            events = Array(events.suffix(1000))
        }
        save(events, to: "audit_log")
    }

    func loadAuditLog() -> [AuditEvent] { load(from: "audit_log") }


    ///guardar timestamp
    func saveCacheTimestamp(for key: String) {
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "cache_ts_\(key)")
    }
    ////aux functions
    func getCacheAge(for key: String) -> TimeInterval? {
        let ts = UserDefaults.standard.double(forKey: "cache_ts_\(key)")
        guard ts > 0 else { return nil }
        return Date().timeIntervalSince1970 - ts
    }

    func isCacheStale(for key: String, maxAge: TimeInterval = 300) -> Bool {
        guard let age = getCacheAge(for: key) else { return true }
        return age > maxAge
    }

    // lougout y clear data
    func clearAllData() {
        let dataFiles = ["products", "stores", "employees", "alerts", "orders", "suppliers", "audit_log"]
        for file in dataFiles {
            delete(file)
            UserDefaults.standard.removeObject(forKey: "cache_ts_\(file)")
        }
        print("[PersistenceService] All cached data cleared")
    }

    // clear mock data
    func clearMockDataIfNeeded() {
        let migrationKey = "didClearMockDataV1"
        guard !UserDefaults.standard.bool(forKey: migrationKey) else { return }
        clearAllData()
        UserDefaults.standard.set(true, forKey: migrationKey)
        print("[PersistenceService] Cleared legacy mock data")
    }
}

//audit event
struct AuditEvent: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let userName: String
    let action: String
    let entityType: String
    let entityId: UUID?
    let entityName: String?
    let details: String
    let timestamp: Date

    init(userId: UUID, userName: String, action: String, entityType: String, entityId: UUID? = nil, entityName: String? = nil, details: String) {
        self.id = UUID()
        self.userId = userId
        self.userName = userName
        self.action = action
        self.entityType = entityType
        self.entityId = entityId
        self.entityName = entityName
        self.details = details
        self.timestamp = Date()
    }
}


