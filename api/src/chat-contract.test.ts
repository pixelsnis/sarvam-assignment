import { describe, expect, test } from "bun:test";
import {
  chatRequestSchema,
  decodeStoredMessages,
  getToolLabel,
  InvalidChatHistoryError,
} from "./chat-contract";

describe("chat request contract", () => {
  test("trims valid text", () => {
    expect(chatRequestSchema.parse({ text: "  Hello  " })).toEqual({
      text: "Hello",
    });
  });

  test("rejects empty text and removed attachment fields", () => {
    expect(chatRequestSchema.safeParse({ text: "   " }).success).toBe(false);
    expect(
      chatRequestSchema.safeParse({ text: "Hello", files: [] }).success,
    ).toBe(false);
  });
});

describe("stored chat history", () => {
  test("decodes and validates JSON-stringified model messages", () => {
    const messages = [
      { role: "user" as const, content: "Hello" },
      { role: "assistant" as const, content: "Hi there" },
    ];

    expect(
      decodeStoredMessages(messages.map((message) => JSON.stringify(message))),
    ).toEqual(messages);
  });

  test("rejects invalid JSON and invalid model messages", () => {
    expect(() => decodeStoredMessages(["not json"])).toThrow(
      InvalidChatHistoryError,
    );
    expect(() =>
      decodeStoredMessages([JSON.stringify({ role: "user" })]),
    ).toThrow(InvalidChatHistoryError);
  });
});

describe("tool labels", () => {
  test("maps known tools to UI-friendly labels", () => {
    expect(getToolLabel("read_file")).toBe("Reading files");
  });

  test("provides a readable fallback for future tools", () => {
    expect(getToolLabel("write_file")).toBe("Write file");
  });
});
