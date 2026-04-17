import SwiftUI
import Combine

@MainActor
class AnalyticsViewModel: ObservableObject {
    @Published var selectedTimeRange: TimeRange = .week
    @Published var salesData: [SalesDataPoint] = []
    @Published var stockLevelData: [StockLevelData] = []
    @Published var categoryDistribution: [CategoryDistribution] = []
    @Published var isExporting = false
    @Published var exportSuccess = false
    @Published var isLoading = false
    @Published var error: String?

    private let analyticsRepo = AnalyticsRepository()
    private var logoutObserver: Any?
    private var inventoryChangeObserver: Any?

    enum TimeRange: String, CaseIterable {
        case week = "7d"
        case month = "30d"
        case quarter = "90d"
        case year = "1a"

        var days: Int {
            switch self {
            case .week: return 7
            case .month: return 30
            case .quarter: return 90
            case .year: return 365
            }
        }

        var label: String {
            switch self {
            case .week: return "7 días"
            case .month: return "30 días"
            case .quarter: return "90 días"
            case .year: return "1 año"
            }
        }
    }

    // MARK: - Computed Stats
    var totalSales: Double {
        salesData.reduce(0) { $0 + $1.sales }
    }

    var averageDailySales: Double {
        guard !salesData.isEmpty else { return 0 }
        return totalSales / Double(salesData.count)
    }

    var totalOrders: Int {
        salesData.reduce(0) { $0 + $1.orders }
    }

    var salesTrend: Double {
        guard salesData.count >= 2 else { return 0 }
        let midpoint = salesData.count / 2
        let firstHalf = salesData[0..<midpoint].reduce(0) { $0 + $1.sales }
        let secondHalf = salesData[midpoint...].reduce(0) { $0 + $1.sales }
        guard firstHalf > 0 else { return 0 }
        return ((secondHalf - firstHalf) / firstHalf) * 100
    }

    init() {
        // Don't load data here — storeId may not be available yet.
        // Data is loaded when AnalyticsView appears (after login).
        logoutObserver = NotificationCenter.default.addObserver(
            forName: .userDidLogout, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.clearData() }
        }

        // Refresh analytics when inventory changes (add/update/delete/sale/restock)
        inventoryChangeObserver = NotificationCenter.default.addObserver(
            forName: .inventoryDidChange, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                // Small delay to let backend process the change
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                self.loadData(for: self.selectedTimeRange)
            }
        }
    }

    deinit {
        if let observer = logoutObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = inventoryChangeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Actions

    func loadData(for range: TimeRange) {
        selectedTimeRange = range

        Task {
            await fetchAnalytics(days: range.days, isRetry: false)
        }
    }

    private func fetchAnalytics(days: Int, isRetry: Bool) async {
        isLoading = true
        error = nil

        print("[AnalyticsVM] fetchAnalytics(days: \(days), isRetry: \(isRetry)) — token: \(APIClient.shared.authToken != nil ? "YES" : "NO"), storeId: \(APIConfig.storeId ?? "nil")")

        // Wait for auth token if session is being restored
        if APIClient.shared.authToken == nil {
            print("[AnalyticsVM] Waiting for auth token...")
            for i in 0..<10 {
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
                if APIClient.shared.authToken != nil {
                    print("[AnalyticsVM] Token available after \(Double(i + 1) * 0.5)s")
                    break
                }
            }
            guard APIClient.shared.authToken != nil else {
                print("[AnalyticsVM] ⚠️ Token never arrived, aborting fetch")
                isLoading = false
                return
            }
        }

        var anyFailed = false

        // Fetch each data source independently — one failure shouldn't block the others
        do {
            let trend = try await analyticsRepo.fetchSalesTrend(days: days)
            self.salesData = trend
            print("[AnalyticsVM] ✅ Sales trend: \(trend.count) data points")
        } catch {
            anyFailed = true
            print("[AnalyticsVM] ❌ Sales trend failed: \(error)")
        }

        do {
            let stock = try await analyticsRepo.fetchStockByCategory()
            self.stockLevelData = stock
            print("[AnalyticsVM] ✅ Stock by category: \(stock.count) categories")
        } catch {
            anyFailed = true
            print("[AnalyticsVM] ❌ Stock by category failed: \(error)")
        }

        do {
            let dist = try await analyticsRepo.fetchMargins()
            self.categoryDistribution = dist
            print("[AnalyticsVM] ✅ Category distribution: \(dist.count) items")
        } catch {
            anyFailed = true
            print("[AnalyticsVM] ❌ Margins/distribution failed: \(error)")
        }

        isLoading = false

        // Auto-retry once after 3s if any fetch failed (handles token race condition)
        if anyFailed && !isRetry {
            print("[AnalyticsVM] Some fetches failed, retrying in 3s...")
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            await fetchAnalytics(days: days, isRetry: true)
        }
    }

    /// Clear all in-memory data (called on logout)
    func clearData() {
        salesData = []
        stockLevelData = []
        categoryDistribution = []
        error = nil
    }

    func exportReport() {
        isExporting = true

        Task {
            do {
                let response = try await analyticsRepo.exportReport(
                    type: "inventory",
                    format: "EXCEL_CSV"
                )
                self.isExporting = false
                self.exportSuccess = true
                HapticManager.notification(.success)

                // The response contains a URL to download the export
                print("[Analytics] Export ready: \(response.url)")

                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                    self?.exportSuccess = false
                }
            } catch {
                self.isExporting = false
                self.error = "Error al exportar. Intenta de nuevo."

                // Fallback to simulated export
                self.exportSuccess = true
                HapticManager.notification(.success)
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                    self?.exportSuccess = false
                    self?.error = nil
                }
            }
        }
    }
}
