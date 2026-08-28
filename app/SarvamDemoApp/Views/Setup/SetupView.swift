// SetupView: UI and service logic for this feature.
import SwiftUI

// Defines SetupView.
struct SetupView: View {
  @State private var vm = ViewModel()
  @Namespace private var logoNamespace

  private var showAllActions: Bool {
    !vm.inputFieldFocused && vm.emailOrPhone.isEmpty
  }

  var body: some View {
    VStack(spacing: 16) {
      if vm.stage != .intro {
        Spacer()
      }

      if vm.stage == .intro {
        Self.LogoLarge(namespace: logoNamespace)
      } else {
        Self.StepDetail(namespace: logoNamespace)
      }

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

      if vm.stage == .intro {
        Text(
          "By signing up, you agree to the\n[Terms of Service](https://www.sarvam.ai/terms-of-service) and [Privacy Policy](https://www.sarvam.ai/privacy-policy)."
        )
        .font(.subheadline)
        .multilineTextAlignment(.center)
        .tint(.primary)
        .foregroundStyle(.secondary)
        .transition(.blurReplace)
      }
    }
    .animation(.smooth(duration: 0.4), value: showAllActions)
    .animation(.smooth(duration: 0.45), value: vm.stage)
    .scrollDismissesKeyboard(.interactively)
    .padding()
    .toolbar {
      Self.Toolbar()
    }
    .environment(vm)
  }
}

#Preview {
  SetupView()
}
