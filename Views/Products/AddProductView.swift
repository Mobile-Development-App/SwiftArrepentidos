import SwiftUI

struct AddProductView: View {
    var editingProduct: Product? = nil
    var fromScan: ScannedProductResult? = nil

    @EnvironmentObject var inventoryViewModel: InventoryViewModel
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme

    @State private var name = ""
    @State private var sku = ""
    @State private var barcode = ""
    @State private var category: ProductCategory = .other
    @State private var supplier = ""
    @State private var costPrice = ""
    @State private var salePrice = ""
    @State private var quantity = ""
    @State private var minStock = ""
    @State private var location = ""
    @State private var expirationDate = Date()
    @State private var hasExpiration = false
    @State private var description = ""
    @State private var showSuccess = false

    var isEditing: Bool { editingProduct != nil }

    var calculatedMargin: Double {
        guard let cost = Double(costPrice), let sale = Double(salePrice), cost > 0 else { return 0 }
        return ((sale - cost) / cost) * 100
    }

    var isFormValid: Bool {
        !name.isEmpty && !sku.isEmpty && !costPrice.isEmpty && !salePrice.isEmpty && !quantity.isEmpty
    }

    var body: some View {
        NavigationStack {
            if showSuccess {
                successView
            } else {
                formView
            }
        }
        .onAppear {
            if let product = editingProduct {
                populateForm(with: product)
            } else if let scan = fromScan {
                populateFromScan(scan)
            }
        }
    }

    private var formView: some View {
        ScrollView {
            VStack(spacing: 24) {
                // AI detected banner
                if fromScan != nil {
                    aiDetectedBanner
                }

                // Basic Info
                sectionView(title: "Información Básica", icon: "info.circle") {
                    VStack(spacing: 14) {
                        formField(label: "Nombre del producto", placeholder: "Ej: Leche Entera 1L", text: $name)
                        formField(label: "SKU", placeholder: "Ej: DAI-001", text: $sku)
                        formField(label: "Código de barras", placeholder: "Ej: 7701234567890", text: $barcode, keyboardType: .numberPad)

                        // Category picker
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Categoría")
                                .font(AppTypography.captionFont)
                                .foregroundColor(AppColors.textSecondary)

                            Picker("Categoría", selection: $category) {
                                ForEach(ProductCategory.allCases, id: \.self) { cat in
                                    Label(cat.rawValue, systemImage: cat.icon).tag(cat)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                            .background(colorScheme == .dark ? AppColors.darkSurfaceSecondary : AppColors.surfaceSecondary)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        formField(label: "Proveedor", placeholder: "Ej: Lácteos Alpina", text: $supplier)
                    }
                }

                // Pricing
                sectionView(title: "Precios", icon: "dollarsign.circle") {
                    VStack(spacing: 14) {
                        HStack(spacing: 12) {
                            formField(label: "Precio de costo", placeholder: "0", text: $costPrice, keyboardType: .decimalPad)
                            formField(label: "Precio de venta", placeholder: "0", text: $salePrice, keyboardType: .decimalPad)
                        }

                        // Live margin calculator
                        HStack {
                            Image(systemName: "percent")
                                .foregroundColor(marginColor)
                            Text("Margen de ganancia:")
                                .font(AppTypography.captionFont)
                                .foregroundColor(AppColors.textSecondary)
                            Text(calculatedMargin.percentFormatted)
                                .font(AppTypography.calloutFont)
                                .fontWeight(.semibold)
                                .foregroundColor(marginColor)
                        }
                        .padding(12)
                        .background(marginColor.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }

                // Inventory
                sectionView(title: "Inventario", icon: "cube") {
                    VStack(spacing: 14) {
                        HStack(spacing: 12) {
                            formField(label: "Cantidad", placeholder: "0", text: $quantity, keyboardType: .numberPad)
                            formField(label: "Stock mínimo", placeholder: "0", text: $minStock, keyboardType: .numberPad)
                        }

                        formField(label: "Ubicación", placeholder: "Ej: Pasillo 3, Estante A", text: $location)

                        // Expiration toggle
                        Toggle(isOn: $hasExpiration) {
                            HStack {
                                Image(systemName: "calendar")
                                    .foregroundColor(AppColors.textTertiary)
                                Text("Tiene fecha de vencimiento")
                                    .font(AppTypography.calloutFont)
                            }
                        }
                        .tint(AppColors.primary)

                        if hasExpiration {
                            DatePicker("Fecha de vencimiento", selection: $expirationDate, displayedComponents: .date)
                                .datePickerStyle(.compact)
                                .font(AppTypography.calloutFont)
                        }
                    }
                }

                // Description
                sectionView(title: "Descripción", icon: "text.alignleft") {
                    TextEditor(text: $description)
                        .font(AppTypography.bodyFont)
                        .frame(minHeight: 80)
                        .padding(10)
                        .background(colorScheme == .dark ? AppColors.darkSurfaceSecondary : AppColors.surfaceSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                // Save button
                Button(action: saveProduct) {
                    Text(isEditing ? "Guardar Cambios" : "Agregar Producto")
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!isFormValid)

                Spacer().frame(height: 20)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(colorScheme == .dark ? AppColors.darkBackground : AppColors.background)
        .navigationTitle(isEditing ? "Editar Producto" : "Agregar Producto")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancelar") { dismiss() }
                    .foregroundColor(AppColors.textSecondary)
            }
        }
    }

    private var successView: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(AppColors.success.opacity(0.1))
                    .frame(width: 120, height: 120)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 56))
                    .foregroundColor(AppColors.success)
            }

            Text(isEditing ? "Producto Actualizado" : "Producto Agregado")
                .font(AppTypography.titleFont)

            Text(isEditing ? "\(name) se ha actualizado correctamente" : "\(name) se ha agregado al inventario")
                .font(AppTypography.bodyFont)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button(action: { dismiss() }) {
                Text("Continuar")
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, 24)

            Spacer()
        }
        .background(Color(.systemBackground))
    }

    private var aiDetectedBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles")
                .foregroundColor(AppColors.primary)
            VStack(alignment: .leading, spacing: 2) {
                Text("Detectado por IA")
                    .font(AppTypography.captionFont)
                    .fontWeight(.semibold)
                Text("Los campos fueron completados automáticamente. Verifica la información.")
                    .font(AppTypography.caption2Font)
                    .foregroundColor(AppColors.textSecondary)
            }
            Spacer()
        }
        .padding(14)
        .background(AppColors.primary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private func sectionView<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.primary)
                Text(title)
                    .font(AppTypography.headlineFont)
            }
            content()
        }
        .padding(16)
        .cardStyle()
    }

    @ViewBuilder
    private func formField(label: String, placeholder: String, text: Binding<String>, keyboardType: UIKeyboardType = .default) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(AppTypography.captionFont)
                .foregroundColor(AppColors.textSecondary)

            TextField(placeholder, text: text)
                .font(AppTypography.bodyFont)
                .keyboardType(keyboardType)
                .padding(14)
                .background(colorScheme == .dark ? AppColors.darkSurfaceSecondary : AppColors.surfaceSecondary)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private var marginColor: Color {
        if calculatedMargin >= 20 { return AppColors.success }
        if calculatedMargin >= 10 { return AppColors.warning }
        return AppColors.error
    }

    private func populateForm(with product: Product) {
        name = product.name
        sku = product.sku
        barcode = product.barcode
        category = product.category
        supplier = product.supplier
        costPrice = String(format: "%.0f", product.costPrice)
        salePrice = String(format: "%.0f", product.salePrice)
        quantity = "\(product.quantity)"
        minStock = "\(product.minStock)"
        location = product.location
        description = product.description
        if let expDate = product.expirationDate {
            hasExpiration = true
            expirationDate = expDate
        }
    }

    private func populateFromScan(_ scan: ScannedProductResult) {
        name = scan.name
        barcode = scan.barcode
        category = scan.category
        salePrice = String(format: "%.0f", scan.suggestedPrice)
    }

    private func saveProduct() {
        let product = Product(
            id: editingProduct?.id ?? UUID(),
            name: name,
            sku: sku,
            barcode: barcode,
            category: category,
            supplier: supplier,
            costPrice: Double(costPrice) ?? 0,
            salePrice: Double(salePrice) ?? 0,
            quantity: Int(quantity) ?? 0,
            minStock: Int(minStock) ?? 0,
            location: location,
            expirationDate: hasExpiration ? expirationDate : nil,
            imageURL: nil,
            description: description,
            lastUpdated: Date(),
            isActive: true
        )

        if isEditing {
            inventoryViewModel.updateProduct(product)
        } else {
            inventoryViewModel.addProduct(product)
        }

        withAnimation {
            showSuccess = true
        }
    }
}
