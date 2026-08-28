import SwiftUI

extension ChatView {
  struct Toolbar: ToolbarContent {
    var body: some ToolbarContent {
      ToolbarItem(placement: .topBarLeading) {
        Button("Sidebar", systemImage: "sidebar.left") {
          
        }
      }
      
      ToolbarItem(placement: .topBarTrailing) {
        Button("New Chat", systemImage: "square.and.pencil") {
          
        }
      }
    }
  }
}

#Preview {
  NavigationStack {
    VStack {
    }
    .toolbar {
      ChatView.Toolbar()
    }
  }
}
