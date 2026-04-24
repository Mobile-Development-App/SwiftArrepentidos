import SwiftUI
import Combine

// ─────────────────────────────────────────────────────────────────────────────
// BusinessQuestionsViewModel — drives the two BQs owned by Juan Felipe:
//
//   • BQ2 — Inventory valuation per store (aggregate)
//   • BQ6 — Peak hours at which the user creates products (usage pattern)
//
// Concurrency
//   Inherits @MainActor from SwiftUI conventions. Heavy work is delegated to
//   `InventoryValuationService` (TaskGroup) and `PeakActivityAnalyzer`
//   (detached task). The view-model only awaits those results — it never
//   does number-crunching inline.
//
// Eventual connectivity
//   Both BQs read from already-cached sources: the `InventoryViewModel`'s
//   products list (hydrated from PersistenceService on launch) and the
//   on-device `UsageTrackingService`. They therefore keep answering while
//   the phone is offline.
//
//   When the network reappears we re-trigger `refresh()` from the view so
//   the valuation can pick up whatever products the inventory sync fetched.
// ─────────────────────────────────────────────────────────────────────────────

@MainActor
final class BusinessQuestionsViewModel: ObservableObject {

    // BQ2 — valuation
    @Published private(set) var valuation: ValuationSnapshot?
    @Published private(set) var isLoadingValuation = false

    // BQ6 — peak hours
    @Published private(set) var peakActivity: PeakActivitySummary?
    @Published private(set) var isLoadingPeak = false

    @Published var errorMessage: String?

    private let valuationService = InventoryValuationService.shared
    private let tracker = UsageTrackingService.shared
    private var cancellables: Set<AnyCancellable> = []

    init() {
        // Invalidate the valuation cache whenever the inventory changes so
        // the next refresh is guaranteed to reflect the edit the user just
        // made. Uses the existing NotificationCenter hook in
        // `InventoryViewModel.addProduct` etc.
        NotificationCenter.default.publisher(for: .inventoryDidChange)
            .sink { [weak self] _ in
                guard let self else { return }
                Task { await self.valuationService.invalidateCache() }
            }
            .store(in: &cancellables)
    }

    /// Re-computes both BQs. Called on view appear and on pull-to-refresh.
    /// The two BQs are independent so we kick them off concurrently.
    func refresh(stores: [Store], products: [Product]) async {
        async let v: () = refreshValuation(stores: stores, products: products)
        async let p: () = refreshPeakActivity()
        _ = await (v, p)
    }

    func refreshValuation(stores: [Store], products: [Product]) async {
        isLoadingValuation = true
        defer { isLoadingValuation = false }
        let snapshot = await valuationService.compute(stores: stores, products: products)
        self.valuation = snapshot
    }

    func refreshPeakActivity() async {
        isLoadingPeak = true
        defer { isLoadingPeak = false }
        let events = await tracker.recentEvents(within: 30)
        let summary = await PeakActivityAnalyzer.analyze(events: events)
        self.peakActivity = summary
    }

    // MARK: - Formatting helpers for the views

    static let currency: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencySymbol = "$"
        f.maximumFractionDigits = 0
        return f
    }()

    func currencyString(_ value: Double) -> String {
        Self.currency.string(from: NSNumber(value: value)) ?? "$0"
    }
}
