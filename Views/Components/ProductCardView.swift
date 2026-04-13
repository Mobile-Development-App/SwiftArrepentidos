import SwiftUI

struct ProductCardView: View {
    let product: Product
    var onTap: (() -> Void)? = nil

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Button(action: { onTap?() }) {
            HStack(spacing: 14) {
                // Product Image/Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(categoryColor.opacity(0.12))
                    Image(systemName: product.category.icon)
                        .font(.system(size: 22))
                        .foregroundColor(categoryColor)
                }
                .frame(width: 56, height: 56)

                // Product Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(product.name)
                        .font(AppTypography.headlineFont)
                        .foregroundColor(colorScheme == .dark ? AppColors.darkTextPrimary : AppColors.textPrimary)
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        Text(product.sku)
                            .font(AppTypography.caption2Font)
                            .foregroundColor(colorScheme == .dark ? AppColors.darkTextSecondary : AppColors.textSecondary)

                        Text("•")
                            .foregroundColor(AppColors.textTertiary)

                        Text(product.category.rawValue)
                            .font(AppTypography.caption2Font)
                            .foregroundColor(colorScheme == .dark ? AppColors.darkTextSecondary : AppColors.textSecondary)
                    }

                    HStack {
                        Text(product.salePrice.currencyFormatted)
                            .font(AppTypography.calloutFont)
                            .fontWeight(.semibold)
                            .foregroundColor(colorScheme == .dark ? AppColors.darkTextPrimary : AppColors.textPrimary)

                        Spacer()

                        StockBadge(status: product.stockStatus)
                    }
                }

                Spacer()

                // Quantity
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(product.quantity)")
                        .font(AppTypography.title3Font)
                        .foregroundColor(quantityColor)
                    Text("uds")
                        .font(AppTypography.caption2Font)
                        .foregroundColor(colorScheme == .dark ? AppColors.darkTextSecondary : AppColors.textSecondary)
                }
                .frame(width: 40)
            }
            .padding(14)
            .cardStyle()
        }
        .buttonStyle(.plain)
    }

    private var categoryColor: Color {
        switch product.category {
        case .beverages: return AppColors.secondary
        case .dairy: return AppColors.info
        case .snacks: return AppColors.warning
        case .cleaning: return AppColors.accent
        case .personalCare: return .pink
        case .grains: return .brown
        case .fruits: return AppColors.success
        case .meat: return AppColors.error
        case .bakery: return .orange
        case .frozen: return AppColors.secondary
        case .condiments: return .red
        case .other: return AppColors.textSecondary
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
