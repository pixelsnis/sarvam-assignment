// SetupView+ViewModel: UI and service logic for this feature.
import Foundation

// Defines SetupView.
extension SetupView {
  // Defines SetupStage.
  enum SetupStage {
    case intro, otpInput, createAccount
  }

  // Defines PhoneNumber.
  struct PhoneNumber {
    let countryCode: Int
    let phoneNumber: Int
  }
  
  // Defines InputContentType.
  enum InputContentType {
    case email
    case phone(number: PhoneNumber)
    case unknown
  }
  
  @MainActor
  @Observable
  final class ViewModel {
    let auth: Auth

    private var resendTask: Task<Void, Never>?
    private var otpErrorTask: Task<Void, Never>?

    // MARK: Input
    
    var emailOrPhone: String = ""
    var otp: String = ""
    var name: String = ""
    
    // MARK: State
    
    var stage: SetupStage = .intro
    var inputFieldFocused = false
    var error: String?
    var isLoading = false
    var resendSecondsRemaining = 0

    init(auth: Auth? = nil) {
      self.auth = auth ?? Auth.shared
    }
    
    // MARK: Computed Properties
    
    var inputContentType: InputContentType {
      let input = emailOrPhone.trimmingCharacters(in: .whitespacesAndNewlines)

      let emailPattern = #"^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$"#
      if input.range(of: emailPattern, options: [.regularExpression, .caseInsensitive]) != nil {
        return .email
      }

      let phonePattern = #"^\+?[0-9][0-9 ()-]{5,}[0-9]$"#
      let phoneDigits = input.filter(\.isNumber)
      if phoneDigits.count >= 7 && phoneDigits.count <= 15,
         input.range(of: phonePattern, options: .regularExpression) != nil {
        let hasCountryCode = input.first == "+"
        let countryCodeLength = hasCountryCode ? min(3, phoneDigits.count - 1) : 0
        let countryCode = hasCountryCode
          ? Int(phoneDigits.prefix(countryCodeLength)) ?? 0
          : 0
        let numberStartIndex = phoneDigits.index(phoneDigits.startIndex, offsetBy: countryCodeLength)
        let phoneNumber = Int(phoneDigits[numberStartIndex...]) ?? 0

        return .phone(number: PhoneNumber(countryCode: countryCode, phoneNumber: phoneNumber))
      }

      return .unknown
    }

    var isNameValid: Bool {
      let normalizedName = name.precomposedStringWithCanonicalMapping
      let hasLetter = normalizedName.unicodeScalars.contains {
        CharacterSet.letters.contains($0)
      }

      return hasLetter && normalizedName.unicodeScalars.allSatisfy {
        CharacterSet.letters.contains($0)
          || CharacterSet.nonBaseCharacters.contains($0)
          || CharacterSet.whitespaces.contains($0)
      }
    }

    var normalizedEmail: String? {
      guard case .email = inputContentType else { return nil }
      return emailOrPhone.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    // Handles submitEmail.
    func submitEmail() async {
      // 1. Validate and normalize the email before requesting an OTP.
      print("[App:SetupVM] Submitting email")
      guard let email = normalizedEmail else { return }

      await runLoading {
        do {
          try await auth.requestOTP(email: email)
          error = nil
          otp = ""
          stage = .otpInput
          startResendCooldown()
        } catch {
          print("[App:SetupVM] Email submission failed")
          self.error = error.localizedDescription
        }
      }
    }

    // Handles resendOTP.
    func resendOTP() async {
      // 1. Enforce the cooldown, then request a replacement OTP.
      print("[App:SetupVM] Resending OTP")
      guard let email = normalizedEmail, resendSecondsRemaining == 0, !isLoading else { return }

      await runLoading {
        do {
          try await auth.resendOTP(email: email)
          error = nil
          otp = ""
          startResendCooldown()
        } catch {
          print("[App:SetupVM] OTP resend failed")
          self.error = error.localizedDescription
        }
      }
    }

    // Handles updateOTP.
    func updateOTP(_ value: String) {
      let digits = value.filter(\.isNumber)
      otp = String(digits.prefix(6))

      guard otp.count == 6, !isLoading else { return }
      Task { await verifyOTP() }
    }

    // Handles verifyOTP.
    func verifyOTP() async {
      // 1. Verify the code and either finish sign-in or request a name.
      print("[App:SetupVM] Verifying OTP")
      guard let email = normalizedEmail, otp.count == 6, !isLoading else { return }

      await runLoading {
        do {
          try await auth.verifyOTP(email: email, otp: otp)
          error = nil

          if auth.user?.name.isEmpty == true {
            stage = .createAccount
          } else {
            auth.markLoggedIn()
          }
        } catch let apiError as APIClient.APIError where apiError.statusCode == 400 {
          showInvalidOTP()
        } catch {
          print("[App:SetupVM] OTP verification failed")
          self.error = error.localizedDescription
        }
      }
    }

    // Handles submitName.
    func submitName() async {
      // 1. Validate the name, save it, and mark the user as logged in.
      print("[App:SetupVM] Submitting name")
      guard isNameValid else {
        error = "Alphabets and accents only."
        return
      }

      await runLoading {
        do {
          try await auth.updateUser(name: name.trimmingCharacters(in: .whitespacesAndNewlines))
          error = nil
          auth.markLoggedIn()
        } catch {
          print("[App:SetupVM] Name submission failed")
          self.error = error.localizedDescription
        }
      }
    }

    // Handles goBack.
    func goBack() {
      print("[App:SetupVM] Navigating back")
      switch stage {
      case .intro:
        break
      case .otpInput, .createAccount:
        stage = .intro
        otp = ""
        error = nil
        cancelTasks()
      }
    }

    // Handles runLoading.
    private func runLoading(_ operation: () async -> Void) async {
      isLoading = true
      defer { isLoading = false }
      await operation()
    }

    // Handles showInvalidOTP.
    private func showInvalidOTP() {
      otp = ""
      error = "Invalid OTP."
      otpErrorTask?.cancel()
      otpErrorTask = Task { [weak self] in
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        guard !Task.isCancelled else { return }
        self?.error = nil
      }
    }

    // Handles startResendCooldown.
    private func startResendCooldown() {
      // 1. Cancel the old countdown and publish the remaining seconds.
      resendTask?.cancel()
      resendSecondsRemaining = 30
      resendTask = Task { [weak self] in
        for remaining in stride(from: 29, through: 0, by: -1) {
          try? await Task.sleep(nanoseconds: 1_000_000_000)
          guard !Task.isCancelled else { return }
          self?.resendSecondsRemaining = remaining
        }
      }
    }

    // Handles cancelTasks.
    private func cancelTasks() {
      resendTask?.cancel()
      resendTask = nil
      otpErrorTask?.cancel()
      otpErrorTask = nil
      resendSecondsRemaining = 0
    }

  }
}
