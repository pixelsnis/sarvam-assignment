import Foundation
import Observation

extension ChatView {
  @MainActor
  @Observable
  final class ViewModel {
    enum DictationState: Equatable {
      case idle
      case recording
      case transcribing
    }

    // MARK: Dependencies

    let audioRecorder: AudioRecorder
    let transcriptionsAPI: APIClient.Transcriptions

    @ObservationIgnored private var transcriptionTask: Task<Void, Never>?
    @ObservationIgnored private var dictationGeneration: UInt = 0

    // MARK: Input

    var text: String = ""

    // MARK: State

    var dictationState: DictationState = .idle
    var isTranscribing = false

    init() {
      audioRecorder = AudioRecorder()
      transcriptionsAPI = APIClient.transcriptions
    }

    init(
      audioRecorder: AudioRecorder,
      transcriptionsAPI: APIClient.Transcriptions = APIClient.transcriptions
    ) {
      self.audioRecorder = audioRecorder
      self.transcriptionsAPI = transcriptionsAPI
    }

    func startDictation() async {
      guard dictationState == .idle else { return }

      do {
        try await audioRecorder.start()
        dictationState = .recording
      } catch {
        dictationState = .idle
      }
    }

    func finishDictation() async {
      guard dictationState == .recording else { return }
      guard audioRecorder.stop() != nil else {
        dictationState = .idle
        isTranscribing = false
        return
      }

      await transcribe()
    }

    /// Transcribes the most recent recording into the prompt text.
    func transcribe() async {
      guard dictationState != .transcribing else { return }
      guard let fileURL = audioRecorder.fileURL() else {
        dictationState = .idle
        isTranscribing = false
        return
      }

      dictationState = .transcribing
      isTranscribing = true
      dictationGeneration &+= 1
      let generation = dictationGeneration

      let task = Task { [weak self] in
        await self?.transcribe(fileAt: fileURL, generation: generation)
      }
      transcriptionTask = task

      await task.value
    }

    func cancelDictation() {
      dictationGeneration &+= 1
      transcriptionTask?.cancel()
      transcriptionTask = nil

      if let fileURL = audioRecorder.stop() {
        try? FileManager.default.removeItem(at: fileURL)
      }

      dictationState = .idle
      isTranscribing = false
    }

    private func transcribe(fileAt fileURL: URL, generation: UInt) async {
      defer {
        guard generation == dictationGeneration else { return }

        transcriptionTask = nil
        dictationState = .idle
        isTranscribing = false
      }

      guard !Task.isCancelled else { return }
      guard let transcription = try? await transcriptionsAPI.transcribe(fileAt: fileURL) else {
        return
      }

      guard !Task.isCancelled, generation == dictationGeneration else { return }

      text = "\(text) \(transcription)".trimmingCharacters(in: .whitespacesAndNewlines)
    }
  }
}
