import Foundation

extension APIClient.Auth {
  func signOut() async throws {
    print("[App:AuthAPI] Signing out")
    try await client.perform(
      path: "auth/sign-out",
      method: .post
    )
  }
}
