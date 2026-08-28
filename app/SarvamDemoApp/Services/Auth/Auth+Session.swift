import Foundation

extension Auth {
  func refreshSession() async {
    guard !isRefreshing else { return }

    isRefreshing = true
    defer { isRefreshing = false }

    do {
      let authSession = try await apiClient.authAPI.getSession()
      apply(authSession)
      clearError()
    } catch let error as APIClient.APIError where error.statusCode == 401 {
      apply(nil)
      record(error: error)
    } catch {
      // Keep a known session during transient network failures. If the
      // initial session is unknown, leave it unknown until it can be checked.
      record(error: error)
    }
  }

  func signOut() async throws {
    setLoading(true)
    defer { setLoading(false) }

    do {
      try await apiClient.authAPI.signOut()
      apply(nil)
      clearError()
    } catch {
      record(error: error)
      throw error
    }
  }
}
