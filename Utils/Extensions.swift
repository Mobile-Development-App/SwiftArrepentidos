import SwiftUI

// MARK: - UUID ↔ Backend
extension UUID {
    /// Backend (Firestore) stores document IDs in lowercase UUID format (from Node.js `uuidv4()`).
    /// Swift's default `uuidString` is uppercase → causes NOT_FOUND on PATCH/DELETE/POST calls.
    /// This property normalizes to lowercase for HTTP requests.
    var apiString: String {
        return uuidString.lowercased()
    }
}

// MARK: - Shared formatter cache (Sprint 4 micro-optimization)
//
// Antes de este cambio, cada llamada a `Double.currencyFormatted`,
// `Int.formatted`, `Date.shortFormatted`, etc. instanciaba un
// `NumberFormatter`/`DateFormatter` nuevo. Esos formatters son CAROS de
// construir (cargan tablas ICU, configuran `Locale`), y los hot-paths los
// llaman cientos de veces por scroll del catálogo y por render del
// dashboard de BQs.
//
// Cacheamos una instancia única por configuración. Como `NumberFormatter`
// y `DateFormatter` son thread-safe a partir de iOS 7, las podemos compartir
// sin problemas.
private enum SharedFormatters {
    static let copCurrency: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencySymbol = "$"
        f.maximumFractionDigits = 0
        f.locale = Locale(identifier: "es_CO")
        return f
    }()

    static let groupedInt: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = "."
        return f
    }()

    static let mediumDateES: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.locale = Locale(identifier: "es_ES")
        return f
    }()

    static let dayMonthES: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd MMM"
        f.locale = Locale(identifier: "es_ES")
        return f
    }()

    static let dayOfWeekES: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        f.locale = Locale(identifier: "es_ES")
        return f
    }()

    static let relativeES: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.locale = Locale(identifier: "es_ES")
        f.unitsStyle = .abbreviated
        return f
    }()
}

// MARK: - Number Formatting
extension Double {
    var currencyFormatted: String {
        SharedFormatters.copCurrency.string(from: NSNumber(value: self)) ?? "$0"
    }

    var compactCurrency: String {
        if self >= 1_000_000 {
            return String(format: "$%.1fM", self / 1_000_000)
        } else if self >= 1_000 {
            return String(format: "$%.0fK", self / 1_000)
        }
        return String(format: "$%.0f", self)
    }

    var percentFormatted: String {
        return String(format: "%.1f%%", self)
    }
}

extension Int {
    var formatted: String {
        SharedFormatters.groupedInt.string(from: NSNumber(value: self)) ?? "\(self)"
    }
}

// MARK: - Date Formatting
extension Date {
    var shortFormatted: String {
        SharedFormatters.mediumDateES.string(from: self)
    }

    var dayMonth: String {
        SharedFormatters.dayMonthES.string(from: self)
    }

    var relativeFormatted: String {
        SharedFormatters.relativeES.localizedString(for: self, relativeTo: Date())
    }

    var dayOfWeek: String {
        SharedFormatters.dayOfWeekES.string(from: self)
    }
}

// MARK: - View Extensions
extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

// MARK: - Haptic Feedback
struct HapticManager {
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }

    static func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(type)
    }

    static func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }
}
