//
//  ContentView.swift
//  SarvamDemoApp
//
//  Created by Aneesh on 27/08/26.
//

import SwiftUI

struct ContentView: View {
  @AppStorage("isLoggedIn") private var isLoggedIn = false

  var body: some View {
    NavigationStack {
      ZStack {
        if isLoggedIn {
          ChatView()
            .transition(.push(from: .bottom).combined(with: .blurReplace))
        } else {
          SetupView()
            .transition(.push(from: .top).combined(with: .blurReplace))
        }
      }
      .animation(.smooth(duration: 0.45), value: isLoggedIn)
    }
  }
}

#Preview {
  ContentView()
}
