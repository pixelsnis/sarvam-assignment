import { Hono } from "hono";
import { auth } from "./auth";
import { createTranscriptionHandler } from "./transcriptions";

const app = new Hono();

app.get("/health", (c) => c.json({ status: "ok" }));

app.post("/transcriptions", createTranscriptionHandler());

app.on(["GET", "POST"], "/auth/*", (c) => auth.handler(c.req.raw));

export default app;
