// errors: project logic for this module.
import type { Context } from "hono";
import type { ContentfulStatusCode } from "hono/utils/http-status";

export class TranscriptionHttpError extends Error {
  constructor(
    readonly status: 400 | 401 | 500 | 502,
    readonly code: string,
    message: string,
  ) {
    super(message);
    this.name = "TranscriptionHttpError";
  }
}

// Exports errorResponse.
export function errorResponse(c: Context, error: unknown): Response {
  if (!(error instanceof TranscriptionHttpError)) {
    console.error("[API:Transcription] Request failed", error);
  }

  const transcriptionError =
    error instanceof TranscriptionHttpError
      ? error
      : new TranscriptionHttpError(
          500,
          "internal_error",
          "The server could not complete the transcription request.",
        );

  return c.json(
    {
      code: transcriptionError.code,
      message: transcriptionError.message,
    },
    transcriptionError.status as ContentfulStatusCode,
  );
}
