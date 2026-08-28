import Foundation
import Observation

@MainActor
@Observable
final class ChatSession {
  enum Status: Equatable {
    case idle
    case loading
    case streaming
    case complete
    case error
  }

  enum Error: LocalizedError {
    case alreadyStreaming
    case emptyText
    case incompleteStream
    case mismatchedSession
    case serverReportedError

    var errorDescription: String? {
      switch self {
      case .alreadyStreaming:
        "A chat response is already streaming."
      case .emptyText:
        "Chat text must not be empty."
      case .incompleteStream:
        "The chat stream ended before completing the response."
      case .mismatchedSession:
        "The server returned a different chat session."
      case .serverReportedError:
        "The server could not complete the chat response."
      }
    }
  }

  let id: String

  private let chatAPI: APIClient.Chat
  private var activeStreamTask: Task<Void, Swift.Error>?

  private(set) var messages: [APIClient.ChatMessage]
  private(set) var streamChunks: [APIClient.ChatStreamEvent] = []
  private(set) var streamedAssistantText = ""
  private(set) var status: Status = .idle
  private(set) var finishReason: String?
  private(set) var reasoningDurationSeconds: Double?
  private(set) var errorMessage: String?

  init(id: String, chatAPI: APIClient.Chat = APIClient.chat) {
    self.id = id
    self.chatAPI = chatAPI
    messages = []
  }

  private init(response: APIClient.ChatResponse, chatAPI: APIClient.Chat) {
    id = response.id
    self.chatAPI = chatAPI
    messages = response.messages
  }

  static func makeNew(
    using chatAPI: APIClient.Chat = APIClient.chat
  ) async throws -> ChatSession {
    let response = try await chatAPI.create()
    return ChatSession(id: response.id, chatAPI: chatAPI)
  }

  func load() async throws {
    guard activeStreamTask == nil else {
      throw Error.alreadyStreaming
    }

    status = .loading
    errorMessage = nil

    do {
      let response = try await chatAPI.fetch(id: id)
      guard response.id == id else {
        throw Error.mismatchedSession
      }

      messages = response.messages
      resetStreamState()
      status = .idle
    } catch {
      status = .error
      errorMessage = error.localizedDescription
      throw error
    }
  }

  func send(_ text: String) async throws {
    guard activeStreamTask == nil else {
      throw Error.alreadyStreaming
    }

    let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !text.isEmpty else {
      throw Error.emptyText
    }

    resetStreamState()
    errorMessage = nil
    status = .streaming

    let task = Task { [weak self] in
      guard let self else { return }
      try await self.consumeStream(text)
    }
    activeStreamTask = task

    defer {
      activeStreamTask = nil
    }

    do {
      try await task.value
    } catch is CancellationError {
      status = .idle
      throw CancellationError()
    } catch {
      status = .error
      errorMessage = error.localizedDescription
      throw error
    }
  }

  func cancel() {
    activeStreamTask?.cancel()
  }

  private func resetStreamState() {
    streamChunks = []
    streamedAssistantText = ""
    finishReason = nil
    reasoningDurationSeconds = nil
  }

  private func consumeStream(_ text: String) async throws {
    let stream = try chatAPI.stream(text, for: id)
    var didComplete = false

    for try await event in stream {
      streamChunks.append(event)

      switch event {
      case .start(let sessionId):
        guard sessionId == id else {
          throw Error.mismatchedSession
        }
      case .status(let chatStatus):
        switch chatStatus {
        case .thinking:
          status = .streaming
        case .complete:
          status = .complete
        case .error:
          status = .error
          throw Error.serverReportedError
        }
      case .toolCall, .toolResult:
        break
      case .textDelta(let text):
        streamedAssistantText += text
      case .end(let sessionId, let finishReason, let responseMessages):
        guard sessionId == id else {
          throw Error.mismatchedSession
        }

        messages.append(contentsOf: responseMessages)
        self.finishReason = finishReason
        reasoningDurationSeconds =
          responseMessages.reversed().compactMap {
            guard case .assistant(let message) = $0 else { return nil }
            return message.reasoningDurationSeconds
          }.first
        status = .complete
        didComplete = true
      }
    }

    guard didComplete else {
      throw Error.incompleteStream
    }
  }
}
