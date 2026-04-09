import SwiftUI
import FirebaseCore

@main
struct InventarIAApp: App {
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var inventoryViewModel = InventoryViewModel()
    @StateObject private var storeViewModel = StoreViewModel()
    @StateObject private var settingsViewModel = SettingsViewModel()
    @StateObject private var analyticsViewModel = AnalyticsViewModel()

    init() {
        // Initialize Firebase
        FirebaseApp.configure()

        // Start network monitoring
        _ = NetworkMonitor.shared

        // Clear any old mock data on first run after update
        PersistenceService.shared.clearMockDataIfNeeded()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authViewModel)
                .environmentObject(inventoryViewModel)
                .environmentObject(storeViewModel)
                .environmentObject(settingsViewModel)
                .environmentObject(analyticsViewModel)
                .preferredColorScheme(settingsViewModel.isDarkMode ? .dark : nil)
                .tint(AppColors.freshSky)
        }
    }
}
