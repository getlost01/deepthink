import { appendFileSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname } from "node:path";
import { getPath } from "../core/sandbox";

export function writeFile(
  content: string,
  filename: string,
  category: "docs" | "outputs" | "analysis" | "insights" = "outputs"
): string {
  const path = getPath(category, filename);
  mkdirSync(dirname(path), { recursive: true });
  writeFileSync(path, content, "utf-8");
  return path;
}

export function readFile(filepath: string): string {
  return readFileSync(filepath, "utf-8");
}

export function appendToFile(
  content: string,
  filename: string,
  category: "docs" | "outputs" | "analysis" | "insights" = "outputs"
): string {
  const path = getPath(category, filename);
  mkdirSync(dirname(path), { recursive: true });
  appendFileSync(path, content, "utf-8");
  return path;
}
