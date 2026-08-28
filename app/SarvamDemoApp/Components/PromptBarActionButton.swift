// PromptBarActionButton: UI and service logic for this feature.
//
//  PromptBarActionButton.swift
//  SarvamDemoApp
//
//  Created by Aneesh on 27/08/26.
//

import SwiftUI

// Defines PromptBarActionButton.
struct PromptBarActionButton: View {
  let titleKey: String
  let systemImage: String
  let loading: Binding<Bool>
  let gradient: [Gradient.Stop]
  let action: () async -> Void

  init(_ titleKey: String, systemImage: String, loading: Binding<Bool> = .constant(false), gradient: [Gradient.Stop] = [.init(color: .init(hex: "B81514"), location: 0.0), .init(color: .init(hex: "FFCB79"), location: 1.0)], action: @escaping () async -> Void) {
    self.titleKey = titleKey
    self.systemImage = systemImage
    self.loading = loading
    self.gradient = gradient
    self.action = action
  }
  
  @Environment(\.isEnabled) private var isEnabled
  
  var body: some View {
    Button(action: onPress) {
      VStack {
        if isEnabled {
          buttonContent()
            .foregroundStyle(.white)
            .tint(.secondary)
            .frame(width: 56, height: 40)
            .background(LinearGradient(stops: gradient, startPoint: .top, endPoint: .bottom))
            .clipShape(.capsule)
            .glassEffect(.regular.interactive(), in: .capsule)
            .contentShape(.capsule)
        } else {
          buttonContent()
            .foregroundStyle(.secondary)
            .tint(.secondary)
            .frame(width: 56, height: 40)
            .background(.quaternary)
            .clipShape(.capsule)
            .contentShape(.capsule)
        }
      }
    }
    .buttonStyle(.plain)
    .disabled(!isEnabled)
    .animation(.default, value: isEnabled)
  }
  
  // Handles onPress.
  private func onPress() {
    guard !loading.wrappedValue, isEnabled else { return }
    
    Task {
      print("[App:PromptButton] Action started")
      loading.wrappedValue = true
      defer { loading.wrappedValue = false }
      await action()
      print("[App:PromptButton] Action finished")
    }
  }

  @ViewBuilder private func buttonContent() -> some View {
    ZStack {
      if loading.wrappedValue {
        ProgressView()
          .frame(height: 24)
          .transition(.blurReplace)
      } else {
        Label(titleKey, systemImage: systemImage)
          .transition(.blurReplace)
      }
    }
    .animation(.default, value: loading.wrappedValue)
    .labelStyle(.iconOnly)
    .font(.headline)
  }
}

#Preview {
  PromptBarActionButton("Send", systemImage: "arrow.right", loading: .constant(false)) {
    print("[Preview:PromptButton] Action invoked")
  }
}
