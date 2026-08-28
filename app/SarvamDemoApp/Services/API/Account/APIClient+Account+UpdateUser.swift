// APIClient+Account+UpdateUser: UI and service logic for this feature.
import Foundation

// Defines APIClient.
extension APIClient.Account {
  // Defines UpdateUserPayload.
  private struct UpdateUserPayload: Encodable {
    let name: String
  }

  // Handles updateUser.
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
