import { modelMessageSchema, type ModelMessage } from "ai";
import { z } from "zod";

export const CHAT_INSTRUCTIONS =
  "You are a general-use work agent. Respond conversationally, neutrally, and directly.";

export const chatRequestSchema = z
  .object({
    text: z.string().trim().min(1),
  })
  .strict();

export type ChatRequest = z.infer<typeof chatRequestSchema>;

export type ChatMessage =
  | {
      id: string;
      role: "user";
      text: string;
    }
  | {
      id: string;
      role: "assistant";
      text: string;
      reasoningDurationSeconds: number | null;
    };

export type ChatResponse = {
  id: string;
  messages: ChatMessage[];
};

export type ChatSummary = {
  id: string;
  createdAt: Date;
  updatedAt: Date;
};

export type ChatStreamEvent =
  | { type: "start"; sessionId: string }
  | {
      type: "status";
      status: "thinking" | "complete" | "error";
    }
  | { type: "tool-call"; toolId: string; toolName: string; label: string }
  | { type: "tool-result"; toolId: string; toolName: string; label: string }
  | { type: "text-delta"; text: string }
  | {
      type: "end";
      sessionId: string;
      finishReason: string;
      messages: ChatMessage[];
    };

const toolLabels: Record<string, string> = {
  read_file: "Reading files",
};

export class InvalidChatHistoryError extends Error {
  constructor() {
    super("Stored chat history is invalid.");
    this.name = "InvalidChatHistoryError";
  }
}

export function getToolLabel(toolName: string): string {
  const knownLabel = toolLabels[toolName];
  if (knownLabel) {
    return knownLabel;
  }

  return toolName
    .split("_")
    .map((word, index) => {
      const normalizedWord = word.toLowerCase();
      return index === 0
        ? normalizedWord.charAt(0).toUpperCase() + normalizedWord.slice(1)
        : normalizedWord;
    })
    .join(" ");
}

function plainTextFromMessage(message: ModelMessage): string {
  if (typeof message.content === "string") {
    return message.content;
  }

  return message.content
    .filter((part) => part.type === "text")
    .map((part) => part.text)
    .join("");
}

export function toChatMessage(
  id: string,
  message: ModelMessage,
  reasoningDurationSeconds: number | null = null,
): ChatMessage | null {
  const text = plainTextFromMessage(message);

  switch (message.role) {
    case "user":
      return { id, role: "user", text };
    case "assistant":
      return {
        id,
        role: "assistant",
        text,
        reasoningDurationSeconds,
      };
    default:
      return null;
  }
}

export function decodeStoredMessages(
  serializedMessages: readonly string[],
): ModelMessage[] {
  let messages: unknown[];

  try {
    messages = serializedMessages.map(
      (serializedMessage) => JSON.parse(serializedMessage) as unknown,
    );
  } catch {
    throw new InvalidChatHistoryError();
  }

  const parsedMessages = modelMessageSchema.array().safeParse(messages);
  if (!parsedMessages.success) {
    throw new InvalidChatHistoryError();
  }

  return parsedMessages.data;
}
