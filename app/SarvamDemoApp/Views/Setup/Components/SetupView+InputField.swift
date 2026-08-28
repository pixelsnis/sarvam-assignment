// SetupView+InputField: UI and service logic for this feature.
//
//  SetupView+InputField.swift
//  SarvamDemoApp
//
//  Created by Aneesh on 27/08/26.
//

import SwiftUI

// Defines SetupView.
extension SetupView {
  // Defines InputField.
  struct InputField: View {
    @Environment(ViewModel.self) private var viewModel
    
    @Namespace private var namespace
    
    var body: some View {
      GlassEffectContainer(spacing: 10) {
        switch viewModel.stage {
        case .intro:
          EmailOrPhoneField(namespace: namespace)
        case .otpInput:
          OTPField(namespace: namespace)
        case .createAccount:
          NameField(namespace: namespace)
        }
      }
      .animation(.default, value: viewModel.stage)
    }
  }
  
  // Defines EmailOrPhoneField.
  private struct EmailOrPhoneField: View {
    let namespace: Namespace.ID
    
    @Environment(ViewModel.self) private var viewModel
    
    @FocusState private var focused
    
    private var isButtonVisible: Bool {
      viewModel.inputFieldFocused || !viewModel.emailOrPhone.isEmpty
    }
    
    private var submitEnabled: Bool {
      switch viewModel.inputContentType {
      case .email:
        return true
      case .phone, .unknown:
        return false
      }
    }
    
    var body: some View {
      @Bindable var viewModel = viewModel
      
      HStack {
        TextField("Email or phone number", text: $viewModel.emailOrPhone)
          .focused($focused)
          .onChange(of: focused) {
            viewModel.inputFieldFocused = $1
          }
          .onChange(of: viewModel.inputFieldFocused) {
            self.focused = $1
          }
        
        if isButtonVisible {
          PromptBarActionButton("Next", systemImage: "arrow.right", loading: $viewModel.isLoading) {
            await viewModel.submitEmail()
          }
          .disabled(!submitEnabled)
          .transition(.blurReplace)
        }
      }
      .animation(.default, value: isButtonVisible)
      .padding(.leading, 20)
      .padding(.trailing, 8)
      .frame(height: 54)
      .glassEffect(.regular, in: .capsule)
      .glassEffectID("EmailOrPhoneField", in: namespace)
    }
  }
  
  // Defines OTPField.
  private struct OTPField: View {
    let namespace: Namespace.ID
    
    @Environment(ViewModel.self) private var viewModel
    @FocusState private var focused: Bool
    
    var body: some View {
      @Bindable var viewModel = viewModel

      HStack(spacing: 10) {
        TextField("XXX-XXX", text: $viewModel.otp)
          .focused($focused)
          .onChange(of: viewModel.otp) { _, value in
            viewModel.updateOTP(value)
          }
          .keyboardType(.numberPad)
          .fontDesign(.monospaced)
          .tracking(20)
          .fontWeight(.semibold)
          .foregroundStyle(viewModel.error == "Invalid OTP." ? .red : .primary)
          .multilineTextAlignment(.center)
          .frame(height: 54)
          .glassEffect(.regular, in: .capsule)
          .contentShape(.capsule)
          .glassEffectID("OTPField", in: namespace)
        
        Menu {
          Button("Resend OTP") {
            Task { await viewModel.resendOTP() }
          }
          .disabled(viewModel.resendSecondsRemaining > 0 || viewModel.isLoading)
        } label: {
          Image(systemName: "arrow.clockwise")
            .font(.title3.weight(.semibold))
            .frame(width: 54, height: 54)
            .glassEffect(.regular.interactive(), in: .circle)
            .contentShape(.circle)
        }
        .buttonStyle(.plain)
      }
      .task {
        await Task.yield()
        focused = true
      }
    }
  }
  
  // Defines NameField.
  private struct NameField: View {
    let namespace: Namespace.ID
    
    @Environment(ViewModel.self) private var viewModel
    @FocusState private var focused: Bool
    
    var body: some View {
      @Bindable var viewModel = viewModel
      
      HStack {
        TextField("Type here", text: $viewModel.name)
          .focused($focused)
        
        PromptBarActionButton("Next", systemImage: "arrow.right", loading: $viewModel.isLoading) {
          await viewModel.submitName()
        }
        .disabled(viewModel.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
      }
      .task {
        await Task.yield()
        focused = true
      }
      .padding(.leading, 20)
      .padding(.trailing, 8)
      .frame(height: 54)
      .glassEffect(.regular, in: .capsule)
      .glassEffectID("NameField", in: namespace)
    }
  }
}

#Preview {
  @Previewable @State var viewModel = SetupView.ViewModel()
  
  SetupView.InputField()
    .environment(viewModel)
}
