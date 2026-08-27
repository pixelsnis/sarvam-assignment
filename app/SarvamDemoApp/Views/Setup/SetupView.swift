import SwiftUI

struct SetupView: View {
  @State private var vm = ViewModel()
  
  private var showAllActions: Bool {
    !vm.inputFieldFocused && vm.emailOrPhone.isEmpty
  }
  
  var body: some View {
    VStack(spacing: 16) {
      Self.LogoLarge()
      
      if showAllActions {
        VStack(spacing: 16) {
          Self.SocialSignOnActions()

          Text("or")
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .transition(.blurReplace)
      }
      
      Self.InputField()

      Text("By signing up, you agree to the\n[Terms of Service](https://www.sarvam.ai/terms-of-service) and [Privacy Policy](https://www.sarvam.ai/privacy-policy).")
        .font(.subheadline)
        .multilineTextAlignment(.center)
        .tint(.primary)
        .foregroundStyle(.secondary)
    }
    .animation(.default, value: showAllActions)
    .scrollDismissesKeyboard(.interactively)
    .padding()
    .environment(vm)
  }
}

#Preview {
  SetupView()
}
