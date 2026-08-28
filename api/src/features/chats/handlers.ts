import { createOpenAICompatible } from "@ai-sdk/openai-compatible";
import type { Context } from "hono";
import { stepCountIs, streamText, type ModelMessage } from "ai";
import { chatProviderConfig } from "./config";
import { errorResponse, ChatHttpError } from "./errors";
import {
  clientMessage,
  createChat,
  createUserMessage,
  listChats,
  listMessages,
  ownedChat,
} from "./repository";
import { authenticatedUser } from "./session";
import { createChatStream } from "./stream";
import { createChatTools } from "./tools";

const CHAT_MODEL = "sarvam-105b";

export function createChatHandler() {
  return async (c: Context): Promise<Response> => {
    try {
      console.log("[API:Chat] Creating chat");
      const user = await authenticatedUser(c);
      const created = await createChat(user.id);
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
      return c.json({ chats: await listChats(user.id) });
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
      const rows = await listMessages(value.id);
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

      const priorRows = await listMessages(value.id);
      const userModelMessage: ModelMessage = { role: "user", content: prompt };
      const userRow = await createUserMessage(value.id, prompt, userModelMessage);

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

      const stream = createChatStream({
        result,
        assistantId,
        chatId: value.id,
        userRow,
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
