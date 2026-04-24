import SwiftUI
import FirebaseCore
import UIKit

/// UIApplicationDelegate adapter — requerido por Firebase para swizzling.
/// Silencia el warning "App Delegate does not conform to UIApplicationDelegate protocol".
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        FirebaseApp.configure()
        return true
    }
}

@main
struct InventarIAApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var inventoryViewModel = InventoryViewModel()
    @StateObject private var storeViewModel = StoreViewModel()
    @StateObject private var settingsViewModel = SettingsViewModel()
    @StateObject private var analyticsViewModel = AnalyticsViewModel()

    init() {
        _ = NetworkMonitor.shared

        PersistenceService.shared.clearMockDataIfNeeded()

        // offline nunca se replayean al volver la conexión
        OfflineQueueService.bootstrap(replayHandlers: .init(
            createProduct: { product in
                try await ProductRepository().createProduct(product)
            },
            updateProduct: { id, product in
                try await ProductRepository().updateProduct(id: id.uuidString, product)
            },
            deleteProduct: { id in
                try await ProductRepository().deleteProduct(id: id.uuidString)
            }
        ))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authViewModel)
                .environmentObject(inventoryViewModel)
                .environmentObject(storeViewModel)
                .environmentObject(settingsViewModel)
                .environmentObject(analyticsViewModel)
                .preferredColorScheme(settingsViewModel.isDarkMode ? .dark : .light)
                .tint(AppColors.freshSky)
        }
    }
}
