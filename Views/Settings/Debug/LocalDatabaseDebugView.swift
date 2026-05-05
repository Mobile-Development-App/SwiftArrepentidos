import SwiftUI
import SwiftData

// ─────────────────────────────────────────────────────────────────────────────
// LocalDatabaseDebugView — pantalla utilitaria para inspeccionar el contenido
// de la BD relacional local (SwiftData).
//
// La uso durante el viva voce de Sprint 3 para mostrar en vivo:
//   • El esquema relacional de tres tablas (UserSession ──┬── AuditLogEntry
//                                                         └── UsageEventRecord)
//   • Lecturas reactivas con `@Query` (equivalente a un SELECT con ORDER BY)
//   • Predicados (`#Predicate`) — equivalente a un WHERE
//   • Conteos por tabla (fetchCount)
//
// Sin esta pantalla la BD funciona igual; existe para tener una superficie
// visible que demuestre que SwiftData persiste lo escrito por el dual-write.
// ─────────────────────────────────────────────────────────────────────────────

struct LocalDatabaseDebugView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss

    /// Últimos 50 audits, ordenados por fecha desc — equivalente a:
    ///   SELECT * FROM AuditLogEntry ORDER BY timestamp DESC LIMIT 50
    @Query(
        sort: [SortDescriptor(\AuditLogEntry.timestamp, order: .reverse)],
        animation: .default
    ) private var allAudits: [AuditLogEntry]

    /// Últimos 100 usage events.
    @Query(
        sort: [SortDescriptor(\UsageEventRecord.timestamp, order: .reverse)],
        animation: .default
    ) private var allUsageEvents: [UsageEventRecord]

    /// Sesiones, ordenadas por inicio desc.
    @Query(
        sort: [SortDescriptor(\UserSession.startedAt, order: .reverse)],
        animation: .default
    ) private var sessions: [UserSession]

    @State private var entityFilter: String = "Todos"
    @State private var showWipeConfirm = false

    private var entityTypes: [String] {
        let unique = Set(allAudits.map(\.entityType))
        return ["Todos"] + unique.sorted()
    }

    private var filteredAudits: [AuditLogEntry] {
        guard entityFilter != "Todos" else { return Array(allAudits.prefix(50)) }
        return allAudits.filter { $0.entityType == entityFilter }.prefix(50).map { $0 }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    statsCard
                    schemaCard
                    auditsSection
                    usageEventsSection
                    sessionsSection
                    wipeButton
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .padding(.bottom, 60)
            }
            .background(colorScheme == .dark ? AppColors.darkBackground : AppColors.background)
            .navigationTitle("Base de Datos Local")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cerrar") { dismiss() }
                }
            }
            .alert("Borrar todo el contenido?", isPresented: $showWipeConfirm) {
                Button("Cancelar", role: .cancel) {}
                Button("Borrar", role: .destructive) {
                    LocalDatabaseService.shared.wipeAll()
                }
            } message: {
                Text("Esto vacía las tres tablas de SwiftData. Los archivos JSON de respaldo no se tocan.")
            }
        }
    }

    // MARK: - Sections

    private var statsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Conteos (fetchCount)")
                .font(AppTypography.captionFont)
                .foregroundColor(AppColors.textSecondary)
            HStack(spacing: 12) {
                statTile(label: "Sesiones", value: "\(sessions.count)", color: AppColors.accent)
                statTile(label: "Audits", value: "\(allAudits.count)", color: AppColors.primary)
                statTile(label: "Usage", value: "\(allUsageEvents.count)", color: AppColors.success)
            }
        }
    }

    private var schemaCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Esquema relacional")
                .font(AppTypography.captionFont)
                .foregroundColor(AppColors.textSecondary)
            VStack(alignment: .leading, spacing: 6) {
                Text("UserSession (id, userId, userName, startedAt, endedAt)")
                Text("  └── AuditLogEntry (FK: session)  ─ cascade")
                Text("  └── UsageEventRecord (FK: session) ─ cascade")
            }
            .font(.system(.footnote, design: .monospaced))
            .foregroundColor(colorScheme == .dark ? AppColors.darkTextPrimary : AppColors.textPrimary)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColors.primary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    private var auditsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("AuditLogEntry — últimos 50")
                    .font(AppTypography.captionFont)
                    .foregroundColor(AppColors.textSecondary)
                Spacer()
                Picker("Filtro", selection: $entityFilter) {
                    ForEach(entityTypes, id: \.self) { Text($0).tag($0) }
                }
                .pickerStyle(.menu)
                .font(.caption)
            }
            if filteredAudits.isEmpty {
                emptyRow(message: "Sin entradas todavía")
            } else {
                VStack(spacing: 0) {
                    ForEach(filteredAudits) { entry in
                        auditRow(entry)
                        if entry.id != filteredAudits.last?.id {
                            Divider().padding(.leading, 12)
                        }
                    }
                }
                .cardStyle()
            }
        }
    }

    private var usageEventsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("UsageEventRecord — últimos 50")
                .font(AppTypography.captionFont)
                .foregroundColor(AppColors.textSecondary)
            let visible = Array(allUsageEvents.prefix(50))
            if visible.isEmpty {
                emptyRow(message: "Sin eventos todavía")
            } else {
                VStack(spacing: 0) {
                    ForEach(visible) { event in
                        usageRow(event)
                        if event.id != visible.last?.id {
                            Divider().padding(.leading, 12)
                        }
                    }
                }
                .cardStyle()
            }
        }
    }

    private var sessionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("UserSession — todas")
                .font(AppTypography.captionFont)
                .foregroundColor(AppColors.textSecondary)
            if sessions.isEmpty {
                emptyRow(message: "Sin sesiones registradas")
            } else {
                VStack(spacing: 0) {
                    ForEach(sessions) { session in
                        sessionRow(session)
                        if session.id != sessions.last?.id {
                            Divider().padding(.leading, 12)
                        }
                    }
                }
                .cardStyle()
            }
        }
    }

    private var wipeButton: some View {
        Button(action: { showWipeConfirm = true }) {
            HStack {
                Image(systemName: "trash")
                Text("Vaciar tablas (sólo SwiftData)")
            }
            .font(AppTypography.captionFont)
            .foregroundColor(AppColors.error)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(AppColors.error.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Row builders

    private func statTile(label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(AppTypography.title2Font)
                .foregroundColor(color)
            Text(label)
                .font(AppTypography.caption2Font)
                .foregroundColor(AppColors.textSecondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func auditRow(_ entry: AuditLogEntry) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(entry.action)
                    .font(AppTypography.captionFont)
                    .foregroundColor(colorScheme == .dark ? AppColors.darkTextPrimary : AppColors.textPrimary)
                Spacer()
                Text(entry.entityType)
                    .font(AppTypography.caption2Font)
                    .padding(.horizontal, 8).padding(.vertical, 2)
                    .background(AppColors.primary.opacity(0.15))
                    .clipShape(Capsule())
            }
            if !entry.details.isEmpty {
                Text(entry.details)
                    .font(AppTypography.caption2Font)
                    .foregroundColor(AppColors.textSecondary)
                    .lineLimit(2)
            }
            HStack {
                Text(entry.timestamp.formatted(date: .abbreviated, time: .shortened))
                    .font(AppTypography.caption2Font)
                    .foregroundColor(AppColors.textTertiary)
                if let session = entry.session {
                    Text("· session \(session.id.uuidString.prefix(6))")
                        .font(AppTypography.caption2Font)
                        .foregroundColor(AppColors.textTertiary)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func usageRow(_ event: UsageEventRecord) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(event.kind)
                    .font(AppTypography.captionFont)
                    .foregroundColor(colorScheme == .dark ? AppColors.darkTextPrimary : AppColors.textPrimary)
                Spacer()
                Text("\(event.hourOfDay):00")
                    .font(AppTypography.caption2Font)
                    .foregroundColor(AppColors.textTertiary)
            }
            if !event.attributes.isEmpty {
                Text(event.attributes.map { "\($0.key)=\($0.value)" }.sorted().joined(separator: " · "))
                    .font(AppTypography.caption2Font)
                    .foregroundColor(AppColors.textSecondary)
                    .lineLimit(1)
            }
            Text(event.timestamp.formatted(date: .abbreviated, time: .shortened))
                .font(AppTypography.caption2Font)
                .foregroundColor(AppColors.textTertiary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func sessionRow(_ session: UserSession) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(session.userName)
                    .font(AppTypography.captionFont)
                    .foregroundColor(colorScheme == .dark ? AppColors.darkTextPrimary : AppColors.textPrimary)
                Spacer()
                Text(session.isActive ? "activa" : "cerrada")
                    .font(AppTypography.caption2Font)
                    .foregroundColor(session.isActive ? AppColors.success : AppColors.textTertiary)
            }
            HStack(spacing: 12) {
                Text("audits: \(session.auditEntries.count)")
                Text("usage: \(session.usageEvents.count)")
            }
            .font(AppTypography.caption2Font)
            .foregroundColor(AppColors.textSecondary)
            Text("Inicio: \(session.startedAt.formatted(date: .abbreviated, time: .shortened))")
                .font(AppTypography.caption2Font)
                .foregroundColor(AppColors.textTertiary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func emptyRow(message: String) -> some View {
        Text(message)
            .font(AppTypography.captionFont)
            .foregroundColor(AppColors.textTertiary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 18)
            .cardStyle()
    }
}
