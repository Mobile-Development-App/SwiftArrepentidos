import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authViewModel: AuthViewModel

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
    }
}
