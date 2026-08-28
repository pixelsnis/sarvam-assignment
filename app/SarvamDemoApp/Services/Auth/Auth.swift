import Foundation
import Observation

@MainActor
@Observable
final class Auth {
  static let shared = Auth()

  let apiClient: APIClient

  private(set) var status: Status = .unknown
  private(set) var user: APIClient.User?
  private(set) var session: APIClient.Session?
  private(set) var isLoading = false
  private(set) var errorMessage: String?

  var lifecycleTask: Task<Void, Never>?
  var isRefreshing = false

  init() {
    self.apiClient = .shared
  }

  init(apiClient: APIClient) {
    self.apiClient = apiClient
  }

  func apply(_ authSession: APIClient.AuthSession?) {
    print("[App:Auth] Applying session state")
    guard let authSession else {
      status = .unauthenticated
      user = nil
      session = nil
      return
    }

    status = .authenticated
    user = authSession.user
    session = authSession.session
  }

  func clearError() {
    errorMessage = nil
  }

  func record(error: Error) {
    print("[App:Auth] Error recorded")
    errorMessage = error.localizedDescription
  }

  func setLoading(_ isLoading: Bool) {
    self.isLoading = isLoading
  }
}
