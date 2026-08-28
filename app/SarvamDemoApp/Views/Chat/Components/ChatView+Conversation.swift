// ChatView+Conversation: UI and service logic for this feature.
//
//  ChatView+Conversation.swift
//  SarvamDemoApp
//
//  Created by Aneesh on 28/08/26.
//

import SwiftUI

// Defines ChatView.
extension ChatView {
  // Defines Conversation.
  struct Conversation: View {
    @Environment(ViewModel.self) private var viewModel
    @State private var scrollPosition = ScrollPosition(edge: .bottom)
    
    var body: some View {
      ScrollView(.vertical) {
        LazyVStack(alignment: .leading, spacing: 16) {
          ForEach(viewModel.messages) { message in
            switch message {
            case .user(let message):
              UserMessageView(message: message)
                .transition(.push(from: .bottom))
            case .assistant(let message):
              AssistantMessageView(message: message)
            }
          }

          if !viewModel.streamChunks.isEmpty {
            StreamingAssistantMessageView(message: viewModel.streamingAssistantMessage)
              .id("streaming-assistant")
              .transition(.push(from: .bottom))
          }

          Color.clear
            .frame(height: 1)
            .id("conversation-bottom")
        }
        .padding(.horizontal)
        .padding(.top)
        .padding(.bottom, 120)
        .scrollTargetLayout()
        .animation(.smooth(duration: 0.22), value: viewModel.messages)
        .animation(.smooth(duration: 0.18), value: viewModel.streamChunks)
      }
      .scrollPosition($scrollPosition)
      .onAppear { scrollPosition.scrollTo(edge: .bottom) }
      .onChange(of: viewModel.scrollRevision) {
        withAnimation(.smooth) { scrollPosition.scrollTo(edge: .bottom) }
      }
    }
  }
}
