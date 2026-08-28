// provider: project logic for this module.
import { auth } from "../auth";
import { TranscriptionHttpError } from "./errors";
import type { TranscriptionDependencies, TranscriptionUser } from "./types";
import { isTranscriptionPayload } from "./validation";

const SARVAM_SPEECH_TO_TEXT_URL = "https://api.sarvam.ai/speech-to-text";
const SARVAM_MODEL = "saaras:v3";

// Defines defaultGetSession.
function defaultGetSession(headers: Headers): Promise<TranscriptionUser | null> {
  return auth.api.getSession({ headers });
}

// Exports createTranscriptionDependencies.
export function createTranscriptionDependencies(): TranscriptionDependencies {
  return {
    getSession: defaultGetSession,
    fetch,
    sarvamApiKey: process.env.SARVAM_API_KEY,
  };
}

// Exports requestTranscription.
export async function requestTranscription(
  file: File,
  dependencies: TranscriptionDependencies,
): Promise<string> {
  // 1. Fail early when the upstream provider is not configured.
  if (!dependencies.sarvamApiKey) {
    throw new TranscriptionHttpError(
      500,
      "configuration_error",
      "SARVAM_API_KEY is required for transcription.",
    );
  }

  const body = new FormData();
  body.set("file", file, file.name || "audio");
  body.set("model", SARVAM_MODEL);

  // 2. Send the audio file to Sarvam's speech-to-text endpoint.
  let response: Response;
  try {
    response = await dependencies.fetch(SARVAM_SPEECH_TO_TEXT_URL, {
      method: "POST",
      headers: {
        "api-subscription-key": dependencies.sarvamApiKey,
        Accept: "application/json",
      },
      body,
    });
  } catch (error) {
    console.error("[API:Transcription] Provider request failed", error);
    throw new TranscriptionHttpError(
      502,
      "upstream_error",
      "The transcription provider could not be reached.",
    );
  }

  const payload = await response.json().catch(() => undefined);

  // 3. Normalize upstream failures and validate the response shape.
  if (!response.ok) {
    throw new TranscriptionHttpError(
      502,
      "upstream_error",
      "The transcription provider rejected the audio.",
    );
  }

  if (!isTranscriptionPayload(payload)) {
    throw new TranscriptionHttpError(
      502,
      "upstream_error",
      "The transcription provider returned an invalid response.",
    );
  }

  return payload.transcript;
}
