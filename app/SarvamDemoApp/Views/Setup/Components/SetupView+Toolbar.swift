// SetupView+Toolbar: UI and service logic for this feature.
//
//  SetupView+Toolbar.swift
//  SarvamDemoApp
//
//  Created by Aneesh on 27/08/26.
//

import SwiftUI

// Defines SetupView.
extension SetupView {
  // Defines Toolbar.
  struct Toolbar: ToolbarContent {
    @Environment(ViewModel.self) private var viewModel
    
    var body: some ToolbarContent {
      if viewModel.stage != .intro {
        ToolbarItem(placement: .cancellationAction) {
          Button("Back", systemImage: "chevron.left") {
            viewModel.goBack()
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
