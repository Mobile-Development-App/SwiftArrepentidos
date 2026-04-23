import SwiftUI
struct RestockView: View {
    @EnvironmentObject var inventoryViewModel: InventoryViewModel
    @Environment(\.colorScheme) var colorScheme

    @State private var restockQuantities: [UUID: String] = [:]
    @State private var showPurchaseList = false
    @State private var purchaseListItems: [PurchaseListItem] = []

    struct PurchaseListItem: Identifiable {
        let id: UUID
        let product: Product
        let quantity: Int
        let estimatedCost: Double
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Summary header
                    summaryCard

                    // AI Suggestions
                    if !inventoryViewModel.restockNeeded.isEmpty {
                        aiSuggestionsSection
                    }

                    // Expiring soon
                    if !inventoryViewModel.expiringProducts.isEmpty {
                        expiringSection
                    }

                    // Empty state
                    if inventoryViewModel.restockNeeded.isEmpty && inventoryViewModel.expiringProducts.isEmpty {
                        EmptyStateView(
                            icon: "checkmark.circle",
                            title: "Todo en orden",
                            description: "No hay productos que necesiten reabastecimiento en este momento."
                        )
                        .frame(height: 300)
                    }

                    Spacer().frame(height: 80)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            .background(colorScheme == .dark ? AppColors.darkBackground : AppColors.background)
            .navigationTitle("Reabastecimiento")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if !inventoryViewModel.restockNeeded.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: generatePurchaseList) {
                            Image(systemName: "list.clipboard")
                                .foregroundColor(AppColors.freshSky)
                        }
                    }
                }
            }
            .sheet(isPresented: $showPurchaseList) {
                purchaseListView
            }
        }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.system(size: 20))
                    .foregroundColor(AppColors.teaGreen)
                Text("Sugerencias IA")
                    .font(AppTypography.headlineFont)
                    .foregroundColor(.white)
                Spacer()
                BadgeView(text: "\(inventoryViewModel.restockNeeded.count) productos", style: .warning)
            }

            Text("Basado en niveles de stock minimo y velocidad de venta, estos productos necesitan reabastecimiento.")
                .font(AppTypography.captionFont)
                .foregroundColor(.white.opacity(0.7))

            HStack(spacing: 16) {
                summaryMetric(value: "\(inventoryViewModel.restockNeeded.count)", label: "Por reabastecer", icon: "exclamationmark.triangle.fill", color: AppColors.warning)
                summaryMetric(value: "\(inventoryViewModel.expiringProducts.count)", label: "Por vencer", icon: "clock.fill", color: AppColors.error)
                summaryMetric(value: "\(inventoryViewModel.dashboardStats.outOfStockCount)", label: "Agotados", icon: "xmark.circle.fill", color: AppColors.error)
            }
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [AppColors.deepSpaceBlue, AppColors.inkBlack],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func summaryMetric(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 14)).foregroundColor(color)
            Text(value).font(AppTypography.headlineFont).foregroundColor(.white)
            Text(label).font(.system(size: 9, weight: .medium)).foregroundColor(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
    }

    private var aiSuggestionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Productos para Reabastecer")
                    .font(AppTypography.headlineFont)
                Spacer()
                Text("Prioridad")
                    .font(AppTypography.caption2Font)
                    .foregroundColor(AppColors.textSecondary)
            }

            ForEach(Array(inventoryViewModel.restockNeeded.enumerated()), id: \.element.id) { index, product in
                restockProductCard(product: product, priority: index + 1)
            }
        }
    }

    private func restockProductCard(product: Product, priority: Int) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                // Priority badge
                ZStack {
                    Circle()
                        .fill(priorityColor(priority).opacity(0.15))
                        .frame(width: 36, height: 36)
                    Text("#\(priority)")
                        .font(AppTypography.captionFont)
                        .fontWeight(.bold)
                        .foregroundColor(priorityColor(priority))
                }

                // Product info
                VStack(alignment: .leading, spacing: 4) {
                    Text(product.name)
                        .font(AppTypography.calloutFont)
                        .fontWeight(.semibold)
                        .foregroundColor(colorScheme == .dark ? AppColors.darkTextPrimary : AppColors.textPrimary)

                    HStack(spacing: 8) {
                        Text(product.sku)
                            .font(AppTypography.caption2Font)
                            .foregroundColor(AppColors.textSecondary)
                        Text("|")
                            .foregroundColor(AppColors.textTertiary)
                        Text(product.supplier)
                            .font(AppTypography.caption2Font)
                            .foregroundColor(AppColors.textSecondary)
                    }
                }

                Spacer()

                // Stock status
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(product.quantity)/\(product.minStock)")
                        .font(AppTypography.calloutFont)
                        .fontWeight(.semibold)
                        .foregroundColor(product.stockStatus == .outOfStock ? AppColors.error : AppColors.warning)
                    Text("actual/min")
                        .font(AppTypography.caption2Font)
                        .foregroundColor(AppColors.textTertiary)
                }
            }

            // Restock quantity input
            HStack(spacing: 12) {
                Text("Cantidad a pedir:")
                    .font(AppTypography.captionFont)
                    .foregroundColor(AppColors.textSecondary)

                TextField("0", text: Binding(
                    get: { restockQuantities[product.id] ?? "\(max(product.minStock - product.quantity, 0))" },
                    set: { restockQuantities[product.id] = $0 }
                ))
                .font(AppTypography.calloutFont)
                .keyboardType(.numberPad)
                .frame(width: 60)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(colorScheme == .dark ? AppColors.darkSurfaceSecondary : AppColors.surfaceSecondary)
                .clipShape(RoundedRectangle(cornerRadius: 8))

                Spacer()

                // Quick restock button
                Button(action: {
                    let defaultQty = max(product.minStock - product.quantity, 0)
                    let qty = Int(restockQuantities[product.id] ?? "\(defaultQty)") ?? defaultQty
                    if qty > 0 {
                        inventoryViewModel.restockProduct(productId: product.id, quantity: qty)
                        restockQuantities.removeValue(forKey: product.id)
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                        Text("Reabastecer")
                    }
                    .font(AppTypography.caption2Font)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.inkBlack)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(AppColors.teaGreen)
                    .clipShape(Capsule())
                }
            }
        }
        .padding(14)
        .cardStyle()
    }

    private var expiringSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "clock.fill")
                    .foregroundColor(AppColors.warning)
                Text("Proximos a Vencer")
                    .font(AppTypography.headlineFont)
            }

            ForEach(inventoryViewModel.expiringProducts) { product in
                HStack(spacing: 12) {
                    Image(systemName: product.category.icon)
                        .foregroundColor(AppColors.warning)
                        .frame(width: 32, height: 32)
                        .background(AppColors.warning.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(product.name).font(AppTypography.captionFont).fontWeight(.medium)
                        if let expDate = product.expirationDate {
                            let daysLeft = Int(expDate.timeIntervalSinceNow / 86400)
                            Text("Vence en \(daysLeft) dias")
                                .font(AppTypography.caption2Font)
                                .foregroundColor(daysLeft <= 7 ? AppColors.error : AppColors.warning)
                        }
                    }

                    Spacer()

                    Text("\(product.quantity) uds")
                        .font(AppTypography.captionFont)
                        .foregroundColor(AppColors.textSecondary)
                }
                .padding(10)
            }
        }
        .padding(16)
        .cardStyle()
    }

    private func generatePurchaseList() {
        purchaseListItems = inventoryViewModel.restockNeeded.compactMap { product in
            let defaultQty = max(product.minStock - product.quantity, 0)
            let qty = Int(restockQuantities[product.id] ?? "\(defaultQty)") ?? defaultQty
            // Saltar productos con 0 unidades a comprar o sin precio de costo
            guard qty > 0, product.costPrice > 0 else { return nil }
            return PurchaseListItem(
                id: product.id,
                product: product,
                quantity: qty,
                estimatedCost: product.costPrice * Double(qty)
            )
        }
        showPurchaseList = true
    }

    private var purchaseListView: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Total
                    VStack(spacing: 8) {
                        Text("Lista de Compra")
                            .font(AppTypography.titleFont)
                        Text("Total estimado: \(purchaseListItems.reduce(0) { $0 + $1.estimatedCost }.currencyFormatted)")
                            .font(AppTypography.headlineFont)
                            .foregroundColor(AppColors.freshSky)
                        Text("\(purchaseListItems.count) productos | \(purchaseListItems.reduce(0) { $0 + $1.quantity }) unidades")
                            .font(AppTypography.captionFont)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .padding(20)

                    ForEach(purchaseListItems) { item in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.product.name).font(AppTypography.calloutFont).fontWeight(.medium)
                                Text(item.product.supplier).font(AppTypography.caption2Font).foregroundColor(AppColors.textSecondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("\(item.quantity) uds").font(AppTypography.calloutFont).fontWeight(.semibold)
                                Text(item.estimatedCost.currencyFormatted).font(AppTypography.caption2Font).foregroundColor(AppColors.textSecondary)
                            }
                        }
                        .padding(14)
                        .cardStyle()
                    }
                    .padding(.horizontal, 16)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cerrar") { showPurchaseList = false }
                }
            }
        }
        .presentationDetents([.large])
    }

    private func priorityColor(_ priority: Int) -> Color {
        switch priority {
        case 1: return AppColors.error
        case 2: return AppColors.warning
        case 3: return AppColors.warning.opacity(0.8)
        default: return AppColors.freshSky
        }
    }
}
