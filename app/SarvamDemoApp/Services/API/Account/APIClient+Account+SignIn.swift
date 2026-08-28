import Foundation

extension APIClient.Account {
  private struct SignInPayload: Encodable {
    let email: String
    let password: String
  }

  func signIn(
    email: String,
    password: String
  ) async throws -> APIClient.AuthSession {
    let payload = try client.encode(SignInPayload(
      email: email,
      password: password
    ))

    return try await client.perform(
      path: "auth/sign-in/email",
      method: .post,
      body: payload
    )
  }
}
