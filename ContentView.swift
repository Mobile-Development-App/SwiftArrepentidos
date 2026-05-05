import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var didBootstrap = false

    var body: some View {
        Group {
            if !authViewModel.hasCompletedOnboarding {
                OnboardingView()
                    .transition(.opacity)
            } else if !authViewModel.isAuthenticated {
                LoginView()
                    .transition(.opacity)
            } else {
                MainTabView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: authViewModel.hasCompletedOnboarding)
        .animation(.easeInOut(duration: 0.3), value: authViewModel.isAuthenticated)
        .onAppear {
            // BD relacional local: el bootstrap se hace desde la primera
            // vista para asegurar que el `ModelContext` ya tiene su scene
            // gráfico activo. Idempotente: sólo escribe la primera vez.
            if !didBootstrap {
                didBootstrap = true
                LocalDatabaseService.shared.bootstrapLaunchEvent()
            }
        }
    }
}
