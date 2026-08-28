import Foundation

extension APIClient.Auth {
  func getSession() async throws -> APIClient.AuthSession? {
    print("[App:AuthAPI] Loading session")
    return try await client.perform(
      path: "auth/get-session",
      method: .get
    )
  }
}
