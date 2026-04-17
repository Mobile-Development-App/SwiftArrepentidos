import SwiftUI
import Charts

struct StoreDetailView: View {
    let store: Store
    @EnvironmentObject var storeViewModel: StoreViewModel
    @EnvironmentObject var inventoryViewModel: InventoryViewModel
    @EnvironmentObject var analyticsViewModel: AnalyticsViewModel
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme

    @State private var selectedTab = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    heroSection
                    quickStats
                    tabSelector
                    switch selectedTab {
                    case 0: overviewTab
                    case 1: analyticsTab
                    case 2: productsTab
                    case 3: teamTab
                    default: overviewTab
                    }

                    Spacer().frame(height: 20)
                }
                .padding(.horizontal, 16)
            }
            .background(colorScheme == .dark ? AppColors.darkBackground : AppColors.background)
            .navigationTitle(store.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                    }
                }
            }
        }
    }

    private var heroSection: some View {
        VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: [AppColors.primary, AppColors.primaryLight],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 120)

                VStack(spacing: 4) {
                    Image(systemName: "storefront.fill")
                        .font(.system(size: 36))
                        .foregroundColor(.white)
                    Text(store.name)
                        .font(AppTypography.title3Font)
                        .foregroundColor(.white)
                    Text(store.address)
                        .font(AppTypography.caption2Font)
                        .foregroundColor(.white.opacity(0.8))
                }
            }
        }
    }
    private var quickStats: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
            miniStat(icon: "shippingbox", value: "\(store.productCount)", label: "Productos")
            miniStat(icon: "dollarsign.circle", value: store.formattedSales, label: "Ventas/Mes")
            miniStat(icon: "bag", value: "\(Int.random(in: 20...50))", label: "Pedidos")
            miniStat(icon: "person.2", value: "\(store.employeeCount)", label: "Equipo")
        }
    }

    private func miniStat(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(AppColors.primary)
            Text(value)
                .font(AppTypography.captionFont)
                .fontWeight(.semibold)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .cardStyle()
    }

    private var tabSelector: some View {
        HStack(spacing: 0) {
            ForEach(0..<4) { index in
                let titles = ["General", "Analítica", "Productos", "Equipo"]
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) { selectedTab = index }
                    HapticManager.selection()
                }) {
                    Text(titles[index])
                        .font(AppTypography.captionFont)
                        .fontWeight(.medium)
                        .foregroundColor(selectedTab == index ? .white : AppColors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(selectedTab == index ? AppColors.primary : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding(4)
        .background(colorScheme == .dark ? AppColors.darkSurface : AppColors.surfaceSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var overviewTab: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Tendencia de Ventas")
                    .font(AppTypography.headlineFont)

                Chart(analyticsViewModel.salesData) { point in
                    AreaMark(
                        x: .value("Día", point.date, unit: .day),
                        y: .value("Ventas", point.sales)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [AppColors.primary.opacity(0.3), AppColors.primary.opacity(0.05)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    LineMark(
                        x: .value("Día", point.date, unit: .day),
                        y: .value("Ventas", point.sales)
                    )
                    .foregroundStyle(AppColors.primary)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                }
                .frame(height: 150)
            }
            .padding(16)
            .cardStyle()
            VStack(alignment: .leading, spacing: 12) {
                Text("Información de la Tienda")
                    .font(AppTypography.headlineFont)

                infoRow(icon: "mappin", label: "Dirección", value: store.address)
                infoRow(icon: "phone", label: "Teléfono", value: store.phone)
                infoRow(icon: "envelope", label: "Email", value: store.email)
                infoRow(icon: "person", label: "Gerente", value: store.manager)
                infoRow(icon: "calendar", label: "Creada", value: store.createdAt.shortFormatted)
            }
            .padding(16)
            .cardStyle()
        }
    }

    private var analyticsTab: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Ventas vs Pedidos")
                    .font(AppTypography.headlineFont)

                Chart(analyticsViewModel.salesData) { point in
                    BarMark(
                        x: .value("Día", point.date, unit: .day),
                        y: .value("Ventas", point.sales)
                    )
                    .foregroundStyle(AppColors.primary.opacity(0.7))
                }
                .frame(height: 180)
            }
            .padding(16)
            .cardStyle()

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                metricCard(title: "Tasa de Rotación", value: "4.2x", color: AppColors.success)
                metricCard(title: "Margen Promedio", value: "32.5%", color: AppColors.primary)
                metricCard(title: "Productos Activos", value: "\(store.productCount)", color: AppColors.info)
                metricCard(title: "Alertas Activas", value: "5", color: AppColors.warning)
            }
        }
    }

    private var productsTab: some View {
        VStack(spacing: 16) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                metricCard(title: "Total", value: "\(store.productCount)", color: AppColors.primary)
                metricCard(title: "En Stock", value: "\(store.productCount - 15)", color: AppColors.success)
                metricCard(title: "Stock Bajo", value: "12", color: AppColors.warning)
                metricCard(title: "Agotados", value: "3", color: AppColors.error)
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Productos Principales")
                    .font(AppTypography.headlineFont)

                ForEach(inventoryViewModel.products.prefix(3)) { product in
                    HStack(spacing: 12) {
                        Image(systemName: product.category.icon)
                            .foregroundColor(AppColors.primary)
                            .frame(width: 32, height: 32)
                            .background(AppColors.primary.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(product.name)
                                .font(AppTypography.captionFont)
                                .fontWeight(.medium)
                            Text("\(product.quantity) unidades")
                                .font(AppTypography.caption2Font)
                                .foregroundColor(AppColors.textSecondary)
                        }

                        Spacer()

                        Text(product.salePrice.currencyFormatted)
                            .font(AppTypography.captionFont)
                            .fontWeight(.semibold)
                    }
                    .padding(.vertical, 4)
                }
            }
            .padding(16)
            .cardStyle()
        }
    }

    private var teamTab: some View {
        VStack(spacing: 16) {
            let storeEmployees = storeViewModel.employees(for: store.id)

            if storeEmployees.isEmpty {
                EmptyStateView(
                    icon: "person.2",
                    title: "Sin miembros",
                    description: "No hay miembros asignados a esta tienda"
                )
                .frame(height: 200)
            } else {
                ForEach(storeEmployees) { employee in
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(AppColors.primary.opacity(0.15))
                                .frame(width: 44, height: 44)
                            Text(employee.initials)
                                .font(AppTypography.captionFont)
                                .fontWeight(.semibold)
                                .foregroundColor(AppColors.primary)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(employee.fullName)
                                .font(AppTypography.calloutFont)
                                .fontWeight(.medium)
                            Text(employee.role.rawValue)
                                .font(AppTypography.caption2Font)
                                .foregroundColor(AppColors.textSecondary)
                        }

                        Spacer()

                        BadgeView(text: employee.isActive ? "Activo" : "Inactivo",
                                  style: employee.isActive ? .success : .secondary)
                    }
                    .padding(14)
                    .cardStyle()
                }
            }
        }
    }
    //helpers
    private func infoRow(icon: String, label: String, value: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(AppColors.textTertiary)
                .frame(width: 24)
            Text(label)
                .font(AppTypography.captionFont)
                .foregroundColor(AppColors.textSecondary)
            Spacer()
            Text(value)
                .font(AppTypography.captionFont)
                .fontWeight(.medium)
        }
        .padding(.vertical, 2)
    }

    private func metricCard(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Text(value)
                .font(AppTypography.title3Font)
                .foregroundColor(color)
            Text(title)
                .font(AppTypography.caption2Font)
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(14)
        .cardStyle()
    }
}
