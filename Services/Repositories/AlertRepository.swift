import Foundation

protocol AlertRepositoryProtocol {
    func fetchAlerts(type: String?, priority: String?, isRead: Bool?, limit: Int?, cursor: String?) async throws -> (alerts: [InventoryAlert], nextCursor: String?)
    func markAsRead(id: String) async throws
    func markAllAsRead() async throws
    func fetchSummary() async throws -> AlertSummaryDTO
}

final class AlertRepository: AlertRepositoryProtocol {
    private let apiClient = APIClient.shared
    private let cache = PersistenceService.shared
    private let networkMonitor = NetworkMonitor.shared

    func fetchAlerts(type: String? = nil, priority: String? = nil, isRead: Bool? = nil, limit: Int? = nil, cursor: String? = nil) async throws -> (alerts: [InventoryAlert], nextCursor: String?) {
        guard networkMonitor.isConnected else {
            return (cache.loadAlerts(), nil)
        }

        var params: [String: String] = [:]
        if let type { params["type"] = type }
        if let priority { params["priority"] = priority }
        if let isRead { params["isRead"] = String(isRead) }
        if let limit { params["limit"] = String(limit) }
        if let cursor { params["startAfter"] = cursor }

        let (dtos, pagination): ([AlertDTO], APIPagination?) = try await apiClient.requestPaginated(
            .alerts,
            queryParams: params.isEmpty ? nil : params
        )

        let alerts = dtos.map { $0.toDomain() }

        if cursor == nil {
            cache.saveAlerts(alerts)
        }

        return (alerts, pagination?.nextCursor)
    }

    func markAsRead(id: String) async throws {
        guard networkMonitor.isConnected else {
            // Mark locally, sync later
            var alerts = cache.loadAlerts()
            if let index = alerts.firstIndex(where: { $0.id == UUID(deterministicFrom: id) }) {
                alerts[index].isRead = true
                cache.saveAlerts(alerts)
            }
            return
        }

        let _: [String: String] = try await apiClient.request(
            .alertRead(id: id),
            method: .PATCH
        )

        // Update cache
        var alerts = cache.loadAlerts()
        if let index = alerts.firstIndex(where: { $0.id == UUID(deterministicFrom: id) }) {
            alerts[index].isRead = true
            cache.saveAlerts(alerts)
        }
    }

    func markAllAsRead() async throws {
        guard networkMonitor.isConnected else {
            var alerts = cache.loadAlerts()
            for i in alerts.indices { alerts[i].isRead = true }
            cache.saveAlerts(alerts)
            return
        }

        let _: [String: String] = try await apiClient.request(
            .alertsMarkAllRead,
            method: .POST
        )

        var alerts = cache.loadAlerts()
        for i in alerts.indices { alerts[i].isRead = true }
        cache.saveAlerts(alerts)
    }

    func fetchSummary() async throws -> AlertSummaryDTO {
        try await apiClient.request(.alertsSummary)
    }
}
