// SetupView+LogoLarge: UI and service logic for this feature.
//
//  SetupView+LogoLarge.swift
//  SarvamDemoApp
//
//  Created by Aneesh on 27/08/26.
//

import SwiftUI

// Defines SetupView.
extension SetupView {
  // Defines LogoLarge.
  struct LogoLarge: View {
    let namespace: Namespace.ID

    var body: some View {
      Group {
        Spacer()
        
        Image("Sarvam Logo Color")
          .resizable()
          .scaledToFit()
          .frame(height: 100)
          .matchedGeometryEffect(id: "setup-logo", in: namespace)
        
        Spacer()
        
        Spacer()
      }
    }
  }
}

#Preview {
  @Previewable @Namespace var namespace

  VStack {
    SetupView.LogoLarge(namespace: namespace)
  }
}
