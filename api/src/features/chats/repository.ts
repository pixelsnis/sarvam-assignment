// repository: project logic for this module.
import { and, asc, desc, eq } from "drizzle-orm";
import type { ModelMessage } from "ai";
import { db } from "../../db";
import { chat, chatMessage } from "../../db/schema";
import { ChatHttpError } from "./errors";
import type { ChatContentPart, ClientChatMessage } from "./types";

export type ChatMessageRow = typeof chatMessage.$inferSelect;

// Exports createChat.
export async function createChat(userId: string) {
  // 1. Insert the chat for the authenticated user.
  const [created] = await db.insert(chat).values({ userId }).returning();
  if (!created) throw new Error("Chat insert returned no row");
  return created;
}

// Exports listChats.
export async function listChats(userId: string) {
  // 1. Return the user's chats with the newest activity first.
  return db
    .select({ id: chat.id, createdAt: chat.createdAt, updatedAt: chat.updatedAt })
    .from(chat)
    .where(eq(chat.userId, userId))
    .orderBy(desc(chat.updatedAt));
}

// Exports ownedChat.
export async function ownedChat(id: string | undefined, userId: string) {
  // 1. Require both a chat ID and matching owner.
  if (!id) throw new ChatHttpError(404, "chat_not_found", "Chat not found.");
  const [value] = await db
    .select()
    .from(chat)
    .where(and(eq(chat.id, id), eq(chat.userId, userId)))
    .limit(1);
  if (!value) throw new ChatHttpError(404, "chat_not_found", "Chat not found.");
  return value;
}

// Exports listMessages.
export async function listMessages(chatId: string) {
  // 1. Preserve message order when reading the conversation.
  return db
    .select()
    .from(chatMessage)
    .where(eq(chatMessage.chatId, chatId))
    .orderBy(asc(chatMessage.sequence));
}

// Exports createUserMessage.
export async function createUserMessage(
  chatId: string,
  prompt: string,
  modelMessage: ModelMessage,
) {
  // 1. Store the prompt in both client and model formats.
  const [userRow] = await db
    .insert(chatMessage)
    .values({
      chatId,
      role: "user",
      content: [{ type: "text", text: prompt } satisfies ChatContentPart],
      modelMessage,
    })
    .returning();
  if (!userRow) throw new Error("Message insert returned no row");
  return userRow;
}

// Exports saveAssistantMessage.
export async function saveAssistantMessage(
  chatId: string,
  assistantId: string,
  content: ChatContentPart[],
  modelMessage: ModelMessage,
) {
  // 1. Save the assistant response and update chat activity atomically.
  const now = new Date();
  return db.transaction(async (tx) => {
    const [inserted] = await tx
      .insert(chatMessage)
      .values({
        id: assistantId,
        chatId,
        role: "assistant",
        content,
        modelMessage,
      })
      .returning();
    await tx.update(chat).set({ updatedAt: now }).where(eq(chat.id, chatId));
    if (!inserted) throw new Error("Assistant insert returned no row");
    return inserted;
  });
}

// Exports clientMessage.
export function clientMessage(row: ChatMessageRow): ClientChatMessage {
  // 1. Expose only the fields required by the client.
  return {
    id: row.id,
    role: row.role,
    content: row.content as ChatContentPart[],
    createdAt: row.createdAt,
  };
}
