import Foundation

extension APIClient {
  struct User: Codable, Equatable, Identifiable {
    let id: String
    let name: String
    let email: String
    let emailVerified: Bool
    let image: String?
    let createdAt: Date
    let updatedAt: Date
  }

  struct Session: Codable, Equatable {
    let id: String
    let expiresAt: Date
    let token: String
    let createdAt: Date
    let updatedAt: Date
    let ipAddress: String?
    let userAgent: String?
  }

  struct AuthSession: Codable, Equatable {
    let session: Session
    let user: User
  }
}
