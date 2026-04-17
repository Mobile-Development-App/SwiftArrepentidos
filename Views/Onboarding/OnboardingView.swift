import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var currentPage = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "camera.viewfinder",
            title: "Escaneo con IA",
            description: "Escanea tus productos con la cámara y nuestra IA los reconocerá automáticamente, ahorrándote tiempo en el registro de inventario.",
            color: AppColors.primary
        ),
        OnboardingPage(
            icon: "bell.badge.fill",
            title: "Alertas Inteligentes",
            description: "Recibe notificaciones cuando tus productos estén por agotarse, próximos a vencer o cuando sea momento de reabastecer.",
            color: AppColors.warning
        ),
        OnboardingPage(
            icon: "chart.bar.fill",
            title: "Analítica en Tiempo Real",
            description: "Visualiza el rendimiento de tu inventario con gráficos y estadísticas que te ayudan a tomar mejores decisiones de negocio.",
            color: AppColors.accent
        )
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button("Omitir") {
                    authViewModel.completeOnboarding()
                }
                .font(AppTypography.calloutFont)
                .foregroundColor(AppColors.textSecondary)
                .padding()
            }

            TabView(selection: $currentPage) {
                ForEach(0..<pages.count, id: \.self) { index in
                    onboardingPageView(pages[index])
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut(duration: 0.3), value: currentPage)

            HStack(spacing: 8) {
                ForEach(0..<pages.count, id: \.self) { index in
                    Circle()
                        .fill(index == currentPage ? AppColors.primary : AppColors.textTertiary.opacity(0.3))
                        .frame(width: index == currentPage ? 24 : 8, height: 8)
                        .animation(.spring(response: 0.3), value: currentPage)
                }
            }
            .padding(.bottom, 32)

            HStack(spacing: 16) {
                if currentPage > 0 {
                    Button(action: {
                        withAnimation { currentPage -= 1 }
                        HapticManager.impact(.light)
                    }) {
                        Text("Atrás")
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }

                Button(action: {
                    if currentPage < pages.count - 1 {
                        withAnimation { currentPage += 1 }
                    } else {
                        authViewModel.completeOnboarding()
                    }
                    HapticManager.impact(.light)
                }) {
                    Text(currentPage < pages.count - 1 ? "Siguiente" : "Comenzar")
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .background(Color(.systemBackground))
    }

    @ViewBuilder
    private func onboardingPageView(_ page: OnboardingPage) -> some View {
        VStack(spacing: 32) {
            Spacer()

            ZStack {
                Circle()
                    .fill(page.color.opacity(0.1))
                    .frame(width: 160, height: 160)

                Circle()
                    .fill(page.color.opacity(0.2))
                    .frame(width: 120, height: 120)

                Image(systemName: page.icon)
                    .font(.system(size: 52))
                    .foregroundColor(page.color)
            }

            VStack(spacing: 16) {
                Text(page.title)
                    .font(AppTypography.titleFont)
                    .multilineTextAlignment(.center)

                Text(page.description)
                    .font(AppTypography.bodyFont)
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()
        }
    }
}

struct OnboardingPage {
    let icon: String
    let title: String
    let description: String
    let color: Color
}
