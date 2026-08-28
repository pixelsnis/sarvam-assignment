import { Hono } from "hono";
import { auth } from "./auth";
import { createChat, getChat, listChats, streamChat } from "./chat";

const app = new Hono();

app.get("/health", (c) => c.json({ status: "ok" }));

app.post("/chats/new", createChat);
app.get("/chats", listChats);
app.get("/chats/:id", getChat);
app.post("/chats/:id/stream", streamChat);

app.on(["GET", "POST"], "/auth/*", (c) => auth.handler(c.req.raw));

export default app;
