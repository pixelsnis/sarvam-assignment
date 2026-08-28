import type { Context } from "hono";
import type { ContentfulStatusCode } from "hono/utils/http-status";

export class ChatHttpError extends Error {
  constructor(
    readonly status: 400 | 401 | 404 | 500,
    readonly code: string,
    message: string,
  ) {
    super(message);
  }
}

export function errorResponse(c: Context, error: unknown): Response {
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
