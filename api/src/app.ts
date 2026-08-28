import { Hono } from "hono";
import { auth } from "./auth";
import { createChat, streamChat } from "./chat";

const app = new Hono();

app.get("/health", (c) => c.json({ status: "ok" }));

app.post("/chats/new", createChat);
app.post("/chats/:id/stream", streamChat);

app.on(["GET", "POST"], "/auth/*", (c) => auth.handler(c.req.raw));

export default app;
