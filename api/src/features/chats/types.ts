export type ChatProviderEnvironment = {
  CHAT_BASE_URL?: string;
  CHAT_API_KEY?: string;
  OPENAI_BASE_URL?: string;
  OPENAI_API_KEY?: string;
};

export type ChatProviderConfig = {
  baseURL: string;
  apiKey: string;
};

export type ChatContentPart =
  | { type: "text"; text: string }
  | { type: "reasoning"; reasoning: string; duration: number }
  | { type: "tool_call"; toolCallId: string; toolName: string; label: string }
  | { type: "tool-result"; toolCallId: string; toolName: string; label: string };

export type ClientChatMessage = {
  id: string;
  role: "user" | "assistant";
  content: ChatContentPart[];
  createdAt: Date;
};

export type ChatStreamChunk =
  | { type: "start"; messageId: string }
  | { type: "reasoning-delta"; delta: string }
  | { type: "text-delta"; delta: string }
  | { type: "tool-call"; toolCallId: string; toolName: string; label: string }
  | { type: "tool-result"; toolCallId: string; toolName: string; label: string }
  | {
      type: "end";
      outcome: "complete" | "failed";
      finishReason?: string;
      messages: ClientChatMessage[];
      error?: { code: string; message: string };
    };
