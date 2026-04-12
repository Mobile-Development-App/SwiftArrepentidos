import SwiftUI
import Combine

@MainActor
class StoreViewModel: ObservableObject {
    @Published var stores: [Store] = []
    @Published var employees: [Employee] = []
    @Published var activeStoreId: UUID?
    @Published var selectedStore: Store?

    @Published var newStoreName = ""
    @Published var newStoreAddress = ""
    @Published var newStorePhone = ""
    @Published var newStoreEmail = ""
    @Published var newStoreManager = ""

    private let persistence = PersistenceService.shared
    private let storeRepo = StoreRepository()
    private var logoutObserver: Any?

    init() {
        logoutObserver = NotificationCenter.default.addObserver(
            forName: .userDidLogout, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.clearData() }
        }
    }

    deinit {
        if let observer = logoutObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    func loadData() {
        stores = persistence.loadStores()
        employees = persistence.loadEmployees()
        if activeStoreId == nil { activeStoreId = stores.first?.id }

        //api
        Task {
            do {
                let remoteStores = try await storeRepo.fetchStores()
                if !remoteStores.isEmpty {
                    self.stores = remoteStores
                    persistence.saveStores(remoteStores)
                    if activeStoreId == nil { activeStoreId = stores.first?.id }
                }
            } catch {
                print("Error fetching stores: \(error)")
            }
        }
    }

    var activeStore: Store? { stores.first { $0.id == activeStoreId } }
    func employees(for storeId: UUID) -> [Employee] { employees.filter { $0.storeId == storeId } }
    var isAddStoreValid: Bool { !newStoreName.isEmpty && !newStoreAddress.isEmpty && !newStorePhone.isEmpty }

    func addStore() {
        guard isAddStoreValid else { return }
        let store = Store(id: UUID(), name: newStoreName, address: newStoreAddress, phone: newStorePhone, email: newStoreEmail, manager: newStoreManager, employeeCount: 0, productCount: 0, monthlySales: 0, isActive: true, createdAt: Date())
        stores.append(store)
        persistence.saveStores(stores)
        clearForm()
        HapticManager.notification(.success)
    }

    func deleteStore(_ store: Store) {
        stores.removeAll { $0.id == store.id }
        employees.removeAll { $0.storeId == store.id }
        persistence.saveStores(stores)
        persistence.saveEmployees(employees)
    }

    func setActiveStore(_ store: Store) { activeStoreId = store.id }

    func clearForm() {
        newStoreName = ""; newStoreAddress = ""; newStorePhone = ""
        newStoreEmail = ""; newStoreManager = ""
    }

    //logout funct
    func clearData() {
        stores = []
        employees = []
        activeStoreId = nil
        selectedStore = nil
    }
}
