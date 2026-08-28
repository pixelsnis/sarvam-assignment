import type { Context } from "hono";
import { TranscriptionHttpError } from "./errors";

export async function getAudioFile(c: Context): Promise<File> {
  let formData: FormData;

  try {
    formData = await c.req.formData();
  } catch {
    throw new TranscriptionHttpError(
      400,
      "invalid_request",
      "Request body must be multipart form data.",
    );
  }

  const file = formData.get("file");
  if (!(file instanceof File)) {
    throw new TranscriptionHttpError(
      400,
      "invalid_request",
      "Request must include an audio file in the file field.",
    );
  }

  if (file.size === 0) {
    throw new TranscriptionHttpError(
      400,
      "invalid_request",
      "The audio file must not be empty.",
    );
  }

  return file;
}

export function isTranscriptionPayload(
  payload: unknown,
): payload is { transcript: string } {
  if (typeof payload !== "object" || payload === null) {
    return false;
  }

  return "transcript" in payload && typeof payload.transcript === "string";
}
