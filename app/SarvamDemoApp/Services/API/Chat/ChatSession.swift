import Foundation
import Observation

extension APIClient {
  @MainActor
  @Observable
  final class ChatSession {
    enum State: Equatable, Sendable { case idle, streaming, completed, failed }

    let id: String
    var messages: [ChatMessage] = []
    var streamChunks: [ChatStreamChunk] = []
    var streamingAssistantMessage = StreamingAssistantMessage()
    var state: State = .idle
    var errorMessage: String?

    @ObservationIgnored private let chats: Chats
    @ObservationIgnored private var streamTask: Task<Void, Never>?

    init(id: String) {
      self.id = id
      self.chats = APIClient.chats
    }

    init(id: String, chats: Chats) {
      self.id = id
      self.chats = chats
    }

    func load() async {
      print("[App:ChatSession] Loading messages")
      do {
        messages = try await chats.get(id: id).messages
        errorMessage = nil
      } catch {
        print("[App:ChatSession] Load failed")
        errorMessage = error.localizedDescription
        state = .failed
      }
    }

    func send(_ content: String) async {
      print("[App:ChatSession] Sending message")
      guard streamTask == nil, !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
      streamChunks = []
      streamingAssistantMessage = StreamingAssistantMessage()
      errorMessage = nil
      state = .streaming
      let task = Task { [weak self] in
        guard let self else { return }
        do {
          for try await chunk in chats.stream(id: id, content: content) {
            if Task.isCancelled { return }
            streamChunks.append(chunk)
            streamingAssistantMessage.chunks.append(chunk)
            if case .end(let end) = chunk {
              messages = end.messages
              if end.outcome == .failed {
                errorMessage = end.error?.message
                state = .failed
              } else {
                state = .completed
              }
            }
          }
        } catch {
          if !Task.isCancelled {
            print("[App:ChatSession] Stream failed")
            errorMessage = error.localizedDescription
            state = .failed
          }
        }
        streamTask = nil
      }
      streamTask = task
      await task.value
    }

    func cancel() {
      print("[App:ChatSession] Cancelling stream")
      streamTask?.cancel()
      streamTask = nil
      if state == .streaming { state = .idle }
    }
  }
}
