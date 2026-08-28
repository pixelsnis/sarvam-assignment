// APIClient+Auth+GetSession: UI and service logic for this feature.
import Foundation

// Defines APIClient.
extension APIClient.Auth {
  // Handles getSession.
  func getSession() async throws -> APIClient.AuthSession? {
    print("[App:AuthAPI] Loading session")
    return try await client.perform(
      path: "auth/get-session",
      method: .get
    )
  }
}
