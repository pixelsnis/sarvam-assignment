import type { Context } from "hono";
import type { ContentfulStatusCode } from "hono/utils/http-status";
import { auth } from "./auth";

const SARVAM_SPEECH_TO_TEXT_URL = "https://api.sarvam.ai/speech-to-text";
const SARVAM_MODEL = "saaras:v3";

type TranscriptionUser = { user: { id: string } };
type TranscriptionFetcher = (
  input: string | URL | Request,
  init?: RequestInit,
) => Promise<Response>;

export type TranscriptionDependencies = {
  getSession: (headers: Headers) => Promise<TranscriptionUser | null>;
  fetch: TranscriptionFetcher;
  sarvamApiKey: string | undefined;
};

class TranscriptionHttpError extends Error {
  constructor(
    readonly status: 400 | 401 | 500 | 502,
    readonly code: string,
    message: string,
  ) {
    super(message);
    this.name = "TranscriptionHttpError";
  }
}

function errorResponse(c: Context, error: unknown): Response {
  if (!(error instanceof TranscriptionHttpError)) {
    console.error("Transcription request failed", error);
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

async function getAuthenticatedUser(
  c: Context,
  getSession: TranscriptionDependencies["getSession"],
): Promise<TranscriptionUser["user"]> {
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

async function getAudioFile(c: Context): Promise<File> {
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

function isTranscriptionPayload(
  payload: unknown,
): payload is { transcript: string } {
  if (typeof payload !== "object" || payload === null) {
    return false;
  }

  return (
    "transcript" in payload &&
    typeof payload.transcript === "string"
  );
}

function defaultGetSession(
  headers: Headers,
): Promise<TranscriptionUser | null> {
  return auth.api.getSession({ headers });
}

function createTranscriptionDependencies(): TranscriptionDependencies {
  return {
    getSession: defaultGetSession,
    fetch,
    sarvamApiKey: process.env.SARVAM_API_KEY,
  };
}

export function createTranscriptionHandler(
  dependencies: TranscriptionDependencies = createTranscriptionDependencies(),
) {
  return async function transcribe(c: Context): Promise<Response> {
    try {
      await getAuthenticatedUser(c, dependencies.getSession);
      const file = await getAudioFile(c);

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
        console.error("Sarvam transcription request failed", error);
        throw new TranscriptionHttpError(
          502,
          "upstream_error",
          "The transcription provider could not be reached.",
        );
      }

      const payload = await response.json().catch(() => undefined);

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

      return c.json({ transcript: payload.transcript });
    } catch (error) {
      return errorResponse(c, error);
    }
  };
}
