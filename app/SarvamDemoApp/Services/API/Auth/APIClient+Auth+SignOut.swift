// APIClient+Auth+SignOut: UI and service logic for this feature.
import Foundation

// Defines APIClient.
extension APIClient.Auth {
  // Handles signOut.
  func signOut() async throws {
    print("[App:AuthAPI] Signing out")
    try await client.perform(
      path: "auth/sign-out",
      method: .post
    )
  }
}
