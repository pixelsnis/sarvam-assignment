import { and, asc, desc, eq } from "drizzle-orm";
import type { ModelMessage } from "ai";
import { db } from "../../db";
import { chat, chatMessage } from "../../db/schema";
import { ChatHttpError } from "./errors";
import type { ChatContentPart, ClientChatMessage } from "./types";

export type ChatMessageRow = typeof chatMessage.$inferSelect;

export async function createChat(userId: string) {
  const [created] = await db.insert(chat).values({ userId }).returning();
  if (!created) throw new Error("Chat insert returned no row");
  return created;
}

export async function listChats(userId: string) {
  return db
    .select({ id: chat.id, createdAt: chat.createdAt, updatedAt: chat.updatedAt })
    .from(chat)
    .where(eq(chat.userId, userId))
    .orderBy(desc(chat.updatedAt));
}

export async function ownedChat(id: string | undefined, userId: string) {
  if (!id) throw new ChatHttpError(404, "chat_not_found", "Chat not found.");
  const [value] = await db
    .select()
    .from(chat)
    .where(and(eq(chat.id, id), eq(chat.userId, userId)))
    .limit(1);
  if (!value) throw new ChatHttpError(404, "chat_not_found", "Chat not found.");
  return value;
}

export async function listMessages(chatId: string) {
  return db
    .select()
    .from(chatMessage)
    .where(eq(chatMessage.chatId, chatId))
    .orderBy(asc(chatMessage.sequence));
}

export async function createUserMessage(
  chatId: string,
  prompt: string,
  modelMessage: ModelMessage,
) {
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

export async function saveAssistantMessage(
  chatId: string,
  assistantId: string,
  content: ChatContentPart[],
  modelMessage: ModelMessage,
) {
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

export function clientMessage(row: ChatMessageRow): ClientChatMessage {
  return {
    id: row.id,
    role: row.role,
    content: row.content as ChatContentPart[],
    createdAt: row.createdAt,
  };
}
