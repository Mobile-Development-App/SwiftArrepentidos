import SwiftUI

struct ProductsView: View {
    @EnvironmentObject var inventoryViewModel: InventoryViewModel
    @State private var selectedProduct: Product?
    @State private var showAddProduct = false

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                SearchBarView(text: $inventoryViewModel.searchText)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                // Filter tabs
                filterTabs
                    .padding(.top, 12)

                // Product list
                if inventoryViewModel.filteredProducts.isEmpty {
                    EmptyStateView(
                        icon: "shippingbox",
                        title: "No se encontraron productos",
                        description: inventoryViewModel.searchText.isEmpty ?
                            "No hay productos en esta categoría" :
                            "No hay resultados para \"\(inventoryViewModel.searchText)\"",
                        actionTitle: "Agregar Producto",
                        action: { showAddProduct = true }
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(inventoryViewModel.filteredProducts) { product in
                                ProductCardView(product: product) {
                                    selectedProduct = product
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 100)
                    }
                }
            }
            .background(colorScheme == .dark ? AppColors.darkBackground : AppColors.background)
            .navigationTitle("Productos")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showAddProduct = true }) {
                        Image(systemName: "plus")
                            .foregroundColor(AppColors.primary)
                    }
                }
            }
            .sheet(item: $selectedProduct) { product in
                ProductDetailView(product: product)
            }
            .sheet(isPresented: $showAddProduct) {
                AddProductView()
            }
        }
    }

    private var filterTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(InventoryViewModel.StockFilter.allCases, id: \.self) { filter in
                    filterTab(filter)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func filterTab(_ filter: InventoryViewModel.StockFilter) -> some View {
        let isSelected = inventoryViewModel.selectedFilter == filter
        let count = inventoryViewModel.filterCounts[filter] ?? 0

        return Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                inventoryViewModel.selectedFilter = filter
            }
            HapticManager.selection()
        }) {
            HStack(spacing: 6) {
                Text(filter.rawValue)
                    .font(AppTypography.captionFont)

                Text("\(count)")
                    .font(AppTypography.caption2Font)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        isSelected ? Color.white.opacity(0.2) :
                            (colorScheme == .dark ? AppColors.darkSurfaceSecondary : AppColors.surfaceSecondary)
                    )
                    .clipShape(Capsule())
            }
            .foregroundColor(isSelected ? .white : (colorScheme == .dark ? AppColors.darkTextPrimary : AppColors.textPrimary))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(isSelected ? AppColors.primary : (colorScheme == .dark ? AppColors.darkSurface : AppColors.surface))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(isSelected ? Color.clear : AppColors.border.opacity(0.5), lineWidth: 1)
            )
        }
    }
}
