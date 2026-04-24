import SwiftUI

/// BQ2 — Inventory valuation per store.
/// Shows total stock value across stores and a per-store breakdown with
/// margin percentage, plus a tiny debug footer with the wall-clock time of
/// the concurrent aggregation (proof that multi-threading is doing work).
struct InventoryValuationCard: View {
    let snapshot: ValuationSnapshot?
    let isLoading: Bool
    let currencyFormatter: (Double) -> String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            if isLoading && snapshot == nil {
                loadingRow
            } else if let s = snapshot {
                totals(s)
                Divider()
                if s.perStore.isEmpty {
                    emptyState
                } else {
                    storeList(s.perStore)
                }
                footer(s)
            } else {
                emptyState
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppColors.surface)
                .shadow(color: Color.black.opacity(0.04), radius: 6, y: 2)
        )
    }

    // MARK: - Sections

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("BQ2 · Valor del inventario por tienda")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(AppColors.inkBlack)
                Text("Agregación paralela (TaskGroup)")
                    .font(.caption2)
                    .foregroundColor(AppColors.textTertiary)
            }
            Spacer()
            if isLoading {
                ProgressView().scaleEffect(0.7)
            }
        }
    }

    private func totals(_ s: ValuationSnapshot) -> some View {
        HStack(spacing: 20) {
            metricBlock(
                label: "Valor total",
                value: currencyFormatter(s.totalStockValue),
                color: AppColors.freshSky
            )
            metricBlock(
                label: "Margen sobre costo",
                value: currencyFormatter(s.totalMarginValue),
                color: AppColors.teaGreen
            )
        }
    }

    private func metricBlock(label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(AppColors.textTertiary)
            Text(value)
                .font(.title3.weight(.bold))
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func storeList(_ items: [StoreValuation]) -> some View {
        VStack(spacing: 10) {
            ForEach(items) { v in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(v.storeName)
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(AppColors.inkBlack)
                        Text("\(v.productCount) productos")
                            .font(.caption2)
                            .foregroundColor(AppColors.textTertiary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(currencyFormatter(v.stockValue))
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(AppColors.inkBlack)
                        Text(String(format: "margen %.1f%%", v.marginPct))
                            .font(.caption2)
                            .foregroundColor(AppColors.textTertiary)
                    }
                }
            }
        }
    }

    private func footer(_ s: ValuationSnapshot) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "bolt.fill").font(.caption2)
            Text(String(format: "Agregado en %.1f ms · %@",
                        s.durationMs,
                        relativeTime(from: s.computedAt)))
                .font(.caption2)
        }
        .foregroundColor(AppColors.textTertiary)
    }

    private var emptyState: some View {
        HStack {
            Spacer()
            VStack(spacing: 6) {
                Image(systemName: "tray")
                    .font(.title2)
                    .foregroundColor(AppColors.textTertiary)
                Text("Aún no hay productos cargados")
                    .font(.footnote)
                    .foregroundColor(AppColors.textTertiary)
            }
            .padding(.vertical, 20)
            Spacer()
        }
    }

    private var loadingRow: some View {
        HStack {
            Spacer()
            ProgressView("Agregando inventario…")
                .font(.footnote)
            Spacer()
        }
        .padding(.vertical, 24)
    }

    private func relativeTime(from date: Date) -> String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return f.localizedString(for: date, relativeTo: Date())
    }
}
