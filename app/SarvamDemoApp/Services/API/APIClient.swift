// APIClient: UI and service logic for this feature.
import Alamofire
import Foundation

nonisolated final class APIClient {
  // Defines Configuration.
  struct Configuration {
    let baseURL: URL

    static var `default`: Configuration {
      let savedURL = UserDefaults.standard.string(forKey: "apiBaseURL")
        .flatMap(URL.init(string:))
      return Configuration(
        baseURL: savedURL ?? URL(string: "http://localhost:3000")!
      )
    }
  }

  static let shared = APIClient()
  static var account: Account { shared.accountAPI }
  static var auth: Auth { shared.authAPI }
  static var transcriptions: Transcriptions { shared.transcriptionsAPI }

  private(set) var configuration: Configuration
  let session: URLSession
  let decoder: JSONDecoder
  let encoder: JSONEncoder
  lazy var accountAPI = Account(client: self)
  lazy var authAPI = Auth(client: self)
  lazy var transcriptionsAPI = Transcriptions(client: self)
  lazy var chatsAPI = Chats(client: self)

  init(configuration: Configuration = .default, session: URLSession? = nil) {
    print("[App:API] Client initialized")
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

  // Handles updateBaseURL.
  func updateBaseURL(_ baseURL: URL) {
    print("[App:API] Base URL discovered")
    configuration = Configuration(baseURL: baseURL)
    UserDefaults.standard.set(baseURL.absoluteString, forKey: "apiBaseURL")
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

  final class Transcriptions {
    let client: APIClient
    let session: Alamofire.Session

    init(client: APIClient) {
      self.client = client
      self.session = Alamofire.Session(
        configuration: client.session.configuration
      )
    }
  }
}
