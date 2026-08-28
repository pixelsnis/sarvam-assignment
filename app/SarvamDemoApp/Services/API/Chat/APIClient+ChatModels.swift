import Foundation

extension APIClient {
  struct UserMessage: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let text: String
  }

  struct AssistantMessage: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let text: String
    let reasoningDurationSeconds: Double?
  }

  enum ChatMessage: Codable, Equatable, Identifiable, Sendable {
    case user(UserMessage)
    case assistant(AssistantMessage)

    var id: String {
      switch self {
      case .user(let message): message.id
      case .assistant(let message): message.id
      }
    }

    var text: String {
      switch self {
      case .user(let message): message.text
      case .assistant(let message): message.text
      }
    }

    private enum CodingKeys: String, CodingKey {
      case id
      case role
      case text
      case reasoningDurationSeconds
    }

    private enum Role: String, Codable {
      case user
      case assistant
    }

    init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      let role = try container.decode(Role.self, forKey: .role)
      let id = try container.decode(String.self, forKey: .id)
      let text = try container.decode(String.self, forKey: .text)

      switch role {
      case .user:
        self = .user(UserMessage(id: id, text: text))
      case .assistant:
        self = .assistant(
          AssistantMessage(
            id: id,
            text: text,
            reasoningDurationSeconds: try container.decodeIfPresent(
              Double.self,
              forKey: .reasoningDurationSeconds
            )
          ))
      }
    }

    func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)

      switch self {
      case .user(let message):
        try container.encode(message.id, forKey: .id)
        try container.encode(Role.user, forKey: .role)
        try container.encode(message.text, forKey: .text)
      case .assistant(let message):
        try container.encode(message.id, forKey: .id)
        try container.encode(Role.assistant, forKey: .role)
        try container.encode(message.text, forKey: .text)
        try container.encode(
          message.reasoningDurationSeconds,
          forKey: .reasoningDurationSeconds
        )
      }
    }
  }

  struct ChatResponse: Codable, Equatable, Sendable {
    let id: String
    let messages: [ChatMessage]
  }

  struct ChatSummary: Decodable, Equatable, Identifiable, Sendable {
    let id: String
    let createdAt: Date
    let updatedAt: Date
  }

  struct ChatCreationResponse: Codable, Equatable, Sendable {
    let id: String
  }

  enum ChatStatus: String, Codable, Equatable, Sendable {
    case thinking
    case complete
    case error
  }

  enum ChatStreamEvent: Codable, Equatable, Sendable {
    case start(sessionId: String)
    case status(ChatStatus)
    case toolCall(toolId: String, toolName: String, label: String)
    case toolResult(toolId: String, toolName: String, label: String)
    case textDelta(String)
    case end(
      sessionId: String,
      finishReason: String,
      messages: [ChatMessage]
    )

    private enum CodingKeys: String, CodingKey {
      case type
      case sessionId
      case status
      case toolId
      case toolName
      case label
      case text
      case finishReason
      case messages
    }

    private enum EventType: String, Codable {
      case start
      case status
      case toolCall = "tool-call"
      case toolResult = "tool-result"
      case textDelta = "text-delta"
      case end
    }

    init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      let type = try container.decode(EventType.self, forKey: .type)

      switch type {
      case .start:
        self = .start(sessionId: try container.decode(String.self, forKey: .sessionId))
      case .status:
        self = .status(try container.decode(ChatStatus.self, forKey: .status))
      case .toolCall:
        self = .toolCall(
          toolId: try container.decode(String.self, forKey: .toolId),
          toolName: try container.decode(String.self, forKey: .toolName),
          label: try container.decode(String.self, forKey: .label)
        )
      case .toolResult:
        self = .toolResult(
          toolId: try container.decode(String.self, forKey: .toolId),
          toolName: try container.decode(String.self, forKey: .toolName),
          label: try container.decode(String.self, forKey: .label)
        )
      case .textDelta:
        self = .textDelta(try container.decode(String.self, forKey: .text))
      case .end:
        self = .end(
          sessionId: try container.decode(String.self, forKey: .sessionId),
          finishReason: try container.decode(String.self, forKey: .finishReason),
          messages: try container.decode([ChatMessage].self, forKey: .messages)
        )
      }
    }

    func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)

      switch self {
      case .start(let sessionId):
        try container.encode(EventType.start, forKey: .type)
        try container.encode(sessionId, forKey: .sessionId)
      case .status(let status):
        try container.encode(EventType.status, forKey: .type)
        try container.encode(status, forKey: .status)
      case .toolCall(let toolId, let toolName, let label):
        try container.encode(EventType.toolCall, forKey: .type)
        try container.encode(toolId, forKey: .toolId)
        try container.encode(toolName, forKey: .toolName)
        try container.encode(label, forKey: .label)
      case .toolResult(let toolId, let toolName, let label):
        try container.encode(EventType.toolResult, forKey: .type)
        try container.encode(toolId, forKey: .toolId)
        try container.encode(toolName, forKey: .toolName)
        try container.encode(label, forKey: .label)
      case .textDelta(let text):
        try container.encode(EventType.textDelta, forKey: .type)
        try container.encode(text, forKey: .text)
      case .end(let sessionId, let finishReason, let messages):
        try container.encode(EventType.end, forKey: .type)
        try container.encode(sessionId, forKey: .sessionId)
        try container.encode(finishReason, forKey: .finishReason)
        try container.encode(messages, forKey: .messages)
      }
    }
  }
}
