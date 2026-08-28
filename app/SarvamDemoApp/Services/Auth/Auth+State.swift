import Foundation

extension Auth {
  enum Status: Equatable {
    case unknown
    case authenticated
    case unauthenticated
  }

  var isAuthenticated: Bool {
    status == .authenticated
  }
}
