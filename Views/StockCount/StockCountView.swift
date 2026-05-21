import SwiftUI

// ─────────────────────────────────────────────────────────────────────────────
// StockCountView — Sprint 4. Vista de la feature de Conteo Físico de
// Inventario (Juan Felipe). Una de las 3 vistas nuevas del sprint.
//
// Tres estados:
//   1. Sin sesión        → empty state + botón "Iniciar conteo".
//   2. Conteo en progreso → lista de productos con campo de cantidad real,
//                           barra de progreso y botón "Finalizar".
//   3. Resultado          → reconciliación: exactitud global y por categoría.
// ─────────────────────────────────────────────────────────────────────────────

struct StockCountView: View {
    @EnvironmentObject private var inventoryViewModel: InventoryViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @StateObject private var viewModel = StockCountViewModel()
    @State private var showCancelConfirm = false

    var body: some View {
        NavigationStack {
            Group {
                if let summary = viewModel.summary {
                    resultView(summary)
                } else if viewModel.hasActiveSession {
                    countingView
                } else {
                    emptyState
                }
            }
            .background(colorScheme == .dark ? AppColors.darkBackground : AppColors.background)
            .navigationTitle("Conteo Físico")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cerrar") { dismiss() }
                }
                if viewModel.hasActiveSession {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Cancelar", role: .destructive) {
                            showCancelConfirm = true
                        }
                    }
                }
            }
            .onAppear { viewModel.restoreActiveSession() }
            .alert("Cancelar conteo", isPresented: $showCancelConfirm) {
                Button("Volver", role: .cancel) {}
                Button("Descartar conteo", role: .destructive) {
                    viewModel.cancelCount()
                }
            } message: {
                Text("Se descartará el conteo en progreso. Esta acción no se puede deshacer.")
            }
            .alert("Aviso", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }

    // MARK: - Estado 1: sin sesión

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "checklist")
                .font(.system(size: 56))
                .foregroundColor(AppColors.freshSky)
            Text("Conteo Físico de Inventario")
                .font(AppTypography.title3Font)
                .foregroundColor(colorScheme == .dark ? AppColors.darkTextPrimary : AppColors.textPrimary)
            Text("Recorre tus productos, registra la cantidad real en estantería y la app calcula las discrepancias contra el stock del sistema.")
                .font(AppTypography.captionFont)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button(action: {
                viewModel.startNewCount(products: inventoryViewModel.products)
            }) {
                Text("Iniciar conteo")
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, 40)
            .disabled(inventoryViewModel.products.isEmpty)
            Spacer()
        }
    }

    // MARK: - Estado 2: conteo en progreso

    private var countingView: some View {
        VStack(spacing: 0) {
            progressHeader
            List {
                ForEach(viewModel.items) { item in
                    StockCountRow(item: item) { qty in
                        viewModel.recordCount(itemId: item.id, quantity: qty)
                    }
                }
            }
            .listStyle(.plain)
            finishBar
        }
    }

    private var progressHeader: some View {
        VStack(spacing: 8) {
            HStack {
                Text("\(viewModel.countedCount) de \(viewModel.totalCount) contados")
                    .font(AppTypography.captionFont)
                    .foregroundColor(AppColors.textSecondary)
                Spacer()
                Text("\(Int(viewModel.progress * 100))%")
                    .font(AppTypography.captionFont)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.freshSky)
            }
            ProgressView(value: viewModel.progress)
                .tint(AppColors.freshSky)
        }
        .padding(16)
    }

    private var finishBar: some View {
        VStack(spacing: 0) {
            Divider()
            Button(action: { Task { await viewModel.finishCount() } }) {
                if viewModel.isReconciling {
                    ProgressView().tint(.white)
                } else {
                    Text(viewModel.allCounted
                         ? "Finalizar y reconciliar"
                         : "Finalizar (\(viewModel.countedCount) contados)")
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(16)
            .disabled(viewModel.countedCount == 0 || viewModel.isReconciling)
        }
    }

    // MARK: - Estado 3: resultado

    private func resultView(_ summary: StockCountSummary) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                accuracyHeadline(summary)
                metricsGrid(summary)
                if !summary.perCategory.isEmpty {
                    categoryBreakdown(summary)
                }
                if !viewModel.discrepantItems.isEmpty {
                    adjustmentsCard
                }
                Text("Reconciliado en \(String(format: "%.0f", summary.durationMs)) ms · cómputo concurrente con TaskGroup")
                    .font(AppTypography.caption2Font)
                    .foregroundColor(AppColors.textTertiary)
                    .multilineTextAlignment(.center)
                Spacer().frame(height: 20)
            }
            .padding(16)
        }
    }

    private func accuracyHeadline(_ summary: StockCountSummary) -> some View {
        VStack(spacing: 6) {
            Text("\(String(format: "%.0f", summary.overallAccuracyPct))%")
                .font(.system(size: 52, weight: .bold))
                .foregroundColor(accuracyColor(summary.overallAccuracyPct))
            Text("Exactitud del inventario")
                .font(AppTypography.captionFont)
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .cardStyle()
    }

    private func metricsGrid(_ summary: StockCountSummary) -> some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12),
                            GridItem(.flexible(), spacing: 12)], spacing: 12) {
            metricTile("Productos contados", "\(summary.countedItems)", AppColors.deepSpaceBlue)
            metricTile("Con discrepancia", "\(summary.itemsWithDiscrepancy)", AppColors.warning)
            metricTile("Diferencia neta", "\(summary.netUnitDiscrepancy) uds", AppColors.info)
            metricTile("Impacto", summary.absoluteValueImpact.compactCurrency, AppColors.error)
        }
    }

    private func metricTile(_ title: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(value)
                .font(AppTypography.title3Font)
                .foregroundColor(color)
            Text(title)
                .font(AppTypography.caption2Font)
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .cardStyle()
    }

    private func categoryBreakdown(_ summary: StockCountSummary) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Exactitud por categoría")
                .font(AppTypography.headlineFont)
            ForEach(summary.perCategory) { cat in
                HStack {
                    Image(systemName: cat.category.icon)
                        .foregroundColor(AppColors.freshSky)
                        .frame(width: 24)
                    Text(cat.category.rawValue)
                        .font(AppTypography.captionFont)
                    Spacer()
                    Text("\(String(format: "%.0f", cat.accuracyPct))%")
                        .font(AppTypography.captionFont)
                        .fontWeight(.semibold)
                        .foregroundColor(accuracyColor(cat.accuracyPct))
                }
                .padding(.vertical, 4)
            }
        }
        .padding(16)
        .cardStyle()
    }

    private var adjustmentsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Ajustar inventario")
                .font(AppTypography.headlineFont)
            Text("\(viewModel.discrepantItems.count) productos no coinciden. Aplica el conteo físico como cantidad oficial.")
                .font(AppTypography.caption2Font)
                .foregroundColor(AppColors.textSecondary)
            Button(action: applyAdjustments) {
                Text("Aplicar ajustes al inventario")
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding(16)
        .cardStyle()
    }

    // MARK: - Helpers

    /// Aplica el conteo físico como cantidad real de cada producto discrepante.
    /// Va por `InventoryViewModel.updateProduct`, que ya tiene la lógica
    /// offline-first: si no hay red, encola el cambio en `OfflineQueueService`.
    private func applyAdjustments() {
        for item in viewModel.discrepantItems {
            guard let counted = item.countedQuantity,
                  var product = inventoryViewModel.products
                      .first(where: { $0.id == item.productId }) else { continue }
            product.quantity = counted
            product.lastUpdated = Date()
            inventoryViewModel.updateProduct(product)
        }
        HapticManager.notification(.success)
        dismiss()
    }

    private func accuracyColor(_ pct: Double) -> Color {
        if pct >= 95 { return AppColors.success }
        if pct >= 80 { return AppColors.warning }
        return AppColors.error
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// StockCountRow — un renglón de la lista de conteo. Mantiene su propio
// estado de texto local para el campo numérico; al confirmar, reporta al
// view-model vía el closure `onCount`.
// ─────────────────────────────────────────────────────────────────────────────

private struct StockCountRow: View {
    let item: StockCountItem
    let onCount: (Int) -> Void

    @State private var text: String = ""
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.productName)
                    .font(AppTypography.captionFont)
                    .lineLimit(1)
                Text("Sistema: \(item.systemQuantity) uds")
                    .font(AppTypography.caption2Font)
                    .foregroundColor(AppColors.textTertiary)
            }
            Spacer()
            if let diff = item.discrepancy, item.isCounted {
                Text(diff == 0 ? "OK" : (diff > 0 ? "+\(diff)" : "\(diff)"))
                    .font(AppTypography.caption2Font)
                    .fontWeight(.semibold)
                    .foregroundColor(diff == 0 ? AppColors.success : AppColors.warning)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background((diff == 0 ? AppColors.success : AppColors.warning).opacity(0.15))
                    .clipShape(Capsule())
            }
            TextField("Real", text: $text)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .frame(width: 60)
                .padding(.vertical, 6)
                .background(AppColors.surfaceSecondary)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .focused($focused)
                .onSubmit { commit() }
        }
        .onChange(of: focused) { _, isFocused in
            if !isFocused { commit() }
        }
        .onAppear {
            if let counted = item.countedQuantity { text = "\(counted)" }
        }
    }

    private func commit() {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, let qty = Int(trimmed) else { return }
        onCount(qty)
    }
}
