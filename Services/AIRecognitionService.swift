import Foundation
import UIKit
import Vision

/// OpenAI Vision API (costs $0.01/image) for smart product identification
///
/// usage: Set `openAIApiKey` to enable enhanced AI recognition.
/// without the key, the service uses on-device processing only.
class AIRecognitionService: ObservableObject {
    static let shared = AIRecognitionService()

    @Published var isProcessing = false
    @Published var lastResult: AIProductResult?
    @Published var error: String?

    /// set this to the openai key
    /// Without it, the service uses free on-device Apple Vision only.
    var openAIApiKey: String? = nil

    var isOpenAIEnabled: Bool { openAIApiKey != nil && !openAIApiKey!.isEmpty }

    // free version (free)

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
        result.confidence = 65.0  
        result.source = .onDevice

        await MainActor.run {
            self.lastResult = result
            self.isProcessing = false
        }

        return result
    }

    // openai version (Paid per token)

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

            var result = parseOpenAIResponse(content)
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

    func analyze(image: UIImage, barcode: String? = nil) async -> AIProductResult {
        if isOpenAIEnabled {
            return await analyzeWithOpenAI(image: image, barcode: barcode)
        } else {
            return await analyzeWithVision(image: image, barcode: barcode)
        }
    }

    //helpers
    private func detectBarcodes(in cgImage: CGImage) async -> String? {
        await withCheckedContinuation { continuation in
            let request = VNDetectBarcodesRequest { request, _ in
                let barcode = (request.results as? [VNBarcodeObservation])?.first?.payloadStringValue
                continuation.resume(returning: barcode)
            }
            request.symbologies = [.ean13, .ean8, .upce, .code128, .code39, .qr]
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

    private func parseOpenAIResponse(_ content: String) -> AIProductResult {
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

        result.name = json["nombre"] as? String ?? ""
        result.brand = json["marca"] as? String ?? ""
        result.suggestedPrice = json["precio_sugerido"] as? Double ?? 0
        result.description = json["descripcion"] as? String ?? ""
        result.confidence = json["confianza"] as? Double ?? 0

        let categoryStr = (json["categoria"] as? String ?? "").lowercased()
        let categoryMap: [String: ProductCategory] = [
            "bebidas": .beverages, "lácteos": .dairy, "snacks": .snacks,
            "limpieza": .cleaning, "cuidado personal": .personalCare,
            "granos": .grains, "frutas y verduras": .fruits,
            "carnes": .meat, "panadería": .bakery,
            "congelados": .frozen, "condimentos": .condiments
        ]
        result.category = categoryMap.first(where: { categoryStr.contains($0.key) })?.value ?? .other

        return result
    }

    private func resizeImage(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let ratio = maxDimension / max(size.width, size.height)
        if ratio >= 1.0 { return image }

        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let resized = UIGraphicsGetImageFromCurrentImageContext() ?? image
        UIGraphicsEndImageContext()
        return resized
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
    }

    var isEmpty: Bool {
        name.isEmpty && brand.isEmpty && barcode == nil
    }
}
