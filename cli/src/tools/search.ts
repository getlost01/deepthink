import { execFileSync } from "node:child_process";

interface SearchResult {
  title: string;
  url: string;
  snippet: string;
}

export async function searchWeb(q: string, numResults = 5): Promise<SearchResult[]> {
  const apiKey = process.env.DEEPTHINK_SEARCH_API;

  if (apiKey) {
    return searchSerper(q, apiKey, numResults);
  }

  return [
    {
      title: "[Search placeholder]",
      url: "",
      snippet: `Web search for '${q}' requires DEEPTHINK_SEARCH_API env var (serper.dev key).`,
    },
  ];
}

async function searchSerper(q: string, apiKey: string, numResults: number): Promise<SearchResult[]> {
  const resp = await fetch("https://google.serper.dev/search", {
    method: "POST",
    headers: { "X-API-KEY": apiKey, "Content-Type": "application/json" },
    body: JSON.stringify({ q, num: numResults }),
  });
  const data = await resp.json();
  return (data.organic ?? []).slice(0, numResults).map((item: any) => ({
    title: item.title ?? "",
    url: item.link ?? "",
    snippet: item.snippet ?? "",
  }));
}

// `q` reaches here from a CLI argument and from the `search_local` agent tool, so it must
// never touch a shell: JSON.stringify only double-quotes, and bash still expands $(…) inside
// double quotes, which made an agent-supplied query arbitrary command execution. execFileSync
// passes argv directly with no shell, and `-e` / `--` keep a leading dash from parsing as a flag.
export function searchLocal(q: string, directory = "."): string[] {
  try {
    const result = execFileSync(
      "grep",
      [
        "-rl",
        "--include=*.ts",
        "--include=*.js",
        "--include=*.md",
        "--include=*.json",
        "--include=*.txt",
        "--include=*.csv",
        "-e",
        q,
        "--",
        directory,
      ],
      { encoding: "utf-8", timeout: 10000 }
    );
    return result
      .trim()
      .split("\n")
      .filter((l) => l.length > 0);
  } catch {
    return [];
  }
}
