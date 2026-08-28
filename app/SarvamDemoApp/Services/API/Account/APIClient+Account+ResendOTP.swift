import Foundation

extension APIClient.Account {
  func resendOTP(email: String) async throws {
    try await sendOTP(email: email)
  }
}
