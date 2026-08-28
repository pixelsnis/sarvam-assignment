import Foundation

extension APIClient.Auth {
  func signOut() async throws {
    try await client.perform(
      path: "auth/sign-out",
      method: .post
    )
  }
}
