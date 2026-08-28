// APIClient+Error: UI and service logic for this feature.
import Foundation

// Defines APIClient.
extension APIClient {
  // Defines APIError.
  enum APIError: LocalizedError {
    case encoding(Error)
    case decoding(Error)
    case transport(URLError)
    case request(Error)
    case invalidResponse
    case http(statusCode: Int, payload: ErrorPayload?)

    // Defines ErrorPayload.
    struct ErrorPayload: Decodable {
      let code: String?
      let message: String?
    }

    var statusCode: Int? {
      guard case let .http(statusCode, _) = self else { return nil }
      return statusCode
    }

    var errorDescription: String? {
      switch self {
      case let .encoding(error), let .decoding(error), let .request(error):
        return error.localizedDescription
      case let .transport(error):
        return error.localizedDescription
      case .invalidResponse:
        return "The server returned an invalid response."
      case let .http(statusCode, payload):
        return payload?.message ?? "The server returned HTTP status \(statusCode)."
      }
    }
  }
}
