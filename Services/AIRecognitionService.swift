import Foundation
import UIKit
import Vision

/// AI-powered product recognition with 3-tier fallback:
///  1. Claude Vision (if `claudeApiKey` set) — recommended, supports vision via Haiku model
///  2. OpenAI Vision (if `openAIApiKey` set) — alternative paid option
///  3. Apple Vision on-device (always available, free, privacy-preserving)
///
/// Cost notes:
///  - Claude Haiku Vision: ~$0.0008 per image (very cheap)
///  - OpenAI gpt-4o-mini Vision: ~$0.01 per image
///  - Apple Vision: free, on-device
class AIRecognitionService: ObservableObject {
    static let shared = AIRecognitionService()

    @Published var isProcessing = false
    @Published var lastResult: AIProductResult?
    @Published var error: String?

    /// Claude API key. If set, used first (cheaper than OpenAI).
    var claudeApiKey: String? = Secrets.claudeApiKey

    /// OpenAI API key. Used as secondary fallback.
    var openAIApiKey: String? = Secrets.openAIApiKey

    var isClaudeEnabled: Bool { (claudeApiKey?.isEmpty == false) }
    var isOpenAIEnabled: Bool { (openAIApiKey?.isEmpty == false) }

    // MARK: - Router (decides which engine to use)

    /// Entry point. Routes to the best available engine.
    /// Priority: Claude → OpenAI → Apple Vision.
    func analyze(image: UIImage, barcode: String? = nil) async -> AIProductResult {
        if isClaudeEnabled {
            return await analyzeWithClaude(image: image, barcode: barcode)
        }
        // Guard de Santiago: si no hay OpenAI key tampoco, fallback gratis a Vision
        guard let _ = openAIApiKey, isOpenAIEnabled else {
            return await analyzeWithVision(image: image, barcode: barcode)
        }
        return await analyzeWithOpenAI(image: image, barcode: barcode)
    }

    // MARK: - Apple Vision (on-device, free)

    func analyzeWithVision(image: UIImage, barcode: String? = nil) async -> AIProductResult {
        await MainActor.run { isProcessing = true }

        var result = AIProductResult()
        result.barcode = barcode

        guard let cgImage = image.cgImage else {
            await MainActor.run { isProcessing = false }
            return result
        }

        if barcode == nil {
            let barcodeResult = await detectBarcodes(in: cgImage)
            result.barcode = barcodeResult
        }

        let texts = await recognizeText(in: cgImage)
        result.detectedTexts = texts

        result = classifyFromText(result: result, texts: texts)

        // Si no detectamos nada útil, confianza 0 (para que la UI lo muestre honestamente)
        if result.name.isEmpty && result.brand.isEmpty && (result.barcode?.isEmpty ?? true) {
            result.confidence = 0
        } else {
            result.confidence = 65.0
        }
        result.source = .onDevice

        await MainActor.run {
            self.lastResult = result
            self.isProcessing = false
        }

        return result
    }

    // MARK: - Claude Vision (Anthropic, Haiku model)

    func analyzeWithClaude(image: UIImage, barcode: String? = nil) async -> AIProductResult {
        guard let apiKey = claudeApiKey, !apiKey.isEmpty else {
            return await analyzeWithVision(image: image, barcode: barcode)
        }

        await MainActor.run { isProcessing = true }

        // Usar una imagen más grande (1568px) y menor compresión (0.9) para mejor OCR
        let resizedImage = resizeImage(image, maxDimension: 1568)
        guard let imageData = resizedImage.jpegData(compressionQuality: 0.9) else {
            await MainActor.run { isProcessing = false }
            return await analyzeWithVision(image: image, barcode: barcode)
        }
        let base64Image = imageData.base64EncodedString()

        // Prompt más detallado y con ejemplos (few-shot) para mejorar la detección
        let prompt = """
        Eres un experto en identificación de productos de tiendas y supermercados colombianos. Analiza esta imagen cuidadosamente observando:
        - Texto en etiquetas/empaque (marca, nombre del producto, presentación)
        - Logotipos y colores característicos de marcas
        - Forma y tipo de empaque
        - Categoría del producto

        Responde ÚNICAMENTE con un objeto JSON válido. NO agregues markdown, NO uses ```json, NO expliques nada antes o después. Solo el JSON:

        {
          "nombre": "nombre específico del producto incluyendo presentación (ej: 'Coca-Cola 400ml', 'Leche Alpina Entera 1L')",
          "marca": "marca principal (ej: 'Coca-Cola', 'Alpina', 'Colgate'). Si no se ve claramente, cadena vacía",
          "categoria": "UNA de estas palabras EXACTAS: Bebidas, Lácteos, Snacks, Limpieza, Cuidado Personal, Granos, Frutas y Verduras, Carnes, Panadería, Congelados, Condimentos, Otros",
          "precio_sugerido": número entero estimado en pesos colombianos basándote en productos similares del mercado colombiano,
          "descripcion": "descripción corta (máximo 100 caracteres) con presentación, sabor, tamaño, etc.",
          "confianza": entero del 0 al 100 indicando qué tan seguro estás de la identificación (90+ si es claro, 50-80 si hay dudas, 0-40 si no estás seguro)
        }

        Reglas importantes:
        - Si la imagen está borrosa, vacía, o no muestra un producto, devuelve todos los campos vacíos y confianza: 0
        - Sé específico con el nombre (incluir presentación). Mal: "Leche". Bien: "Leche Alpina Entera 1L"
        - Para precio, usa rangos reales del mercado colombiano (ej: gaseosa pequeña 2000-4000, leche 1L 4000-7000)
        - Solo responde el JSON, nada más.
        """

        let requestBody: [String: Any] = [
            // Sonnet 4.5 tiene visión mucho mejor que Haiku para productos con texto pequeño
            "model": "claude-sonnet-4-5",
            "max_tokens": 800,
            "messages": [
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "image",
                            "source": [
                                "type": "base64",
                                "media_type": "image/jpeg",
                                "data": base64Image
                            ]
                        ],
                        [
                            "type": "text",
                            "text": prompt
                        ]
                    ]
                ]
            ]
        ]

        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else {
            await MainActor.run { isProcessing = false }
            return await analyzeWithVision(image: image, barcode: barcode)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: requestBody)
        request.timeoutInterval = 30

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                #if DEBUG
                let errBody = String(data: data, encoding: .utf8)?.prefix(200) ?? ""
                print("[AI] Claude HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0): \(errBody)")
                #endif
                await MainActor.run {
                    self.error = "Error en Claude API. Usando Apple Vision."
                    self.isProcessing = false
                }
                return await analyzeWithVision(image: image, barcode: barcode)
            }

            // Claude response format: { "content": [ { "type": "text", "text": "..." } ] }
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let contentArray = json["content"] as? [[String: Any]],
                  let firstBlock = contentArray.first,
                  let textContent = firstBlock["text"] as? String else {
                await MainActor.run { isProcessing = false }
                return await analyzeWithVision(image: image, barcode: barcode)
            }

            var result = parseAIJSONResponse(textContent)
            result.barcode = barcode
            result.source = .claude

            await MainActor.run {
                self.lastResult = result
                self.isProcessing = false
                self.error = nil
            }
            return result

        } catch {
            #if DEBUG
            print("[AI] Claude request failed: \(error.localizedDescription)")
            #endif
            await MainActor.run {
                self.error = "Error de red con Claude. Usando Apple Vision."
                self.isProcessing = false
            }
            return await analyzeWithVision(image: image, barcode: barcode)
        }
    }

    // MARK: - OpenAI Vision (paid per token, secondary)

    func analyzeWithOpenAI(image: UIImage, barcode: String? = nil) async -> AIProductResult {
        guard let apiKey = openAIApiKey, !apiKey.isEmpty else {
            return await analyzeWithVision(image: image, barcode: barcode)
        }

        await MainActor.run { isProcessing = true }

        let resizedImage = resizeImage(image, maxDimension: 512)
        guard let imageData = resizedImage.jpegData(compressionQuality: 0.7) else {
            await MainActor.run { isProcessing = false }
            return AIProductResult()
        }

        let base64Image = imageData.base64EncodedString()

        let prompt = """
        Analiza esta imagen de un producto de tienda/supermercado. Responde SOLO en formato JSON con estos campos:
        {
          "nombre": "nombre del producto",
          "marca": "marca del producto",
          "categoria": "una de: Bebidas, Lácteos, Snacks, Limpieza, Cuidado Personal, Granos, Frutas y Verduras, Carnes, Panadería, Congelados, Condimentos, Otros",
          "precio_sugerido": número estimado en pesos colombianos,
          "descripcion": "breve descripción del producto",
          "confianza": número del 0 al 100 indicando tu confianza
        }
        Si no puedes identificar el producto, pon confianza en 0.
        """

        let requestBody: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": [
                [
                    "role": "user",
                    "content": [
                        ["type": "text", "text": prompt],
                        ["type": "image_url", "image_url": ["url": "data:image/jpeg;base64,\(base64Image)", "detail": "low"]]
                    ]
                ]
            ],
            "max_tokens": 300
        ]

        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: requestBody)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                await MainActor.run {
                    self.error = "Error en la API de OpenAI. Código: \((response as? HTTPURLResponse)?.statusCode ?? 0)"
                    self.isProcessing = false
                }
                return await analyzeWithVision(image: image, barcode: barcode)
            }

            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let choices = json?["choices"] as? [[String: Any]]
            let message = choices?.first?["message"] as? [String: Any]
            let content = message?["content"] as? String ?? ""

            var result = parseAIJSONResponse(content)
            result.barcode = barcode
            result.source = .openAI

            await MainActor.run {
                self.lastResult = result
                self.isProcessing = false
            }

            return result

        } catch {
            await MainActor.run {
                self.error = "Error de red: \(error.localizedDescription)"
                self.isProcessing = false
            }
            return await analyzeWithVision(image: image, barcode: barcode)
        }
    }

    // MARK: - Helpers

    private func detectBarcodes(in cgImage: CGImage) async -> String? {
        await withCheckedContinuation { continuation in
            let request = VNDetectBarcodesRequest { request, _ in
                let barcode = (request.results as? [VNBarcodeObservation])?.first?.payloadStringValue
                continuation.resume(returning: barcode)
            }
            request.symbologies = [.ean13, .ean8, .upce, .code128, .code39, .itf14]
            let handler = VNImageRequestHandler(cgImage: cgImage)
            try? handler.perform([request])
        }
    }

    private func recognizeText(in cgImage: CGImage) async -> [String] {
        await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, _ in
                let texts = (request.results as? [VNRecognizedTextObservation])?
                    .compactMap { $0.topCandidates(1).first?.string } ?? []
                continuation.resume(returning: texts)
            }
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["es", "en"]
            let handler = VNImageRequestHandler(cgImage: cgImage)
            try? handler.perform([request])
        }
    }

    private func classifyFromText(result: AIProductResult, texts: [String]) -> AIProductResult {
        var r = result
        let allText = texts.joined(separator: " ").lowercased()

        let categoryKeywords: [(ProductCategory, [String])] = [
            (.beverages, ["agua", "jugo", "gaseosa", "cerveza", "vino", "refresco", "bebida", "té", "café", "leche", "cola", "sprite"]),
            (.dairy, ["leche", "yogurt", "queso", "crema", "mantequilla", "lácteo"]),
            (.snacks, ["galleta", "papa", "chip", "snack", "dulce", "chocolate", "gomita", "cereal"]),
            (.cleaning, ["jabón", "detergente", "limpia", "desinfect", "cloro", "blanqueador"]),
            (.personalCare, ["shampoo", "crema", "dental", "cepillo", "desodorante", "toalla"]),
            (.grains, ["arroz", "frijol", "lenteja", "pasta", "harina", "avena", "maíz"]),
            (.fruits, ["fruta", "verdura", "manzana", "banano", "tomate", "cebolla"]),
            (.meat, ["carne", "pollo", "cerdo", "res", "jamón", "salchicha"]),
            (.bakery, ["pan", "torta", "pastel", "galleta", "arepa"]),
            (.condiments, ["sal", "pimienta", "salsa", "aceite", "vinagre", "mostaza", "ketchup"])
        ]

        for (category, keywords) in categoryKeywords {
            if keywords.contains(where: { allText.contains($0) }) {
                r.category = category
                break
            }
        }

        if let firstText = texts.first, firstText.count > 2 {
            r.name = firstText.capitalized
        }
        if texts.count > 1 {
            r.brand = texts[1].capitalized
        }

        return r
    }

    /// Parser compartido por Claude y OpenAI (ambos devuelven JSON con los mismos campos)
    private func parseAIJSONResponse(_ content: String) -> AIProductResult {
        var result = AIProductResult()

        let jsonString: String
        if let start = content.firstIndex(of: "{"),
           let end = content.lastIndex(of: "}") {
            jsonString = String(content[start...end])
        } else {
            jsonString = content
        }

        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return result
        }

        // Clamp strings para evitar layout breaks si la IA alucina textos larguísimos
        result.name = clampString(json["nombre"] as? String ?? "", max: 100)
        result.brand = clampString(json["marca"] as? String ?? "", max: 50)
        result.description = clampString(json["descripcion"] as? String ?? "", max: 500)

        // Validar precio sugerido (rechazar negativos, infinitos, y cap en 10M)
        let rawPrice = (json["precio_sugerido"] as? Double) ?? Double(json["precio_sugerido"] as? Int ?? 0)
        result.suggestedPrice = (rawPrice.isFinite && rawPrice > 0) ? min(rawPrice, 10_000_000) : 0

        // Validar confianza (0-100)
        let rawConfidence = (json["confianza"] as? Double) ?? Double(json["confianza"] as? Int ?? 0)
        result.confidence = max(0, min(rawConfidence, 100))

        let categoryStr = (json["categoria"] as? String ?? "").lowercased()
        let categoryMap: [String: ProductCategory] = [
            "bebidas": .beverages, "lácteos": .dairy, "lacteos": .dairy, "snacks": .snacks,
            "limpieza": .cleaning, "cuidado personal": .personalCare,
            "granos": .grains, "frutas y verduras": .fruits, "frutas": .fruits,
            "carnes": .meat, "panadería": .bakery, "panaderia": .bakery,
            "congelados": .frozen, "condimentos": .condiments
        ]
        result.category = categoryMap.first(where: { categoryStr.contains($0.key) })?.value ?? .other

        return result
    }

    /// Limita un string a un largo máximo después de trim (para evitar que IA alucine textos enormes)
    private func clampString(_ s: String, max: Int) -> String {
        String(s.trimmingCharacters(in: .whitespacesAndNewlines).prefix(max))
    }

    private func resizeImage(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let ratio = maxDimension / max(size.width, size.height)
        if ratio >= 1.0 { return image }

        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}

struct AIProductResult {
    var name: String = ""
    var brand: String = ""
    var category: ProductCategory = .other
    var barcode: String?
    var suggestedPrice: Double = 0
    var description: String = ""
    var confidence: Double = 0
    var detectedTexts: [String] = []
    var source: RecognitionSource = .onDevice

    enum RecognitionSource: String {
        case onDevice = "Apple Vision (Gratis)"
        case openAI = "OpenAI Vision API"
        case claude = "Claude Sonnet 4.5 Vision"
    }

    var isEmpty: Bool {
        name.isEmpty && brand.isEmpty && barcode == nil
    }
}
