// UIApplicationExtensions: UI and service logic for this feature.
import UIKit

// Defines UIApplication.
extension UIApplication {
  // Handles dismissKeyboard.
  func dismissKeyboard() {
    sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
  }
}
