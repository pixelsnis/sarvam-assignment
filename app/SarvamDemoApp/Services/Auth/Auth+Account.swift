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
    otp: String,
    name: String? = nil
  ) async throws {
    setLoading(true)
    defer { setLoading(false) }

    do {
      let authSession = try await apiClient.accountAPI.verifyOTP(
        email: email,
        otp: otp,
        name: name
      )
      apply(authSession)
      clearError()
    } catch {
      record(error: error)
      throw error
    }
  }
}
