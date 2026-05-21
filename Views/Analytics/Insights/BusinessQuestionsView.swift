import SwiftUI
import Charts

struct BusinessQuestionsView: View {
    @EnvironmentObject private var inventoryViewModel: InventoryViewModel
    @EnvironmentObject private var storeViewModel: StoreViewModel

    @StateObject private var viewModel = BusinessQuestionsViewModel()
    @StateObject private var sprint3VM = Sprint3BQsViewModel()
    @StateObject private var insightsVM = InventoryInsightsViewModel()
    @StateObject private var sprint4VM = Sprint4BQsViewModel()
    @StateObject private var wasteBQVM = WasteBQViewModel()
    @StateObject private var supplierBQVM = SupplierBQViewModel()
    @ObservedObject private var network = NetworkMonitor.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                connectivityBanner
                InventoryValuationCard(
                    snapshot: viewModel.valuation,
                    isLoading: viewModel.isLoadingValuation,
                    currencyFormatter: viewModel.currencyString
                )
                PeakActivityHoursCard(
                    summary: viewModel.peakActivity,
                    isLoading: viewModel.isLoadingPeak
                )
                PipelineLatencyCard(
                    summary: sprint3VM.latency,
                    isLoading: sprint3VM.isLoading
                )
                PeakScreensCard(
                    summary: sprint3VM.peakScreens,
                    isLoading: sprint3VM.isLoading
                )
                ScanAccuracyCard(
                    summary: sprint3VM.scanAccuracy,
                    isLoading: sprint3VM.isLoading
                )
                FeatureUsageCard(
                    summary: sprint3VM.featureUsage,
                    isLoading: sprint3VM.isLoading
                )
                RestockCyclesCard(
                    dashboard: insightsVM.restockDashboard,
                    isLoading: insightsVM.isLoadingRestock
                )
                ExpirationActionCard(
                    dashboard: insightsVM.expirationDashboard,
                    isLoading: insightsVM.isLoadingExpiration
                )
                // Sprint 4 — BQ9 (Juan Felipe)
                StockAccuracyCard(
                    summary: sprint4VM.stockAccuracy,
                    sessionsAnalyzed: sprint4VM.sessionsAnalyzed,
                    isLoading: sprint4VM.isLoading
                )
                // Sprint 4 — BQ10 (Santiago)
                WasteReportCard(
                    report: wasteBQVM.report,
                    isLoading: wasteBQVM.isLoading
                )
                // Sprint 4 — BQ11 (Angel)
                SupplierPerformanceCard(
                    report: supplierBQVM.report,
                    isLoading: supplierBQVM.isLoading
                )
                Spacer().frame(height: 40)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
        }
        .navigationTitle("Business Questions")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await refresh() }
        .task { await refresh() }
        .onChange(of: network.isConnected) { _, isConnected in
            guard isConnected else { return }
            Task { await refresh() }
        }
    }

    private func refresh() async {
        await viewModel.refresh(
            stores: storeViewModel.stores,
            products: inventoryViewModel.products
        )
        await sprint3VM.refresh()
        await insightsVM.refresh(products: inventoryViewModel.products)
        await sprint4VM.refresh()
        await wasteBQVM.refresh()
        await supplierBQVM.refresh()
        // BQ8
        await AnalyticsLogService.shared.record(
            kind: .featureAccessed,
            attributes: ["feature": "business_questions_screen"]
        )
    }

    @ViewBuilder
    private var connectivityBanner: some View {
        if !network.isConnected {
            HStack(spacing: 8) {
                Image(systemName: "wifi.slash")
                Text("Sin conexión — mostrando la última aggregation local")
                    .font(.footnote)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .foregroundColor(AppColors.inkBlack)
            .padding(10)
            .background(AppColors.teaGreen.opacity(0.25))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
}
