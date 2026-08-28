import Foundation

extension APIClient.Account {
  private struct UpdateUserPayload: Encodable {
    let name: String
  }

  func updateUser(name: String) async throws {
    print("[App:AccountAPI] Updating user")
    let payload = try client.encode(UpdateUserPayload(name: name))

    try await client.perform(
      path: "auth/update-user",
      method: .post,
      body: payload
    )
  }
}
