import SwiftUI
import Combine


@MainActor
final class WasteBQViewModel: ObservableObject {

    @Published private(set) var report: WasteReport?
    @Published private(set) var isLoading = false

    private let store = WasteStore.shared
    private let analytics = WasteAnalyticsService.shared

    func refresh() async {
        isLoading = true
        defer { isLoading = false }
        let events = await store.allEvents()
        guard !events.isEmpty else {
            report = nil
            return
        }
        report = await analytics.report(events: events, windowDays: 30)
    }
}
