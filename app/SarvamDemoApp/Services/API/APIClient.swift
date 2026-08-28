import Foundation

final class APIClient {
  struct Configuration {
    let baseURL: URL

    static let `default` = Configuration(
      baseURL: URL(string: "http://localhost:3000")!
    )
  }

  static let shared = APIClient()
  static var account: Account { shared.accountAPI }
  static var auth: Auth { shared.authAPI }
  static var chat: Chat { shared.chatAPI }

  let configuration: Configuration
  let session: URLSession
  let decoder: JSONDecoder
  let encoder: JSONEncoder
  lazy var accountAPI = Account(client: self)
  lazy var authAPI = Auth(client: self)
  lazy var chatAPI = Chat(client: self)

  init(configuration: Configuration = .default, session: URLSession? = nil) {
    self.configuration = configuration

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .custom { decoder in
      let value = try decoder.singleValueContainer().decode(String.self)
      let formatter = ISO8601DateFormatter()
      formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

      if let date = formatter.date(from: value) {
        return date
      }

      formatter.formatOptions = [.withInternetDateTime]
      guard let date = formatter.date(from: value) else {
        throw DecodingError.dataCorruptedError(
          in: try decoder.singleValueContainer(),
          debugDescription: "Invalid ISO-8601 date: \(value)"
        )
      }

      return date
    }
    self.decoder = decoder

    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    self.encoder = encoder

    if let session {
      self.session = session
    } else {
      let sessionConfiguration = URLSessionConfiguration.default
      sessionConfiguration.httpCookieStorage = .shared
      sessionConfiguration.httpShouldSetCookies = true
      sessionConfiguration.httpCookieAcceptPolicy = .always
      self.session = URLSession(configuration: sessionConfiguration)
    }

  }

  final class Account {
    let client: APIClient

    init(client: APIClient) {
      self.client = client
    }
  }

  final class Auth {
    let client: APIClient

    init(client: APIClient) {
      self.client = client
    }
  }
}
