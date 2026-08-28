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
  @State private var endpointDiscovery: APIEndpointDiscovery?

  var body: some Scene {
    WindowGroup {
      ContentView()
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
