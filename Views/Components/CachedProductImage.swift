import SwiftUI
import Kingfisher

// ─────────────────────────────────────────────────────────────────────────────
// CachedProductImage — vista reutilizable que renderiza la imagen remota de
// un `Product` con caché Kingfisher de dos capas (memoria + disco).
//
// • Si el `imageURL` está vacío o falla la descarga, cae al ícono de la
//   categoría con su color de marca — manteniendo la coherencia visual con
//   las pantallas que ya usan `Image(systemName: product.category.icon)`.
// • La descarga corre off-main automáticamente (Kingfisher usa su propia
//   queue); SwiftUI sólo recibe la imagen ya decodificada.
// • `placeholder` y `transition(.fade)` ofrecen feedback visual mientras
//   la imagen llega.
// ─────────────────────────────────────────────────────────────────────────────

struct CachedProductImage: View {

    enum Style {
        case thumbnail   // 56x56 con corner radius 12 (ProductCardView)
        case hero        // 100% width, height 180 (ProductDetailView)
    }

    let imageURL: String?
    let category: ProductCategory
    let style: Style

    var body: some View {
        if let urlString = imageURL,
           !urlString.isEmpty,
           let url = URL(string: urlString) {
            remoteImage(url: url)
        } else {
            fallbackIcon
        }
    }

    @ViewBuilder
    private func remoteImage(url: URL) -> some View {
        KFImage(url)
            .placeholder { fallbackIcon.opacity(0.6) }
            .fade(duration: 0.25)
            .cancelOnDisappear(true)
            .resizable()
            .scaledToFill()
            .modifier(CachedImageFrame(style: style))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }

    @ViewBuilder
    private var fallbackIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(categoryColor.opacity(style == .hero ? 0.15 : 0.12))
            Image(systemName: category.icon)
                .font(.system(size: style == .hero ? 64 : 22))
                .foregroundColor(categoryColor)
        }
        .modifier(CachedImageFrame(style: style))
    }

    // MARK: - Layout

    private var cornerRadius: CGFloat {
        switch style {
        case .thumbnail: return 12
        case .hero:      return 20
        }
    }

    private var categoryColor: Color {
        switch category {
        case .beverages:    return AppColors.secondary
        case .dairy:        return AppColors.info
        case .snacks:       return AppColors.warning
        case .cleaning:     return AppColors.accent
        case .personalCare: return .pink
        case .grains:       return .brown
        case .fruits:       return AppColors.success
        case .meat:         return AppColors.error
        case .bakery:       return .orange
        case .frozen:       return AppColors.secondary
        case .condiments:   return .red
        case .other:        return AppColors.textSecondary
        }
    }
}

/// Aplica el frame correcto según el estilo. Lo extraemos en un modifier
/// porque `.hero` necesita ancho elástico (`maxWidth: .infinity`) y
/// `CGSize` no acepta `.infinity` directamente — un modifier separado
/// es más limpio que un `if/else` repetido en cada call site.
private struct CachedImageFrame: ViewModifier {
    let style: CachedProductImage.Style

    func body(content: Content) -> some View {
        switch style {
        case .thumbnail:
            content.frame(width: 56, height: 56)
        case .hero:
            content.frame(maxWidth: .infinity).frame(height: 180)
        }
    }
}
