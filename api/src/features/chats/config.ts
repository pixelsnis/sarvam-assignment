import type { ChatProviderConfig, ChatProviderEnvironment } from "./types";

export function chatProviderConfig(
  environment?: ChatProviderEnvironment,
): ChatProviderConfig | null {
  const values = environment ?? process.env;
  const baseURL = values.CHAT_BASE_URL || values.OPENAI_BASE_URL;
  const apiKey = values.CHAT_API_KEY || values.OPENAI_API_KEY;
  if (!baseURL || !apiKey) return null;
  return { baseURL, apiKey };
}
