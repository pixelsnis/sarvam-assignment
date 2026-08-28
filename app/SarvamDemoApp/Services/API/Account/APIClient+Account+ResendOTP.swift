import Foundation

extension APIClient.Account {
  func resendOTP(email: String) async throws {
    print("[App:AccountAPI] Resending OTP")
    try await sendOTP(email: email)
  }
}
