import SwiftUI

struct StoreManagementView: View {
    @EnvironmentObject var storeViewModel: StoreViewModel
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme

    @State private var showAddStore = false
    @State private var selectedStore: Store?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    //active store info
                    if let activeStore = storeViewModel.activeStore {
                        activeStoreCard(activeStore)
                    }
                    //all stores
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Todas las Tiendas")
                                .font(AppTypography.headlineFont)
                            Spacer()
                            Text("\(storeViewModel.stores.count) tiendas")
                                .font(AppTypography.captionFont)
                                .foregroundColor(AppColors.textSecondary)
                        }

                        ForEach(storeViewModel.stores) { store in
                            storeCard(store)
                        }
                    }

                    //add store button
                    Button(action: { showAddStore = true }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Agregar Nueva Tienda")
                        }
                    }
                    .buttonStyle(SecondaryButtonStyle())

                    Spacer().frame(height: 20)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
            }
            .background(colorScheme == .dark ? AppColors.darkBackground : AppColors.background)
            .navigationTitle("Gestión de Tiendas")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                    }
                }
            }
            .sheet(isPresented: $showAddStore) {
                AddStoreView()
            }
            .sheet(item: $selectedStore) { store in
                StoreDetailView(store: store)
            }
        }
    }

    private func activeStoreCard(_ store: Store) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "storefront.fill")
                    .foregroundColor(AppColors.primary)
                Text("Tienda Activa")
                    .font(AppTypography.captionFont)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.primary)
                Spacer()
                BadgeView(text: "Activa", style: .success)
            }

            Text(store.name)
                .font(AppTypography.title3Font)

            Text(store.address)
                .font(AppTypography.captionFont)
                .foregroundColor(AppColors.textSecondary)

            HStack(spacing: 16) {
                infoItem(icon: "person.2", value: "\(store.employeeCount) empleados")
                infoItem(icon: "shippingbox", value: "\(store.productCount) productos")
            }
        }
        .padding(16)
        .background(AppColors.primary.opacity(0.05))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(AppColors.primary.opacity(0.2), lineWidth: 1.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func storeCard(_ store: Store) -> some View {
        Button(action: { selectedStore = store }) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(store.name)
                        .font(AppTypography.headlineFont)
                        .foregroundColor(colorScheme == .dark ? AppColors.darkTextPrimary : AppColors.textPrimary)

                    Spacer()

                    if store.id == storeViewModel.activeStoreId {
                        BadgeView(text: "Activa", style: .success)
                    }
                }

                Text(store.address)
                    .font(AppTypography.captionFont)
                    .foregroundColor(AppColors.textSecondary)

                HStack(spacing: 16) {
                    infoItem(icon: "phone", value: store.phone)
                }

                HStack(spacing: 16) {
                    infoItem(icon: "person.2", value: "\(store.employeeCount)")
                    infoItem(icon: "shippingbox", value: "\(store.productCount)")
                    infoItem(icon: "dollarsign.circle", value: store.formattedSales)
                }
            }
            .padding(16)
            .cardStyle()
        }
        .buttonStyle(.plain)
    }

    private func infoItem(icon: String, value: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(AppColors.textTertiary)
            Text(value)
                .font(AppTypography.caption2Font)
                .foregroundColor(AppColors.textSecondary)
        }
    }
}
