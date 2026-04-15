import SwiftUI
import Charts

struct HomeView: View {
    @EnvironmentObject var inventoryViewModel: InventoryViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var analyticsViewModel: AnalyticsViewModel
    @State private var showNotifications = false
    @State private var showAddProduct = false
    @State private var showSettings = false

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    welcomeBanner
                    statsGrid
                    salesChart
                    alertsSection
                    quickActions
                    Spacer().frame(height: 80)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            .refreshable {
                inventoryViewModel.refreshData()
                analyticsViewModel.loadData(for: analyticsViewModel.selectedTimeRange)
                // Wait briefly for loading
                try? await Task.sleep(nanoseconds: 2_000_000_000)
            }
            .background(colorScheme == .dark ? AppColors.darkBackground : AppColors.background)
            .navigationTitle("Inicio")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showSettings = true }) {
                        Image(systemName: "gearshape.fill")
                            .foregroundColor(colorScheme == .dark ? AppColors.darkTextPrimary : AppColors.textPrimary)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showNotifications = true }) {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "bell.fill")
                                .foregroundColor(colorScheme == .dark ? AppColors.darkTextPrimary : AppColors.textPrimary)
                            if inventoryViewModel.unreadAlertCount > 0 {
                                Text("\(min(inventoryViewModel.unreadAlertCount, 9))\(inventoryViewModel.unreadAlertCount > 9 ? "+" : "")")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(3)
                                    .background(AppColors.error)
                                    .clipShape(Circle())
                                    .offset(x: 6, y: -6)
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showNotifications) { NotificationsView() }
            .sheet(isPresented: $showAddProduct) { AddProductView() }
            .sheet(isPresented: $showSettings) { SettingsView() }
        }
    }

    private var welcomeBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Bienvenido, \(authViewModel.currentUser?.fullName.split(separator: " ").first.map(String.init) ?? "Usuario") \u{1F44B}")
                .font(AppTypography.title3Font)
                .foregroundColor(.white)
            Text("Tu inventario esta al dia. Aqui tienes un resumen.")
                .font(AppTypography.captionFont)
                .foregroundColor(.white.opacity(0.8))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            LinearGradient(
                colors: [AppColors.deepSpaceBlue, AppColors.inkBlack],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            StatCardView(title: "Total Productos", value: "\(inventoryViewModel.dashboardStats.totalProducts)", icon: "shippingbox.fill", iconColor: AppColors.deepSpaceBlue, trend: 5.2)
            StatCardView(title: "Stock Bajo", value: "\(inventoryViewModel.dashboardStats.lowStockCount)", icon: "exclamationmark.triangle.fill", iconColor: AppColors.warning)
            StatCardView(title: "Agotados", value: "\(inventoryViewModel.dashboardStats.outOfStockCount)", icon: "xmark.circle.fill", iconColor: AppColors.error)
            StatCardView(title: "Valor en Stock", value: inventoryViewModel.dashboardStats.totalStockValue.compactCurrency, icon: "dollarsign.circle.fill", iconColor: AppColors.success, trend: 12.5)
        }
    }

    private var salesChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Ventas Semanales").font(AppTypography.headlineFont)
                Spacer()
                let total = analyticsViewModel.salesData.reduce(0) { $0 + $1.sales }
                Text(total.compactCurrency)
                    .font(AppTypography.calloutFont).foregroundColor(AppColors.success)
            }

            if analyticsViewModel.salesData.isEmpty {
                // Empty state when no sales data
                VStack(spacing: 12) {
                    Image(systemName: "chart.line.downtrend.xyaxis")
                        .font(.system(size: 36))
                        .foregroundColor(AppColors.textTertiary)
                    Text("Sin datos de ventas")
                        .font(AppTypography.calloutFont)
                        .foregroundColor(AppColors.textSecondary)
                    Text("Las ventas aparecerán aquí cuando se registren transacciones")
                        .font(AppTypography.caption2Font)
                        .foregroundColor(AppColors.textTertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 180)
            } else {
                Chart(analyticsViewModel.salesData) { point in
                    LineMark(x: .value("Dia", point.date, unit: .day), y: .value("Ventas", point.sales))
                        .foregroundStyle(AppColors.freshSky)
                        .lineStyle(StrokeStyle(lineWidth: 2.5))
                    AreaMark(x: .value("Dia", point.date, unit: .day), y: .value("Ventas", point.sales))
                        .foregroundStyle(
                            LinearGradient(colors: [AppColors.freshSky.opacity(0.3), AppColors.freshSky.opacity(0.05)], startPoint: .top, endPoint: .bottom)
                        )
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { value in
                        AxisValueLabel {
                            if let date = value.as(Date.self) { Text(date.dayOfWeek).font(.system(size: 10)) }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisValueLabel {
                            if let val = value.as(Double.self) { Text(val.compactCurrency).font(.system(size: 10)) }
                        }
                    }
                }
                .frame(height: 180)
            }
        }
        .padding(16)
        .cardStyle()
    }

    private var alertsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "sparkles").foregroundColor(AppColors.teaGreen)
                Text("Alertas IA").font(AppTypography.headlineFont)
                Spacer()
                if inventoryViewModel.unreadAlertCount > 0 {
                    BadgeView(text: "\(inventoryViewModel.unreadAlertCount) nuevas", style: .warning)
                }
            }
            ForEach(inventoryViewModel.alerts.prefix(3)) { alert in
                AlertCardView(alert: alert) { inventoryViewModel.markAlertAsRead(alert) }
            }
            if inventoryViewModel.alerts.count > 3 {
                Button(action: { showNotifications = true }) {
                    HStack {
                        Text("Ver todas las alertas").font(AppTypography.calloutFont)
                        Image(systemName: "arrow.right").font(.system(size: 12))
                    }
                    .foregroundColor(AppColors.freshSky)
                    .frame(maxWidth: .infinity).padding(.vertical, 8)
                }
            }
        }
        .padding(16)
        .cardStyle()
    }

    // MARK: - Quick Actions
    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Acciones Rapidas").font(AppTypography.headlineFont)
            HStack(spacing: 12) {
                quickActionButton(icon: "camera.viewfinder", title: "Escanear con IA", color: AppColors.deepSpaceBlue) {}
                quickActionButton(icon: "plus.circle.fill", title: "Agregar Producto", color: AppColors.teaGreen) { showAddProduct = true }
            }
        }
    }

    private func quickActionButton(icon: String, title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: { action(); HapticManager.impact(.medium) }) {
            VStack(spacing: 10) {
                Image(systemName: icon).font(.system(size: 28)).foregroundColor(color)
                Text(title).font(AppTypography.captionFont)
                    .foregroundColor(colorScheme == .dark ? AppColors.darkTextPrimary : AppColors.textPrimary)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 20).cardStyle()
        }
        .buttonStyle(.plain)
    }
}
