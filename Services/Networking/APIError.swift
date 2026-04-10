import Foundation

enum APIError: LocalizedError {
    case unauthorized
    case forbidden
    case notFound
    case conflict
    case validationError(String)
    case approvalRequired
    case serverError(statusCode: Int)
    case networkError(Error)
    case decodingError(Error)
    case offline
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "Sesion expirada. Inicia sesion de nuevo."
        case .forbidden:
            return "No tienes permisos para esta accion."
        case .notFound:
            return "El recurso no fue encontrado."
        case .conflict:
            return "Conflicto: el recurso ya existe."
        case .validationError(let message):
            return message
        case .approvalRequired:
            return "Esta accion requiere aprobacion de un gerente."
        case .serverError(let code):
            return "Error del servidor (\(code)). Intenta de nuevo."
        case .networkError:
            return "Error de conexion. Verifica tu internet."
        case .decodingError:
            return "Error procesando la respuesta del servidor."
        case .offline:
            return "Sin conexion. Usando datos locales."
        case .unknown(let message):
            return message
        }
    }

    static func from(statusCode: Int, message: String?) -> APIError {
        switch statusCode {
        case 401: return .unauthorized
        case 403: return message?.contains("approval") == true ? .approvalRequired : .forbidden
        case 404: return .notFound
        case 409: return .conflict
        case 400, 422: return .validationError(message ?? "Datos invalidos.")
        case 500...599: return .serverError(statusCode: statusCode)
        default: return .unknown(message ?? "Error desconocido.")
        }
    }
}
