import Foundation
import Observation
import SwiftUI

extension ChatView {
  @MainActor
  @Observable
  final class ViewModel {
    enum DictationState: Equatable {
      case idle
      case recording
      case transcribing
    }

    enum SubmissionState: Equatable {
      case idle
      case creatingChat
      case streaming
      case failed

      var isBusy: Bool {
        switch self {
        case .creatingChat, .streaming: true
        case .idle, .failed: false
        }
      }
    }

    // MARK: Dependencies

    let audioRecorder: AudioRecorder
    let transcriptionsAPI: APIClient.Transcriptions
    let chats: APIClient.Chats

    @ObservationIgnored private var transcriptionTask: Task<Void, Never>?
    @ObservationIgnored private var dictationGeneration: UInt = 0
    @ObservationIgnored private var submissionTask: Task<Void, Never>?

    // MARK: Input

    var text: String = ""

    // MARK: State

    var dictationState: DictationState = .idle
    var isTranscribing = false
    var submissionState: SubmissionState = .idle
    var chatID: String?
    var messages: [APIClient.ChatMessage] = []
    var streamChunks: [APIClient.ChatStreamChunk] = []
    var streamingAssistantMessage = APIClient.StreamingAssistantMessage()
    var errorMessage: String?
    var scrollRevision: UInt = 0
    private(set) var pendingPrompt: String?
    private(set) var pendingMessageID: String?

    var canSubmit: Bool {
      !submissionState.isBusy && dictationState == .idle && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    init() {
      audioRecorder = AudioRecorder()
      transcriptionsAPI = APIClient.transcriptions
      chats = APIClient.chats
    }

    init(audioRecorder: AudioRecorder) {
      self.audioRecorder = audioRecorder
      self.transcriptionsAPI = APIClient.transcriptions
      self.chats = APIClient.chats
    }

    init(
      audioRecorder: AudioRecorder,
      transcriptionsAPI: APIClient.Transcriptions
    ) {
      self.audioRecorder = audioRecorder
      self.transcriptionsAPI = transcriptionsAPI
      self.chats = APIClient.chats
    }

    init(audioRecorder: AudioRecorder, transcriptionsAPI: APIClient.Transcriptions, chats: APIClient.Chats) {
      self.audioRecorder = audioRecorder
      self.transcriptionsAPI = transcriptionsAPI
      self.chats = chats
    }

    deinit {
      submissionTask?.cancel()
      transcriptionTask?.cancel()
    }

    func submit() async {
      print("[App:ChatVM] Submitting prompt")
      let prompt = text.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !prompt.isEmpty, !submissionState.isBusy else { return }

      errorMessage = nil
      if let pendingPrompt, pendingPrompt != prompt, let pendingMessageID {
        messages.removeAll { $0.id == pendingMessageID }
        self.pendingPrompt = nil
        self.pendingMessageID = nil
      }

      if pendingMessageID == nil {
        let message = APIClient.UserMessage(
          id: UUID().uuidString,
          role: "user",
          content: [.text(.init(type: "text", text: prompt))],
          createdAt: .now
        )
        pendingMessageID = message.id
        pendingPrompt = prompt
        withAnimation(.smooth) {
          messages.append(.user(message))
          scrollRevision &+= 1
        }
      }
      text = ""
      submissionState = chatID == nil ? .creatingChat : .streaming
      let task = Task { [weak self] in
        guard let self else { return }
        await self.performSubmission(prompt)
      }
      submissionTask = task
    }

    private func performSubmission(_ prompt: String) async {
      print("[App:ChatVM] Processing submission")
      defer { submissionTask = nil }
      do {
        if chatID == nil {
          submissionState = .creatingChat
          chatID = try await chats.create()
        }
        guard let chatID else { throw SubmissionError.missingChatID }

        submissionState = .streaming
        streamChunks = []
        streamingAssistantMessage = .init()
        var receivedEnd = false
        for try await chunk in chats.stream(id: chatID, content: prompt) {
          try Task.checkCancellation()
          streamChunks.append(chunk)
          streamingAssistantMessage.chunks.append(chunk)
          scrollRevision &+= 1
          if case .end(let end) = chunk {
            receivedEnd = true
            if end.outcome == .failed {
              throw SubmissionError.server(end.error?.message ?? "The response failed.")
            }
            streamChunks = []
            streamingAssistantMessage = .init()
            messages = end.messages
            pendingPrompt = nil
            pendingMessageID = nil
            submissionState = .idle
            scrollRevision &+= 1
          }
        }
        if !receivedEnd { throw SubmissionError.missingEnd }
      } catch is CancellationError {
        return
      } catch {
        print("[App:ChatVM] Submission failed")
        streamChunks = []
        streamingAssistantMessage = .init()
        text = prompt
        errorMessage = error.localizedDescription
        submissionState = .failed
      }
    }

    func dismissError() {
      print("[App:ChatVM] Dismissing error")
      errorMessage = nil
      if submissionState == .failed { submissionState = .idle }
    }

    func startNewChat() {
      print("[App:ChatVM] Starting new chat")
      submissionTask?.cancel()
      submissionTask = nil
      cancelDictation()
      chatID = nil
      messages = []
      streamChunks = []
      streamingAssistantMessage = .init()
      submissionState = .idle
      pendingPrompt = nil
      pendingMessageID = nil
      errorMessage = nil
      text = ""
      scrollRevision &+= 1
    }

    func cancelSubmission() {
      print("[App:ChatVM] Cancelling submission")
      submissionTask?.cancel()
      submissionTask = nil
      streamChunks = []
      streamingAssistantMessage = .init()
      if submissionState.isBusy { submissionState = .idle }
    }

    func startDictation() async {
      print("[App:ChatVM] Starting dictation")
      guard dictationState == .idle else { return }

      do {
        try await audioRecorder.start()
        dictationState = .recording
      } catch {
        print("[App:ChatVM] Transcription failed")
        errorMessage = error.localizedDescription
        dictationState = .idle
      }
    }

    func finishDictation() async {
      print("[App:ChatVM] Finishing dictation")
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
      print("[App:ChatVM] Starting transcription")
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

      let task = Task<Void, Never> { [weak self] in
        guard let self else { return }
        await self.transcribe(fileAt: fileURL, generation: generation)
      }
      transcriptionTask = task

      await task.value
    }

    func cancelDictation() {
      print("[App:ChatVM] Cancelling dictation")
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
        if generation == dictationGeneration {
          transcriptionTask = nil
          dictationState = .idle
          isTranscribing = false
        }
      }

      guard !Task.isCancelled else { return }
      let transcription: String
      do {
        transcription = try await transcriptionsAPI.transcribe(fileAt: fileURL)
      } catch {
        errorMessage = error.localizedDescription
        return
      }

      guard !Task.isCancelled, generation == dictationGeneration else { return }

      text = "\(text) \(transcription)".trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private enum SubmissionError: LocalizedError {
      case missingChatID
      case missingEnd
      case server(String)

      var errorDescription: String? {
        switch self {
        case .missingChatID: "Unable to create a chat."
        case .missingEnd: "The response ended unexpectedly."
        case .server(let message): message
        }
      }
    }
  }
}
