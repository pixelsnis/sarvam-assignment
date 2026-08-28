import SwiftUI

extension ChatView {
  private enum AssistantEyebrowState: Equatable {
    case hidden
    case visible(String)
  }

  private static func eyebrowState(
    for content: [APIClient.ChatContentPart],
    visibleText: String?
  ) -> AssistantEyebrowState {
    guard visibleText == nil else {
      return .hidden
    }

    guard let latestPart = content.last else {
      return .visible("")
    }

    switch latestPart {
    case .reasoning:
      return .visible("Thinking")
    case .toolCall(let toolCall):
      return .visible(toolCall.label)
    case .toolResult(let toolResult):
      return .visible(toolResult.label)
    case .text:
      return .visible("")
    }
  }

  private static func eyebrowState(
    for chunks: [APIClient.ChatStreamChunk]
  ) -> AssistantEyebrowState {
    guard let latestChunk = chunks.last else {
      return .visible("")
    }

    switch latestChunk {
    case .reasoningDelta:
      return .visible("Thinking")
    case .toolCall(let toolCall):
      return .visible(toolCall.label)
    case .toolResult(let toolResult):
      return .visible(toolResult.label)
    case .start, .textDelta, .end:
      return .visible("")
    }
  }

  private struct AssistantEyebrowView: View {
    let label: String

    var body: some View {
      HStack(spacing: 8) {
        Image("Sarvam 105B")
          .resizable()
          .scaledToFit()
          .frame(height: 24)

        Text(label)
          .foregroundStyle(.secondary)
          .contentTransition(.numericText())
          .shimmering()
      }
    }
  }

  struct AssistantMessageView: View {
    let message: APIClient.AssistantMessage

    private var eyebrowState: AssistantEyebrowState {
      ChatView.eyebrowState(
        for: message.content,
        visibleText: message.visibleTextContent
      )
    }

    var body: some View {
      VStack(alignment: .leading, spacing: 10) {
        if case .visible(let label) = eyebrowState {
          AssistantEyebrowView(label: label)
            .transition(.blurReplace)
        }

        if let text = message.visibleTextContent {
          Text(text)
            .lineHeight(.loose)
            .contentTransition(.interpolate)
            .transition(.blurReplace)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .animation(.smooth(duration: 0.22), value: eyebrowState)
      .animation(.smooth(duration: 0.22), value: message.visibleTextContent)
    }
  }

  struct UserMessageView: View {
    let message: APIClient.UserMessage

    var body: some View {
      HStack(spacing: 0) {
        Spacer()
        if let text = message.visibleTextContent {
          Text(text)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.quinary)
            .clipShape(.rect(cornerRadius: 26))
            .frame(maxWidth: 270, alignment: .trailing)
        }
      }
    }
  }
  
  struct StreamingAssistantMessageView: View {
    let message: APIClient.StreamingAssistantMessage

    private var eyebrowState: AssistantEyebrowState {
      ChatView.eyebrowState(
        for: message.chunks
      )
    }

    var body: some View {
      VStack(alignment: .leading, spacing: 10) {
        if case .visible(let label) = eyebrowState {
          AssistantEyebrowView(label: label)
            .transition(.blurReplace)
        }

        if let text = message.visibleTextContent {
          Text(text)
            .lineHeight(.loose)
            .contentTransition(.interpolate)
            .transition(.blurReplace)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .animation(.smooth(duration: 0.22), value: eyebrowState)
      .animation(.smooth(duration: 0.22), value: message.visibleTextContent)
    }
  }
}

#Preview {
  let now = Date()
  let userMessage = APIClient.UserMessage(
    id: "preview-user-message",
    role: "user",
    content: [
      .text(.init(type: "text", text: "Can you summarize the latest project updates?"))
    ],
    createdAt: now
  )
  let assistantMessage = APIClient.AssistantMessage(
    id: "preview-assistant-message",
    role: "assistant",
    content: [
      .reasoning(.init(
        type: "reasoning",
        reasoning: "I’ll review the available updates and group them by theme.",
        duration: 2.0
      )),
      .toolCall(.init(
        type: "tool_call",
        toolCallId: "preview-tool-call",
        toolName: "read_file",
        label: "Reading files"
      )),
      .toolResult(.init(
        type: "tool-result",
        toolCallId: "preview-tool-call",
        toolName: "read_file",
        label: "Read files"
      )),
      .text(.init(
        type: "text",
        text: "The project is focused on the chat service, streaming responses, and the Swift client integration."
      ))
    ],
    createdAt: now
  )
  let assistantStatusOnlyMessage = APIClient.AssistantMessage(
    id: "preview-assistant-status-only-message",
    role: "assistant",
    content: [
      .reasoning(.init(
        type: "reasoning",
        reasoning: "I’m still working through the answer.",
        duration: 2.0
      )),
      .toolCall(.init(
        type: "tool_call",
        toolCallId: "preview-status-only-tool-call",
        toolName: "read_file",
        label: "Reading files"
      ))
    ],
    createdAt: now
  )
  let streamingStart = APIClient.StreamingAssistantMessage(chunks: [
    .start(.init(type: "start", messageId: "preview-streaming-message"))
  ])
  let streamingReasoning = APIClient.StreamingAssistantMessage(chunks: [
    .start(.init(type: "start", messageId: "preview-streaming-message")),
    .reasoningDelta(.init(type: "reasoning-delta", delta: "I’m thinking"))
  ])
  let streamingToolCall = APIClient.StreamingAssistantMessage(chunks: [
    .start(.init(type: "start", messageId: "preview-streaming-message")),
    .toolCall(.init(
      type: "tool-call",
      toolCallId: "preview-tool-call",
      toolName: "read_file",
      label: "Reading files"
    ))
  ])
  let streamingToolResult = APIClient.StreamingAssistantMessage(chunks: [
    .start(.init(type: "start", messageId: "preview-streaming-message")),
    .toolResult(.init(
      type: "tool-result",
      toolCallId: "preview-tool-call",
      toolName: "read_file",
      label: "Read files"
    ))
  ])
  let streamingText = APIClient.StreamingAssistantMessage(chunks: [
    .start(.init(type: "start", messageId: "preview-streaming-message")),
    .textDelta(.init(type: "text-delta", delta: "The response is streaming")),
    .textDelta(.init(type: "text-delta", delta: " in now."))
  ])
  let streamingTextOnly = APIClient.StreamingAssistantMessage(chunks: [
    .textDelta(.init(type: "text-delta", delta: "Text-only streaming hides the eyebrow."))
  ])
  let streamingTextThenTool = APIClient.StreamingAssistantMessage(chunks: [
    .textDelta(.init(type: "text-delta", delta: "The next step is")),
    .toolCall(.init(
      type: "tool-call",
      toolCallId: "preview-tool-call",
      toolName: "read_file",
      label: "Reading files"
    ))
  ])

  VStack(alignment: .leading, spacing: 20) {
    ChatView.UserMessageView(message: userMessage)
    ChatView.AssistantMessageView(message: assistantMessage)
    ChatView.AssistantMessageView(message: assistantStatusOnlyMessage)
    ChatView.StreamingAssistantMessageView(message: streamingStart)
    ChatView.StreamingAssistantMessageView(message: streamingReasoning)
    ChatView.StreamingAssistantMessageView(message: streamingToolCall)
    ChatView.StreamingAssistantMessageView(message: streamingToolResult)
    ChatView.StreamingAssistantMessageView(message: streamingText)
    ChatView.StreamingAssistantMessageView(message: streamingTextOnly)
    ChatView.StreamingAssistantMessageView(message: streamingTextThenTool)
  }
  .padding()
}
