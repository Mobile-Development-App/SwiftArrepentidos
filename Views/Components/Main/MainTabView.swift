import SwiftUI

/// MainTabView - Bottom navigation per Sprint 1 / MS6:
/// Home | Inventario | Scan (center FAB) | Reabastecimiento | Analitica
/// Settings accessible from Home toolbar.
struct MainTabView: View {
    @State private var selectedTab: Tab = .home
    @State private var showScanSheet = false
    @EnvironmentObject var inventoryViewModel: InventoryViewModel
    @EnvironmentObject var analyticsViewModel: AnalyticsViewModel
    @EnvironmentObject var storeViewModel: StoreViewModel

    enum Tab: String, CaseIterable {
        case home = "Inicio"
        case products = "Inventario"
        case scan = "Escanear"
        case restock = "Reabastecer"
        case analytics = "Analitica"

        var icon: String {
            switch self {
            case .home: return "house.fill"
            case .products: return "shippingbox.fill"
            case .scan: return "viewfinder"
            case .restock: return "arrow.clockwise.circle.fill"
            case .analytics: return "chart.bar.fill"
            }
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                HomeView().tag(Tab.home)
                ProductsView().tag(Tab.products)
                Color.clear.tag(Tab.scan)
                RestockView().tag(Tab.restock)
                AnalyticsView().tag(Tab.analytics)
            }
            .tabViewStyle(.automatic)

            customTabBar
        }
        .onChange(of: selectedTab) { _, newValue in
            // BQ5
            Task.detached(priority: .utility) {
                await AnalyticsLogService.shared.record(
                    kind: .screenViewed,
                    attributes: ["screen": newValue.rawValue]
                )
            }
            if newValue == .scan {
                showScanSheet = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    selectedTab = .home
                }
            }
        }}
        .fullScreenCover(isPresented: $showScanSheet) {
            ScanView()
        }
        .onAppear {
            // Load data now that user is authenticated and storeId is available
            inventoryViewModel.loadData()
            analyticsViewModel.loadData(for: analyticsViewModel.selectedTimeRange)
            storeViewModel.loadData()
        }
    }

    private var customTabBar: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases, id: \.self) { tab in
                if tab == .scan {
                    // Center scan button with Tea Green (wiki palette)
                    Button(action: {
                        showScanSheet = true
                        HapticManager.impact(.medium)
                    }) {
                        ZStack {
                            Circle()
                                .fill(AppColors.teaGreen)
                                .frame(width: 56, height: 56)
                                .shadow(color: AppColors.teaGreen.opacity(0.3), radius: 8, y: 4)

                            Image(systemName: tab.icon)
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundColor(AppColors.inkBlack)
                        }
                        .offset(y: -16)
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    Button(action: {
                        selectedTab = tab
                        HapticManager.selection()
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 20))
                                .foregroundColor(selectedTab == tab ? AppColors.freshSky : AppColors.textTertiary)

                            Text(tab.rawValue)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(selectedTab == tab ? AppColors.freshSky : AppColors.textTertiary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)
                    }
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 20)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.05), radius: 8, y: -2)
                .ignoresSafeArea(edges: .bottom)
        )
    }
}
