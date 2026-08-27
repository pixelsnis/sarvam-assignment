//
//  PromptBarActionButton.swift
//  SarvamDemoApp
//
//  Created by Aneesh on 27/08/26.
//

import SwiftUI

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
      Label(titleKey, systemImage: systemImage)
        .labelStyle(.iconOnly)
        .font(.headline)
        .foregroundStyle(isEnabled ? .white : .secondary)
        .frame(width: 56, height: 40)
        .background {
          LinearGradient(stops: gradient, startPoint: .top, endPoint: .bottom)
            .opacity(isEnabled ? 1 : 0.0)
        }
        .clipShape(.capsule)
        .glassEffect(.regular.interactive(), in: .capsule)
        .contentShape(.capsule)
    }
    .buttonStyle(.plain)
    .disabled(!isEnabled)
    .animation(.default, value: isEnabled)
  }
  
  private func onPress() {
    guard !loading.wrappedValue, isEnabled else { return }
    
    Task {
      loading.wrappedValue = true
      defer { loading.wrappedValue = false }
      await action()
    }
  }
}

#Preview {
  PromptBarActionButton("Send", systemImage: "arrow.right") {
    print("Test")
  }
}
