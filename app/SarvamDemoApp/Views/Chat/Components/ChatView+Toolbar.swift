// ChatView+Toolbar: UI and service logic for this feature.
import SwiftUI

// Defines ChatView.
extension ChatView {
  // Defines Toolbar.
  struct Toolbar: ToolbarContent {
    @Environment(ViewModel.self) private var viewModel

    var body: some ToolbarContent {
      ToolbarItem(placement: .topBarLeading) {
        Button("Sidebar", systemImage: "sidebar.left") {
          // NOTE: No-op for now
        }
      }
      
      ToolbarItem(placement: .topBarTrailing) {
        Button("New Chat", systemImage: "square.and.pencil") {
          viewModel.startNewChat()
        }
      }
    }
  }
}

#Preview {
  @Previewable @State var viewModel = ChatView.ViewModel()

  NavigationStack {
    VStack {
    }
    .toolbar {
      ChatView.Toolbar()
    }
  }
  .environment(viewModel)
}
