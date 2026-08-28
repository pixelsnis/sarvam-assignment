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
    print("[App:Auth] User marked logged in")
    UserDefaults.standard.set(true, forKey: "isLoggedIn")
  }

  func markLoggedOut() {
    print("[App:Auth] User marked logged out")
    UserDefaults.standard.set(false, forKey: "isLoggedIn")
  }
}
