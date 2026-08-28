// handlers: project logic for this module.
import type { Context } from "hono";
import { errorResponse, TranscriptionHttpError } from "./errors";
import { createTranscriptionDependencies, requestTranscription } from "./provider";
import type { TranscriptionDependencies, TranscriptionUser } from "./types";
import { getAudioFile } from "./validation";

// Defines getAuthenticatedUser.
async function getAuthenticatedUser(
  c: Context,
  getSession: TranscriptionDependencies["getSession"],
): Promise<TranscriptionUser["user"]> {
  // 1. Resolve the session from the request headers.
  const session = await getSession(c.req.raw.headers);

  if (!session) {
    throw new TranscriptionHttpError(
      401,
      "unauthorized",
      "You must be signed in to transcribe audio.",
    );
  }

  return session.user;
}

// Exports createTranscriptionHandler.
export function createTranscriptionHandler(
  dependencies: TranscriptionDependencies = createTranscriptionDependencies(),
) {
  return async function transcribe(c: Context): Promise<Response> {
    try {
      // 1. Authenticate, validate the upload, and request the transcript.
      console.log("[API:Transcription] Starting request");
      await getAuthenticatedUser(c, dependencies.getSession);
      const file = await getAudioFile(c);
      const transcript = await requestTranscription(file, dependencies);
      return c.json({ transcript });
    } catch (error) {
      return errorResponse(c, error);
    }
  };
}
