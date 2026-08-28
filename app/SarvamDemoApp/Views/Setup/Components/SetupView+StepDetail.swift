//
//  SetupView+StepDetail.swift
//  SarvamDemoApp
//
//  Created by Aneesh on 27/08/26.
//

import SwiftUI

extension SetupView {
  struct StepDetail: View {
    @Environment(ViewModel.self) private var viewModel
    
    private var title: String {
      switch viewModel.stage {
      case .intro:
        return "" // Not supposed to be reachable anyway
      case .otpInput:
        return "We've sent you an OTP"
      case .createAccount:
        return "What should we call you?"
      }
    }
    
    var body: some View {
      VStack(alignment: .leading, spacing: 10) {
        Image(.sarvamLogoMonochrome)
          .resizable()
          .scaledToFit()
          .frame(height: 32)
      
        VStack(alignment: .leading, spacing: 8) {
          Text(title)
            .contentTransition(.numericText())
            // TODO: Update this to Season Mix
            .font(.title3.weight(.medium))
          
          if let error = viewModel.error {
            Label(error, systemImage: "xmark")
              .font(.subheadline)
              .foregroundStyle(.red)
              .transition(.push(from: .bottom))
          } else {
            switch viewModel.stage {
            case .otpInput:
              InboxSubheader()
                .transition(.push(from: .bottom))
            case .createAccount:
              Text("Full name would be great, but a nickname works!")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .transition(.push(from: .bottom))
            default:
              EmptyView()
            }
          }
        }
        .animation(.default, value: viewModel.stage)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }
  
  private struct InboxSubheader: View {
    @Environment(ViewModel.self) private var viewModel
    @Environment(\.openURL) private var openURL

    var body: some View {
      HStack(spacing: 8) {
        Text("Check your inbox")
          .foregroundStyle(.secondary)
        
        if case .email = viewModel.inputContentType {
          Button {
            guard let mailURL = URL(string: "mailto:") else { return }
            openURL(mailURL)
          } label: {
            Text("Open \(Text(Image(systemName: "arrow.up.right")))")
          }
        }
      }
      .font(.subheadline)
    }
  }
}

#Preview {
  @Previewable @State var viewModel = SetupView.ViewModel()
  
  SetupView.StepDetail()
    .environment(viewModel)
    .onAppear {
      viewModel.stage = .otpInput
    }
}
