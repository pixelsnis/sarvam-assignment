// tools: project logic for this module.
import { tavilyExtract, tavilySearch } from "@tavily/ai-sdk";

// Exports toolLabel.
export function toolLabel(toolName: string, completed: boolean): string {
  const labels: Record<string, [string, string]> = {
    read_file: ["Reading files", "Read files"],
    webSearch: ["Searching the web", "Searched the web"],
    webExtract: ["Extracting webpage content", "Extracted webpage content"],
  };
  const configured = labels[toolName];
  if (configured) return configured[completed ? 1 : 0];
  const words = toolName.replaceAll("_", " ");
  return completed ? `Used ${words}` : `Using ${words}`;
}

// Exports createChatTools.
export function createChatTools() {
  return {
    webSearch: tavilySearch(),
    webExtract: tavilyExtract(),
  };
}
