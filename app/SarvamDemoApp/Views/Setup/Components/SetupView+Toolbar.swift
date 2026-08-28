//
//  SetupView+Toolbar.swift
//  SarvamDemoApp
//
//  Created by Aneesh on 27/08/26.
//

import SwiftUI

extension SetupView {
  struct Toolbar: ToolbarContent {
    @Environment(ViewModel.self) private var viewModel
    
    var body: some ToolbarContent {
      if viewModel.stage != .intro {
        ToolbarItem(placement: .cancellationAction) {
          Button("Back", systemImage: "chevron.left") {
            
          }
          .labelStyle(.iconOnly)
        }
        
        ToolbarItem(placement: .topBarTrailing) {
          Menu("Support", systemImage: "info.bubble") {
            
          }
          .labelStyle(.iconOnly)
        }
      }
    }
  }
}
