import { describe, expect, test } from "bun:test";
import { Hono } from "hono";
import {
  createTranscriptionHandler,
  type TranscriptionDependencies,
} from "./index";

function makeAudioFormData(
  file: File | string | null = new File(["audio"], "sample.m4a", {
    type: "audio/mp4",
  }),
): FormData {
  const formData = new FormData();
  if (file !== null) {
    formData.set("file", file);
  }
  return formData;
}

function makeApp(options?: {
  authenticated?: boolean;
  sarvamApiKey?: string;
  fetch?: TranscriptionDependencies["fetch"];
}) {
  const app = new Hono();
  const state = {
    fetchCalls: [] as Array<{ input: string | URL | Request; init?: RequestInit }>,
  };
  const dependencies: TranscriptionDependencies = {
    getSession: async () =>
      options?.authenticated === false ? null : { user: { id: "user-1" } },
    fetch:
      options?.fetch ??
      (async (input, init) => {
        state.fetchCalls.push({ input, init });
        return Response.json({ transcript: "नमस्ते" });
      }),
    sarvamApiKey:
      options && "sarvamApiKey" in options ? options.sarvamApiKey : "sarvam-test-key",
  };

  app.post("/transcriptions", createTranscriptionHandler(dependencies));

  return { app, state };
}

describe("transcription route", () => {
  test("requires authentication before forwarding audio", async () => {
    const { app, state } = makeApp({ authenticated: false });
    const response = await app.request("/transcriptions", {
      method: "POST",
      body: makeAudioFormData(),
    });

    expect(response.status).toBe(401);
    expect(await response.json()).toMatchObject({ code: "unauthorized" });
    expect(state.fetchCalls).toHaveLength(0);
  });

  test("rejects requests without an audio file", async () => {
    const { app } = makeApp();
    const response = await app.request("/transcriptions", {
      method: "POST",
      body: makeAudioFormData(null),
    });

    expect(response.status).toBe(400);
    expect(await response.json()).toMatchObject({ code: "invalid_request" });
  });

  test("rejects non-file and empty-file uploads", async () => {
    const { app: nonFileApp } = makeApp();
    const nonFileResponse = await nonFileApp.request("/transcriptions", {
      method: "POST",
      body: makeAudioFormData("not-a-file"),
    });

    expect(nonFileResponse.status).toBe(400);

    const { app: emptyFileApp } = makeApp();
    const emptyFileResponse = await emptyFileApp.request("/transcriptions", {
      method: "POST",
      body: makeAudioFormData(new File([], "empty.m4a", { type: "audio/mp4" })),
    });

    expect(emptyFileResponse.status).toBe(400);
  });

  test("forwards the file and Saaras model and returns the transcript", async () => {
    const { app, state } = makeApp();
    const response = await app.request("/transcriptions", {
      method: "POST",
      body: makeAudioFormData(),
    });

    expect(response.status).toBe(200);
    expect(await response.json()).toEqual({ transcript: "नमस्ते" });
    expect(state.fetchCalls).toHaveLength(1);

    const call = state.fetchCalls[0]!;
    expect(call.input).toBe("https://api.sarvam.ai/speech-to-text");
    expect(call.init?.method).toBe("POST");
    expect(call.init?.headers).toEqual({
      "api-subscription-key": "sarvam-test-key",
      Accept: "application/json",
    });

    const body = call.init?.body as FormData;
    expect(body.get("model")).toBe("saaras:v3");
    expect(body.get("file")).toBeInstanceOf(File);
    expect((body.get("file") as File).name).toBe("sample.m4a");
  });

  test("reports missing Sarvam configuration", async () => {
    const { app } = makeApp({ sarvamApiKey: undefined });
    const response = await app.request("/transcriptions", {
      method: "POST",
      body: makeAudioFormData(),
    });

    expect(response.status).toBe(500);
    expect(await response.json()).toMatchObject({
      code: "configuration_error",
    });
  });

  test("maps provider failures to an upstream error", async () => {
    const { app } = makeApp({
      fetch: async () => new Response("provider failure", { status: 503 }),
    });
    const response = await app.request("/transcriptions", {
      method: "POST",
      body: makeAudioFormData(),
    });

    expect(response.status).toBe(502);
    expect(await response.json()).toMatchObject({ code: "upstream_error" });
  });

  test("rejects a successful provider response without a transcript", async () => {
    const { app } = makeApp({
      fetch: async () => Response.json({ request_id: "request-1" }),
    });
    const response = await app.request("/transcriptions", {
      method: "POST",
      body: makeAudioFormData(),
    });

    expect(response.status).toBe(502);
    expect(await response.json()).toMatchObject({ code: "upstream_error" });
  });
});
