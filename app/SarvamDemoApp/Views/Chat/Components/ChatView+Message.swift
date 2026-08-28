import SwiftUI

extension ChatView {
  struct AssistantMessageView: View {
    let message: APIClient.AssistantMessage
    
    private var reasoningDurationText: String? {
      guard let reasoningPart = message.content.first(where: { part in
        if case .reasoning(_) = part {
          return true
        }
        
        return false
      }) else {
        return nil
      }
      
      guard case let .reasoning(reasoning) = reasoningPart else {
        return nil
      }
      
      if reasoning.duration > 1 {
        return "Thought for \(Int(reasoning.duration)) seconds"
      }
      
      return "Thought briefly"
    }

    var body: some View {
      VStack(alignment: .leading, spacing: 10) {
        if let reasoningDurationText {
          Text(reasoningDurationText)
            .foregroundStyle(.secondary)
        }
        
        if let text = message.visibleTextContent {
          Text(text)
            .lineHeight(.loose)
        }
      }
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
    var body: some View {
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

  VStack(alignment: .leading, spacing: 20) {
    ChatView.UserMessageView(message: userMessage)
    ChatView.AssistantMessageView(message: assistantMessage)
  }
  .padding()
}
