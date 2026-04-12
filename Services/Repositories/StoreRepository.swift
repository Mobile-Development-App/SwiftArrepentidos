import Foundation

protocol StoreRepositoryProtocol {
    func fetchStores() async throws -> [Store]
}

final class StoreRepository: StoreRepositoryProtocol {
    private let apiClient = APIClient.shared
    private let cache = PersistenceService.shared
    private let networkMonitor = NetworkMonitor.shared

    func fetchStores() async throws -> [Store] {
        guard networkMonitor.isConnected else {
            return cache.loadStores()
        }

        //añadir endpoint para obtener las tiendas mas adelante
        return cache.loadStores()
    }
}
