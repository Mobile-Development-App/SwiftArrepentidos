import Foundation
import SwiftData
import SwiftUI

// ─────────────────────────────────────────────────────────────────────────────
// LocalDatabaseService — fachada del store relacional local (SwiftData / SQLite).
//
// ## Por qué existe
// La rúbrica de Sprint 3 categoriza Local Storage en cuatro estrategias:
//   1. BD Local Relacional (10 pts)  ← este servicio
//   2. BD Llave/Valor                 ← BQCacheService
//   3. Archivos Locales               ← PersistenceService, OfflineQueueService…
//   4. Preferences/UserDefaults/Keychain ← SettingsViewModel, Auth entitlement
//
// Hasta esta iteración el repo cubría 2-4. Esta clase introduce 1 sin
// reemplazar lo existente: persistencia "dual-write" — el origen de verdad
// para offline sigue siendo el JSON en `Application Support`, pero cada audit
// y cada usage-event se replica también a SwiftData para que sea consultable
// con `@Query` y predicados.
//
// ## Esquema
//   UserSession ──┬── AuditLogEntry      (1-N, cascade)
//                 └── UsageEventRecord    (1-N, cascade)
// `UserSession` se crea perezosamente: la primera escritura tras un login
// que no tenga sesión activa la abre. `userDidLogout` la cierra y la limpia.
//
// ## Concurrencia
// Toda la API es `@MainActor`. Los callers en background (ej. el actor
// `UsageTrackingService`) hacen `Task { @MainActor in … }` para hopear; el
// volumen es bajo (eventos puntuales) así que no necesitamos un context
// dedicado en background.
// ─────────────────────────────────────────────────────────────────────────────

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
            UsageEventRecord.self
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

    /// Llamada una vez por cold-start desde `InventarIAApp.init`. Inserta un
    /// audit `AppLaunched` para que la BD nunca se vea vacía en el demo y
    /// para que tengamos un marcador de cada inicio de sesión de la app.
    func bootstrapLaunchEvent() {
        insertAudit(
            action: "AppLaunched",
            entityType: "System",
            details: "Cold-start de la app — bootstrap del store relacional"
        )
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
