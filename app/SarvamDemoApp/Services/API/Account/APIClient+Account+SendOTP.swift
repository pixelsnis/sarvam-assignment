import Foundation

extension APIClient.Account {
  func sendOTP(email: String) async throws {
    let payload = try client.encode(APIClient.EmailOTPRequest(
      email: email,
      type: "sign-in"
    ))

    try await client.perform(
      path: "auth/email-otp/send-verification-otp",
      method: .post,
      body: payload
    )
  }
}
