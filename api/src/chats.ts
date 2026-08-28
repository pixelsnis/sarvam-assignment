import { createOpenAICompatible } from "@ai-sdk/openai-compatible";
import { tavilyExtract, tavilySearch } from "@tavily/ai-sdk";
import { and, asc, desc, eq } from "drizzle-orm";
import type { Context } from "hono";
import type { ContentfulStatusCode } from "hono/utils/http-status";
import { stepCountIs, streamText, type ModelMessage } from "ai";
import { auth } from "./auth";
import { db } from "./db";
import { chat, chatMessage } from "./db/schema";

const CHAT_MODEL = "sarvam-105b";

type ChatProviderEnvironment = {
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

type Session = { user: { id: string } };

class ChatHttpError extends Error {
  constructor(
    readonly status: 400 | 401 | 404 | 500,
    readonly code: string,
    message: string,
  ) {
    super(message);
  }
}

function errorResponse(c: Context, error: unknown): Response {
  const value =
    error instanceof ChatHttpError
      ? error
      : new ChatHttpError(500, "internal_error", "The chat request failed.");
  if (!(error instanceof ChatHttpError)) console.error("[API:Chat] Request failed", error);
  return c.json(
    { code: value.code, message: value.message },
    value.status as ContentfulStatusCode,
  );
}

async function authenticatedUser(c: Context): Promise<Session["user"]> {
  console.log("[API:Chat] Checking session");
  const session = await auth.api.getSession({ headers: c.req.raw.headers });
  if (!session) {
    throw new ChatHttpError(401, "unauthorized", "You must be signed in.");
  }
  return session.user;
}

async function ownedChat(id: string | undefined, userId: string) {
  if (!id) throw new ChatHttpError(404, "chat_not_found", "Chat not found.");
  const [value] = await db
    .select()
    .from(chat)
    .where(and(eq(chat.id, id), eq(chat.userId, userId)))
    .limit(1);
  if (!value) throw new ChatHttpError(404, "chat_not_found", "Chat not found.");
  return value;
}

function clientMessage(row: typeof chatMessage.$inferSelect): ClientChatMessage {
  return {
    id: row.id,
    role: row.role,
    content: row.content as ChatContentPart[],
    createdAt: row.createdAt,
  };
}

export function toolLabel(toolName: string, completed: boolean): string {
  const labels: Record<string, [string, string]> = {
    read_file: ["Reading files", "Read files"],
    webSearch: ["Searching the web", "Searched the web"],
    webExtract: ["Extracting webpage content", "Extracted webpage content"],
  };
  const configured = labels[toolName];
  if (configured) return configured[completed ? 1 : 0];
  const words = toolName.replaceAll("_", " ");
  return completed ? `Used ${words}` : `Using ${words}`;
}

export function createChatTools() {
  return {
    webSearch: tavilySearch(),
    webExtract: tavilyExtract(),
  };
}

export function chatProviderConfig(
  environment?: ChatProviderEnvironment,
): ChatProviderConfig | null {
  const values = environment ?? process.env;
  const baseURL = values.CHAT_BASE_URL || values.OPENAI_BASE_URL;
  const apiKey = values.CHAT_API_KEY || values.OPENAI_API_KEY;
  if (!baseURL || !apiKey) return null;
  return { baseURL, apiKey };
}

export function createChatHandler() {
  return async (c: Context): Promise<Response> => {
    try {
      console.log("[API:Chat] Creating chat");
      const user = await authenticatedUser(c);
      const [created] = await db.insert(chat).values({ userId: user.id }).returning();
      if (!created) throw new Error("Chat insert returned no row");
      console.log("[API:Chat] Chat created");
      return c.json({ id: created.id }, 201);
    } catch (error) {
      return errorResponse(c, error);
    }
  };
}

export function listChatsHandler() {
  return async (c: Context): Promise<Response> => {
    try {
      console.log("[API:Chat] Listing chats");
      const user = await authenticatedUser(c);
      const chats = await db
        .select({ id: chat.id, createdAt: chat.createdAt, updatedAt: chat.updatedAt })
        .from(chat)
        .where(eq(chat.userId, user.id))
        .orderBy(desc(chat.updatedAt));
      return c.json({ chats });
    } catch (error) {
      return errorResponse(c, error);
    }
  };
}

export function getChatHandler() {
  return async (c: Context): Promise<Response> => {
    try {
      console.log("[API:Chat] Loading chat");
      const user = await authenticatedUser(c);
      const value = await ownedChat(c.req.param("id"), user.id);
      const rows = await db
        .select()
        .from(chatMessage)
        .where(eq(chatMessage.chatId, value.id))
        .orderBy(asc(chatMessage.sequence));
      return c.json({
        id: value.id,
        createdAt: value.createdAt,
        updatedAt: value.updatedAt,
        messages: rows.map(clientMessage),
      });
    } catch (error) {
      return errorResponse(c, error);
    }
  };
}

function ndjson(chunk: ChatStreamChunk): Uint8Array {
  return new TextEncoder().encode(`${JSON.stringify(chunk)}\n`);
}

export function streamChatHandler() {
  return async (c: Context): Promise<Response> => {
    try {
      console.log("[API:Chat] Starting stream");
      const user = await authenticatedUser(c);
      const value = await ownedChat(c.req.param("id"), user.id);
      const body: { content?: unknown } = await c.req
        .json<{ content?: unknown }>()
        .catch(() => ({}));
      const prompt = typeof body.content === "string" ? body.content.trim() : "";
      if (!prompt) {
        throw new ChatHttpError(400, "invalid_request", "Content must not be empty.");
      }
      const providerConfig = chatProviderConfig();
      if (!providerConfig) {
        console.error(
          "[API:Chat] Chat provider is not configured; set CHAT_BASE_URL/CHAT_API_KEY " +
            "or OPENAI_BASE_URL/OPENAI_API_KEY",
        );
        throw new ChatHttpError(500, "configuration_error", "Chat provider is not configured.");
      }

      const priorRows = await db
        .select()
        .from(chatMessage)
        .where(eq(chatMessage.chatId, value.id))
        .orderBy(asc(chatMessage.sequence));
      const userModelMessage: ModelMessage = { role: "user", content: prompt };
      const [userRow] = await db
        .insert(chatMessage)
        .values({
          chatId: value.id,
          role: "user",
          content: [{ type: "text", text: prompt } satisfies ChatContentPart],
          modelMessage: userModelMessage,
        })
        .returning();
      if (!userRow) throw new Error("Message insert returned no row");

      const assistantId = crypto.randomUUID();
      const provider = createOpenAICompatible({
        name: "sarvam",
        baseURL: providerConfig.baseURL,
        apiKey: providerConfig.apiKey,
      });
      const result = streamText({
        model: provider(CHAT_MODEL),
        tools: createChatTools(),
        stopWhen: stepCountIs(3),
        messages: [
          ...priorRows.map((row) => row.modelMessage as ModelMessage),
          userModelMessage,
        ],
        abortSignal: c.req.raw.signal,
      });
      console.log("[API:Chat] Provider stream started");

      const stream = new ReadableStream<Uint8Array>({
        async start(controller) {
          const content: ChatContentPart[] = [];
          const partIndexes = new Map<string, number>();
          const reasoningStarted = new Map<string, number>();
          let finishReason: string | undefined;
          controller.enqueue(ndjson({ type: "start", messageId: assistantId }));

          try {
            for await (const part of result.fullStream) {
              switch (part.type) {
                case "reasoning-start":
                  reasoningStarted.set(part.id, performance.now());
                  partIndexes.set(part.id, content.length);
                  content.push({ type: "reasoning", reasoning: "", duration: 0 });
                  break;
                case "reasoning-delta": {
                  let index = partIndexes.get(part.id);
                  if (index === undefined) {
                    index = content.length;
                    partIndexes.set(part.id, index);
                    reasoningStarted.set(part.id, performance.now());
                    content.push({ type: "reasoning", reasoning: "", duration: 0 });
                  }
                  const current = content[index];
                  if (current?.type === "reasoning") current.reasoning += part.text;
                  controller.enqueue(ndjson({ type: "reasoning-delta", delta: part.text }));
                  break;
                }
                case "reasoning-end": {
                  const index = partIndexes.get(part.id);
                  const current = index === undefined ? undefined : content[index];
                  const started = reasoningStarted.get(part.id);
                  if (current?.type === "reasoning" && started !== undefined) {
                    current.duration = (performance.now() - started) / 1_000;
                  }
                  break;
                }
                case "text-start":
                  partIndexes.set(part.id, content.length);
                  content.push({ type: "text", text: "" });
                  break;
                case "text-delta": {
                  let index = partIndexes.get(part.id);
                  if (index === undefined) {
                    index = content.length;
                    partIndexes.set(part.id, index);
                    content.push({ type: "text", text: "" });
                  }
                  const current = content[index];
                  if (current?.type === "text") current.text += part.text;
                  controller.enqueue(ndjson({ type: "text-delta", delta: part.text }));
                  break;
                }
                case "tool-call": {
                  const value: ChatContentPart = {
                    type: "tool_call",
                    toolCallId: part.toolCallId,
                    toolName: part.toolName,
                    label: toolLabel(part.toolName, false),
                  };
                  content.push(value);
                  controller.enqueue(ndjson({
                    type: "tool-call",
                    toolCallId: value.toolCallId,
                    toolName: value.toolName,
                    label: value.label,
                  }));
                  break;
                }
                case "tool-result": {
                  if (part.preliminary) break;
                  const value: ChatContentPart = {
                    type: "tool-result",
                    toolCallId: part.toolCallId,
                    toolName: part.toolName,
                    label: toolLabel(part.toolName, true),
                  };
                  content.push(value);
                  controller.enqueue(ndjson({
                    type: "tool-result",
                    toolCallId: value.toolCallId,
                    toolName: value.toolName,
                    label: value.label,
                  }));
                  break;
                }
                case "finish":
                  finishReason = part.finishReason;
                  break;
                case "error":
                  throw part.error;
                case "abort":
                  throw new Error(part.reason ?? "Stream aborted");
              }
            }

            const responseMessages = await result.responseMessages;
            const assistantModelMessage = responseMessages.findLast(
              (message) => message.role === "assistant",
            );
            if (!assistantModelMessage) throw new Error("Provider returned no assistant message");
            const now = new Date();
            const assistantRow = await db.transaction(async (tx) => {
              const [inserted] = await tx
                .insert(chatMessage)
                .values({
                  id: assistantId,
                  chatId: value.id,
                  role: "assistant",
                  content,
                  modelMessage: assistantModelMessage,
                })
                .returning();
              await tx.update(chat).set({ updatedAt: now }).where(eq(chat.id, value.id));
              if (!inserted) throw new Error("Assistant insert returned no row");
              return inserted;
            });
            controller.enqueue(
              ndjson({
                type: "end",
                outcome: "complete",
                finishReason,
                messages: [clientMessage(userRow), clientMessage(assistantRow)],
              }),
            );
          } catch (error) {
            console.error("[API:Chat] Stream failed", error);
            controller.enqueue(
              ndjson({
                type: "end",
                outcome: "failed",
                messages: [clientMessage(userRow)],
                error: { code: "stream_error", message: "The response could not be completed." },
              }),
            );
            console.log("[API:Chat] Stream completed");
          } finally {
            controller.close();
          }
        },
      });
      return new Response(stream, {
        headers: {
          "Content-Type": "application/x-ndjson; charset=utf-8",
          "Cache-Control": "no-cache, no-transform",
        },
      });
    } catch (error) {
      return errorResponse(c, error);
    }
  };
}
