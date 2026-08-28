import { createOpenAICompatible } from "@ai-sdk/openai-compatible";
import {
  streamText,
  type LanguageModel,
  type ModelMessage,
  type TextStreamPart,
  type ToolSet,
} from "ai";
import { and, asc, desc, eq } from "drizzle-orm";
import type { Context } from "hono";
import {
  SSEStreamingApi,
  streamSSE,
} from "hono/streaming";
import type { ContentfulStatusCode } from "hono/utils/http-status";
import { auth } from "./auth";
import {
  CHAT_INSTRUCTIONS,
  chatRequestSchema,
  decodeStoredMessages,
  getToolLabel,
  InvalidChatHistoryError,
  toChatMessage,
  type ChatRequest,
  type ChatMessage,
  type ChatResponse,
  type ChatSummary,
  type ChatStreamEvent,
} from "./chat-contract";
import { db } from "./db";
import {
  chat as chatTable,
  chatMessage as chatMessageTable,
} from "./db/schema";

type ChatStreamPart = TextStreamPart<ToolSet>;

type ChatStreamResult = {
  fullStream: AsyncIterable<ChatStreamPart>;
};

type ChatStreamTextOptions = {
  model: LanguageModel;
  instructions: string;
  messages: ModelMessage[];
};

type ChatDatabase = typeof db;

export type ChatDependencies = {
  database: ChatDatabase;
  getSession: (
    headers: Headers,
  ) => Promise<{ user: { id: string } } | null>;
  createModel: () => LanguageModel;
  streamText: (options: ChatStreamTextOptions) => ChatStreamResult;
  now: () => number;
};

class ChatHttpError extends Error {
  constructor(
    readonly status: 400 | 401 | 404 | 500,
    readonly code: string,
    message: string,
  ) {
    super(message);
    this.name = "ChatHttpError";
  }
}

function errorMessage(error: unknown): string {
  return error instanceof Error ? error.message : "Unknown chat stream error";
}

function errorResponse(c: Context, error: unknown): Response {
  if (!(error instanceof ChatHttpError)) {
    console.error("Chat request failed", error);
  }

  const chatError =
    error instanceof ChatHttpError
      ? error
      : new ChatHttpError(
          500,
          "internal_error",
          "The server could not complete the chat request.",
        );

  return c.json(
    {
      code: chatError.code,
      message: chatError.message,
    },
    chatError.status as ContentfulStatusCode,
  );
}

async function getAuthenticatedUser(
  c: Context,
  getSession: ChatDependencies["getSession"],
) {
  const session = await getSession(c.req.raw.headers);

  if (!session) {
    throw new ChatHttpError(
      401,
      "unauthorized",
      "You must be signed in to use chat.",
    );
  }

  return session.user;
}

async function parseChatRequest(c: Context): Promise<ChatRequest> {
  let body: unknown;

  try {
    body = await c.req.json();
  } catch {
    throw new ChatHttpError(
      400,
      "invalid_request",
      "Request body must be valid JSON.",
    );
  }

  const parsed = chatRequestSchema.safeParse(body);
  if (!parsed.success) {
    throw new ChatHttpError(
      400,
      "invalid_request",
      "Request body must include non-empty text and no unsupported fields.",
    );
  }

  return parsed.data;
}

async function loadChatHistory(
  database: ChatDatabase,
  chatId: string,
  userId: string,
) {
  const [ownedChat] = await database
    .select({ id: chatTable.id })
    .from(chatTable)
    .where(and(eq(chatTable.id, chatId), eq(chatTable.userId, userId)))
    .limit(1);

  if (!ownedChat) {
    throw new ChatHttpError(404, "chat_not_found", "Chat not found.");
  }

  const rows = await database
    .select({
      id: chatMessageTable.id,
      message: chatMessageTable.message,
      position: chatMessageTable.position,
      reasoningDurationSeconds: chatMessageTable.reasoningDurationSeconds,
    })
    .from(chatMessageTable)
    .where(eq(chatMessageTable.chatId, chatId))
    .orderBy(asc(chatMessageTable.position));

  try {
    const messages = decodeStoredMessages(rows.map((row) => row.message));
    const chatMessages = rows.flatMap((row, index) => {
      const message = toChatMessage(
        row.id,
        messages[index]!,
        row.reasoningDurationSeconds,
      );

      return message ? [message] : [];
    });

    return {
      messages,
      chatMessages,
      nextPosition: (rows.at(-1)?.position ?? -1) + 1,
    };
  } catch (error) {
    if (!(error instanceof InvalidChatHistoryError)) {
      console.error("Unable to decode stored chat JSON", error);
    } else {
      console.error("Stored chat history failed ModelMessage validation", {
        chatId,
      });
    }

    throw new ChatHttpError(
      500,
      "invalid_chat_history",
      "Stored chat history is invalid.",
    );
  }
}

async function appendMessage(
  database: ChatDatabase,
  chatId: string,
  position: number,
  message: ModelMessage,
  reasoningDurationSeconds: number | null = null,
): Promise<string> {
  const id = crypto.randomUUID();

  await database.transaction(async (transaction) => {
    await transaction.insert(chatMessageTable).values({
      id,
      chatId,
      position,
      message: JSON.stringify(message),
      reasoningDurationSeconds,
    });

    await transaction
      .update(chatTable)
      .set({ updatedAt: new Date() })
      .where(eq(chatTable.id, chatId));
  });

  return id;
}

function createSarvamModel() {
  const baseURL = process.env.OPENAI_BASE_URL;
  const apiKey = process.env.OPENAI_API_KEY;

  if (!baseURL || !apiKey) {
    throw new ChatHttpError(
      500,
      "configuration_error",
      "OPENAI_BASE_URL and OPENAI_API_KEY are required for chat.",
    );
  }

  const sarvam = createOpenAICompatible({
    name: "sarvam",
    baseURL,
    apiKey,
  });

  return sarvam("sarvam-105b");
}

async function writeEvent(
  stream: SSEStreamingApi,
  event: ChatStreamEvent,
): Promise<void> {
  await stream.writeSSE({ data: JSON.stringify(event) });
}

function defaultStreamText(options: ChatStreamTextOptions): ChatStreamResult {
  return streamText(options);
}

function defaultGetSession(
  headers: Headers,
): Promise<{ user: { id: string } } | null> {
  return auth.api.getSession({ headers });
}

function createSarvamDependencies(): ChatDependencies {
  return {
    database: db,
    getSession: defaultGetSession,
    createModel: createSarvamModel,
    streamText: defaultStreamText,
    now: () => performance.now(),
  };
}

export function createChatHandlers(
  dependencies: ChatDependencies = createSarvamDependencies(),
) {
  async function createChat(c: Context): Promise<Response> {
    try {
      const user = await getAuthenticatedUser(c, dependencies.getSession);
      const id = crypto.randomUUID();

      await dependencies.database.insert(chatTable).values({
        id,
        userId: user.id,
      });

      return c.json({ id }, 201);
    } catch (error) {
      return errorResponse(c, error);
    }
  }

  async function getChat(c: Context): Promise<Response> {
    try {
      const user = await getAuthenticatedUser(c, dependencies.getSession);
      const chatId = c.req.param("id");

      if (!chatId) {
        throw new ChatHttpError(404, "chat_not_found", "Chat not found.");
      }

      const { chatMessages } = await loadChatHistory(
        dependencies.database,
        chatId,
        user.id,
      );

      const response: ChatResponse = {
        id: chatId,
        messages: chatMessages,
      };

      return c.json(response);
    } catch (error) {
      return errorResponse(c, error);
    }
  }

  async function listChats(c: Context): Promise<Response> {
    try {
      const user = await getAuthenticatedUser(c, dependencies.getSession);
      const chats: ChatSummary[] = await dependencies.database
        .select({
          id: chatTable.id,
          createdAt: chatTable.createdAt,
          updatedAt: chatTable.updatedAt,
        })
        .from(chatTable)
        .where(eq(chatTable.userId, user.id))
        .orderBy(desc(chatTable.updatedAt), desc(chatTable.createdAt));

      return c.json(chats);
    } catch (error) {
      return errorResponse(c, error);
    }
  }

  async function streamChat(c: Context): Promise<Response> {
    try {
      const user = await getAuthenticatedUser(c, dependencies.getSession);
      const request = await parseChatRequest(c);
      const chatId = c.req.param("id");

      if (!chatId) {
        throw new ChatHttpError(404, "chat_not_found", "Chat not found.");
      }

      const { messages, nextPosition } = await loadChatHistory(
        dependencies.database,
        chatId,
        user.id,
      );
      const userMessage: ModelMessage = {
        role: "user",
        content: request.text,
      };

      const userMessageId = await appendMessage(
        dependencies.database,
        chatId,
        nextPosition,
        userMessage,
      );
      const model = dependencies.createModel();

      const result = dependencies.streamText({
        model,
        instructions: CHAT_INSTRUCTIONS,
        messages: [...messages, userMessage],
      });

      return streamSSE(
        c,
        async (stream) => {
          let assistantText = "";
          let finishReason = "stop";
          let reasoningDurationSeconds: number | null = null;
          let hasSeenTextDelta = false;

          try {
            await writeEvent(stream, { type: "start", sessionId: chatId });
            const reasoningStartedAt = dependencies.now();
            await writeEvent(stream, { type: "status", status: "thinking" });

            for await (const part of result.fullStream) {
              switch (part.type) {
                case "text-delta":
                  if (!hasSeenTextDelta) {
                    reasoningDurationSeconds =
                      (dependencies.now() - reasoningStartedAt) / 1000;
                    hasSeenTextDelta = true;
                  }
                  assistantText += part.text;
                  await writeEvent(stream, {
                    type: "text-delta",
                    text: part.text,
                  });
                  break;
                case "tool-call":
                  await writeEvent(stream, {
                    type: "tool-call",
                    toolId: part.toolCallId,
                    toolName: part.toolName,
                    label: getToolLabel(part.toolName),
                  });
                  break;
                case "tool-result":
                  await writeEvent(stream, {
                    type: "tool-result",
                    toolId: part.toolCallId,
                    toolName: part.toolName,
                    label: getToolLabel(part.toolName),
                  });
                  break;
                case "finish":
                  finishReason = part.finishReason;
                  break;
                case "error":
                  throw new Error(errorMessage(part.error));
                case "abort":
                  throw new Error("Chat stream was aborted.");
                default:
                  break;
              }
            }

            const assistantMessage: ModelMessage = {
              role: "assistant",
              content: assistantText,
            };
            const assistantMessageId = await appendMessage(
              dependencies.database,
              chatId,
              nextPosition + 1,
              assistantMessage,
              reasoningDurationSeconds,
            );

            const messages: ChatMessage[] = [
              toChatMessage(userMessageId, userMessage),
              toChatMessage(
                assistantMessageId,
                assistantMessage,
                reasoningDurationSeconds,
              ),
            ].filter(
              (message): message is NonNullable<typeof message> =>
                message !== null,
            );

            await writeEvent(stream, { type: "status", status: "complete" });
            await writeEvent(stream, {
              type: "end",
              sessionId: chatId,
              finishReason,
              messages,
            });
          } catch (error) {
            console.error("Chat stream failed", error);

            try {
              await writeEvent(stream, { type: "status", status: "error" });
            } catch {
              // The client may have disconnected before the error event could be sent.
            }
          }
        },
        async (error) => {
          console.error("SSE chat stream failed", error);
        },
      );
    } catch (error) {
      return errorResponse(c, error);
    }
  }

  return { createChat, getChat, listChats, streamChat };
}

const defaultChatHandlers = createChatHandlers();

export const { createChat, getChat, listChats, streamChat } = defaultChatHandlers;
