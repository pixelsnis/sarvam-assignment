import SwiftUI

extension ChatView {
  struct DictationView: View {
    @Environment(ViewModel.self) private var viewModel
    
    var body: some View {
      HStack(spacing: 0) {
        CancelButton()
        
        WaveformView(waveform: viewModel.audioRecorder.waveformSamples)
          .padding(.leading, 4)
          .padding(.trailing, 8)
        
        PromptBarActionButton("Finish", systemImage: "checkmark", gradient: [.init(color: .init(hex: "#B81514"), location: 0.0), .init(color: .init(hex: "#D2DFF9"), location: 1.0)]) {
          
        }
      }
    }
  }
  
  private struct CancelButton: View {
    var body: some View {
      Button {
        
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
    
    var body: some View {
      HStack(spacing: 4) {
        Image(.saaras)
          .resizable()
          .scaledToFit()
          .frame(height: 32)
        
        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: 4) {
            
          }
        }
      }
    }
    
    @ViewBuilder private func pill(_ amplitude: Float) -> some View {
      let height = max(amplitude * 22, 3)
      
      Capsule()
        .fill(Color(hex: "#BF4B51"))
        .frame(width: 3, height: CGFloat(height))
    }
  }
}

#Preview {
  @Previewable @State var viewModel = ChatView.ViewModel()
  
  ChatView.DictationView()
    .environment(viewModel)
}
