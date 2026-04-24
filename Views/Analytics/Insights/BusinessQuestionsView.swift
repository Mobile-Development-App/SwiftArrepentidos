import SwiftUI
import Charts

/// Sprint 3 Business Questions dashboard (Juan Felipe).
///
///   • BQ2 — Inventory valuation per store
///   • BQ6 — Peak hours at which the user adds products
///

struct BusinessQuestionsView: View {
    @EnvironmentObject private var inventoryViewModel: InventoryViewModel
    @EnvironmentObject private var storeViewModel: StoreViewModel

    @StateObject private var viewModel = BusinessQuestionsViewModel()
    @StateObject private var sprint3VM = Sprint3BQsViewModel()
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
            // When we transition online, re-run so the valuation picks up
            // anything the inventory sync pulled in.
            guard isConnected else { return }
            Task { await sprint3VM.refresh()
                await AnalyticsLogService.shared.record(
                kind: .featureAccessed,
                attributes: ["feature": "business_questions_screen"]
            ) }
        }
    }

    private func refresh() async {
        await viewModel.refresh(
            stores: storeViewModel.stores,
            products: inventoryViewModel.products
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
