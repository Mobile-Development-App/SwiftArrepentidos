import Foundation
import SwiftData
import SwiftUI


@MainActor
final class LocalDatabaseService: ObservableObject {

    static let shared = LocalDatabaseService()

    let container: ModelContainer
    private var context: ModelContext { container.mainContext }

    @Published private(set) var currentSession: UserSession?

    private var logoutObserver: NSObjectProtocol?

    private init() {

        let schema = Schema([
            UserSession.self,
            AuditLogEntry.self,
            UsageEventRecord.self,
            PipelineLatencySample.self,
            AnalyticsEventSample.self,
            LocalKeyValueEntry.self,
            RestockCycleEntry.self,
            ExpirationAdviceEntry.self,
            // Sprint 4 — Conteo Físico de Inventario (Juan Felipe)
            StockCountSessionEntry.self,
            StockCountItemEntry.self
        ])
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )
        do {
            self.container = try ModelContainer(
                for: schema,
                configurations: [config]
            )
        } catch {
            // Si el store está corrupto preferimos arrancar limpio en
            // memoria a tumbar la app — el JSON sigue siendo el respaldo.
            #if DEBUG
            print("[LocalDB] persistent store init failed (\(error)). Falling back to in-memory.")
            #endif
            let memConfig = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: true
            )
            self.container = try! ModelContainer(
                for: schema,
                configurations: [memConfig]
            )
        }

        logoutObserver = NotificationCenter.default.addObserver(
            forName: .userDidLogout, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.endCurrentSession() }
        }
    }

    deinit {
        if let logoutObserver {
            NotificationCenter.default.removeObserver(logoutObserver)
        }
    }

    func bootstrapLaunchEvent() {
        insertAudit(
            action: "AppLaunched",
            entityType: "System",
            details: "Cold-start de la app — bootstrap del store relacional"
        )

        // Triggers dual-write desde los actors de Santiago. Los `Task` los
        // crea cada servicio internamente; nosotros sólo invocamos su API.
        Task {
            await PipelineLogger.shared.recordExternal(stage: .ingestion, durationMs: 0)
            await AnalyticsLogService.shared.record(
                kind: .featureAccessed,
                attributes: ["feature": "AppLaunch"]
            )
        }

        // KV store directo (no async, ya estamos en @MainActor).
        let now = Date()
        LocalKeyValueStore.shared.set(now, for: "lastLaunchAt", ttl: 7 * 86_400)
    }

    // MARK: - Session lifecycle

    @discardableResult
    func ensureSession(userId: UUID, userName: String) -> UserSession {
        if let active = currentSession, active.isActive {
            return active
        }
        let session = UserSession(userId: userId, userName: userName)
        context.insert(session)
        try? context.save()
        currentSession = session
        return session
    }

    func endCurrentSession() {
        guard let session = currentSession else { return }
        session.endedAt = Date()
        try? context.save()
        currentSession = nil
    }

    // MARK: - Inserts (called via dual-write from JSON-based services)

    func insertAudit(action: String,
                     entityType: String,
                     entityId: UUID? = nil,
                     entityName: String? = nil,
                     details: String,
                     userId: UUID? = nil,
                     userName: String? = nil) {
        let entry = AuditLogEntry(
            action: action,
            entityType: entityType,
            entityId: entityId,
            entityName: entityName,
            details: details,
            session: sessionFor(userId: userId, userName: userName)
        )
        context.insert(entry)
        try? context.save()
    }

    func insertUsageEvent(kind: String,
                          attributes: [String: String],
                          userId: UUID? = nil,
                          userName: String? = nil) {
        let json = encodeAttributes(attributes)
        let record = UsageEventRecord(
            kind: kind,
            attributesJSON: json,
            session: sessionFor(userId: userId, userName: userName)
        )
        context.insert(record)
        try? context.save()
    }

    // MARK: - Inserts (Santiago — telemetría del pipeline analítico)

    func insertPipelineLatency(stage: String,
                               durationMs: Double,
                               timestamp: Date = Date()) {
        let sample = PipelineLatencySample(
            stage: stage,
            durationMs: durationMs,
            timestamp: timestamp
        )
        context.insert(sample)
        try? context.save()
    }

    /// Persistencia relacional para los eventos analíticos que normalmente
    /// `AnalyticsLogService` guarda en JSON. Misma estrategia dual-write.
    func insertAnalyticsEvent(kind: String,
                              attributes: [String: String],
                              timestamp: Date = Date()) {
        let json = encodeAttributes(attributes)
        let sample = AnalyticsEventSample(
            kind: kind,
            timestamp: timestamp,
            attributesJSON: json
        )
        context.insert(sample)
        try? context.save()
    }

    // MARK: - Inserts (Angel — BQ3 y BQ4 relacional)

    func insertRestockCycle(productId: UUID,
                            productName: String,
                            outOfStockAt: Date,
                            restockedAt: Date) {
        let entry = RestockCycleEntry(
            productId: productId,
            productName: productName,
            outOfStockAt: outOfStockAt,
            restockedAt: restockedAt
        )
        context.insert(entry)
        try? context.save()
    }

    func insertExpirationAdvice(productId: UUID,
                                productName: String,
                                category: String,
                                quantity: Int,
                                daysRemaining: Int,
                                urgency: String,
                                action: String,
                                rationale: String,
                                computedAt: Date = Date()) {
        let entry = ExpirationAdviceEntry(
            productId: productId,
            productName: productName,
            category: category,
            quantity: quantity,
            daysRemaining: daysRemaining,
            urgency: urgency,
            action: action,
            rationale: rationale,
            computedAt: computedAt
        )
        context.insert(entry)
        try? context.save()
    }

    // MARK: - Stock Count (Sprint 4 — Conteo Físico, Juan Felipe)

    /// Crea una sesión de conteo nueva con sus renglones (uno por producto)
    /// y la devuelve. Los renglones arrancan sin `countedQuantity`.
    @discardableResult
    func createStockCountSession(items: [StockCountItem]) -> StockCountSessionEntry {
        let session = StockCountSessionEntry()
        context.insert(session)
        for item in items {
            let entry = StockCountItemEntry(
                productId: item.productId,
                productName: item.productName,
                categoryRaw: item.category.rawValue,
                systemQuantity: item.systemQuantity,
                countedQuantity: item.countedQuantity,
                costPrice: item.costPrice,
                session: session
            )
            context.insert(entry)
        }
        try? context.save()
        return session
    }

    /// Devuelve la sesión de conteo en progreso, si existe. Permite retomar
    /// un conteo que quedó a medias tras cerrar la app.
    func activeStockCountSession() -> StockCountSessionEntry? {
        let target = StockCountStatus.inProgress.rawValue
        let predicate = #Predicate<StockCountSessionEntry> { $0.statusRaw == target }
        var descriptor = FetchDescriptor<StockCountSessionEntry>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }

    /// Registra la cantidad contada para un renglón puntual y persiste.
    func recordCountedQuantity(itemId: UUID, quantity: Int) {
        let predicate = #Predicate<StockCountItemEntry> { $0.id == itemId }
        let descriptor = FetchDescriptor<StockCountItemEntry>(predicate: predicate)
        guard let entry = (try? context.fetch(descriptor))?.first else { return }
        entry.countedQuantity = quantity
        try? context.save()
    }

    /// Marca una sesión como completada.
    func finishStockCountSession(sessionId: UUID) {
        let predicate = #Predicate<StockCountSessionEntry> { $0.id == sessionId }
        let descriptor = FetchDescriptor<StockCountSessionEntry>(predicate: predicate)
        guard let session = (try? context.fetch(descriptor))?.first else { return }
        session.statusRaw = StockCountStatus.completed.rawValue
        session.finishedAt = Date()
        try? context.save()
    }

    /// Todas las sesiones de conteo, más recientes primero. Lo usa BQ9.
    func allStockCountSessions() -> [StockCountSessionEntry] {
        let descriptor = FetchDescriptor<StockCountSessionEntry>(
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    /// Sesiones completadas — fuente de BQ9 (exactitud de inventario).
    func completedStockCountSessions() -> [StockCountSessionEntry] {
        let target = StockCountStatus.completed.rawValue
        let predicate = #Predicate<StockCountSessionEntry> { $0.statusRaw == target }
        let descriptor = FetchDescriptor<StockCountSessionEntry>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    // MARK: - Key-Value store (Santiago — BD llave-valor)

    /// Inserta o actualiza el par `key → value` con TTL opcional.
    /// Equivalente al `put` de Realm/Hive, con upsert atómico.
    func setKeyValue(_ value: Data, for key: String, ttl: TimeInterval? = nil) {
        let expiresAt: Date? = ttl.map { Date().addingTimeInterval($0) }
        // Upsert: si la key existe, actualizamos; si no, insertamos.
        let descriptor = FetchDescriptor<LocalKeyValueEntry>(
            predicate: #Predicate { $0.key == key }
        )
        if let existing = try? context.fetch(descriptor).first {
            existing.value = value
            existing.expiresAt = expiresAt
            existing.updatedAt = Date()
        } else {
            let entry = LocalKeyValueEntry(key: key, value: value, expiresAt: expiresAt)
            context.insert(entry)
        }
        try? context.save()
    }

    /// Lee el valor para una key. Devuelve `nil` si no existe o está expirado.
    /// Limpia entradas expiradas lazy en cada `get`.
    func getKeyValue(_ key: String) -> Data? {
        let descriptor = FetchDescriptor<LocalKeyValueEntry>(
            predicate: #Predicate { $0.key == key }
        )
        guard let entry = try? context.fetch(descriptor).first else { return nil }
        if entry.isExpired {
            context.delete(entry)
            try? context.save()
            return nil
        }
        return entry.value
    }

    /// Elimina una entrada del store. No-op si la key no existe.
    func removeKeyValue(_ key: String) {
        let descriptor = FetchDescriptor<LocalKeyValueEntry>(
            predicate: #Predicate { $0.key == key }
        )
        if let entry = try? context.fetch(descriptor).first {
            context.delete(entry)
            try? context.save()
        }
    }

    /// Lista todas las entradas (debug / inspección).
    func allKeyValueEntries() -> [LocalKeyValueEntry] {
        let descriptor = FetchDescriptor<LocalKeyValueEntry>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    // MARK: - Queries

    func recentAuditEntries(limit: Int = 100) -> [AuditLogEntry] {
        var descriptor = FetchDescriptor<AuditLogEntry>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return (try? context.fetch(descriptor)) ?? []
    }

    /// Predicado: `entityType == X`. Demuestra el uso de `#Predicate` sobre
    /// la tabla relacional, comparable a un `WHERE` de SQL.
    func auditEntries(forEntityType entityType: String,
                      limit: Int = 100) -> [AuditLogEntry] {
        let predicate = #Predicate<AuditLogEntry> { entry in
            entry.entityType == entityType
        }
        var descriptor = FetchDescriptor<AuditLogEntry>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return (try? context.fetch(descriptor)) ?? []
    }

    func recentUsageEvents(limit: Int = 200) -> [UsageEventRecord] {
        var descriptor = FetchDescriptor<UsageEventRecord>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return (try? context.fetch(descriptor)) ?? []
    }

    func usageEvents(ofKind kind: String,
                     within days: Int = 30) -> [UsageEventRecord] {
        let cutoff = Date().addingTimeInterval(-Double(days) * 86_400)
        let predicate = #Predicate<UsageEventRecord> { event in
            event.kind == kind && event.timestamp >= cutoff
        }
        let descriptor = FetchDescriptor<UsageEventRecord>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    func allSessions() -> [UserSession] {
        let descriptor = FetchDescriptor<UserSession>(
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    func auditEntryCount() -> Int {
        let descriptor = FetchDescriptor<AuditLogEntry>()
        return (try? context.fetchCount(descriptor)) ?? 0
    }

    func usageEventCount() -> Int {
        let descriptor = FetchDescriptor<UsageEventRecord>()
        return (try? context.fetchCount(descriptor)) ?? 0
    }

    func sessionCount() -> Int {
        let descriptor = FetchDescriptor<UserSession>()
        return (try? context.fetchCount(descriptor)) ?? 0
    }

    // MARK: - Maintenance

    /// Llamado desde la pantalla de Debug. Borra sólo lo que pertenece a
    /// SwiftData; el JSON original permanece intacto.
    func wipeAll() {
        try? context.delete(model: AuditLogEntry.self)
        try? context.delete(model: UsageEventRecord.self)
        try? context.delete(model: UserSession.self)
        try? context.save()
        currentSession = nil
    }

    // MARK: - Private

    private func sessionFor(userId: UUID?, userName: String?) -> UserSession? {
        if let active = currentSession, active.isActive {
            return active
        }
        // Si la primera escritura llega antes que la sesión, intentamos
        // abrirla con los datos del usuario cacheado en disco.
        if let id = userId ?? cachedUserId(),
           let name = userName ?? cachedUserName() {
            return ensureSession(userId: id, userName: name)
        }
        return nil // se grabará huérfano; aún consultable
    }

    private func cachedUserId() -> UUID? {
        PersistenceService.shared.loadUser()?.id
    }

    private func cachedUserName() -> String? {
        PersistenceService.shared.loadUser()?.fullName
    }

    private func encodeAttributes(_ attrs: [String: String]) -> String {
        guard let data = try? JSONEncoder().encode(attrs),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return json
    }
}
