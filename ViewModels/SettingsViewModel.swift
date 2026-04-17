import SwiftUI
import Combine

@MainActor
class SettingsViewModel: ObservableObject {
    @AppStorage("isDarkMode") var isDarkMode = false
    @AppStorage("notificationsEnabled") var notificationsEnabled = true
    @AppStorage("selectedLanguage") var selectedLanguage = "es"

    @Published var showingLogoutConfirmation = false

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
