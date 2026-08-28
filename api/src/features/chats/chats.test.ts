// chats.test: project logic for this module.
import { describe, expect, test } from "bun:test";
import { chatProviderConfig } from "./config";
import { createChatTools, toolLabel } from "./tools";

describe("chat provider configuration", () => {
  test("falls back to OPENAI environment variables", () => {
    expect(
      chatProviderConfig({
        OPENAI_BASE_URL: "https://provider.example/v1",
        OPENAI_API_KEY: "openai-key",
      }),
    ).toEqual({
      baseURL: "https://provider.example/v1",
      apiKey: "openai-key",
    });
  });

  test("prefers CHAT environment variables when both names are present", () => {
    expect(
      chatProviderConfig({
        CHAT_BASE_URL: "https://chat.example/v1",
        CHAT_API_KEY: "chat-key",
        OPENAI_BASE_URL: "https://provider.example/v1",
        OPENAI_API_KEY: "openai-key",
      }),
    ).toEqual({
      baseURL: "https://chat.example/v1",
      apiKey: "chat-key",
    });
  });

  test("rejects incomplete provider configuration", () => {
    expect(chatProviderConfig({ OPENAI_BASE_URL: "https://provider.example/v1" })).toBeNull();
    expect(chatProviderConfig({ OPENAI_API_KEY: "openai-key" })).toBeNull();
  });
});

describe("chat tool labels", () => {
  test("uses friendly labels for known tools", () => {
    expect(toolLabel("read_file", false)).toBe("Reading files");
    expect(toolLabel("read_file", true)).toBe("Read files");
    expect(toolLabel("webSearch", false)).toBe("Searching the web");
    expect(toolLabel("webSearch", true)).toBe("Searched the web");
    expect(toolLabel("webExtract", false)).toBe("Extracting webpage content");
    expect(toolLabel("webExtract", true)).toBe("Extracted webpage content");
  });

  test("keeps unknown tool labels readable for future tools", () => {
    expect(toolLabel("search_web", false)).toBe("Using search web");
    expect(toolLabel("search_web", true)).toBe("Used search web");
  });
});

describe("chat tools", () => {
  test("exposes web search and web extract tools", () => {
    expect(Object.keys(createChatTools())).toEqual(["webSearch", "webExtract"]);
  });
});
