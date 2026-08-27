//
//  SetupView+LogoLarge.swift
//  SarvamDemoApp
//
//  Created by Aneesh on 27/08/26.
//

import SwiftUI

extension SetupView {
  struct LogoLarge: View {
    var body: some View {
      Group {
        Spacer()
        
        Image("Sarvam Logo Color")
          .resizable()
          .scaledToFit()
          .frame(height: 100)
        
        Spacer()
        
        Spacer()
      }
    }
  }
}

#Preview {
  VStack {
    SetupView.LogoLarge()
  }
}
