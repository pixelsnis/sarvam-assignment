// APIClient+Account+SendOTP: UI and service logic for this feature.
import Foundation

// Defines APIClient.
extension APIClient.Account {
  // Handles sendOTP.
  func sendOTP(email: String) async throws {
    print("[App:AccountAPI] Sending OTP")
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
