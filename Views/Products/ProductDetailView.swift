import SwiftUI

struct ProductDetailView: View {
    let product: Product
    @EnvironmentObject var inventoryViewModel: InventoryViewModel
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @State private var showEditProduct = false
    @State private var showDeleteConfirm = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Hero image/icon
                    heroSection

                    // Status and badges
                    statusSection

                    // Alerts
                    if product.stockStatus == .lowStock || product.stockStatus == .outOfStock {
                        alertBanner
                    }

                    // Pricing grid
                    pricingGrid

                    // Product details
                    detailsSection

                    // Financial summary
                    financialSummary

                    // Actions
                    actionButtons

                    Spacer().frame(height: 20)
                }
                .padding(.horizontal, 16)
            }
            .background(colorScheme == .dark ? AppColors.darkBackground : AppColors.background)
            .navigationTitle("Detalle del Producto")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .foregroundColor(colorScheme == .dark ? AppColors.darkTextPrimary : AppColors.textPrimary)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { showEditProduct = true }) {
                            Label("Editar", systemImage: "pencil")
                        }
                        Button(role: .destructive, action: { showDeleteConfirm = true }) {
                            Label("Eliminar", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(colorScheme == .dark ? AppColors.darkTextPrimary : AppColors.textPrimary)
                    }
                }
            }
            .sheet(isPresented: $showEditProduct) {
                AddProductView(editingProduct: product)
            }
            .alert("Eliminar Producto", isPresented: $showDeleteConfirm) {
                Button("Cancelar", role: .cancel) {}
                Button("Eliminar", role: .destructive) {
                    inventoryViewModel.deleteProduct(product)
                    dismiss()
                }
            } message: {
                Text("¿Estás seguro de que deseas eliminar \(product.name)? Esta acción no se puede deshacer.")
            }
        }
    }

    private var heroSection: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [categoryColor.opacity(0.15), categoryColor.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Image(systemName: product.category.icon)
                .font(.system(size: 64))
                .foregroundColor(categoryColor)
        }
        .frame(height: 180)
        .overlay(alignment: .topTrailing) {
            StockBadge(status: product.stockStatus)
                .padding(16)
        }
    }

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(product.name)
                .font(AppTypography.titleFont)
                .foregroundColor(colorScheme == .dark ? AppColors.darkTextPrimary : AppColors.textPrimary)

            HStack(spacing: 8) {
                BadgeView(text: product.category.rawValue, style: .default)
                BadgeView(text: product.supplier, style: .secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var alertBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: product.stockStatus == .outOfStock ? "xmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundColor(product.stockStatus == .outOfStock ? AppColors.error : AppColors.warning)

            VStack(alignment: .leading, spacing: 2) {
                Text(product.stockStatus == .outOfStock ? "Producto Agotado" : "Stock Bajo")
                    .font(AppTypography.captionFont)
                    .fontWeight(.semibold)

                Text(product.stockStatus == .outOfStock ?
                     "Este producto necesita reabastecimiento urgente" :
                     "Solo quedan \(product.quantity) unidades (mín: \(product.minStock))")
                    .font(AppTypography.caption2Font)
                    .foregroundColor(AppColors.textSecondary)
            }

            Spacer()
        }
        .padding(14)
        .background(
            (product.stockStatus == .outOfStock ? AppColors.error : AppColors.warning).opacity(0.1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var pricingGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ], spacing: 12) {
            pricingCard(title: "Precio de Venta", value: product.salePrice.currencyFormatted, icon: "tag.fill", color: AppColors.primary)
            pricingCard(title: "Cantidad", value: "\(product.quantity) uds", icon: "cube.fill", color: quantityColor)
            pricingCard(title: "Precio de Costo", value: product.costPrice.currencyFormatted, icon: "dollarsign.circle", color: AppColors.textSecondary)
            pricingCard(title: "Margen", value: product.profitMargin.percentFormatted, icon: "percent", color: product.profitMargin >= 20 ? AppColors.success : AppColors.warning)
        }
    }

    private func pricingCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(color)

            Text(value)
                .font(AppTypography.title3Font)
                .foregroundColor(colorScheme == .dark ? AppColors.darkTextPrimary : AppColors.textPrimary)

            Text(title)
                .font(AppTypography.caption2Font)
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .cardStyle()
    }

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Detalles del Producto")
                .font(AppTypography.headlineFont)

            detailRow(icon: "barcode", label: "SKU", value: product.sku)
            detailRow(icon: "barcode.viewfinder", label: "Código de Barras", value: product.barcode)
            detailRow(icon: "mappin", label: "Ubicación", value: product.location)
            detailRow(icon: "arrow.down.circle", label: "Stock Mínimo", value: "\(product.minStock) unidades")

            if let expDate = product.expirationDate {
                detailRow(
                    icon: "calendar",
                    label: "Fecha de Vencimiento",
                    value: expDate.shortFormatted,
                    valueColor: product.isExpiringSoon ? AppColors.warning : nil
                )
            }

            detailRow(icon: "clock", label: "Última Actualización", value: product.lastUpdated.relativeFormatted)
        }
        .padding(16)
        .cardStyle()
    }

    private func detailRow(icon: String, label: String, value: String, valueColor: Color? = nil) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(AppColors.textTertiary)
                .frame(width: 24)

            Text(label)
                .font(AppTypography.calloutFont)
                .foregroundColor(AppColors.textSecondary)

            Spacer()

            Text(value)
                .font(AppTypography.calloutFont)
                .fontWeight(.medium)
                .foregroundColor(valueColor ?? (colorScheme == .dark ? AppColors.darkTextPrimary : AppColors.textPrimary))
        }
        .padding(.vertical, 4)
    }

    private var financialSummary: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Resumen Financiero")
                .font(AppTypography.headlineFont)

            HStack {
                Text("Valor en Stock (Venta)")
                    .font(AppTypography.calloutFont)
                    .foregroundColor(AppColors.textSecondary)
                Spacer()
                Text(product.stockValue.currencyFormatted)
                    .font(AppTypography.headlineFont)
                    .foregroundColor(AppColors.success)
            }

            Divider()

            HStack {
                Text("Valor en Stock (Costo)")
                    .font(AppTypography.calloutFont)
                    .foregroundColor(AppColors.textSecondary)
                Spacer()
                Text(product.costValue.currencyFormatted)
                    .font(AppTypography.headlineFont)
            }

            Divider()

            HStack {
                Text("Ganancia Potencial")
                    .font(AppTypography.calloutFont)
                    .foregroundColor(AppColors.textSecondary)
                Spacer()
                Text((product.stockValue - product.costValue).currencyFormatted)
                    .font(AppTypography.headlineFont)
                    .foregroundColor(AppColors.accent)
            }
        }
        .padding(16)
        .cardStyle()
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button(action: { showEditProduct = true }) {
                HStack {
                    Image(systemName: "pencil")
                    Text("Editar Producto")
                }
            }
            .buttonStyle(PrimaryButtonStyle())

            Button(role: .destructive, action: { showDeleteConfirm = true }) {
                HStack {
                    Image(systemName: "trash")
                    Text("Eliminar Producto")
                }
            }
            .buttonStyle(SecondaryButtonStyle())
        }
    }

    private var categoryColor: Color {
        switch product.category {
        case .beverages: return AppColors.secondary
        case .dairy: return AppColors.info
        case .snacks: return AppColors.warning
        case .cleaning: return AppColors.accent
        case .personalCare: return .pink
        case .grains: return .brown
        default: return AppColors.primary
        }
    }

    private var quantityColor: Color {
        switch product.stockStatus {
        case .inStock: return AppColors.success
        case .lowStock: return AppColors.warning
        case .outOfStock: return AppColors.error
        }
    }
}
