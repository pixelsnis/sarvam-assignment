import Foundation

extension SetupView {
  enum SetupStage {
    case intro, otpInput, createAccount
  }

  struct PhoneNumber {
    let countryCode: Int
    let phoneNumber: Int
  }
  
  enum InputContentType {
    case email
    case phone(number: PhoneNumber)
    case unknown
  }
  
  @Observable
  final class ViewModel {
    // MARK: Input
    
    var emailOrPhone: String = ""
    var otp: String = ""
    var name: String = ""
    
    // MARK: State
    
    var stage: SetupStage = .intro
    var inputFieldFocused = false
    var error: String?
    
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
      let hasAlphanumeric = normalizedName.unicodeScalars.contains {
        CharacterSet.alphanumerics.contains($0)
      }

      return hasAlphanumeric && normalizedName.unicodeScalars.allSatisfy {
        CharacterSet.alphanumerics.contains($0) || CharacterSet.nonBaseCharacters.contains($0)
      }
    }
  }
}
