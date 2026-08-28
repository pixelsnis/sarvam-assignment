import { describe, expect, test } from "bun:test";
import { Hono } from "hono";
import type { LanguageModel, TextStreamPart, ToolSet } from "ai";
import {
  createChatHandlers,
  type ChatDependencies,
} from "./chat";

type StoredMessage = {
  message: string;
  position: number;
};

type FakeDatabase = {
  select: () => {
    from: () => {
      where: () => {
        limit: () => Promise<Array<{ id: string }>>;
        orderBy: () => Promise<StoredMessage[]>;
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
  storedMessages?: StoredMessage[];
  streamParts?: object[];
}) {
  const insertedChats: Array<{ id: string; userId: string }> = [];
  const insertedMessages: Array<{
    chatId: string;
    message: string;
    position: number;
  }> = [];
  let streamOptions:
    | { instructions: string; messages: Array<unknown> }
    | undefined;

  const storedMessages = options?.storedMessages ?? [];
  const chatExists = options?.chatExists ?? true;

  const database = {} as FakeDatabase;

  database.select = () => ({
    from: () => ({
      where: () => ({
        limit: async () => (chatExists ? [{ id: "chat-1" }] : []),
        orderBy: async () => storedMessages,
      }),
    }),
  });
  database.insert = () => {
    return {
      values: async (values: Record<string, unknown>) => {
        if (typeof values.message === "string") {
          insertedMessages.push({
            chatId: values.chatId as string,
            message: values.message,
            position: values.position as number,
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
  test("creates an authenticated chat", async () => {
    const state = makeDependencies();
    const response = await makeApp(state.dependencies).request("/chats/new", {
      method: "POST",
    });

    expect(response.status).toBe(201);
    expect(await response.json()).toEqual({ id: state.insertedChats[0]?.id });
    expect(state.insertedChats[0]?.userId).toBe("user-1");
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
