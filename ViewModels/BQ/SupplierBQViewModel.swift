import SwiftUI
import Combine


@MainActor
final class SupplierBQViewModel: ObservableObject {

    @Published private(set) var report: SupplierPerformanceReport?
    @Published private(set) var isLoading = false

    private let store = PurchaseOrderStore.shared

    func refresh() async {
        isLoading = true
        defer { isLoading = false }
        let orders = await store.allOrders()
        guard !orders.isEmpty else {
            report = nil
            return
        }
        report = await SupplierPerformanceService.report(orders: orders)
    }
}
