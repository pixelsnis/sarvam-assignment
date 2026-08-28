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
    Group {
      if isLoggedIn {
        ChatView()
      } else {
        SetupView()
      }
    }
  }
}

#Preview {
  ContentView()
}
