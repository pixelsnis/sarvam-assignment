// APIClient+Account+ResendOTP: UI and service logic for this feature.
import Foundation

// Defines APIClient.
extension APIClient.Account {
  // Handles resendOTP.
  func resendOTP(email: String) async throws {
    print("[App:AccountAPI] Resending OTP")
    try await sendOTP(email: email)
  }
}
