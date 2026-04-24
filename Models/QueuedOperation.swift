import Foundation

//when lost conenction, we queue operations to be done after the connection is restored
enum QueuedOperation: Codable, Identifiable, Hashable {
    case createProduct(clientId: UUID, product: Product, enqueuedAt: Date)
    case updateProduct(productId: UUID, product: Product, enqueuedAt: Date)
    case deleteProduct(productId: UUID, enqueuedAt: Date)

    var id: UUID {
        switch self {
        case .createProduct(let id, _, _): return id
        case .updateProduct(let id, _, _): return id
        case .deleteProduct(let id, _): return id
        }
    }

    var enqueuedAt: Date {
        switch self {
        case .createProduct(_, _, let at),
             .updateProduct(_, _, let at),
             .deleteProduct(_, let at):
            return at
        }
    }

    var description: String {
        switch self {
        case .createProduct(_, let p, _): return "createProduct(\(p.name))"
        case .updateProduct(_, let p, _): return "updateProduct(\(p.name))"
        case .deleteProduct(let id, _):   return "deleteProduct(\(id.uuidString.prefix(8)))"
        }
    }
}
