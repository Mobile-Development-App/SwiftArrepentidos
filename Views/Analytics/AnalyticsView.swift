import SwiftUI
import Charts

struct AnalyticsView: View {
    @EnvironmentObject var analyticsViewModel: AnalyticsViewModel
    @EnvironmentObject var inventoryViewModel: InventoryViewModel
    @Environment(\.colorScheme) var colorScheme

    @State private var showExportSheet = false
    @State private var selectedExportFormat: ExportFormat = .csv

    enum ExportFormat: String {
        case pdf = "PDF"
        case csv = "EXCEL_CSV"

        var displayName: String {
            switch self {
            case .pdf: return "PDF"
            case .csv: return "Excel (CSV)"
            }
        }
    }

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
                        NavigationLink {
                            BusinessQuestionsView()
                        } label: {
                            Image(systemName: "questionmark.circle")
                                .foregroundColor(AppColors.primary)
                        }
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
                // Solo mostrar trend si hay al menos 2 puntos de datos reales
                trend: analyticsViewModel.salesData.count >= 2 ? analyticsViewModel.salesTrend : nil,
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
                    .lineStyle(StrokeStyle(lineWidth: 2.5))
                    .interpolationMethod(.catmullRom)

                    PointMark(
                        x: .value("Fecha", point.date, unit: .day),
                        y: .value("Ventas", point.sales)
                    )
                    .foregroundStyle(AppColors.primary)
                    .symbolSize(30)

                    AreaMark(
                        x: .value("Fecha", point.date, unit: .day),
                        y: .value("Ventas", point.sales)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [AppColors.primary.opacity(0.25), AppColors.primary.opacity(0.02)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)
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
                    // Ajustar densidad de ticks según cantidad de datos (evita duplicados "21 abr, 21 abr")
                    AxisMarks(values: .automatic(desiredCount: min(6, max(2, analyticsViewModel.salesData.count)))) { value in
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
                Chart {
                    ForEach(analyticsViewModel.stockLevelData) { item in
                        BarMark(
                            x: .value("Categoría", item.category),
                            y: .value("En Stock", item.inStock)
                        )
                        .foregroundStyle(by: .value("Estado", "En Stock"))

                        BarMark(
                            x: .value("Categoría", item.category),
                            y: .value("Stock Bajo", item.lowStock)
                        )
                        .foregroundStyle(by: .value("Estado", "Stock Bajo"))

                        BarMark(
                            x: .value("Categoría", item.category),
                            y: .value("Agotado", item.outOfStock)
                        )
                        .foregroundStyle(by: .value("Estado", "Agotado"))
                    }
                }
                .chartForegroundStyleScale([
                    "En Stock": AppColors.success,
                    "Stock Bajo": AppColors.warning,
                    "Agotado": AppColors.error
                ])
                .chartLegend(position: .bottom, alignment: .center, spacing: 8)
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
                                Text(label.prefix(7) + (label.count > 7 ? "…" : ""))
                                    .font(.system(size: 9))
                                    .rotationEffect(.degrees(-25))
                            }
                        }
                    }
                }
                .frame(height: 240)

                // Si no hay productos en stock bajo o agotado, mostrar una nota positiva
                let hasLowOrOut = analyticsViewModel.stockLevelData.contains { $0.lowStock > 0 || $0.outOfStock > 0 }
                if !hasLowOrOut && !analyticsViewModel.stockLevelData.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(AppColors.success)
                        Text("Todos los productos están en stock")
                            .font(AppTypography.caption2Font)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .padding(.top, 4)
                }
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
                // Construir mapeo categoría → color (misma fuente para chart y leyenda)
                // uniquingKeysWith evita crashes si el backend devuelve categorías duplicadas
                let colorMap = Dictionary(
                    analyticsViewModel.categoryDistribution.map { ($0.category, categoryColor(for: $0.category)) },
                    uniquingKeysWith: { first, _ in first }
                )

                Chart(analyticsViewModel.categoryDistribution) { item in
                    SectorMark(
                        angle: .value("Cantidad", item.count),
                        innerRadius: .ratio(0.5),
                        outerRadius: .ratio(1.0)
                    )
                    .foregroundStyle(by: .value("Categoría", item.category))
                }
                .chartForegroundStyleScale(domain: Array(colorMap.keys), range: Array(colorMap.values))
                .frame(height: 200)

                // Legend usando los mismos colores
                VStack(spacing: 8) {
                    ForEach(analyticsViewModel.categoryDistribution) { item in
                        HStack {
                            Circle()
                                .fill(colorMap[item.category] ?? AppColors.primary)
                                .frame(width: 10, height: 10)

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
                        Text("El reporte se ha generado correctamente")
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

                        Text("Período: \(analyticsViewModel.selectedTimeRange.label)")
                            .font(AppTypography.calloutFont)
                            .foregroundColor(AppColors.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    VStack(spacing: 12) {
                        exportOption(
                            icon: "doc.text",
                            title: "PDF",
                            description: "Reporte completo con gráficos",
                            isSelected: selectedExportFormat == .pdf,
                            action: { selectedExportFormat = .pdf }
                        )
                        exportOption(
                            icon: "tablecells",
                            title: "Excel (CSV)",
                            description: "Datos en formato de hoja de cálculo",
                            isSelected: selectedExportFormat == .csv,
                            action: { selectedExportFormat = .csv }
                        )
                    }
                    .padding(.horizontal)

                    Button(action: {
                        analyticsViewModel.exportReport(format: selectedExportFormat.rawValue)
                    }) {
                        if analyticsViewModel.isExporting {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Exportar como \(selectedExportFormat.displayName)")
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.horizontal)
                    .disabled(analyticsViewModel.isExporting)

                    if let err = analyticsViewModel.error {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(AppColors.error)
                            Text(err)
                                .font(AppTypography.captionFont)
                                .foregroundColor(AppColors.error)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppColors.error.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .padding(.horizontal)
                    }
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

    private func exportOption(icon: String, title: String, description: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundColor(isSelected ? AppColors.primary : AppColors.textSecondary)
                    .frame(width: 44, height: 44)
                    .background((isSelected ? AppColors.primary : AppColors.textSecondary).opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(AppTypography.headlineFont)
                        .foregroundColor(colorScheme == .dark ? AppColors.darkTextPrimary : AppColors.textPrimary)
                    Text(description)
                        .font(AppTypography.caption2Font)
                        .foregroundColor(AppColors.textSecondary)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundColor(isSelected ? AppColors.primary : AppColors.textTertiary)
            }
            .padding(14)
            .background(colorScheme == .dark ? AppColors.darkSurface : AppColors.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? AppColors.primary : Color.clear, lineWidth: 2)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
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

    /// Paleta profesional con colores distintivos pero armónicos (inspirada en Tailwind/Material)
    private func categoryColor(for category: String) -> Color {
        switch category.lowercased() {
        case "bebidas", "beverages":
            return Color(red: 0.29, green: 0.56, blue: 0.89)       // azul
        case "lacteos", "lácteos", "dairy":
            return Color(red: 0.45, green: 0.75, blue: 0.82)       // teal suave
        case "snacks":
            return Color(red: 0.94, green: 0.58, blue: 0.29)       // naranja cálido
        case "limpieza", "cleaning":
            return Color(red: 0.55, green: 0.40, blue: 0.78)       // púrpura
        case "granos", "grains":
            return Color(red: 0.72, green: 0.52, blue: 0.31)       // marrón cálido
        case "cuidado personal", "higiene", "personalcare":
            return Color(red: 0.85, green: 0.38, blue: 0.55)       // rosa intenso
        case "frutas", "frutas y verduras", "fruits":
            return Color(red: 0.39, green: 0.78, blue: 0.47)       // verde fresco
        case "carnes", "meat":
            return Color(red: 0.82, green: 0.36, blue: 0.36)       // rojo suave
        case "panadería", "panaderia", "bakery":
            return Color(red: 0.93, green: 0.78, blue: 0.29)       // dorado
        case "congelados", "frozen":
            return Color(red: 0.38, green: 0.68, blue: 0.85)       // azul hielo
        case "condimentos", "condiments":
            return Color(red: 0.85, green: 0.55, blue: 0.40)       // terracota
        case "otros", "other":
            return Color(red: 0.60, green: 0.60, blue: 0.67)       // gris neutro
        default:
            // Hash estable para categorías no mapeadas
            let palette: [Color] = [
                Color(red: 0.29, green: 0.56, blue: 0.89),
                Color(red: 0.94, green: 0.58, blue: 0.29),
                Color(red: 0.39, green: 0.78, blue: 0.47),
                Color(red: 0.85, green: 0.38, blue: 0.55),
                Color(red: 0.55, green: 0.40, blue: 0.78)
            ]
            let stableHash = category.lowercased().unicodeScalars.reduce(0) { $0 &+ Int($1.value) }
            return palette[stableHash % palette.count]
        }
    }
}
