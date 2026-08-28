// APIClient+Account+VerifyOTP: UI and service logic for this feature.
import Foundation

// Defines APIClient.
extension APIClient.Account {
  // Defines VerifyOTPPayload.
  private struct VerifyOTPPayload: Encodable {
    let email: String
    let otp: String
    let name: String?
  }

  // Handles verifyOTP.
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
