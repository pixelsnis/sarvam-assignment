// Auth+Session: UI and service logic for this feature.
import Foundation

// Defines Auth.
extension Auth {
  // Handles refreshSession.
  func refreshSession() async {
    print("[App:Auth] Refreshing session")
    guard !isRefreshing else { return }

    isRefreshing = true
    defer { isRefreshing = false }

    do {
      let authSession = try await apiClient.authAPI.getSession()
      apply(authSession)
      clearError()
    } catch let error as APIClient.APIError where error.statusCode == 401 {
      apply(nil)
      markLoggedOut()
      record(error: error)
    } catch {
      // Keep a known session during transient network failures. If the
      // initial session is unknown, leave it unknown until it can be checked.
      record(error: error)
    }
  }

  // Handles signOut.
  func signOut() async throws {
    print("[App:Auth] Signing out")
    setLoading(true)
    defer { setLoading(false) }

    do {
      try await apiClient.authAPI.signOut()
      apply(nil)
      markLoggedOut()
      clearError()
    } catch {
      record(error: error)
      throw error
    }
  }
}
