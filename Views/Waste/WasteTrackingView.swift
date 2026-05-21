import SwiftUI


struct WasteTrackingView: View {
    @EnvironmentObject private var inventoryViewModel: InventoryViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @StateObject private var viewModel = WasteTrackingViewModel()
    @State private var showRecordSheet = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if let report = viewModel.report {
                        reportSection(report)
                    }
                    recordButton
                    recentSection
                    Spacer().frame(height: 20)
                }
                .padding(16)
            }
            .background(colorScheme == .dark ? AppColors.darkBackground : AppColors.background)
            .navigationTitle("Registro de Mermas")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cerrar") { dismiss() }
                }
            }
            .task { await viewModel.load() }
            .sheet(isPresented: $showRecordSheet) {
                RecordWasteSheet(products: inventoryViewModel.products) { product, qty, reason in
                    Task { await viewModel.recordWaste(product: product, quantity: qty, reason: reason) }
                }
            }
            .alert("Aviso", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }

    private func reportSection(_ report: WasteReport) -> some View {
        VStack(spacing: 14) {
            VStack(spacing: 6) {
                Text(report.totalValueLost.compactCurrency)
                    .font(.system(size: 40, weight: .bold))
                    .foregroundColor(AppColors.error)
                Text("Valor perdido en mermas · últimos \(report.windowDays) días")
                    .font(AppTypography.caption2Font)
                    .foregroundColor(AppColors.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .cardStyle()

            if !report.byReason.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Por causa").font(AppTypography.headlineFont)
                    ForEach(report.byReason) { row in
                        HStack {
                            Image(systemName: row.reason.icon)
                                .foregroundColor(AppColors.warning)
                                .frame(width: 24)
                            Text(row.reason.rawValue).font(AppTypography.captionFont)
                            Spacer()
                            Text("\(row.unitsLost) uds")
                                .font(AppTypography.caption2Font)
                                .foregroundColor(AppColors.textTertiary)
                            Text(row.valueLost.compactCurrency)
                                .font(AppTypography.captionFont)
                                .fontWeight(.semibold)
                                .foregroundColor(AppColors.error)
                        }
                    }
                }
                .padding(16)
                .cardStyle()
            }

            if !report.byCategory.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Por categoría").font(AppTypography.headlineFont)
                    ForEach(report.byCategory) { row in
                        HStack {
                            Image(systemName: row.category.icon)
                                .foregroundColor(AppColors.freshSky)
                                .frame(width: 24)
                            Text(row.category.rawValue).font(AppTypography.captionFont)
                            Spacer()
                            Text(row.valueLost.compactCurrency)
                                .font(AppTypography.captionFont)
                                .fontWeight(.semibold)
                                .foregroundColor(AppColors.error)
                        }
                    }
                }
                .padding(16)
                .cardStyle()
            }

            HStack(spacing: 4) {
                Image(systemName: report.fromCache ? "bolt.fill" : "function")
                    .font(.caption2)
                Text(report.fromCache
                     ? "Reporte servido desde caché (0 ms)"
                     : String(format: "Reporte computado en %.1f ms", report.durationMs))
                    .font(AppTypography.caption2Font)
            }
            .foregroundColor(AppColors.textTertiary)
        }
    }

    private var recordButton: some View {
        Button(action: { showRecordSheet = true }) {
            HStack {
                Image(systemName: "plus.circle.fill")
                Text("Registrar merma")
            }
        }
        .buttonStyle(PrimaryButtonStyle())
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Mermas recientes").font(AppTypography.headlineFont)
            if viewModel.recentEvents.isEmpty {
                Text("Aún no has registrado mermas.")
                    .font(AppTypography.caption2Font)
                    .foregroundColor(AppColors.textTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            } else {
                ForEach(viewModel.recentEvents) { event in
                    HStack(spacing: 10) {
                        Image(systemName: event.reason.icon)
                            .foregroundColor(AppColors.warning)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(event.productName)
                                .font(AppTypography.captionFont)
                                .lineLimit(1)
                            Text("\(event.quantity) uds · \(event.reason.rawValue)")
                                .font(AppTypography.caption2Font)
                                .foregroundColor(AppColors.textTertiary)
                        }
                        Spacer()
                        Text(event.valueLost.compactCurrency)
                            .font(AppTypography.captionFont)
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.error)
                    }
                    .padding(.vertical, 4)
                    if event.id != viewModel.recentEvents.last?.id {
                        Divider()
                    }
                }
            }
        }
        .padding(16)
        .cardStyle()
    }
}


// RecordWasteSheet — formulario para registrar una merma: producto,
// cantidad y causa.

private struct RecordWasteSheet: View {
    let products: [Product]
    let onSave: (Product, Int, WasteReason) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedProductId: UUID?
    @State private var quantityText = ""
    @State private var reason: WasteReason = .expired

    private var activeProducts: [Product] {
        products.filter { $0.isActive }.sorted { $0.name < $1.name }
    }
    private var selectedProduct: Product? {
        products.first { $0.id == selectedProductId }
    }
    private var isValid: Bool {
        guard selectedProduct != nil,
              let qty = Int(quantityText.trimmingCharacters(in: .whitespaces)),
              qty > 0 else { return false }
        return true
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Producto") {
                    Picker("Producto", selection: $selectedProductId) {
                        Text("Selecciona…").tag(UUID?.none)
                        ForEach(activeProducts) { product in
                            Text(product.name).tag(UUID?.some(product.id))
                        }
                    }
                }
                Section("Cantidad perdida") {
                    TextField("Unidades", text: $quantityText)
                        .keyboardType(.numberPad)
                }
                Section("Causa") {
                    Picker("Causa", selection: $reason) {
                        ForEach(WasteReason.allCases, id: \.self) { r in
                            Label(r.rawValue, systemImage: r.icon).tag(r)
                        }
                    }
                    .pickerStyle(.inline)
                }
                if let product = selectedProduct,
                   let qty = Int(quantityText.trimmingCharacters(in: .whitespaces)), qty > 0 {
                    Section {
                        HStack {
                            Text("Valor a registrar")
                            Spacer()
                            Text((Double(qty) * product.costPrice).compactCurrency)
                                .fontWeight(.semibold)
                                .foregroundColor(AppColors.error)
                        }
                    }
                }
            }
            .navigationTitle("Nueva merma")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Guardar") {
                        if let product = selectedProduct,
                           let qty = Int(quantityText.trimmingCharacters(in: .whitespaces)) {
                            onSave(product, qty, reason)
                            dismiss()
                        }
                    }
                    .disabled(!isValid)
                }
            }
        }
    }
}
