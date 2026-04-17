import Foundation

protocol SalesRepositoryProtocol {
    func recordSale(productId: String, quantity: Int, unitPrice: Double) async throws
    func fetchSales(limit: Int?, cursor: String?) async throws -> (sales: [SaleRecordDTO], nextCursor: String?)
    func fetchSummary(period: String, dateFrom: String?, dateTo: String?) async throws -> SalesSummaryDTO
}

/// Sale record DTO from backend
struct SaleRecordDTO: Decodable {
    let id: String
    let storeId: String?
    let productId: String?
    let userId: String?
    let quantity: Int
    let unitPrice: Double
    let totalAmount: Double
    let createdAt: FirestoreTimestamp?
}

final class SalesRepository: SalesRepositoryProtocol {
    private let apiClient = APIClient.shared
    private let networkMonitor = NetworkMonitor.shared

    func recordSale(productId: String, quantity: Int, unitPrice: Double) async throws {
        guard networkMonitor.isConnected else {
            throw APIError.offline
        }

        let body: [String: Any] = [
            "productId": productId,
            "quantity": quantity,
            "unitPrice": unitPrice
        ]

        let _: SaleRecordDTO = try await apiClient.request(
            .sales,
            method: .POST,
            body: body
        )
    }

    func fetchSales(limit: Int? = nil, cursor: String? = nil) async throws -> (sales: [SaleRecordDTO], nextCursor: String?) {
        guard networkMonitor.isConnected else {
            throw APIError.offline
        }

        var params: [String: String] = [:]
        if let limit { params["limit"] = String(limit) }
        if let cursor { params["startAfter"] = cursor }

        let (dtos, pagination): ([SaleRecordDTO], APIPagination?) = try await apiClient.requestPaginated(
            .sales,
            queryParams: params.isEmpty ? nil : params
        )

        return (dtos, pagination?.nextCursor)
    }

    func fetchSummary(period: String = "day", dateFrom: String? = nil, dateTo: String? = nil) async throws -> SalesSummaryDTO {
        var params: [String: String] = ["period": period]
        if let dateFrom { params["dateFrom"] = dateFrom }
        if let dateTo { params["dateTo"] = dateTo }

        return try await apiClient.request(
            .salesSummary,
            queryParams: params
        )
    }
}
