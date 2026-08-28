// stream: project logic for this module.
import { streamText, type StreamTextResult, type ToolSet } from "ai";
import { clientMessage, saveAssistantMessage, type ChatMessageRow } from "./repository";
import { toolLabel } from "./tools";
import type { ChatContentPart, ChatStreamChunk } from "./types";

// Defines ndjson.
function ndjson(chunk: ChatStreamChunk): Uint8Array {
  return new TextEncoder().encode(`${JSON.stringify(chunk)}\n`);
}

type ChatStreamOptions<TOOLS extends ToolSet> = {
  result: StreamTextResult<TOOLS, any, any>;
  assistantId: string;
  chatId: string;
  userRow: ChatMessageRow;
};

// Exports createChatStream.
export function createChatStream<TOOLS extends ToolSet>({
  result,
  assistantId,
  chatId,
  userRow,
}: ChatStreamOptions<TOOLS>): ReadableStream<Uint8Array> {
  return new ReadableStream<Uint8Array>({
    async start(controller) {
      // 1. Track provider parts while announcing the assistant message.
      const content: ChatContentPart[] = [];
      const partIndexes = new Map<string, number>();
      const reasoningStarted = new Map<string, number>();
      let finishReason: string | undefined;
      controller.enqueue(ndjson({ type: "start", messageId: assistantId }));

      try {
        for await (const part of result.fullStream) {
          // 2. Forward deltas and collect the complete assistant content.
          switch (part.type) {
            case "reasoning-start":
              reasoningStarted.set(part.id, performance.now());
              partIndexes.set(part.id, content.length);
              content.push({ type: "reasoning", reasoning: "", duration: 0 });
              break;
            case "reasoning-delta": {
              let index = partIndexes.get(part.id);
              if (index === undefined) {
                index = content.length;
                partIndexes.set(part.id, index);
                reasoningStarted.set(part.id, performance.now());
                content.push({ type: "reasoning", reasoning: "", duration: 0 });
              }
              const current = content[index];
              if (current?.type === "reasoning") current.reasoning += part.text;
              controller.enqueue(ndjson({ type: "reasoning-delta", delta: part.text }));
              break;
            }
            case "reasoning-end": {
              const index = partIndexes.get(part.id);
              const current = index === undefined ? undefined : content[index];
              const started = reasoningStarted.get(part.id);
              if (current?.type === "reasoning" && started !== undefined) {
                current.duration = (performance.now() - started) / 1_000;
              }
              break;
            }
            case "text-start":
              partIndexes.set(part.id, content.length);
              content.push({ type: "text", text: "" });
              break;
            case "text-delta": {
              let index = partIndexes.get(part.id);
              if (index === undefined) {
                index = content.length;
                partIndexes.set(part.id, index);
                content.push({ type: "text", text: "" });
              }
              const current = content[index];
              if (current?.type === "text") current.text += part.text;
              controller.enqueue(ndjson({ type: "text-delta", delta: part.text }));
              break;
            }
            case "tool-call": {
              const value: ChatContentPart = {
                type: "tool_call",
                toolCallId: part.toolCallId,
                toolName: part.toolName,
                label: toolLabel(part.toolName, false),
              };
              content.push(value);
              controller.enqueue(
                ndjson({
                  type: "tool-call",
                  toolCallId: value.toolCallId,
                  toolName: value.toolName,
                  label: value.label,
                }),
              );
              break;
            }
            case "tool-result": {
              if (part.preliminary) break;
              const value: ChatContentPart = {
                type: "tool-result",
                toolCallId: part.toolCallId,
                toolName: part.toolName,
                label: toolLabel(part.toolName, true),
              };
              content.push(value);
              controller.enqueue(
                ndjson({
                  type: "tool-result",
                  toolCallId: value.toolCallId,
                  toolName: value.toolName,
                  label: value.label,
                }),
              );
              break;
            }
            case "finish":
              finishReason = part.finishReason;
              break;
            case "error":
              throw part.error;
            case "abort":
              throw new Error(part.reason ?? "Stream aborted");
          }
        }

        const responseMessages = await result.responseMessages;
        // 3. Persist the completed response before sending the final event.
        const assistantModelMessage = responseMessages.findLast(
          (message) => message.role === "assistant",
        );
        if (!assistantModelMessage) throw new Error("Provider returned no assistant message");
        const assistantRow = await saveAssistantMessage(
          chatId,
          assistantId,
          content,
          assistantModelMessage,
        );
        controller.enqueue(
          ndjson({
            type: "end",
            outcome: "complete",
            finishReason,
            messages: [clientMessage(userRow), clientMessage(assistantRow)],
          }),
        );
      } catch (error) {
        console.error("[API:Chat] Stream failed", error);
        controller.enqueue(
          ndjson({
            type: "end",
            outcome: "failed",
            messages: [clientMessage(userRow)],
            error: { code: "stream_error", message: "The response could not be completed." },
          }),
        );
        console.log("[API:Chat] Stream completed");
      } finally {
        controller.close();
      }
    },
  });
}
