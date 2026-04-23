import SwiftUI

struct AddProductView: View {
    var editingProduct: Product? = nil
    var fromScan: ScannedProductResult? = nil

    @EnvironmentObject var inventoryViewModel: InventoryViewModel
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme

    // Open Food Facts lookup dependency
    private let openFoodFactsRepo: OpenFoodFactsRepositoryProtocol = OpenFoodFactsRepository()

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
    @State private var imageURLString = ""
    @State private var showSuccess = false

    // Open Food Facts lookup state
    @State private var isLookingUpBarcode = false
    @State private var lookupMessage: String?

    // Validación + anti-double-tap
    @State private var validationError: String?
    @State private var isSaving = false

    var isEditing: Bool { editingProduct != nil }

    var calculatedMargin: Double {
        guard let cost = Double(costPrice), let sale = Double(salePrice), cost > 0 else { return 0 }
        return ((sale - cost) / cost) * 100
    }

    /// Validación completa con mensaje específico
    private func validateInputs() -> Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSku = sku.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBarcode = barcode.trimmingCharacters(in: .whitespacesAndNewlines)

        // Nombre
        guard !trimmedName.isEmpty else {
            validationError = "El nombre es obligatorio"
            return false
        }
        guard trimmedName.count <= 100 else {
            validationError = "El nombre no puede exceder 100 caracteres"
            return false
        }

        // SKU
        guard !trimmedSku.isEmpty else {
            validationError = "El SKU es obligatorio"
            return false
        }
        guard trimmedSku.count <= 50 else {
            validationError = "El SKU no puede exceder 50 caracteres"
            return false
        }

        // Barcode (opcional, pero si existe debe ser numérico)
        if !trimmedBarcode.isEmpty {
            guard trimmedBarcode.count <= 32,
                  trimmedBarcode.allSatisfy({ $0.isNumber }) else {
                validationError = "El código de barras debe ser numérico (máx 32 dígitos)"
                return false
            }
        }

        // Precios
        guard let cost = Double(costPrice), cost > 0, cost.isFinite, cost < 100_000_000 else {
            validationError = "Precio de costo inválido (entre 1 y 100,000,000)"
            return false
        }
        guard let sale = Double(salePrice), sale.isFinite, sale < 100_000_000 else {
            validationError = "Precio de venta inválido"
            return false
        }
        guard sale >= cost else {
            validationError = "El precio de venta debe ser mayor o igual al costo"
            return false
        }

        // Cantidad e inventario (enteros estrictos, rechazan decimales)
        guard let qty = Int(quantity), quantity == String(qty), qty >= 0, qty <= 1_000_000 else {
            validationError = "La cantidad debe ser un número entero entre 0 y 1,000,000"
            return false
        }
        guard let min = Int(minStock), minStock == String(min), min >= 0, min <= 1_000_000 else {
            validationError = "El stock mínimo debe ser un número entero entre 0 y 1,000,000"
            return false
        }

        // Fecha de vencimiento (no puede ser en el pasado)
        if hasExpiration, expirationDate < Calendar.current.startOfDay(for: Date()) {
            validationError = "La fecha de vencimiento no puede estar en el pasado"
            return false
        }

        // Descripción (opcional pero limitada)
        guard description.count <= 500 else {
            validationError = "La descripción no puede exceder 500 caracteres"
            return false
        }

        validationError = nil
        return true
    }

    /// Validación rápida solo para habilitar/deshabilitar el botón
    var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !sku.trimmingCharacters(in: .whitespaces).isEmpty &&
        !costPrice.isEmpty && !salePrice.isEmpty && !quantity.isEmpty &&
        !isSaving
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
                        formField(label: "Nombre del producto (1-100)", placeholder: "Ej: Leche Entera 1L", text: $name)
                        formField(label: "SKU (1-50)", placeholder: "Ej: DAI-001", text: $sku)
                        formField(label: "Código de barras (opcional, numérico)", placeholder: "Ej: 7701234567890", text: $barcode, keyboardType: .numberPad)

                        // Open Food Facts lookup
                        openFoodFactsLookupButton

                        if let lookupMessage {
                            Text(lookupMessage)
                                .font(AppTypography.captionFont)
                                .foregroundColor(AppColors.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

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
                            formField(label: "Cantidad (entero)", placeholder: "0", text: $quantity, keyboardType: .numberPad)
                            formField(label: "Stock mínimo (entero)", placeholder: "0", text: $minStock, keyboardType: .numberPad)
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
                            DatePicker("Fecha de vencimiento", selection: $expirationDate, in: Date()..., displayedComponents: .date)
                                .datePickerStyle(.compact)
                                .font(AppTypography.calloutFont)
                        }
                    }
                }

                // Description
                sectionView(title: "Descripción (opcional, máx 500)", icon: "text.alignleft") {
                    TextEditor(text: $description)
                        .font(AppTypography.bodyFont)
                        .frame(minHeight: 80)
                        .padding(10)
                        .background(colorScheme == .dark ? AppColors.darkSurfaceSecondary : AppColors.surfaceSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                // Validation error
                if let validationError {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(AppColors.error)
                        Text(validationError)
                            .font(AppTypography.captionFont)
                            .foregroundColor(AppColors.error)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppColors.error.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                // Save button (con guard contra double-tap)
                Button(action: saveProduct) {
                    if isSaving {
                        ProgressView().tint(.white)
                    } else {
                        Text(isEditing ? "Guardar Cambios" : "Agregar Producto")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!isFormValid || isSaving)

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

    private var openFoodFactsLookupButton: some View {
        VStack(spacing: 4) {
            Button {
                Task { await lookupBarcode() }
            } label: {
                HStack(spacing: 8) {
                    if isLookingUpBarcode {
                        ProgressView().scaleEffect(0.8)
                    } else {
                        Image(systemName: "magnifyingglass")
                    }
                    Text(isLookingUpBarcode ? "Buscando..." : "Buscar en Open Food Facts")
                        .font(AppTypography.calloutFont)
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .foregroundColor(AppColors.primary)
                .background(AppColors.primary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(barcode.isEmpty || isLookingUpBarcode)

            Text("Base de datos de alimentos (mejor cobertura internacional)")
                .font(AppTypography.caption2Font)
                .foregroundColor(AppColors.textTertiary)
        }
    }

    @MainActor
    private func lookupBarcode() async {
        // Validar barcode antes de pegarle a la API
        let trimmedBarcode = barcode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedBarcode.isEmpty,
              trimmedBarcode.count <= 32,
              trimmedBarcode.allSatisfy({ $0.isNumber }) else {
            lookupMessage = "Código de barras inválido (solo dígitos, máx 32)"
            return
        }

        isLookingUpBarcode = true
        lookupMessage = nil
        defer { isLookingUpBarcode = false }

        do {
            guard let result = try await openFoodFactsRepo.lookup(barcode: trimmedBarcode) else {
                // OpenFoodFacts tiene base de datos incompleta (fuerte en Europa, débil en LATAM)
                lookupMessage = "No encontrado en Open Food Facts. Puedes llenar los datos manualmente o escanear el producto desde la cámara."
                return
            }

            // Pre-fill form only with empty fields (no clobber de datos del usuario)
            if name.isEmpty { name = String(result.name.prefix(100)) }
            if description.isEmpty, !result.brand.isEmpty {
                description = String(result.brand.prefix(500))
            }
            if supplier.isEmpty, !result.brand.isEmpty {
                supplier = String(result.brand.prefix(100))
            }
            // Validar que la imagen sea de openfoodfacts antes de usarla
            if imageURLString.isEmpty, let image = result.imageURL,
               image.contains("openfoodfacts") {
                imageURLString = image
            }

            lookupMessage = "Datos del producto rellenados ✓"
        } catch let apiError as APIError {
            switch apiError {
            case .offline:
                lookupMessage = "Sin conexión. No se puede consultar Open Food Facts."
            default:
                lookupMessage = "Búsqueda falló. Intenta de nuevo."
            }
        } catch {
            lookupMessage = "Búsqueda falló. Intenta de nuevo."
        }
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
                .autocorrectionDisabled()
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
        costPrice = String(format: "%.2f", product.costPrice)
        salePrice = String(format: "%.2f", product.salePrice)
        quantity = "\(product.quantity)"
        minStock = "\(product.minStock)"
        location = product.location
        description = product.description
        imageURLString = product.imageURL ?? ""
        if let expDate = product.expirationDate {
            hasExpiration = true
            expirationDate = expDate
        }
    }

    private func populateFromScan(_ scan: ScannedProductResult) {
        if name.isEmpty { name = scan.name }
        if barcode.isEmpty { barcode = scan.barcode }
        category = scan.category
        if salePrice.isEmpty { salePrice = String(format: "%.2f", scan.suggestedPrice) }
    }

    private func saveProduct() {
        guard !isSaving else { return }
        guard validateInputs() else {
            HapticManager.notification(.error)
            return
        }

        isSaving = true

        let product = Product(
            id: editingProduct?.id ?? UUID(),
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            sku: sku.trimmingCharacters(in: .whitespacesAndNewlines),
            barcode: barcode.trimmingCharacters(in: .whitespacesAndNewlines),
            category: category,
            supplier: supplier.trimmingCharacters(in: .whitespacesAndNewlines),
            costPrice: Double(costPrice) ?? 0,
            salePrice: Double(salePrice) ?? 0,
            quantity: Int(quantity) ?? 0,
            minStock: Int(minStock) ?? 0,
            location: location.trimmingCharacters(in: .whitespacesAndNewlines),
            expirationDate: hasExpiration ? expirationDate : nil,
            imageURL: imageURLString.isEmpty ? nil : imageURLString,
            description: description.trimmingCharacters(in: .whitespacesAndNewlines),
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
