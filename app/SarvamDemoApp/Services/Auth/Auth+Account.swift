import Foundation

extension Auth {
  func requestOTP(email: String) async throws {
    setLoading(true)
    defer { setLoading(false) }

    do {
      try await apiClient.accountAPI.sendOTP(email: email)
      clearError()
    } catch {
      record(error: error)
      throw error
    }
  }

  func resendOTP(email: String) async throws {
    setLoading(true)
    defer { setLoading(false) }

    do {
      try await apiClient.accountAPI.resendOTP(email: email)
      clearError()
    } catch {
      record(error: error)
      throw error
    }
  }

  func verifyOTP(
    email: String,
    otp: String
  ) async throws {
    setLoading(true)
    defer { setLoading(false) }

    do {
      _ = try await apiClient.accountAPI.verifyOTP(
        email: email,
        otp: otp
      )
      guard let authSession = try await apiClient.authAPI.getSession() else {
        throw APIClient.APIError.invalidResponse
      }
      apply(authSession)
      clearError()
    } catch {
      record(error: error)
      throw error
    }
  }

  func updateUser(name: String) async throws {
    setLoading(true)
    defer { setLoading(false) }

    do {
      try await apiClient.accountAPI.updateUser(name: name)
      let authSession = try await apiClient.authAPI.getSession()
      apply(authSession)
      clearError()
    } catch {
      record(error: error)
      throw error
    }
  }
}
