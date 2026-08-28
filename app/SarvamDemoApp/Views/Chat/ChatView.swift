//
//  ChatView.swift
//  SarvamDemoApp
//
//  Created by Aneesh on 28/08/26.
//

import SwiftUI

struct ChatView: View {
  @State private var viewModel = ViewModel()

  var body: some View {
    VStack {
      sarvam105BGhost()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .overlay(alignment: .bottom) {
      Self.PromptBar()
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
