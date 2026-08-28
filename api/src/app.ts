import { Hono } from "hono";
import { auth } from "./auth";
import { createTranscriptionHandler } from "./transcriptions";
import {
  createChatHandler,
  getChatHandler,
  listChatsHandler,
  streamChatHandler,
} from "./chats";

const app = new Hono();

app.use("*", async (c, next) => {
  console.log(`[API] ${c.req.method} ${new URL(c.req.url).pathname}`);
  await next();
});

app.get("/health", (c) => c.json({ status: "ok" }));

app.post("/transcriptions", createTranscriptionHandler());

app.post("/chats/new", createChatHandler());
app.get("/chats/list", listChatsHandler());
app.get("/chats/:id", getChatHandler());
app.post("/chats/:id/stream", streamChatHandler());

app.on(["GET", "POST"], "/auth/*", (c) => auth.handler(c.req.raw));

export default app;
