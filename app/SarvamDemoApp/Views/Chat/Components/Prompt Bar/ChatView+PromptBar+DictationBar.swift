import SwiftUI

extension ChatView {
  struct DictationBar: View {
    let namespace: Namespace.ID

    @Environment(ViewModel.self) private var viewModel

    var body: some View {
      @Bindable var viewModel = viewModel

      HStack(spacing: 0) {
        CancelButton {
          viewModel.cancelDictation()
        }

        WaveformView(waveform: viewModel.audioRecorder.waveformSamples)
          .padding(.leading, 4)
          .padding(.trailing, 8)

        PromptBarActionButton(
          "Finish",
          systemImage: "checkmark",
          loading: $viewModel.isTranscribing,
          gradient: [
            .init(color: .init(hex: "#B81514"), location: 0.0),
            .init(color: .init(hex: "#D2DFF9"), location: 1.0),
          ]
        ) {
          await viewModel.finishDictation()
        }
      }
      .padding(8)
      .glassEffect(.regular, in: .capsule)
      .glassEffectID("dictation-bar", in: namespace)
    }
  }

  private struct CancelButton: View {
    let action: () -> Void

    var body: some View {
      Button {
        action()
      } label: {
        Label("Cancel", systemImage: "xmark")
          .labelStyle(.iconOnly)
          .frame(width: 40, height: 40)
          .glassEffect(.regular, in: .circle)
          .contentShape(.circle)
      }
      .buttonStyle(.plain)
    }
  }

  private struct WaveformView: View {
    let waveform: [Float]

    @State private var scrollPosition = ScrollPosition(idType: String.self)

    private let pillWidth: CGFloat = 3
    private let pillSpacing: CGFloat = 2
    private let waveformHeight: CGFloat = 32

    var body: some View {
      HStack(spacing: 4) {
        Image(.saaras)
          .resizable()
          .scaledToFit()
          .frame(height: waveformHeight)

        GeometryReader { proxy in
          ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: pillSpacing) {
              ForEach(0..<waveform.count, id: \.self) { index in
                pill(waveform[index])
                  .id("pill-\(index)")
              }

              ForEach(0..<fillerCount(for: proxy.size.width), id: \.self) { index in
                pill(0)
                  .opacity(0.3)
                  .id("filler-\(index)")
              }
            }
            .scrollTargetLayout()
          }
          .scrollPosition($scrollPosition)
          .onChange(of: waveform.count, initial: true) { _, count in
            guard count > 0 else { return }

            withAnimation(.linear(duration: 0.15)) {
              scrollPosition.scrollTo(id: "pill-\(count - 1)", anchor: .trailing)
            }
          }
        }
        .frame(maxWidth: .infinity)
        .frame(height: waveformHeight)
      }
      .frame(maxWidth: .infinity)
    }

    private func fillerCount(for availableWidth: CGFloat) -> Int {
      guard availableWidth > 0 else { return 0 }

      let requiredPillCount = Int(
        ((availableWidth + pillSpacing) / (pillWidth + pillSpacing)).rounded(.up)
      )

      return max(0, requiredPillCount - waveform.count)
    }

    @ViewBuilder private func pill(_ amplitude: Float) -> some View {
      let height = max(amplitude * 22, 3)

      Capsule()
        .fill(Color(hex: "#BF4B51"))
        .frame(width: pillWidth, height: CGFloat(height))
    }
  }
}

#Preview {
  @Previewable @State var viewModel = ChatView.ViewModel()
  @Previewable @Namespace var namespace

  ChatView.DictationBar(namespace: namespace)
    .environment(viewModel)
}
