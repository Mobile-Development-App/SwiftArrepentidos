import Foundation
import UIKit
import PDFKit

/// Genera reportes de analítica (CSV y PDF) localmente y los retorna como archivos en el directorio temporal,
/// listos para compartir vía UIActivityViewController (AirDrop, Mail, Files, etc.).
///
/// Se diseñó para funcionar sin depender del backend: los datos se construyen desde el inventario local
/// (source of truth durante la sesión del usuario).
final class ReportExporter {

    enum ExportError: LocalizedError {
        case writeFailed
        case pdfRenderFailed

        var errorDescription: String? {
            switch self {
            case .writeFailed: return "No se pudo escribir el archivo"
            case .pdfRenderFailed: return "No se pudo generar el PDF"
            }
        }
    }

    /// Genera un CSV con el inventario, salesData y distribución por categoría.
    /// Retorna la URL del archivo en el directorio temporal.
    func generateCSV(
        products: [Product],
        salesData: [SalesDataPoint],
        categoryDistribution: [CategoryDistribution],
        stockLevelData: [StockLevelData]
    ) throws -> URL {
        var csv = ""

        // Header del reporte
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "es_CO")

        csv += "InventarIA - Reporte de Inventario\n"
        csv += "Generado: \(formatter.string(from: Date()))\n"
        csv += "\n"

        // Sección 1: KPIs
        let totalSales = salesData.reduce(0) { $0 + $1.sales }
        let totalOrders = salesData.reduce(0) { $0 + $1.orders }
        let totalProducts = products.count
        let stockValue = products.reduce(0) { $0 + $1.stockValue }

        csv += "==== RESUMEN EJECUTIVO ====\n"
        csv += "Ventas Totales,\(formatMoney(totalSales))\n"
        csv += "Total de Pedidos,\(totalOrders)\n"
        csv += "Total de Productos,\(totalProducts)\n"
        csv += "Valor del Stock,\(formatMoney(stockValue))\n"
        csv += "\n"

        // Sección 2: Productos
        csv += "==== INVENTARIO DE PRODUCTOS ====\n"
        csv += "Nombre,SKU,Código de Barras,Categoría,Proveedor,Stock Actual,Stock Mínimo,Precio Costo,Precio Venta,Margen %,Estado\n"
        for p in products {
            let fields: [String] = [
                escape(p.name),
                escape(p.sku),
                escape(p.barcode),
                escape(p.category.rawValue),
                escape(p.supplier),
                String(p.quantity),
                String(p.minStock),
                String(format: "%.2f", p.costPrice),
                String(format: "%.2f", p.salePrice),
                String(format: "%.1f", p.profitMargin),
                escape(p.stockStatus.rawValue)
            ]
            csv += fields.joined(separator: ",") + "\n"
        }
        csv += "\n"

        // Sección 3: Distribución por Categoría
        csv += "==== DISTRIBUCIÓN POR CATEGORÍA ====\n"
        csv += "Categoría,Cantidad,Porcentaje,Valor\n"
        for cat in categoryDistribution {
            csv += "\(escape(cat.category)),\(cat.count),\(String(format: "%.1f%%", cat.percentage)),\(formatMoney(cat.value))\n"
        }
        csv += "\n"

        // Sección 4: Niveles de Stock
        csv += "==== NIVELES DE STOCK POR CATEGORÍA ====\n"
        csv += "Categoría,En Stock,Stock Bajo,Agotado\n"
        for s in stockLevelData {
            csv += "\(escape(s.category)),\(s.inStock),\(s.lowStock),\(s.outOfStock)\n"
        }
        csv += "\n"

        // Sección 5: Tendencia de Ventas
        if !salesData.isEmpty {
            csv += "==== TENDENCIA DE VENTAS ====\n"
            csv += "Fecha,Ventas,Pedidos\n"
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            for point in salesData {
                csv += "\(dateFormatter.string(from: point.date)),\(formatMoney(point.sales)),\(point.orders)\n"
            }
        }

        // BOM UTF-8 para que Excel abra los acentos correctamente
        let bom = "\u{FEFF}"
        let finalData = (bom + csv).data(using: .utf8) ?? Data()

        let fileName = "InventarIA_Reporte_\(Int(Date().timeIntervalSince1970)).csv"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        do {
            try finalData.write(to: url, options: .atomic)
            return url
        } catch {
            throw ExportError.writeFailed
        }
    }

    /// Genera un PDF con secciones y tablas. Retorna la URL del archivo.
    func generatePDF(
        products: [Product],
        salesData: [SalesDataPoint],
        categoryDistribution: [CategoryDistribution],
        stockLevelData: [StockLevelData]
    ) throws -> URL {
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792) // US Letter
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: UIGraphicsPDFRendererFormat())

        let fileName = "InventarIA_Reporte_\(Int(Date().timeIntervalSince1970)).pdf"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .short
        dateFormatter.locale = Locale(identifier: "es_CO")

        let totalSales = salesData.reduce(0) { $0 + $1.sales }
        let totalOrders = salesData.reduce(0) { $0 + $1.orders }
        let stockValue = products.reduce(0) { $0 + $1.stockValue }

        do {
            try renderer.writePDF(to: url) { ctx in
                ctx.beginPage()
                var yPos: CGFloat = 40

                // Título
                let titleAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 24, weight: .bold),
                    .foregroundColor: UIColor.black
                ]
                let subtitleAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 10, weight: .regular),
                    .foregroundColor: UIColor.darkGray
                ]

                "InventarIA — Reporte de Inventario".draw(at: CGPoint(x: 40, y: yPos), withAttributes: titleAttrs)
                yPos += 32
                "Generado el \(dateFormatter.string(from: Date()))".draw(at: CGPoint(x: 40, y: yPos), withAttributes: subtitleAttrs)
                yPos += 28

                // Línea separadora
                drawLine(at: yPos, in: ctx.cgContext)
                yPos += 12

                // Sección: Resumen ejecutivo
                yPos = drawSectionHeader("Resumen Ejecutivo", at: yPos)
                let summaryRows: [(String, String)] = [
                    ("Ventas Totales", formatMoney(totalSales)),
                    ("Total de Pedidos", "\(totalOrders)"),
                    ("Total de Productos", "\(products.count)"),
                    ("Valor del Stock", formatMoney(stockValue)),
                    ("Productos con Stock Bajo", "\(products.filter { $0.stockStatus == .lowStock }.count)"),
                    ("Productos Agotados", "\(products.filter { $0.stockStatus == .outOfStock }.count)"),
                    ("Productos por Vencer", "\(products.filter { $0.isExpired || $0.isExpiringSoon }.count)")
                ]
                for row in summaryRows {
                    yPos = drawKeyValue(row.0, row.1, at: yPos)
                }
                yPos += 12

                // Sección: Distribución por Categoría
                if !categoryDistribution.isEmpty {
                    yPos = drawSectionHeader("Distribución por Categoría", at: yPos)
                    yPos = drawTableHeader(["Categoría", "Cantidad", "%", "Valor"], widths: [180, 80, 80, 120], at: yPos)
                    for cat in categoryDistribution.prefix(12) {
                        yPos = drawTableRow([
                            cat.category,
                            "\(cat.count)",
                            String(format: "%.1f%%", cat.percentage),
                            formatMoney(cat.value)
                        ], widths: [180, 80, 80, 120], at: yPos)
                        if yPos > 730 {
                            ctx.beginPage()
                            yPos = 40
                        }
                    }
                    yPos += 12
                }

                // Sección: Niveles de Stock
                if !stockLevelData.isEmpty {
                    if yPos > 650 {
                        ctx.beginPage()
                        yPos = 40
                    }
                    yPos = drawSectionHeader("Niveles de Stock por Categoría", at: yPos)
                    yPos = drawTableHeader(["Categoría", "En Stock", "Stock Bajo", "Agotado"], widths: [180, 100, 100, 100], at: yPos)
                    for s in stockLevelData {
                        yPos = drawTableRow([s.category, "\(s.inStock)", "\(s.lowStock)", "\(s.outOfStock)"],
                                            widths: [180, 100, 100, 100], at: yPos)
                        if yPos > 730 {
                            ctx.beginPage()
                            yPos = 40
                        }
                    }
                    yPos += 12
                }

                // Sección: Productos (tabla grande, paginada)
                ctx.beginPage()
                yPos = 40
                yPos = drawSectionHeader("Inventario de Productos (\(products.count))", at: yPos)
                yPos = drawTableHeader(["Producto", "SKU", "Stock", "Precio", "Estado"],
                                        widths: [200, 90, 60, 100, 80], at: yPos)
                for p in products {
                    yPos = drawTableRow([
                        truncate(p.name, to: 28),
                        truncate(p.sku, to: 12),
                        "\(p.quantity)",
                        formatMoney(p.salePrice),
                        p.stockStatus.rawValue
                    ], widths: [200, 90, 60, 100, 80], at: yPos)
                    if yPos > 750 {
                        ctx.beginPage()
                        yPos = 40
                    }
                }
            }
            return url
        } catch {
            throw ExportError.pdfRenderFailed
        }
    }

    // MARK: - Helpers

    private func escape(_ s: String) -> String {
        // Escapar CSV: si el campo tiene coma, comilla o newline, envolver en comillas y escapar internas
        if s.contains(",") || s.contains("\"") || s.contains("\n") {
            let escaped = s.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return s
    }

    private func formatMoney(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "$"
        formatter.maximumFractionDigits = 0
        formatter.locale = Locale(identifier: "es_CO")
        return formatter.string(from: NSNumber(value: value)) ?? "$0"
    }

    private func truncate(_ s: String, to max: Int) -> String {
        s.count <= max ? s : String(s.prefix(max - 1)) + "…"
    }

    private func drawLine(at y: CGFloat, in ctx: CGContext) {
        ctx.setStrokeColor(UIColor.lightGray.cgColor)
        ctx.setLineWidth(0.5)
        ctx.move(to: CGPoint(x: 40, y: y))
        ctx.addLine(to: CGPoint(x: 572, y: y))
        ctx.strokePath()
    }

    private func drawSectionHeader(_ title: String, at y: CGFloat) -> CGFloat {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14, weight: .semibold),
            .foregroundColor: UIColor(red: 0.25, green: 0.45, blue: 0.75, alpha: 1) // azul corporativo
        ]
        title.draw(at: CGPoint(x: 40, y: y), withAttributes: attrs)
        return y + 22
    }

    private func drawKeyValue(_ key: String, _ value: String, at y: CGFloat) -> CGFloat {
        let keyAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 10), .foregroundColor: UIColor.darkGray]
        let valueAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 10, weight: .medium), .foregroundColor: UIColor.black]
        key.draw(at: CGPoint(x: 48, y: y), withAttributes: keyAttrs)
        let valueWidth = (value as NSString).size(withAttributes: valueAttrs).width
        value.draw(at: CGPoint(x: 560 - valueWidth, y: y), withAttributes: valueAttrs)
        return y + 16
    }

    private func drawTableHeader(_ headers: [String], widths: [CGFloat], at y: CGFloat) -> CGFloat {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 9, weight: .semibold),
            .foregroundColor: UIColor.darkGray
        ]
        var x: CGFloat = 40
        for (i, h) in headers.enumerated() {
            h.draw(at: CGPoint(x: x + 4, y: y), withAttributes: attrs)
            x += widths[i]
        }
        return y + 14
    }

    private func drawTableRow(_ values: [String], widths: [CGFloat], at y: CGFloat) -> CGFloat {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 9),
            .foregroundColor: UIColor.black
        ]
        var x: CGFloat = 40
        for (i, v) in values.enumerated() {
            v.draw(at: CGPoint(x: x + 4, y: y), withAttributes: attrs)
            x += widths[i]
        }
        return y + 12
    }
}
