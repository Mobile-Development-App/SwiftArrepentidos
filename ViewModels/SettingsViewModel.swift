import SwiftUI
import Combine

@MainActor
class SettingsViewModel: ObservableObject {
    // `@Published` + `didSet` manual en vez de `@AppStorage`: el wrapper de
    // AppStorage no siempre dispara `objectWillChange` cuando se usa dentro
    // de una clase `ObservableObject`, lo que hacía que el modo oscuro sólo
    // se aplicara después de salir y volver a Ajustes. Con esto, cada toggle
    // notifica al root y el `preferredColorScheme` reacciona al instante.
    @Published var isDarkMode: Bool {
        didSet { UserDefaults.standard.set(isDarkMode, forKey: Self.darkModeKey) }
    }
    @Published var notificationsEnabled: Bool {
        didSet { UserDefaults.standard.set(notificationsEnabled, forKey: Self.notificationsKey) }
    }
    @Published var selectedLanguage: String {
        didSet { UserDefaults.standard.set(selectedLanguage, forKey: Self.languageKey) }
    }

    @Published var showingLogoutConfirmation = false

    private static let darkModeKey = "isDarkMode"
    private static let notificationsKey = "notificationsEnabled"
    private static let languageKey = "selectedLanguage"

    init() {
        let defaults = UserDefaults.standard
        self.isDarkMode = defaults.bool(forKey: Self.darkModeKey)
        // `object(forKey:)` distingue "no seteado" de `false` — default = true.
        self.notificationsEnabled = (defaults.object(forKey: Self.notificationsKey) as? Bool) ?? true
        self.selectedLanguage = defaults.string(forKey: Self.languageKey) ?? "es"
    }

    var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    var languageName: String {
        switch selectedLanguage {
        case "es": return "Español"
        case "en": return "English"
        default: return "Español"
        }
    }

    func toggleDarkMode() {
        isDarkMode.toggle()
        HapticManager.impact(.light)
    }

    func toggleNotifications() {
        notificationsEnabled.toggle()
        HapticManager.impact(.light)
    }
}
