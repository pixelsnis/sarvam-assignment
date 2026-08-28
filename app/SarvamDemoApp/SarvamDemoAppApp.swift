//
//  SarvamDemoAppApp.swift
//  SarvamDemoApp
//
//  Created by Aneesh on 27/08/26.
//

import SwiftUI

@main
struct SarvamDemoAppApp: App {
  @State private var auth = Auth.shared

  var body: some Scene {
    WindowGroup {
      ContentView()
        .environment(auth)
        .task {
          auth.start()
        }
    }
  }
}
