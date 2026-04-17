import SwiftUI

struct HelpCenterView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme

    private let helpCategories: [HelpCategory] = [
        HelpCategory(
            name: "Inventario",
            icon: "shippingbox.fill",
            color: AppColors.primary,
            items: [
                HelpItem(title: "Agregar Productos", description: "Registra nuevos productos manualmente o mediante escaneo con IA."),
                HelpItem(title: "Gestión de Stock", description: "Monitorea niveles de stock y configura alertas de stock mínimo."),
                HelpItem(title: "Control de Vencimiento", description: "Configura alertas para productos próximos a vencer.")
            ]
        ),
        HelpCategory(
            name: "Analítica",
            icon: "chart.bar.fill",
            color: AppColors.accent,
            items: [
                HelpItem(title: "Reportes de Ventas", description: "Visualiza tendencias de ventas por período de tiempo."),
                HelpItem(title: "Exportar Datos", description: "Exporta reportes en formato PDF o CSV para contabilidad.")
            ]
        ),
        HelpCategory(
            name: "Escaneo",
            icon: "camera.viewfinder",
            color: AppColors.secondary,
            items: [
                HelpItem(title: "Escaneo con IA", description: "Usa la cámara para identificar productos automáticamente."),
                HelpItem(title: "Códigos de Barras", description: "Escanea códigos de barras para buscar productos en la base de datos."),
                HelpItem(title: "Detección de Duplicados", description: "El sistema detecta automáticamente si un producto ya existe.")
            ]
        ),
        HelpCategory(
            name: "Gestión",
            icon: "person.2.fill",
            color: AppColors.warning,
            items: [
                HelpItem(title: "Multi-tienda", description: "Administra múltiples ubicaciones desde una sola cuenta."),
                HelpItem(title: "Roles de Equipo", description: "Asigna roles y permisos a los miembros del equipo."),
                HelpItem(title: "Seguridad", description: "Configura autenticación de dos factores y gestiona accesos.")
            ]
        )
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(helpCategories, id: \.name) { category in
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) {
                                Image(systemName: category.icon)
                                    .foregroundColor(category.color)
                                Text(category.name)
                                    .font(AppTypography.headlineFont)
                            }

                            ForEach(category.items, id: \.title) { item in
                                helpItemView(item)
                            }
                        }
                        .padding(16)
                        .cardStyle()
                    }

                    VStack(spacing: 12) {
                        Image(systemName: "headphones")
                            .font(.system(size: 32))
                            .foregroundColor(AppColors.primary)

                        Text("¿Necesitas más ayuda?")
                            .font(AppTypography.headlineFont)

                        Text("Contacta a nuestro equipo de soporte")
                            .font(AppTypography.captionFont)
                            .foregroundColor(AppColors.textSecondary)

                        Button(action: {}) {
                            Text("Contactar Soporte")
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    }
                    .padding(20)
                    .cardStyle()

                    Spacer().frame(height: 20)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
            }
            .background(colorScheme == .dark ? AppColors.darkBackground : AppColors.background)
            .navigationTitle("Centro de Ayuda")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func helpItemView(_ item: HelpItem) -> some View {
        DisclosureGroup {
            Text(item.description)
                .font(AppTypography.captionFont)
                .foregroundColor(AppColors.textSecondary)
                .padding(.vertical, 8)
        } label: {
            Text(item.title)
                .font(AppTypography.calloutFont)
                .foregroundColor(colorScheme == .dark ? AppColors.darkTextPrimary : AppColors.textPrimary)
        }
    }
}

struct HelpCategory {
    let name: String
    let icon: String
    let color: Color
    let items: [HelpItem]
}

struct HelpItem {
    let title: String
    let description: String
}
