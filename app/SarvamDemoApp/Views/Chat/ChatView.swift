// ChatView: UI and service logic for this feature.
//
//  ChatView.swift
//  SarvamDemoApp
//
//  Created by Aneesh on 28/08/26.
//

import SwiftUI

// Defines ChatView.
struct ChatView: View {
  @State private var viewModel = ViewModel()

  var body: some View {
    ZStack {
      if viewModel.messages.isEmpty && viewModel.streamChunks.isEmpty {
        sarvam105BGhost()
      } else {
        Conversation()
          .transition(.push(from: .bottom).combined(with: .blurReplace))
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .overlay(alignment: .bottom) {
      VStack(spacing: 8) {
        Self.PromptBar()
        if let error = viewModel.errorMessage {
          HStack(spacing: 8) {
            Text(error).font(.brandCaption).foregroundStyle(.secondary)
            Spacer()
            if viewModel.pendingPrompt != nil {
              Button("Retry") { Task { await viewModel.submit() } }
                .font(.brandCaption)
            }
            Button("Dismiss") { viewModel.dismissError() }
              .font(.brandCaption)
          }
          .padding(.horizontal, 14)
          .padding(.vertical, 8)
          .background(.thinMaterial, in: .capsule)
          .padding(.horizontal)
          .transition(.move(edge: .bottom).combined(with: .opacity))
        }
      }
      .padding()
    }
    .toolbar { Self.Toolbar() }
    .environment(viewModel)
  }
  
  @ViewBuilder private func sarvam105BGhost() -> some View {
    VStack {
      Spacer()
      
      Rectangle()
        .fill(.quinary)
        .frame(width: 128, height: 128)
        .mask {
          Image(.sarvam105B)
            .resizable()
            .scaledToFit()
            .frame(width: 128, height: 128)
        }
      
      Spacer()
      Spacer()
    }
  }
}

#Preview {
  NavigationStack {
    ChatView()
  }
}
