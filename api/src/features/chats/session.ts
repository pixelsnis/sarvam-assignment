import type { Context } from "hono";
import { auth } from "../auth";
import { ChatHttpError } from "./errors";

type Session = { user: { id: string } };

export async function authenticatedUser(c: Context): Promise<Session["user"]> {
  console.log("[API:Chat] Checking session");
  const session = await auth.api.getSession({ headers: c.req.raw.headers });
  if (!session) {
    throw new ChatHttpError(401, "unauthorized", "You must be signed in.");
  }
  return session.user;
}
