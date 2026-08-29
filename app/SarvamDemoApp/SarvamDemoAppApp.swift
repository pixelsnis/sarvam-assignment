// SarvamDemoAppApp: UI and service logic for this feature.
//
//  SarvamDemoAppApp.swift
//  SarvamDemoApp
//
//  Created by Aneesh on 27/08/26.
//

import SwiftUI

@main
// Defines SarvamDemoAppApp.
struct SarvamDemoAppApp: App {
  @State private var auth = Auth.shared
  @State private var endpointDiscovery: APIEndpointDiscovery?

  init() {
    BrandFontRegistrar.registerFonts()
  }

  var body: some Scene {
    WindowGroup {
      ContentView()
        .font(.brandBody)
        .environment(auth)
        .task {
          let discovery = APIEndpointDiscovery { _ in }
          endpointDiscovery = discovery
          discovery.start()
        }
        .onDisappear {
          endpointDiscovery?.stop()
        }
        .task {
          auth.start()
        }
    }
  }
}
