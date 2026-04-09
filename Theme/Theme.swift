import SwiftUI

// MARK: - App Colors (Wiki Palette)
// Ink Black: #00171F | Dust Grey: #DBD3D8 | Deep Space Blue: #003459
// Tea Green: #D6FFB7 | Fresh Sky: #00A8E8
struct AppColors {
    // ── Wiki Primary Palette ──
    static let inkBlack = Color(hex: "#00171F")          // Navigation, headers, primary text
    static let dustGrey = Color(hex: "#DBD3D8")           // Emphasis, selected states
    static let deepSpaceBlue = Color(hex: "#003459")      // Main screen containers/background
    static let teaGreen = Color(hex: "#D6FFB7")           // Buttons, FAB, confirmations, action
    static let freshSky = Color(hex: "#00A8E8")           // Dividers, placeholders, secondary text/links

    // ── Semantic Aliases ──
    static let primary = deepSpaceBlue                     // Primary brand color
    static let primaryLight = Color(hex: "#004A7F")        // Lighter variant
    static let primaryDark = inkBlack                      // Darker variant

    static let secondary = freshSky                        // Secondary actions, links
    static let secondaryLight = Color(hex: "#33BCEF")

    static let accent = teaGreen                           // CTA buttons, FAB, confirmations
    static let accentDark = Color(hex: "#A8E68A")          // Pressed state for accent

    // ── Status Colors (from MS6) ──
    static let success = Color(hex: "#2ECC71")             // Healthy indicators
    static let warning = Color(hex: "#F39C12")             // Caution states
    static let error = Color(hex: "#E74C3C")               // Alerts, destructive actions
    static let info = freshSky                             // Informational

    // ── Light Mode ──
    static let background = Color(hex: "#F0F4F8")          // Light background
    static let surface = Color.white                       // Card surfaces
    static let surfaceSecondary = Color(hex: "#EBF0F5")    // Secondary surfaces
    static let border = dustGrey                           // Borders, dividers
    static let textPrimary = inkBlack                      // Primary text
    static let textSecondary = Color(hex: "#5A6B7D")       // Secondary text
    static let textTertiary = dustGrey                     // Tertiary/placeholder text

    // ── Dark Mode ──
    static let darkBackground = inkBlack                   // Dark background
    static let darkSurface = deepSpaceBlue                 // Dark card surfaces
    static let darkSurfaceSecondary = Color(hex: "#004A7F") // Dark secondary surface
    static let darkBorder = Color(hex: "#3D6B8E")          // Dark borders
    static let darkTextPrimary = Color(hex: "#F0F4F8")     // Primary text dark
    static let darkTextSecondary = dustGrey                // Secondary text dark
}

// MARK: - Color Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Typography (Inter font from Wiki)
struct AppTypography {
    // Title: Bold, 22-24pt
    static let largeTitleFont: Font = .system(size: 28, weight: .bold)
    static let titleFont: Font = .system(size: 22, weight: .bold)
    static let title2Font: Font = .system(size: 20, weight: .semibold)
    // Section Header: SemiBold, 18pt
    static let title3Font: Font = .system(size: 18, weight: .semibold)
    // KPI Numbers: SemiBold, 16-18pt
    static let headlineFont: Font = .system(size: 16, weight: .semibold)
    // Body: Regular, 14-16pt
    static let bodyFont: Font = .system(size: 16, weight: .regular)
    static let calloutFont: Font = .system(size: 14, weight: .medium)
    static let captionFont: Font = .system(size: 12, weight: .medium)
    static let caption2Font: Font = .system(size: 11, weight: .regular)
}

// MARK: - Shadows
struct AppShadows {
    static let small = ShadowStyle(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    static let medium = ShadowStyle(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
    static let large = ShadowStyle(color: .black.opacity(0.15), radius: 16, x: 0, y: 4)
}

struct ShadowStyle {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

// MARK: - View Modifiers
struct CardModifier: ViewModifier {
    @Environment(\.colorScheme) var colorScheme

    func body(content: Content) -> some View {
        content
            .background(colorScheme == .dark ? AppColors.darkSurface : AppColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.3 : 0.08), radius: 8, x: 0, y: 2)
    }
}

// Tea Green buttons with Ink Black text (per wiki design system)
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTypography.headlineFont)
            .foregroundColor(AppColors.inkBlack)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isEnabled ? AppColors.teaGreen : AppColors.teaGreen.opacity(0.4))
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// Deep Space Blue outlined button
struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTypography.headlineFont)
            .foregroundColor(AppColors.deepSpaceBlue)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(AppColors.deepSpaceBlue, lineWidth: 1.5)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct GhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTypography.headlineFont)
            .foregroundColor(AppColors.freshSky)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(configuration.isPressed ? AppColors.freshSky.opacity(0.1) : Color.clear)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// Deep Space Blue filled button (for dark backgrounds)
struct AccentButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTypography.headlineFont)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isEnabled ? AppColors.deepSpaceBlue : AppColors.deepSpaceBlue.opacity(0.4))
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(CardModifier())
    }
}
