import SwiftUI

struct NotificationsView: View {
    @EnvironmentObject var inventoryViewModel: InventoryViewModel
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme

    @State private var filterAll = true // true = all, false = unread only

    var filteredAlerts: [InventoryAlert] {
        if filterAll {
            return inventoryViewModel.alerts
        } else {
            return inventoryViewModel.alerts.filter { !$0.isRead }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filter toggle
                HStack(spacing: 0) {
                    filterButton(title: "Todas", isSelected: filterAll) {
                        filterAll = true
                    }
                    filterButton(title: "No leídas (\(inventoryViewModel.unreadAlertCount))", isSelected: !filterAll) {
                        filterAll = false
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                if filteredAlerts.isEmpty {
                    EmptyStateView(
                        icon: "bell.slash",
                        title: "Sin notificaciones",
                        description: filterAll ?
                            "No tienes notificaciones aún" :
                            "No tienes notificaciones sin leer"
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(filteredAlerts) { alert in
                                AlertCardView(alert: alert) {
                                    inventoryViewModel.markAlertAsRead(alert)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 20)
                    }
                }
            }
            .background(colorScheme == .dark ? AppColors.darkBackground : AppColors.background)
            .navigationTitle("Notificaciones")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if inventoryViewModel.unreadAlertCount > 0 {
                        Button("Leer todo") {
                            inventoryViewModel.markAllAlertsAsRead()
                            HapticManager.notification(.success)
                        }
                        .font(AppTypography.captionFont)
                        .foregroundColor(AppColors.primary)
                    }
                }
            }
        }
    }

    private func filterButton(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: {
            action()
            HapticManager.selection()
        }) {
            Text(title)
                .font(AppTypography.captionFont)
                .fontWeight(.medium)
                .foregroundColor(isSelected ? .white : AppColors.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(isSelected ? AppColors.primary : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}
