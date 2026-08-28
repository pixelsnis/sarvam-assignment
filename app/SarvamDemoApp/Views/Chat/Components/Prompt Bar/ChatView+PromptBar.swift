import SwiftUI

extension ChatView {
  struct PromptBar: View {
    @Environment(ViewModel.self) private var viewModel

    @Namespace private var namespace

    var body: some View {
      GlassEffectContainer(spacing: 10) {
        HStack {
          if viewModel.dictationState == .idle {
            MainInput(namespace: namespace)
          } else {
            DictationBar(namespace: namespace)
          }
        }
      }
      .animation(.default, value: viewModel.dictationState)
    }
  }

  private struct MainInput: View {
    let namespace: Namespace.ID

    @Environment(ViewModel.self) private var viewModel

    var body: some View {
      @Bindable var viewModel = viewModel

      VStack(spacing: 0) {
        TextField("Ask Sarvam", text: $viewModel.text, axis: .vertical)
          .padding(.horizontal, 16)
          .padding(.vertical, 12)
          .onSubmit { Task { await viewModel.submit() } }

        ActionBar()
      }
      .glassEffect(.regular, in: .rect(cornerRadius: 26))
      .glassEffectID("main-input", in: namespace)
    }
  }

  private struct ActionBar: View {
    @Environment(ViewModel.self) private var viewModel

    var body: some View {
      HStack(spacing: 16) {
        Button("Add attachment", systemImage: "plus") {

        }

        Button("Dictate", systemImage: "mic") {
          Task {
            await viewModel.startDictation()
          }
        }

        Spacer()

        PromptBarActionButton("Send", systemImage: "arrow.up", loading: .constant(viewModel.submissionState.isBusy)) {
          await viewModel.submit()
        }
        .disabled(!viewModel.canSubmit)
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
