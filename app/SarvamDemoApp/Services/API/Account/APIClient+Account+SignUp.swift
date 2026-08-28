import Foundation

extension APIClient.Account {
  private struct SignUpPayload: Encodable {
    let name: String
    let email: String
    let password: String
  }

  func signUp(
    name: String,
    email: String,
    password: String
  ) async throws -> APIClient.AuthSession {
    let payload = try client.encode(SignUpPayload(
      name: name,
      email: email,
      password: password
    ))

    return try await client.perform(
      path: "auth/sign-up/email",
      method: .post,
      body: payload
    )
  }
}
