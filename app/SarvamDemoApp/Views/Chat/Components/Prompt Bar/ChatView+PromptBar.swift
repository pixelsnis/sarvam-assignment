import SwiftUI

extension ChatView {
  struct PromptBar: View {
    @Environment(ViewModel.self) private var viewModel
    
    var body: some View {
      @Bindable var viewModel = viewModel
      
      VStack(spacing: 0) {
        TextField("Ask Sarvam", text: $viewModel.text, axis: .vertical)
          .padding(.horizontal, 16)
          .padding(.vertical, 12)
        
        ActionBar()
      }
      .glassEffect(.regular, in: .rect(cornerRadius: 26))
    }
  }
  
  private struct ActionBar: View {
    var body: some View {
      HStack(spacing: 16) {
        Button("Add attachment", systemImage: "plus") {
          
        }
        
        Button("Dictate", systemImage: "mic") {
          
        }
        
        Spacer()
        
        PromptBarActionButton("Send", systemImage: "arrow.up") {
        }
      }
      .buttonStyle(.plain)
      .labelStyle(.iconOnly)
      .padding(.leading, 16)
      .padding(.bottom, 8)
      .padding(.trailing, 8)
    }
  }
}

#Preview {
  @Previewable @State var viewModel = ChatView.ViewModel()
  
  ChatView.PromptBar()
    .padding()
    .environment(viewModel)
}
