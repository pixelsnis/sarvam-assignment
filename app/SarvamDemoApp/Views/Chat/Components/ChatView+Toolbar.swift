import SwiftUI

extension ChatView {
  struct Toolbar: ToolbarContent {
    @Environment(ViewModel.self) private var viewModel

    var body: some ToolbarContent {
      ToolbarItem(placement: .topBarLeading) {
        Button("Sidebar", systemImage: "sidebar.left") {
          
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
