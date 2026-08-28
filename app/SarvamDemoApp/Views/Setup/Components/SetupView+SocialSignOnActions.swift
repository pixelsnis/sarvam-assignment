// SetupView+SocialSignOnActions: UI and service logic for this feature.
//
//  SetupView+SocialSignOnActions.swift
//  SarvamDemoApp
//
//  Created by Aneesh on 27/08/26.
//

import SwiftUI

// Defines SetupView.
extension SetupView {
  // Defines SocialSignOnActions.
  struct SocialSignOnActions: View {
    @Environment(ViewModel.self) private var viewModel
    
    var body: some View {
      VStack(spacing: 10) {
        GoogleSignInButton()
        AppleSignInButton()
      }
    }
  }
  
  // Defines GoogleSignInButton.
  private struct GoogleSignInButton: View {
    @Environment(ViewModel.self) private var viewModel
    
    var body: some View {
      Button {
        
      } label: {
        HStack(spacing: 8) {
          Image("Google Logo")
            .resizable()
            .scaledToFit()
            .frame(height: 20)
          Text("Sign in with Google")
        }
        .font(.headline)
        .foregroundStyle(Color(uiColor: .systemBackground))
        .padding(16)
        .frame(maxWidth: .infinity)
        .glassEffect(.regular.tint(Color(uiColor: .label)).interactive(), in: .capsule)
        .contentShape(.capsule)
      }
      .buttonStyle(.plain)
    }
  }
  
  // Defines AppleSignInButton.
  private struct AppleSignInButton: View {
    @Environment(ViewModel.self) private var viewModel
    
    var body: some View {
      Button {
        
      } label: {
        Label("Sign in with Apple", systemImage: "applelogo")
          .font(.headline)
          .foregroundStyle(Color(uiColor: .label))
          .padding(16)
          .frame(maxWidth: .infinity)
          .glassEffect(.regular.interactive(), in: .capsule)
          .contentShape(.capsule)
      }
      .buttonStyle(.plain)
    }
  }
}

#Preview {
  @Previewable @State var viewModel = SetupView.ViewModel()
  
  SetupView.SocialSignOnActions()
    .environment(viewModel)
}
