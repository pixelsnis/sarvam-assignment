// validation: project logic for this module.
import type { Context } from "hono";
import { TranscriptionHttpError } from "./errors";

// Exports getAudioFile.
export async function getAudioFile(c: Context): Promise<File> {
  // 1. Parse the multipart form and require a non-empty audio file.
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

// Exports isTranscriptionPayload.
export function isTranscriptionPayload(
  payload: unknown,
): payload is { transcript: string } {
  if (typeof payload !== "object" || payload === null) {
    return false;
  }

  return "transcript" in payload && typeof payload.transcript === "string";
}
