import SwiftUI
import AVFoundation

struct ScanView: View {
    @EnvironmentObject var inventoryViewModel: InventoryViewModel
    @Environment(\.dismiss) var dismiss

    @StateObject private var cameraService = CameraService()
    @StateObject private var aiService = AIRecognitionService.shared
    @State private var scanState: ScanState = .ready
    @State private var showAddProduct = false
    @State private var detectedResult: ScannedProductResult?
    @State private var scanLineOffset: CGFloat = -100
    @State private var aiResult: AIProductResult?

    enum ScanState {
        case ready, scanning, analyzing, complete
    }

    var body: some View {
        NavigationStack {
            ZStack {
                cameraLayer

                VStack(spacing: 0) {
                    topBar
                    Spacer()

                    if scanState == .ready || scanState == .scanning {
                        scanningView
                    } else if scanState == .analyzing {
                        analyzingView
                    } else if scanState == .complete {
                        resultView
                    }
                    Spacer()

                    if scanState == .ready {
                        featureCards
                    }
                }
            }
            .background(Color.black)
            .navigationBarHidden(true)
            .onAppear {
                cameraService.checkAuthorization()
                cameraService.startSession()
            }
            .onDisappear {
                cameraService.stopSession()
            }
            .onChange(of: cameraService.detectedBarcode) { _, barcode in
                if let barcode = barcode, scanState == .scanning {
                    handleBarcodeDetected(barcode)
                }
            }
            .sheet(isPresented: $showAddProduct) {
                if let result = detectedResult {
                    AddProductView(fromScan: result)
                }
            }
        }
    }

    private var cameraLayer: some View {
        Group {
            if cameraService.isAuthorized {
                CameraPreviewView(session: cameraService.session)
                    .ignoresSafeArea()
            } else {
                ZStack {
                    Color.black.ignoresSafeArea()
                    VStack(spacing: 12) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.white.opacity(0.3))
                        Text("Permiso de camara requerido")
                            .font(AppTypography.calloutFont)
                            .foregroundColor(.white.opacity(0.5))
                        Text("Ve a Ajustes > InventarIA > Camara")
                            .font(AppTypography.caption2Font)
                            .foregroundColor(.white.opacity(0.3))
                    }
                }
            }
        }
    }

    private var topBar: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
            Spacer()
            Text("Escaneo IA")
                .font(AppTypography.headlineFont)
                .foregroundColor(.white)
            Spacer()
            Button(action: { cameraService.toggleFlash() }) {
                Image(systemName: cameraService.isFlashOn ? "bolt.fill" : "bolt.slash.fill")
                    .font(.system(size: 18))
                    .foregroundColor(cameraService.isFlashOn ? AppColors.teaGreen : .white)
                    .frame(width: 40, height: 40)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    private var scanningView: some View {
        VStack(spacing: 24) {
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .stroke(style: StrokeStyle(lineWidth: 3, dash: [30, 20]))
                    .foregroundColor(AppColors.teaGreen)
                    .frame(width: 260, height: 260)

                if scanState == .scanning {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [AppColors.teaGreen.opacity(0), AppColors.teaGreen, AppColors.teaGreen.opacity(0)],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .frame(width: 240, height: 2)
                        .offset(y: scanLineOffset)
                        .onAppear {
                            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                                scanLineOffset = 100
                            }
                        }
                }
            }

            Text(scanState == .scanning ? "Escaneando..." : "Apunta la camara al producto")
                .font(AppTypography.calloutFont)
                .foregroundColor(.white.opacity(0.8))

            if scanState == .ready {
                Button(action: startScan) {
                    HStack(spacing: 8) {
                        Image(systemName: "camera.viewfinder")
                        Text("Escanear Producto")
                    }
                    .font(AppTypography.headlineFont)
                    .foregroundColor(AppColors.inkBlack)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 16)
                    .background(AppColors.teaGreen)
                    .clipShape(Capsule())
                    .shadow(color: AppColors.teaGreen.opacity(0.4), radius: 12, y: 4)
                }
            }
        }
    }

    private var analyzingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(AppColors.teaGreen)
            Text("Analizando con IA...")
                .font(AppTypography.headlineFont)
                .foregroundColor(.white)
            Text("Identificando producto y buscando informacion")
                .font(AppTypography.captionFont)
                .foregroundColor(.white.opacity(0.6))

            if let aiResult = aiResult {
                Text("Fuente: \(aiResult.source.rawValue)")
                    .font(AppTypography.caption2Font)
                    .foregroundColor(AppColors.freshSky)
            }
        }
        .padding(32)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private var resultView: some View {
        VStack(spacing: 16) {
            if let result = detectedResult {
                HStack {
                    Image(systemName: "sparkles")
                        .foregroundColor(AppColors.teaGreen)
                    Text("Confianza: \(String(format: "%.0f", result.confidence))%")
                        .font(AppTypography.captionFont)
                        .foregroundColor(AppColors.teaGreen)
                }
                .padding(.horizontal, 16).padding(.vertical, 8)
                .background(AppColors.teaGreen.opacity(0.15))
                .clipShape(Capsule())

                VStack(alignment: .leading, spacing: 12) {
                    detectedInfoRow(label: "Nombre", value: result.name)
                    detectedInfoRow(label: "Marca", value: result.brand)
                    detectedInfoRow(label: "Categoria", value: result.category.rawValue)
                    if !result.barcode.isEmpty {
                        detectedInfoRow(label: "Codigo", value: result.barcode)
                    }
                    if result.suggestedPrice > 0 {
                        detectedInfoRow(label: "Precio Sugerido", value: result.suggestedPrice.currencyFormatted)
                    }

                    if result.isDuplicate {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill").foregroundColor(AppColors.warning)
                            Text("Posible duplicado detectado").font(AppTypography.captionFont).foregroundColor(AppColors.warning)
                        }
                        .padding(10)
                        .background(AppColors.warning.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding(20)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))

                HStack(spacing: 12) {
                    Button(action: { showAddProduct = true }) {
                        HStack { Image(systemName: "plus.circle.fill"); Text("Agregar") }
                            .font(AppTypography.calloutFont).fontWeight(.semibold)
                            .foregroundColor(AppColors.inkBlack)
                            .frame(maxWidth: .infinity).padding(.vertical, 14)
                            .background(AppColors.teaGreen)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    Button(action: resetScan) {
                        HStack { Image(systemName: "arrow.counterclockwise"); Text("Nuevo") }
                            .font(AppTypography.calloutFont).fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity).padding(.vertical, 14)
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
        }
        .padding(.horizontal, 20)
    }

    private func detectedInfoRow(label: String, value: String) -> some View {
        HStack {
            Text(label).font(AppTypography.captionFont).foregroundColor(.white.opacity(0.6))
            Spacer()
            Text(value).font(AppTypography.calloutFont).fontWeight(.medium).foregroundColor(.white)
        }
    }

    private var featureCards: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                featureCard(icon: "barcode.viewfinder", title: "Codigo de Barras", description: "Escanea codigos de barras estandar")
                featureCard(icon: "camera.metering.matrix", title: "Reconocimiento Visual", description: "Identifica productos por apariencia")
                featureCard(icon: "doc.text.viewfinder", title: "Texto en Etiquetas", description: "Lee informacion de etiquetas")
            }
            .padding(.horizontal, 20).padding(.bottom, 40)
        }
    }

    private func featureCard(icon: String, title: String, description: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon).font(.system(size: 24)).foregroundColor(AppColors.teaGreen)
            Text(title).font(AppTypography.captionFont).fontWeight(.semibold).foregroundColor(.white)
            Text(description).font(AppTypography.caption2Font).foregroundColor(.white.opacity(0.6)).lineLimit(2)
        }
        .frame(width: 150).padding(14)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func startScan() {
        HapticManager.impact(.medium)
        withAnimation { scanState = .scanning }
        scanLineOffset = -100

        // Fix crítico: await la captura ANTES de analizar (evita analizar imagen vacía)
        Task {
            // Dar 1.5s para que el usuario encuadre el producto
            try? await Task.sleep(nanoseconds: 1_500_000_000)

            // Si se detectó un barcode mientras esperábamos, handleBarcodeDetected ya se encarga
            guard scanState == .scanning else { return }

            await MainActor.run { withAnimation { scanState = .analyzing } }
            let capturedImage = await cameraService.capturePhotoAsync()

            await analyzeWithAIAsync(image: capturedImage, barcode: nil)
        }
    }



    private func handleBarcodeDetected(_ barcode: String) {
        withAnimation { scanState = .analyzing }

        // 1. ¿El producto ya existe en el inventario local?
        if let existingProduct = inventoryViewModel.findProduct(byBarcode: barcode) {
            let result = ScannedProductResult(
                name: existingProduct.name,
                brand: existingProduct.supplier,
                category: existingProduct.category,
                barcode: barcode,
                suggestedPrice: existingProduct.salePrice,
                confidence: 99.0,
                isDuplicate: true,
                similarProducts: [existingProduct]
            )
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                withAnimation {
                    detectedResult = result
                    scanState = .complete
                }
                HapticManager.notification(.success)
            }
            return
        }

        // 2. Producto no local. Flujo: (a) intentar OpenFoodFacts con el barcode,
        //    (b) si no hay datos, capturar foto y mandar a Claude con el barcode.
        Task {
            let offRepo: OpenFoodFactsRepositoryProtocol = OpenFoodFactsRepository()
            // `try?` aplana el doble optional: el resultado es OpenFoodFactsProduct?
            if let off = try? await offRepo.lookup(barcode: barcode) {
                let result = ScannedProductResult(
                    name: off.name.isEmpty ? "Producto \(barcode)" : off.name,
                    brand: off.brand,
                    category: .other,
                    barcode: barcode,
                    suggestedPrice: 0,
                    confidence: 85.0,
                    isDuplicate: false,
                    similarProducts: []
                )
                await MainActor.run {
                    withAnimation {
                        detectedResult = result
                        scanState = .complete
                    }
                    HapticManager.notification(.success)
                }
                return
            }

            // OFF no tiene el producto → capturar foto y mandar a Claude con el barcode como hint
            let capturedImage = await cameraService.capturePhotoAsync()
            await analyzeWithAIAsync(image: capturedImage, barcode: barcode)
        }
    }

    private func analyzeWithAI(barcode: String? = nil) {
        Task {
            // Si ya había una foto capturada previa, usarla; sino capturar ahora
            let image: UIImage?
            if let existing = cameraService.capturedImage {
                image = existing
            } else {
                image = await cameraService.capturePhotoAsync()
            }
            await analyzeWithAIAsync(image: image, barcode: barcode)
        }
    }

    private func analyzeWithAIAsync(image: UIImage?, barcode: String?) async {
        guard let image = image else {
            await MainActor.run {
                let scanResult = ScannedProductResult(
                    name: "No se pudo capturar la imagen",
                    brand: "",
                    category: .other,
                    barcode: barcode ?? "",
                    suggestedPrice: 0,
                    confidence: 0,
                    isDuplicate: false,
                    similarProducts: []
                )
                withAnimation {
                    self.detectedResult = scanResult
                    self.scanState = .complete
                }
                HapticManager.notification(.error)
            }
            return
        }

        let result = await aiService.analyze(image: image, barcode: barcode)
        let duplicates = await MainActor.run {
            inventoryViewModel.findDuplicates(name: result.name, barcode: barcode ?? "")
        }

        await MainActor.run {
            //por si no detecta nada 
            let hasData = !result.name.isEmpty || !result.brand.isEmpty || (result.barcode != nil && !(result.barcode?.isEmpty ?? true))

            let scanResult = ScannedProductResult(
                name: hasData ? (result.name.isEmpty ? "Producto sin nombre" : result.name) : "No se detectó producto",
                brand: hasData && !result.brand.isEmpty ? result.brand : "Sin información",
                category: result.category,
                barcode: barcode ?? result.barcode ?? "",
                suggestedPrice: result.suggestedPrice,
                confidence: hasData ? max(result.confidence, 40) : 0,
                isDuplicate: !duplicates.isEmpty,
                similarProducts: duplicates
            )

            withAnimation {
                self.aiResult = result
                self.detectedResult = scanResult
                self.scanState = .complete
            }
            HapticManager.notification(hasData ? .success : .warning)
        }
    }

    private func resetScan() {
        cameraService.reset()
        withAnimation {
            scanState = .ready
            detectedResult = nil
            aiResult = nil
            scanLineOffset = -100
        }
        HapticManager.impact(.light)
    }
}
