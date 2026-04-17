import SwiftUI

struct AddStoreView: View {
    @EnvironmentObject var storeViewModel: StoreViewModel
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    VStack(spacing: 14) {
                        formField(label: "Nombre de la tienda", placeholder: "Ej: Sucursal Centro", text: $storeViewModel.newStoreName, icon: "storefront")
                        formField(label: "Dirección", placeholder: "Ej: Cra 15 #45-20", text: $storeViewModel.newStoreAddress, icon: "mappin")
                        formField(label: "Teléfono", placeholder: "+57 300 000 0000", text: $storeViewModel.newStorePhone, icon: "phone", keyboardType: .phonePad)
                        formField(label: "Correo electrónico", placeholder: "tienda@email.com", text: $storeViewModel.newStoreEmail, icon: "envelope", keyboardType: .emailAddress)
                        formField(label: "Gerente", placeholder: "Nombre del gerente", text: $storeViewModel.newStoreManager, icon: "person")
                    }
                    .padding(16)
                    .cardStyle()

                    HStack(spacing: 12) {
                        Button(action: { dismiss() }) {
                            Text("Cancelar")
                        }
                        .buttonStyle(SecondaryButtonStyle())

                        Button(action: {
                            storeViewModel.addStore()
                            dismiss()
                        }) {
                            Text("Guardar")
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(!storeViewModel.isAddStoreValid)
                    }

                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(colorScheme == .dark ? AppColors.darkBackground : AppColors.background)
            .navigationTitle("Nueva Tienda")
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
    private func formField(label: String, placeholder: String, text: Binding<String>, icon: String, keyboardType: UIKeyboardType = .default) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(AppTypography.captionFont)
                .foregroundColor(AppColors.textSecondary)

            HStack {
                Image(systemName: icon)
                    .foregroundColor(AppColors.textTertiary)
                TextField(placeholder, text: text)
                    .font(AppTypography.bodyFont)
                    .keyboardType(keyboardType)
                    .autocapitalization(keyboardType == .emailAddress ? .none : .words)
            }
            .padding(14)
            .background(colorScheme == .dark ? AppColors.darkSurfaceSecondary : AppColors.surfaceSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}
