// APIClient+Models: UI and service logic for this feature.
import Foundation

// Defines APIClient.
extension APIClient {
  // Defines EmailOTPRequest.
  struct EmailOTPRequest: Encodable {
    let email: String
    let type: String
  }

  // Defines User.
  struct User: Codable, Equatable, Identifiable {
    let id: String
    let name: String
    let email: String
    let emailVerified: Bool
    let image: String?
    let createdAt: Date
    let updatedAt: Date
  }

  // Defines Session.
  struct Session: Codable, Equatable {
    let id: String
    let expiresAt: Date
    let token: String
    let createdAt: Date
    let updatedAt: Date
    let ipAddress: String?
    let userAgent: String?
  }

  // Defines AuthSession.
  struct AuthSession: Codable, Equatable {
    let session: Session
    let user: User
  }

  // Defines TranscriptionResponse.
  struct TranscriptionResponse: Decodable, Equatable, Sendable {
    let transcript: String
  }

  // Defines EmailOTPAuthenticationResponse.
  struct EmailOTPAuthenticationResponse: Decodable {
    let token: String?
    let user: User
  }
}
