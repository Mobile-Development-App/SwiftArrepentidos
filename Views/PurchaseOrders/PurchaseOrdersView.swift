import SwiftUI

struct PurchaseOrdersView: View {
    @EnvironmentObject private var inventoryViewModel: InventoryViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @StateObject private var viewModel = PurchaseOrderViewModel()
    @ObservedObject private var network = NetworkMonitor.shared
    @State private var showCreateSheet = false


    private var derivedSuppliers: [Supplier] {
        let names = Set(inventoryViewModel.products
            .map { $0.supplier.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty })
        return names.sorted().map { name in
            Supplier(
                id: UUID(deterministicFrom: "supplier-\(name)"),
                name: name, contactName: "", email: "", phone: "",
                address: "", category: "", isActive: true
            )
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.orders.isEmpty {
                    emptyState
                } else {
                    ordersList
                }
            }
            .background(colorScheme == .dark ? AppColors.darkBackground : AppColors.background)
            .navigationTitle("Órdenes de Compra")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cerrar") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showCreateSheet = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .safeAreaInset(edge: .top) { syncBanner }
            .task { await viewModel.load() }
            .sheet(isPresented: $showCreateSheet) {
                CreatePurchaseOrderSheet(
                    suppliers: derivedSuppliers,
                    products: inventoryViewModel.products
                ) { supplier, lines in
                    Task { await viewModel.createOrder(supplier: supplier, lines: lines) }
                }
            }
            .alert("Aviso", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }

    // MARK: - Banner de sincronización (EvC)

    @ViewBuilder
    private var syncBanner: some View {
        if !network.isConnected {
            bannerRow(icon: "wifi.slash",
                      text: "Sin conexión — las órdenes se guardan local y se sincronizan al volver la red.",
                      bg: AppColors.warning.opacity(0.22))
        } else if viewModel.pendingSyncCount > 0 {
            bannerRow(icon: "arrow.triangle.2.circlepath",
                      text: "\(viewModel.pendingSyncCount) orden(es) sincronizando…",
                      bg: AppColors.info.opacity(0.18))
        }
    }

    private func bannerRow(icon: String, text: String, bg: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
            Text(text)
                .font(.footnote)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .foregroundColor(AppColors.inkBlack)
        .padding(10)
        .background(bg)
    }

    // MARK: - Estados

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "doc.badge.plus")
                .font(.system(size: 56))
                .foregroundColor(AppColors.deepSpaceBlue)
            Text("Órdenes de Compra")
                .font(AppTypography.title3Font)
                .foregroundColor(colorScheme == .dark ? AppColors.darkTextPrimary : AppColors.textPrimary)
            Text("Crea órdenes a tus proveedores. Funcionan sin conexión: se guardan local y se sincronizan cuando vuelve la red.")
                .font(AppTypography.captionFont)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button(action: { showCreateSheet = true }) {
                Text("Crear orden")
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, 40)
            Spacer()
        }
    }

    private var ordersList: some View {
        List {
            ForEach(viewModel.orders) { order in
                PurchaseOrderRow(order: order) { newStatus in
                    Task { await viewModel.updateStatus(orderId: order.id, to: newStatus) }
                }
            }
        }
        .listStyle(.plain)
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// PurchaseOrderRow — un renglón de la lista de órdenes.
// ─────────────────────────────────────────────────────────────────────────────

private struct PurchaseOrderRow: View {
    let order: PurchaseOrder
    let onStatusChange: (PurchaseOrderStatus) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(order.orderNumber)
                    .font(AppTypography.captionFont)
                    .fontWeight(.semibold)
                if order.syncState == .pendingSync {
                    HStack(spacing: 3) {
                        Image(systemName: "icloud.and.arrow.up")
                        Text("pendiente")
                    }
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(AppColors.warning)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(AppColors.warning.opacity(0.15))
                    .clipShape(Capsule())
                }
                Spacer()
                Text(order.total.compactCurrency)
                    .font(AppTypography.captionFont)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.success)
            }
            Text("\(order.supplierName) · \(order.lines.count) ítems · \(order.itemCount) uds")
                .font(AppTypography.caption2Font)
                .foregroundColor(AppColors.textTertiary)
            HStack {
                Label(order.status.rawValue, systemImage: order.status.icon)
                    .font(AppTypography.caption2Font)
                    .foregroundColor(AppColors.freshSky)
                Spacer()
                Menu {
                    ForEach(PurchaseOrderStatus.allCases, id: \.self) { status in
                        Button(status.rawValue) { onStatusChange(status) }
                    }
                } label: {
                    Text("Cambiar estado")
                        .font(AppTypography.caption2Font)
                        .foregroundColor(AppColors.freshSky)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// CreatePurchaseOrderSheet — formulario de orden: proveedor + líneas.
// ─────────────────────────────────────────────────────────────────────────────

private struct CreatePurchaseOrderSheet: View {
    let suppliers: [Supplier]
    let products: [Product]
    let onSave: (Supplier, [PurchaseOrderLine]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var supplierId: UUID?
    @State private var lines: [PurchaseOrderLine] = []
    @State private var pickProductId: UUID?
    @State private var qtyText = ""

    private var selectedSupplier: Supplier? {
        suppliers.first { $0.id == supplierId }
    }
    /// Productos del proveedor elegido.
    private var supplierProducts: [Product] {
        guard let name = selectedSupplier?.name else { return [] }
        return products
            .filter { $0.supplier == name && $0.isActive }
            .sorted { $0.name < $1.name }
    }
    private var total: Double { lines.reduce(0) { $0 + $1.lineTotal } }
    private var canSave: Bool { selectedSupplier != nil && !lines.isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section("Proveedor") {
                    Picker("Proveedor", selection: $supplierId) {
                        Text("Selecciona…").tag(UUID?.none)
                        ForEach(suppliers) { s in
                            Text(s.name).tag(UUID?.some(s.id))
                        }
                    }
                }

                if selectedSupplier != nil {
                    Section("Agregar producto") {
                        Picker("Producto", selection: $pickProductId) {
                            Text("Selecciona…").tag(UUID?.none)
                            ForEach(supplierProducts) { p in
                                Text(p.name).tag(UUID?.some(p.id))
                            }
                        }
                        TextField("Cantidad", text: $qtyText)
                            .keyboardType(.numberPad)
                        Button("Agregar a la orden") { addLine() }
                            .disabled(!canAddLine)
                    }
                }

                if !lines.isEmpty {
                    Section("Líneas de la orden") {
                        ForEach(lines) { line in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(line.productName).font(.subheadline)
                                    Text("\(line.quantity) × \(line.unitCost.compactCurrency)")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Text(line.lineTotal.compactCurrency)
                                    .fontWeight(.semibold)
                            }
                        }
                        .onDelete { lines.remove(atOffsets: $0) }
                        HStack {
                            Text("Total").fontWeight(.semibold)
                            Spacer()
                            Text(total.compactCurrency)
                                .fontWeight(.bold)
                                .foregroundColor(AppColors.success)
                        }
                    }
                }
            }
            .navigationTitle("Nueva orden")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Guardar") {
                        if let supplier = selectedSupplier {
                            onSave(supplier, lines)
                            dismiss()
                        }
                    }
                    .disabled(!canSave)
                }
            }
        }
    }

    private var canAddLine: Bool {
        guard pickProductId != nil,
              let qty = Int(qtyText.trimmingCharacters(in: .whitespaces)),
              qty > 0 else { return false }
        return true
    }

    private func addLine() {
        guard let product = products.first(where: { $0.id == pickProductId }),
              let qty = Int(qtyText.trimmingCharacters(in: .whitespaces)), qty > 0 else { return }
        lines.append(PurchaseOrderLine(
            productId: product.id,
            productName: product.name,
            quantity: qty,
            unitCost: product.costPrice
        ))
        pickProductId = nil
        qtyText = ""
    }
}
