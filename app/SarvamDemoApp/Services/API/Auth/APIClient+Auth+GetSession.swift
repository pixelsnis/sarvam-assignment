import Foundation

extension APIClient.Auth {
  func getSession() async throws -> APIClient.AuthSession? {
    try await client.perform(
      path: "auth/get-session",
      method: .get
    )
  }
}
