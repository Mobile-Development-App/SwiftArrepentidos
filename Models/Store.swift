import Foundation

struct Store: Identifiable, Hashable, Codable {
    let id: UUID
    var name: String
    var address: String
    var phone: String
    var email: String
    var manager: String
    var employeeCount: Int
    var productCount: Int
    var monthlySales: Double
    var isActive: Bool
    var createdAt: Date

    var formattedSales: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "$"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: monthlySales)) ?? "$0"
    }
}
