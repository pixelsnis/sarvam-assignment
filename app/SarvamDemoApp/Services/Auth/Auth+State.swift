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

  var isLoggedIn: Bool {
    UserDefaults.standard.bool(forKey: "isLoggedIn")
  }

  func markLoggedIn() {
    UserDefaults.standard.set(true, forKey: "isLoggedIn")
  }

  func markLoggedOut() {
    UserDefaults.standard.set(false, forKey: "isLoggedIn")
  }
}
