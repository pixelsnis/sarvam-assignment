import { describe, expect, test } from "bun:test";
import { Hono } from "hono";
import type { LanguageModel, TextStreamPart, ToolSet } from "ai";
import {
  createChatHandlers,
  type ChatDependencies,
} from "./chat";

type StoredMessage = {
  id?: string;
  message: string;
  position: number;
  reasoningDurationSeconds?: number | null;
};

type StoredChat = {
  id: string;
  createdAt: Date;
  updatedAt: Date;
};

type FakeDatabase = {
  select: (selection?: Record<string, unknown>) => {
    from: () => {
      where: () => {
        limit: () => Promise<Array<{ id: string }>>;
        orderBy: () => Promise<StoredMessage[] | StoredChat[]>;
      };
    };
  };
  insert: () => {
    values: (values: Record<string, unknown>) => Promise<void>;
  };
  update: () => {
    set: (values: Record<string, unknown>) => {
      where: () => Promise<void>;
    };
  };
  transaction: (callback: (transaction: FakeDatabase) => Promise<void>) => Promise<void>;
};

function makePart(part: object): TextStreamPart<ToolSet> {
  return part as TextStreamPart<ToolSet>;
}

function makeStreamResult(parts: object[]) {
  return {
    fullStream: (async function* () {
      for (const part of parts) {
        yield makePart(part);
      }
    })(),
  };
}

function makeDependencies(options?: {
  authenticated?: boolean;
  chatExists?: boolean;
  chats?: StoredChat[];
  storedMessages?: StoredMessage[];
  streamParts?: object[];
  now?: () => number;
}) {
  const insertedChats: Array<{ id: string; userId: string }> = [];
  const insertedMessages: Array<{
    id: string;
    chatId: string;
    message: string;
    position: number;
    reasoningDurationSeconds: number | null;
  }> = [];
  let streamOptions:
    | { instructions: string; messages: Array<unknown> }
    | undefined;

  const storedMessages = (options?.storedMessages ?? []).map(
    (message, index) => ({
      id: message.id ?? `stored-message-${index}`,
      message: message.message,
      position: message.position,
      reasoningDurationSeconds: message.reasoningDurationSeconds ?? null,
    }),
  );
  const chats = options?.chats ?? [];
  const chatExists = options?.chatExists ?? true;

  const database = {} as FakeDatabase;

  database.select = (selection = {}) => ({
    from: () => ({
      where: () => ({
        limit: async () => (chatExists ? [{ id: "chat-1" }] : []),
        orderBy: async () =>
          "createdAt" in selection ? chats : storedMessages,
      }),
    }),
  });
  database.insert = () => {
    return {
      values: async (values: Record<string, unknown>) => {
        if (typeof values.message === "string") {
          insertedMessages.push({
            id: values.id as string,
            chatId: values.chatId as string,
            message: values.message,
            position: values.position as number,
            reasoningDurationSeconds: values.reasoningDurationSeconds as
              | number
              | null,
          });
        } else {
          insertedChats.push({
            id: values.id as string,
            userId: values.userId as string,
          });
        }
      },
    };
  };
  database.update = () => {
    return {
      set: () => ({
        where: async () => undefined,
      }),
    };
  };
  database.transaction = async (callback) => {
    await callback(database);
  };

  const dependencies: ChatDependencies = {
    database: database as unknown as ChatDependencies["database"],
    getSession: async () =>
      options?.authenticated === false
        ? null
        : { user: { id: "user-1" } },
    createModel: () => ({}) as LanguageModel,
    now: options?.now ?? (() => 0),
    streamText: ({ instructions, messages }) => {
      streamOptions = { instructions, messages };
      return makeStreamResult(
        options?.streamParts ?? [
          { type: "start" },
          { type: "text-delta", text: "Hello" },
          { type: "finish", finishReason: "stop" },
        ],
      );
    },
  };

  return {
    dependencies,
    insertedChats,
    insertedMessages,
    get streamOptions() {
      return streamOptions;
    },
  };
}

function makeApp(dependencies: ChatDependencies) {
  const app = new Hono();
  const handlers = createChatHandlers(dependencies);

  app.post("/chats/new", handlers.createChat);
  app.get("/chats", handlers.listChats);
  app.get("/chats/:id", handlers.getChat);
  app.post("/chats/:id/stream", handlers.streamChat);

  return app;
}

async function readEvents(response: Response): Promise<Array<Record<string, unknown>>> {
  const lines = (await response.text())
    .split("\n")
    .filter((line) => line.startsWith("data: "));

  return lines.map((line) => JSON.parse(line.slice("data: ".length)));
}

describe("chat routes", () => {
  test("lists authenticated chats by most recently updated", async () => {
    const chats = [
      {
        id: "chat-2",
        createdAt: new Date("2026-08-28T10:00:00.000Z"),
        updatedAt: new Date("2026-08-28T10:02:00.000Z"),
      },
      {
        id: "chat-1",
        createdAt: new Date("2026-08-28T09:00:00.000Z"),
        updatedAt: new Date("2026-08-28T09:01:00.000Z"),
      },
    ];
    const state = makeDependencies({ chats });
    const response = await makeApp(state.dependencies).request("/chats", {
      method: "GET",
    });

    expect(response.status).toBe(200);
    expect(await response.json()).toEqual([
      {
        id: "chat-2",
        createdAt: "2026-08-28T10:00:00.000Z",
        updatedAt: "2026-08-28T10:02:00.000Z",
      },
      {
        id: "chat-1",
        createdAt: "2026-08-28T09:00:00.000Z",
        updatedAt: "2026-08-28T09:01:00.000Z",
      },
    ]);
  });

  test("protects the chat list with authentication", async () => {
    const state = makeDependencies({ authenticated: false });
    const response = await makeApp(state.dependencies).request("/chats", {
      method: "GET",
    });

    expect(response.status).toBe(401);
    expect(await response.json()).toMatchObject({ code: "unauthorized" });
  });

  test("creates an authenticated chat", async () => {
    const state = makeDependencies();
    const response = await makeApp(state.dependencies).request("/chats/new", {
      method: "POST",
    });

    expect(response.status).toBe(201);
    expect(await response.json()).toEqual({ id: state.insertedChats[0]?.id });
    expect(state.insertedChats[0]?.userId).toBe("user-1");
  });

  test("gets an ordered flattened transcript", async () => {
    const state = makeDependencies({
      storedMessages: [
        {
          id: "user-message",
          position: 0,
          message: JSON.stringify({ role: "user", content: "Hello" }),
        },
        {
          id: "assistant-message",
          position: 1,
          reasoningDurationSeconds: 1.5,
          message: JSON.stringify({
            role: "assistant",
            content: [
              { type: "reasoning", text: "Hidden reasoning" },
              { type: "text", text: "Hi" },
              { type: "text", text: " there" },
            ],
          }),
        },
      ],
    });
    const response = await makeApp(state.dependencies).request(
      "/chats/chat-1",
      { method: "GET" },
    );

    expect(response.status).toBe(200);
    expect(await response.json()).toEqual({
      id: "chat-1",
      messages: [
        {
          id: "user-message",
          role: "user",
          text: "Hello",
        },
        {
          id: "assistant-message",
          role: "assistant",
          text: "Hi there",
          reasoningDurationSeconds: 1.5,
        },
      ],
    });
  });

  test("protects GET transcripts with authentication and ownership checks", async () => {
    const unauthenticated = makeDependencies({ authenticated: false });
    const unauthenticatedResponse = await makeApp(
      unauthenticated.dependencies,
    ).request("/chats/chat-1", { method: "GET" });
    expect(unauthenticatedResponse.status).toBe(401);

    const inaccessible = makeDependencies({ chatExists: false });
    const inaccessibleResponse = await makeApp(
      inaccessible.dependencies,
    ).request("/chats/chat-1", { method: "GET" });
    expect(inaccessibleResponse.status).toBe(404);
  });

  test("rejects invalid persisted history on GET", async () => {
    const state = makeDependencies({
      storedMessages: [{ position: 0, message: "not json" }],
    });
    const response = await makeApp(state.dependencies).request(
      "/chats/chat-1",
      { method: "GET" },
    );

    expect(response.status).toBe(500);
    expect(await response.json()).toMatchObject({
      code: "invalid_chat_history",
    });
  });

  test("streams ordered history and persists the completed assistant turn", async () => {
    const state = makeDependencies({
      storedMessages: [
        {
          position: 0,
          message: JSON.stringify({ role: "user", content: "Earlier" }),
        },
      ],
      streamParts: [
        { type: "start" },
        {
          type: "tool-call",
          toolCallId: "tool-1",
          toolName: "read_file",
          input: {},
          dynamic: true,
        },
        {
          type: "tool-result",
          toolCallId: "tool-1",
          toolName: "read_file",
          output: "ok",
          dynamic: true,
        },
        { type: "text-delta", text: "Hello" },
        { type: "text-delta", text: " there" },
        { type: "finish", finishReason: "stop" },
      ],
      now: (() => {
        const values = [10_000, 11_250];
        return () => values.shift() ?? 11_250;
      })(),
    });
    const response = await makeApp(state.dependencies).request(
      "/chats/chat-1/stream",
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ text: "Current question" }),
      },
    );

    expect(response.status).toBe(200);
    expect(response.headers.get("content-type")).toContain("text/event-stream");
    expect(state.streamOptions?.instructions).toBe(
      "You are a general-use work agent. Respond conversationally, neutrally, and directly.",
    );
    expect(state.streamOptions?.messages).toEqual([
      { role: "user", content: "Earlier" },
      { role: "user", content: "Current question" },
    ]);

    const events = await readEvents(response);
    expect(events.map((event) => event.type)).toEqual([
      "start",
      "status",
      "tool-call",
      "tool-result",
      "text-delta",
      "text-delta",
      "status",
      "end",
    ]);
    expect(events[0]).toEqual({ type: "start", sessionId: "chat-1" });
    expect(events[2]).toMatchObject({
      type: "tool-call",
      toolId: "tool-1",
      toolName: "read_file",
      label: "Reading files",
    });
    expect(events[3]).toMatchObject({
      type: "tool-result",
      toolId: "tool-1",
      toolName: "read_file",
      label: "Reading files",
    });
    expect(events.at(-1)).toEqual({
      type: "end",
      sessionId: "chat-1",
      finishReason: "stop",
      messages: [
        {
          id: state.insertedMessages[0]?.id,
          role: "user",
          text: "Current question",
        },
        {
          id: state.insertedMessages[1]?.id,
          role: "assistant",
          text: "Hello there",
          reasoningDurationSeconds: 1.25,
        },
      ],
    });

    expect(state.insertedMessages).toHaveLength(2);
    expect(JSON.parse(state.insertedMessages[0]!.message)).toEqual({
      role: "user",
      content: "Current question",
    });
    expect(JSON.parse(state.insertedMessages[1]!.message)).toEqual({
      role: "assistant",
      content: "Hello there",
    });
    expect(state.insertedMessages[1]!.reasoningDurationSeconds).toBe(1.25);
    expect(state.insertedMessages.map((message) => message.position)).toEqual([
      1,
      2,
    ]);
  });

  test("keeps only the user message when the model stream fails", async () => {
    const state = makeDependencies({
      streamParts: [
        { type: "start" },
        { type: "text-delta", text: "Partial" },
        { type: "error", error: new Error("provider failed") },
      ],
    });
    const response = await makeApp(state.dependencies).request(
      "/chats/chat-1/stream",
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ text: "Try this" }),
      },
    );

    const events = await readEvents(response);
    expect(events.map((event) => event.type)).toEqual([
      "start",
      "status",
      "text-delta",
      "status",
    ]);
    expect(events.at(-1)).toEqual({ type: "status", status: "error" });
    expect(state.insertedMessages).toHaveLength(1);
    expect(JSON.parse(state.insertedMessages[0]!.message)).toEqual({
      role: "user",
      content: "Try this",
    });
  });

  test("returns a null reasoning duration when no text delta is emitted", async () => {
    const state = makeDependencies({
      streamParts: [{ type: "start" }, { type: "finish", finishReason: "stop" }],
      now: (() => {
        const values = [2_000];
        return () => values.shift() ?? 2_000;
      })(),
    });
    const response = await makeApp(state.dependencies).request(
      "/chats/chat-1/stream",
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ text: "No text" }),
      },
    );

    const events = await readEvents(response);
    expect(events.at(-1)).toMatchObject({
      type: "end",
      messages: [
        { role: "user", text: "No text" },
        {
          role: "assistant",
          text: "",
          reasoningDurationSeconds: null,
        },
      ],
    });
    expect(state.insertedMessages[1]?.reasoningDurationSeconds).toBeNull();
  });

  test("rejects invalid persisted history before accepting a new turn", async () => {
    const state = makeDependencies({
      storedMessages: [{ position: 0, message: "not json" }],
    });
    const response = await makeApp(state.dependencies).request(
      "/chats/chat-1/stream",
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ text: "Do not send this" }),
      },
    );

    expect(response.status).toBe(500);
    expect(state.insertedMessages).toHaveLength(0);
    expect(state.streamOptions).toBeUndefined();
  });

  test("rejects unauthenticated, invalid, and inaccessible requests", async () => {
    const unauthenticated = makeDependencies({ authenticated: false });
    const unauthenticatedResponse = await makeApp(
      unauthenticated.dependencies,
    ).request("/chats/new", { method: "POST" });
    expect(unauthenticatedResponse.status).toBe(401);

    const invalid = makeDependencies();
    const invalidResponse = await makeApp(invalid.dependencies).request(
      "/chats/chat-1/stream",
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ text: "   " }),
      },
    );
    expect(invalidResponse.status).toBe(400);

    const inaccessible = makeDependencies({ chatExists: false });
    const inaccessibleResponse = await makeApp(
      inaccessible.dependencies,
    ).request("/chats/chat-1/stream", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ text: "Hello" }),
    });
    expect(inaccessibleResponse.status).toBe(404);
  });
});
