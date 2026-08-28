import { describe, expect, test } from "bun:test";
import { toolLabel } from "./chats";

describe("chat tool labels", () => {
  test("uses friendly labels for known tools", () => {
    expect(toolLabel("read_file", false)).toBe("Reading files");
    expect(toolLabel("read_file", true)).toBe("Read files");
  });

  test("keeps unknown tool labels readable for future tools", () => {
    expect(toolLabel("search_web", false)).toBe("Using search web");
    expect(toolLabel("search_web", true)).toBe("Used search web");
  });
});
