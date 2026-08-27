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
    }
  }
}

#Preview {
  @Previewable @State var viewModel = SetupView.ViewModel()
  
  SetupView.InputField()
    .environment(viewModel)
}
