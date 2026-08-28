import { Hono } from "hono";
import { auth } from "./auth";

const app = new Hono();

app.get("/health", (c) => c.json({ status: "ok" }));

app.on(["GET", "POST"], "/auth/*", (c) => auth.handler(c.req.raw));

export default app;
