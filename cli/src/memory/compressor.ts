import { query } from "../core/llm";

export async function summarizeMemories(memories: { content: string }[], maxItems = 20): Promise<string> {
  if (memories.length === 0) return "";

  const text = memories
    .slice(0, maxItems)
    .map((m) => m.content)
    .join("\n");

  return query(
    `Summarize these memory entries into key themes and facts. Be concise:\n\n${text}`,
    "You compress information into dense, useful summaries. Output bullet points.",
  );
}

export async function compressContext(context: string, maxLength = 2000): Promise<string> {
  if (context.length <= maxLength) return context;

  return query(
    `Compress this context to under ${maxLength} chars. Keep all key facts:\n\n${context}`,
    "You compress text while preserving all important information. Be extremely concise.",
  );
}
