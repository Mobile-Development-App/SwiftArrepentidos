import SwiftUI

struct TeamMembersView: View {
    @EnvironmentObject var storeViewModel: StoreViewModel
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme

    @State private var filterStore: UUID?

    var filteredEmployees: [Employee] {
        if let storeId = filterStore {
            return storeViewModel.employees.filter { $0.storeId == storeId }
        }
        return storeViewModel.employees
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    HStack(spacing: 14) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 24))
                            .foregroundColor(AppColors.primary)
                            .frame(width: 48, height: 48)
                            .background(AppColors.primary.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Miembros del Equipo")
                                .font(AppTypography.headlineFont)
                            Text("\(storeViewModel.employees.count) miembros en total")
                                .font(AppTypography.captionFont)
                                .foregroundColor(AppColors.textSecondary)
                        }

                        Spacer()
                    }
                    .padding(16)
                    .cardStyle()

                    // store filter
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            filterChip(title: "Todas", isSelected: filterStore == nil) {
                                filterStore = nil
                            }
                            ForEach(storeViewModel.stores) { store in
                                filterChip(title: store.name, isSelected: filterStore == store.id) {
                                    filterStore = store.id
                                }
                            }
                        }
                    }
                    ForEach(filteredEmployees) { employee in
                        employeeCard(employee)
                    }

                    Button(action: {}) {
                        HStack {
                            Image(systemName: "person.badge.plus")
                            Text("Invitar Miembro")
                        }
                    }
                    .buttonStyle(SecondaryButtonStyle())

                    Spacer().frame(height: 20)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
            }
            .background(colorScheme == .dark ? AppColors.darkBackground : AppColors.background)
            .navigationTitle("Equipo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                    }
                }
            }
        }
    }

    private func filterChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: {
            action()
            HapticManager.selection()
        }) {
            Text(title)
                .font(AppTypography.captionFont)
                .foregroundColor(isSelected ? .white : AppColors.textSecondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(isSelected ? AppColors.primary : (colorScheme == .dark ? AppColors.darkSurface : AppColors.surface))
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(isSelected ? Color.clear : AppColors.border.opacity(0.5), lineWidth: 1)
                )
        }
    }

    private func employeeCard(_ employee: Employee) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(AppColors.primary.opacity(0.15))
                    .frame(width: 48, height: 48)
                Text(employee.initials)
                    .font(AppTypography.calloutFont)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.primary)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(employee.fullName)
                    .font(AppTypography.headlineFont)
                    .foregroundColor(colorScheme == .dark ? AppColors.darkTextPrimary : AppColors.textPrimary)

                HStack(spacing: 8) {
                    Image(systemName: employee.role.icon)
                        .font(.system(size: 10))
                    Text(employee.role.rawValue)
                        .font(AppTypography.caption2Font)
                }
                .foregroundColor(AppColors.textSecondary)

                HStack(spacing: 8) {
                    BadgeView(text: employee.storeName, style: .default)

                    Text("Desde \(employee.joinDate.shortFormatted)")
                        .font(AppTypography.caption2Font)
                        .foregroundColor(AppColors.textTertiary)
                }
            }

            Spacer()

            BadgeView(
                text: employee.isActive ? "Activo" : "Inactivo",
                style: employee.isActive ? .success : .secondary
            )
        }
        .padding(14)
        .cardStyle()
    }
}
