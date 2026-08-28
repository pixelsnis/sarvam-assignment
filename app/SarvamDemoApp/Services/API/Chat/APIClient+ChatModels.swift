import Foundation

extension APIClient {
  struct ChatSummary: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let createdAt: Date
    let updatedAt: Date
  }

  struct Chat: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let createdAt: Date
    let updatedAt: Date
    let messages: [ChatMessage]
  }

  enum ChatContentPart: Codable, Equatable, Sendable {
    case text(TextPart)
    case reasoning(ReasoningPart)
    case toolCall(ToolCallPart)
    case toolResult(ToolResultPart)

    static func visibleTextContent(in parts: [Self]) -> String? {
      guard case .text = parts.last else { return nil }
      var text: [String] = []
      for part in parts.reversed() {
        guard case .text(let value) = part else { break }
        text.append(value.text)
      }
      return text.reversed().joined()
    }

    private enum CodingKeys: String, CodingKey { case type }
    private enum Kind: String, Codable { case text, reasoning, tool_call, toolResult = "tool-result" }

    init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      switch try container.decode(Kind.self, forKey: .type) {
      case .text: self = .text(try TextPart(from: decoder))
      case .reasoning: self = .reasoning(try ReasoningPart(from: decoder))
      case .tool_call: self = .toolCall(try ToolCallPart(from: decoder))
      case .toolResult: self = .toolResult(try ToolResultPart(from: decoder))
      }
    }

    func encode(to encoder: Encoder) throws {
      switch self {
      case .text(let value): try value.encode(to: encoder)
      case .reasoning(let value): try value.encode(to: encoder)
      case .toolCall(let value): try value.encode(to: encoder)
      case .toolResult(let value): try value.encode(to: encoder)
      }
    }
  }

  struct TextPart: Codable, Equatable, Sendable { let type: String; let text: String }
  struct ReasoningPart: Codable, Equatable, Sendable {
    let type: String
    let reasoning: String
    let duration: Double
  }
  struct ToolCallPart: Codable, Equatable, Sendable {
    let type: String
    let toolCallId: String
    let toolName: String
    let label: String
  }
  struct ToolResultPart: Codable, Equatable, Sendable {
    let type: String
    let toolCallId: String
    let toolName: String
    let label: String
  }

  enum ChatMessage: Codable, Equatable, Identifiable, Sendable {
    case user(UserMessage)
    case assistant(AssistantMessage)

    var id: String {
      switch self { case .user(let value): value.id; case .assistant(let value): value.id }
    }

    var content: [ChatContentPart] {
      switch self { case .user(let value): value.content; case .assistant(let value): value.content }
    }

    var visibleTextContent: String? {
      ChatContentPart.visibleTextContent(in: content)
    }

    private enum CodingKeys: String, CodingKey { case role }
    private enum Role: String, Codable { case user, assistant }

    init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      switch try container.decode(Role.self, forKey: .role) {
      case .user: self = .user(try UserMessage(from: decoder))
      case .assistant: self = .assistant(try AssistantMessage(from: decoder))
      }
    }

    func encode(to encoder: Encoder) throws {
      switch self {
      case .user(let value): try value.encode(to: encoder)
      case .assistant(let value): try value.encode(to: encoder)
      }
    }
  }

  struct UserMessage: Codable, Equatable, Sendable {
    let id: String
    let role: String
    let content: [ChatContentPart]
    let createdAt: Date

    var visibleTextContent: String? {
      ChatContentPart.visibleTextContent(in: content)
    }
  }
  struct AssistantMessage: Codable, Equatable, Sendable {
    let id: String
    let role: String
    let content: [ChatContentPart]
    let createdAt: Date

    var visibleTextContent: String? {
      ChatContentPart.visibleTextContent(in: content)
    }
  }

  enum ChatStreamChunk: Codable, Equatable, Sendable {
    case start(StartChunk)
    case reasoningDelta(ReasoningDeltaChunk)
    case textDelta(TextDeltaChunk)
    case toolCall(StreamToolCallChunk)
    case toolResult(StreamToolResultChunk)
    case end(EndChunk)

    private enum CodingKeys: String, CodingKey { case type }
    private enum Kind: String, Codable { case start, reasoningDelta = "reasoning-delta", textDelta = "text-delta", toolCall = "tool-call", toolResult = "tool-result", end }

    init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      switch try container.decode(Kind.self, forKey: .type) {
      case .start: self = .start(try StartChunk(from: decoder))
      case .reasoningDelta: self = .reasoningDelta(try ReasoningDeltaChunk(from: decoder))
      case .textDelta: self = .textDelta(try TextDeltaChunk(from: decoder))
      case .toolCall: self = .toolCall(try StreamToolCallChunk(from: decoder))
      case .toolResult: self = .toolResult(try StreamToolResultChunk(from: decoder))
      case .end: self = .end(try EndChunk(from: decoder))
      }
    }

    func encode(to encoder: Encoder) throws {
      switch self {
      case .start(let value): try value.encode(to: encoder)
      case .reasoningDelta(let value): try value.encode(to: encoder)
      case .textDelta(let value): try value.encode(to: encoder)
      case .toolCall(let value): try value.encode(to: encoder)
      case .toolResult(let value): try value.encode(to: encoder)
      case .end(let value): try value.encode(to: encoder)
      }
    }

    static func visibleTextContent(in chunks: [Self]) -> String? {
      guard case .textDelta = chunks.last else { return nil }
      var text: [String] = []
      for chunk in chunks.reversed() {
        guard case .textDelta(let value) = chunk else { break }
        text.append(value.delta)
      }
      return text.reversed().joined()
    }
  }

  struct StreamingAssistantMessage: Equatable, Sendable {
    var chunks: [ChatStreamChunk]

    init(chunks: [ChatStreamChunk] = []) {
      self.chunks = chunks
    }

    var visibleTextContent: String? {
      ChatStreamChunk.visibleTextContent(in: chunks)
    }
  }

  struct StartChunk: Codable, Equatable, Sendable { let type: String; let messageId: String }
  struct ReasoningDeltaChunk: Codable, Equatable, Sendable { let type: String; let delta: String }
  struct TextDeltaChunk: Codable, Equatable, Sendable { let type: String; let delta: String }
  struct StreamToolCallChunk: Codable, Equatable, Sendable { let type: String; let toolCallId: String; let toolName: String; let label: String }
  struct StreamToolResultChunk: Codable, Equatable, Sendable { let type: String; let toolCallId: String; let toolName: String; let label: String }
  struct EndChunk: Codable, Equatable, Sendable {
    let type: String
    let outcome: Outcome
    let finishReason: String?
    let messages: [ChatMessage]
    let error: StreamError?

    enum Outcome: String, Codable, Sendable { case complete, failed }
    struct StreamError: Codable, Equatable, Sendable { let code: String; let message: String }
  }
}
