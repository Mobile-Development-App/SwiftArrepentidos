import SwiftUI
import Charts

struct AnalyticsView: View {
    @EnvironmentObject var analyticsViewModel: AnalyticsViewModel
    @EnvironmentObject var inventoryViewModel: InventoryViewModel
    @Environment(\.colorScheme) var colorScheme

    @State private var showExportSheet = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Loading indicator
                    if analyticsViewModel.isLoading {
                        ProgressView("Cargando datos...")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }

                    // Time range selector
                    timeRangeSelector

                    // Summary stats
                    summaryStats

                    // Sales trend chart
                    salesTrendChart

                    // Stock levels chart
                    stockLevelsChart

                    // Category distribution
                    categoryDistributionChart

                    Spacer().frame(height: 80)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            .refreshable {
                analyticsViewModel.loadData(for: analyticsViewModel.selectedTimeRange)
                // Wait for loading to complete
                while analyticsViewModel.isLoading {
                    try? await Task.sleep(nanoseconds: 200_000_000)
                }
            }
            .background(colorScheme == .dark ? AppColors.darkBackground : AppColors.background)
            .navigationTitle("Analítica")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        Button(action: {
                            analyticsViewModel.loadData(for: analyticsViewModel.selectedTimeRange)
                        }) {
                            Image(systemName: "arrow.clockwise")
                                .foregroundColor(AppColors.primary)
                        }
                        Button(action: { showExportSheet = true }) {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundColor(AppColors.primary)
                        }
                    }
                }
            }
            .sheet(isPresented: $showExportSheet) {
                exportSheet
            }
            .onAppear {
                // Always reload when tab appears to ensure fresh data
                analyticsViewModel.loadData(for: analyticsViewModel.selectedTimeRange)
            }
        }
    }

    // MARK: - Time Range Selector
    private var timeRangeSelector: some View {
        HStack(spacing: 0) {
            ForEach(AnalyticsViewModel.TimeRange.allCases, id: \.self) { range in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        analyticsViewModel.loadData(for: range)
                    }
                    HapticManager.selection()
                }) {
                    Text(range.rawValue)
                        .font(AppTypography.captionFont)
                        .fontWeight(.medium)
                        .foregroundColor(analyticsViewModel.selectedTimeRange == range ? .white : AppColors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            analyticsViewModel.selectedTimeRange == range ?
                                AppColors.primary : Color.clear
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding(4)
        .background(colorScheme == .dark ? AppColors.darkSurface : AppColors.surfaceSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Summary Stats
    private var summaryStats: some View {
        HStack(spacing: 12) {
            summaryCard(
                title: "Ventas Totales",
                value: analyticsViewModel.totalSales.compactCurrency,
                trend: analyticsViewModel.salesTrend,
                icon: "dollarsign.circle.fill",
                color: AppColors.success
            )

            summaryCard(
                title: "Promedio Diario",
                value: analyticsViewModel.averageDailySales.compactCurrency,
                icon: "chart.line.uptrend.xyaxis",
                color: AppColors.primary
            )

            summaryCard(
                title: "Pedidos",
                value: "\(analyticsViewModel.totalOrders)",
                icon: "bag.fill",
                color: AppColors.secondary
            )
        }
    }

    private func summaryCard(title: String, value: String, trend: Double? = nil, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(color)

            Text(value)
                .font(AppTypography.headlineFont)
                .foregroundColor(colorScheme == .dark ? AppColors.darkTextPrimary : AppColors.textPrimary)

            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(AppColors.textSecondary)
                .lineLimit(1)

            if let trend = trend {
                HStack(spacing: 2) {
                    Image(systemName: trend >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.system(size: 8, weight: .bold))
                    Text(String(format: "%.1f%%", abs(trend)))
                        .font(.system(size: 9, weight: .semibold))
                }
                .foregroundColor(trend >= 0 ? AppColors.success : AppColors.error)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .cardStyle()
    }

    // MARK: - Sales Trend Chart
    private var salesTrendChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Tendencia de Ventas")
                    .font(AppTypography.headlineFont)
                Spacer()
                Text(analyticsViewModel.selectedTimeRange.label)
                    .font(AppTypography.captionFont)
                    .foregroundColor(AppColors.textSecondary)
            }

            if analyticsViewModel.salesData.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "chart.line.downtrend.xyaxis")
                        .font(.system(size: 36))
                        .foregroundColor(AppColors.textTertiary)
                    Text("Sin datos de ventas")
                        .font(AppTypography.calloutFont)
                        .foregroundColor(AppColors.textSecondary)
                    Text("Registra ventas para ver la tendencia aquí")
                        .font(AppTypography.caption2Font)
                        .foregroundColor(AppColors.textTertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 200)
            } else {
                Chart(analyticsViewModel.salesData) { point in
                    LineMark(
                        x: .value("Fecha", point.date, unit: .day),
                        y: .value("Ventas", point.sales)
                    )
                    .foregroundStyle(AppColors.primary)
                    .lineStyle(StrokeStyle(lineWidth: 2))

                    AreaMark(
                        x: .value("Fecha", point.date, unit: .day),
                        y: .value("Ventas", point.sales)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [AppColors.primary.opacity(0.2), AppColors.primary.opacity(0.02)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisValueLabel {
                            if let val = value.as(Double.self) {
                                Text(val.compactCurrency)
                                    .font(.system(size: 9))
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 5)) { value in
                        AxisValueLabel {
                            if let date = value.as(Date.self) {
                                Text(date.dayMonth)
                                    .font(.system(size: 9))
                            }
                        }
                    }
                }
                .frame(height: 200)
            }
        }
        .padding(16)
        .cardStyle()
    }

    // MARK: - Stock Levels Chart
    private var stockLevelsChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Niveles de Stock")
                .font(AppTypography.headlineFont)

            if analyticsViewModel.stockLevelData.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "chart.bar")
                        .font(.system(size: 36))
                        .foregroundColor(AppColors.textTertiary)
                    Text("Sin datos de stock")
                        .font(AppTypography.calloutFont)
                        .foregroundColor(AppColors.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 200)
            } else {
                Chart(analyticsViewModel.stockLevelData) { item in
                    BarMark(
                        x: .value("Categoría", item.category),
                        y: .value("Unidades", item.inStock)
                    )
                    .foregroundStyle(AppColors.success.gradient)
                    .cornerRadius(4)
                }
                .chartYAxis {
                    AxisMarks(position: .trailing) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let val = value.as(Int.self) {
                                Text("\(val)")
                                    .font(.system(size: 9))
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks { value in
                        AxisValueLabel {
                            if let label = value.as(String.self) {
                                Text(label.prefix(1).uppercased() + label.dropFirst())
                                    .font(.system(size: 9))
                            }
                        }
                    }
                }
                .frame(height: 200)
            }
        }
        .padding(16)
        .cardStyle()
    }

    // MARK: - Category Distribution
    private var categoryDistributionChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Distribución por Categoría")
                .font(AppTypography.headlineFont)

            if analyticsViewModel.categoryDistribution.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "chart.pie")
                        .font(.system(size: 36))
                        .foregroundColor(AppColors.textTertiary)
                    Text("Sin datos de categorías")
                        .font(AppTypography.calloutFont)
                        .foregroundColor(AppColors.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 200)
            } else {
                Chart(analyticsViewModel.categoryDistribution) { item in
                    SectorMark(
                        angle: .value("Cantidad", item.count),
                        innerRadius: .ratio(0.5),
                        outerRadius: .ratio(1.0)
                    )
                    .foregroundStyle(by: .value("Categoría", item.category))
                }
                .frame(height: 200)

                // Legend
                VStack(spacing: 8) {
                    ForEach(analyticsViewModel.categoryDistribution) { item in
                        HStack {
                            Circle()
                                .fill(categoryColor(for: item.category))
                                .frame(width: 8, height: 8)

                            Text(item.category)
                                .font(AppTypography.captionFont)
                                .foregroundColor(colorScheme == .dark ? AppColors.darkTextPrimary : AppColors.textPrimary)

                            Spacer()

                            Text("\(item.count) (\(item.percentage.percentFormatted))")
                                .font(AppTypography.captionFont)
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }
                }
            }
        }
        .padding(16)
        .cardStyle()
    }

    // MARK: - Export Sheet
    private var exportSheet: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if analyticsViewModel.exportSuccess {
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 56))
                            .foregroundColor(AppColors.success)
                        Text("Reporte Exportado")
                            .font(AppTypography.titleFont)
                        Text("El reporte se ha descargado correctamente")
                            .font(AppTypography.calloutFont)
                            .foregroundColor(AppColors.textSecondary)
                    }
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "doc.text.fill")
                            .font(.system(size: 48))
                            .foregroundColor(AppColors.primary)

                        Text("Exportar Reporte")
                            .font(AppTypography.titleFont)

                        Text("Genera un reporte con los datos del período seleccionado (\(analyticsViewModel.selectedTimeRange.label))")
                            .font(AppTypography.calloutFont)
                            .foregroundColor(AppColors.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    VStack(spacing: 12) {
                        exportOption(icon: "doc.text", title: "PDF", description: "Reporte completo con gráficos")
                        exportOption(icon: "tablecells", title: "Excel (CSV)", description: "Datos en formato de hoja de cálculo")
                    }
                    .padding(.horizontal)

                    Button(action: { analyticsViewModel.exportReport() }) {
                        if analyticsViewModel.isExporting {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Exportar Reporte")
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.horizontal)
                    .disabled(analyticsViewModel.isExporting)
                }

                Spacer()
            }
            .padding(.top, 32)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cerrar") { showExportSheet = false }
                        .foregroundColor(AppColors.textSecondary)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func exportOption(icon: String, title: String, description: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundColor(AppColors.primary)
                .frame(width: 44, height: 44)
                .background(AppColors.primary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppTypography.headlineFont)
                Text(description)
                    .font(AppTypography.caption2Font)
                    .foregroundColor(AppColors.textSecondary)
            }

            Spacer()

            Image(systemName: "circle")
                .foregroundColor(AppColors.textTertiary)
        }
        .padding(14)
        .background(colorScheme == .dark ? AppColors.darkSurface : AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Helpers
    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(AppTypography.caption2Font)
                .foregroundColor(AppColors.textSecondary)
        }
    }

    private func categoryColor(for category: String) -> Color {
        switch category.lowercased() {
        case "bebidas": return AppColors.secondary
        case "lacteos", "lácteos": return AppColors.info
        case "snacks": return AppColors.warning
        case "limpieza": return AppColors.accent
        case "granos": return .brown
        case "cuidado personal", "higiene": return .pink
        case "otros", "other": return AppColors.textSecondary
        default: return AppColors.primary
        }
    }
}
