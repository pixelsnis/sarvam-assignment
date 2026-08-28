import Foundation

extension Auth {
  func signUp(
    name: String,
    email: String,
    password: String
  ) async throws {
    setLoading(true)
    defer { setLoading(false) }

    do {
      let authSession = try await apiClient.accountAPI.signUp(
        name: name,
        email: email,
        password: password
      )
      apply(authSession)
      clearError()
    } catch {
      record(error: error)
      throw error
    }
  }

  func signIn(email: String, password: String) async throws {
    setLoading(true)
    defer { setLoading(false) }

    do {
      let authSession = try await apiClient.accountAPI.signIn(
        email: email,
        password: password
      )
      apply(authSession)
      clearError()
    } catch {
      record(error: error)
      throw error
    }
  }
}
