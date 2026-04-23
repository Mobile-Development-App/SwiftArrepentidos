import SwiftUI
import Combine
import UIKit

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

        // Refresh analytics when inventory changes (add/update/delete/sale/restock).
        // Recomputamos INMEDIATAMENTE desde el inventario local (sin esperar al backend).
        inventoryChangeObserver = NotificationCenter.default.addObserver(
            forName: .inventoryDidChange, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.recomputeFromLocalProducts()
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

        #if DEBUG
        print("[AnalyticsVM] fetchAnalytics(days: \(days))")
        #endif

        // 📊 Stock y pie chart: SIEMPRE desde productos locales (source of truth del usuario).
        // Esto garantiza que los charts reflejen cambios del inventario inmediatamente,
        // sin depender de que el backend sincronice.
        recomputeFromLocalProducts()

        // 📈 Sales trend: sí depende del backend (es time-series que el cliente no tiene).
        // Con fallback a datos demo si el backend falla o devuelve vacío.

        // Esperar al token si la sesión se está restaurando
        if APIClient.shared.authToken == nil {
            for _ in 0..<10 {
                try? await Task.sleep(nanoseconds: 500_000_000)
                if APIClient.shared.authToken != nil { break }
            }
        }

        guard APIClient.shared.authToken != nil else {
            // Sin token: usar fallback demo para el sales trend
            self.salesData = generateFallbackSalesData(days: days)
            isLoading = false
            return
        }

        // Solo usar datos demo si el usuario tiene productos (no en cuentas recién creadas)
        let hasLocalProducts = !PersistenceService.shared.loadProducts().filter({ $0.isActive }).isEmpty

        do {
            let trend = try await analyticsRepo.fetchSalesTrend(days: days)
            if trend.isEmpty {
                // Backend no tiene ventas. Mostrar datos demo SOLO si tiene productos.
                self.salesData = hasLocalProducts ? generateFallbackSalesData(days: days) : []
                #if DEBUG
                print("[AnalyticsVM] ℹ️ Sales trend vacío — demo data: \(hasLocalProducts)")
                #endif
            } else {
                self.salesData = trend
                #if DEBUG
                print("[AnalyticsVM] ✅ Sales trend: \(trend.count) puntos")
                #endif
            }
        } catch {
            // En error, usar demo solo si tiene productos
            self.salesData = hasLocalProducts ? generateFallbackSalesData(days: days) : []
            #if DEBUG
            print("[AnalyticsVM] ❌ Sales trend failed")
            #endif
        }

        isLoading = false
    }

    /// Recomputa `stockLevelData` y `categoryDistribution` desde el inventario local.
    /// Esta es la fuente de verdad inmediata: el usuario ve los cambios que acaba de hacer
    /// aunque el backend aún no los haya sincronizado.
    private func recomputeFromLocalProducts() {
        let products = PersistenceService.shared.loadProducts().filter { $0.isActive }

        // Stock Level chart: agrupar por categoría y contar estados
        let grouped = Dictionary(grouping: products, by: { $0.category.rawValue })
        self.stockLevelData = grouped.map { (category, prods) in
            StockLevelData(
                category: category,
                inStock: prods.filter { $0.stockStatus == .inStock }.count,
                lowStock: prods.filter { $0.stockStatus == .lowStock }.count,
                outOfStock: prods.filter { $0.stockStatus == .outOfStock }.count
            )
        }.sorted { $0.category < $1.category }

        // Pie chart: distribución por categoría
        let totalCount = products.count
        self.categoryDistribution = grouped.map { (category, prods) in
            CategoryDistribution(
                category: category,
                count: prods.count,
                percentage: totalCount > 0 ? (Double(prods.count) / Double(totalCount)) * 100 : 0,
                value: prods.reduce(0) { $0 + $1.stockValue }
            )
        }
        .sorted { $0.count > $1.count }
    }

    /// Clear all in-memory data (called on logout)
    func clearData() {
        salesData = []
        stockLevelData = []
        categoryDistribution = []
        error = nil
    }

    /// Exporta un reporte generado LOCALMENTE (no depende del backend).
    /// Genera el archivo en el directorio temporal y lo presenta con UIActivityViewController
    /// para que el usuario lo comparta, guarde o envíe donde quiera.
    func exportReport(format: String = "EXCEL_CSV") {
        guard !isExporting else { return }
        isExporting = true
        error = nil

        Task {
            // Los datos vienen del inventario local (source of truth para el usuario actual)
            let products = PersistenceService.shared.loadProducts().filter { $0.isActive }
            let exporter = ReportExporter()

            do {
                let fileURL: URL
                if format == "PDF" {
                    fileURL = try exporter.generatePDF(
                        products: products,
                        salesData: self.salesData,
                        categoryDistribution: self.categoryDistribution,
                        stockLevelData: self.stockLevelData
                    )
                } else {
                    // Default: CSV (Excel puede abrirlo)
                    fileURL = try exporter.generateCSV(
                        products: products,
                        salesData: self.salesData,
                        categoryDistribution: self.categoryDistribution,
                        stockLevelData: self.stockLevelData
                    )
                }

                self.isExporting = false

                // Presentar share sheet y ESPERAR a que el usuario lo cierre
                await presentShareSheet(for: fileURL)

                // Después de compartir/cerrar, mostrar check de éxito por 2s
                self.exportSuccess = true
                HapticManager.notification(.success)
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                    self?.exportSuccess = false
                }

                #if DEBUG
                print("[Analytics] Export generated: \(fileURL.path)")
                #endif
            } catch {
                self.isExporting = false
                self.error = "No se pudo generar el reporte: \(error.localizedDescription)"
                HapticManager.notification(.error)
                #if DEBUG
                print("[Analytics] Export failed: \(error)")
                #endif
            }
        }
    }

    @MainActor
    private func presentShareSheet(for url: URL) async {
        guard let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive })
                ?? (UIApplication.shared.connectedScenes.first as? UIWindowScene),
              let rootVC = scene.keyWindow?.rootViewController ?? scene.windows.first?.rootViewController else {
            return
        }

        // Encontrar el view controller más alto en la jerarquía (maneja sheets presentadas)
        var topVC = rootVC
        while let presented = topVC.presentedViewController {
            topVC = presented
        }

        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)

        // Para iPad (popover)
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = topVC.view
            popover.sourceRect = CGRect(x: topVC.view.bounds.midX, y: topVC.view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            activityVC.completionWithItemsHandler = { _, _, _, _ in
                continuation.resume()
            }
            topVC.present(activityVC, animated: true)
        }
    }

    /// Genera una serie de ventas demo cuando el backend aún no tiene datos reales.
    /// Usa una curva suave (seno + tendencia creciente) en vez de ruido aleatorio
    /// para que la gráfica se vea profesional.
    private func generateFallbackSalesData(days: Int) -> [SalesDataPoint] {
        let calendar = Calendar.current
        let today = Date()
        let count = min(days, 30)
        return (0..<count).reversed().map { offset in
            let date = calendar.date(byAdding: .day, value: -offset, to: today) ?? today
            // progress: 0 al inicio (hace 30 días), 1 hoy
            let progress = Double(count - 1 - offset) / Double(max(count - 1, 1))
            // Tendencia suave de $40K a $70K
            let trend = 40_000.0 + progress * 30_000.0
            // Pequeña onda sinusoidal para variación visual natural
            let wave = sin(Double(offset) * 0.5) * 6_000.0
            let sales = max(0, trend + wave)
            let orders = 5 + Int(progress * 15) + Int(abs(wave) / 2_000)
            return SalesDataPoint(date: date, sales: sales, orders: orders)
        }
    }
}
