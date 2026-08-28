import Foundation

extension APIClient.Account {
  private struct VerifyOTPPayload: Encodable {
    let email: String
    let otp: String
    let name: String?
  }

  func verifyOTP(
    email: String,
    otp: String
  ) async throws -> APIClient.User {
    print("[App:AccountAPI] Verifying OTP")
    let payload = try client.encode(VerifyOTPPayload(
      email: email,
      otp: otp,
      name: nil
    ))

    let response: APIClient.EmailOTPAuthenticationResponse = try await client.perform(
      path: "auth/sign-in/email-otp",
      method: .post,
      body: payload
    )

    return response.user
  }
}
