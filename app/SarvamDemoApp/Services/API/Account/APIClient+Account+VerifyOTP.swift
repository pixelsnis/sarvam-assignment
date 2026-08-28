import Foundation

extension APIClient.Account {
  private struct VerifyOTPPayload: Encodable {
    let email: String
    let otp: String
    let name: String?
  }

  func verifyOTP(
    email: String,
    otp: String,
    name: String? = nil
  ) async throws -> APIClient.AuthSession {
    let payload = try client.encode(VerifyOTPPayload(
      email: email,
      otp: otp,
      name: name
    ))

    return try await client.perform(
      path: "auth/sign-in/email-otp",
      method: .post,
      body: payload
    )
  }
}
