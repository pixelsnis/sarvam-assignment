//
//  SetupView+InputField.swift
//  SarvamDemoApp
//
//  Created by Aneesh on 27/08/26.
//

import SwiftUI

extension SetupView {
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
  
  private struct EmailOrPhoneField: View {
    let namespace: Namespace.ID
    
    @Environment(ViewModel.self) private var viewModel
    
    @FocusState private var focused
    
    private var isButtonVisible: Bool {
      viewModel.inputFieldFocused || !viewModel.emailOrPhone.isEmpty
    }
    
    private var submitEnabled: Bool {
      if case .unknown = viewModel.inputContentType {
        return false
      }
      
      return true
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
          PromptBarActionButton("Next", systemImage: "arrow.right") {
            
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
  
  private struct OTPField: View {
    let namespace: Namespace.ID
    
    @Environment(ViewModel.self) private var viewModel
    
    var body: some View {
      @Bindable var viewModel = viewModel
      
      HStack(spacing: 10) {
        TextField("XXX-XXX", text: $viewModel.otp)
          .keyboardType(.numberPad)
          .fontDesign(.monospaced)
          .tracking(20)
          .fontWeight(.semibold)
          .multilineTextAlignment(.center)
          .frame(height: 54)
          .glassEffect(.regular, in: .capsule)
          .contentShape(.capsule)
          .glassEffectID("OTPField", in: namespace)
        
        Menu {
          Button("Resend OTP") {
            
          }
        } label: {
          Image(systemName: "arrow.clockwise")
            .font(.title3.weight(.semibold))
            .frame(width: 54, height: 54)
            .glassEffect(.regular.interactive(), in: .circle)
            .contentShape(.circle)
        }
        .buttonStyle(.plain)
      }
    }
  }
  
  private struct NameField: View {
    let namespace: Namespace.ID
    
    @Environment(ViewModel.self) private var viewModel
    
    var body: some View {
      @Bindable var viewModel = viewModel
      
      HStack {
        TextField("Type here", text: $viewModel.name)
        
        PromptBarActionButton("Next", systemImage: "arrow.right") {
          
        }
        .disabled(!viewModel.isNameValid)
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
