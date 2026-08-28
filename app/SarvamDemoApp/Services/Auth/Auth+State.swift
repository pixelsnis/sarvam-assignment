// Auth+State: UI and service logic for this feature.
import Foundation

// Defines Auth.
extension Auth {
  // Defines Status.
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

  // Handles markLoggedIn.
  func markLoggedIn() {
    print("[App:Auth] User marked logged in")
    UserDefaults.standard.set(true, forKey: "isLoggedIn")
  }

  // Handles markLoggedOut.
  func markLoggedOut() {
    print("[App:Auth] User marked logged out")
    UserDefaults.standard.set(false, forKey: "isLoggedIn")
  }
}
