import { readFileSync, writeFileSync, appendFileSync, mkdirSync } from "fs";
import { dirname } from "path";
import { getPath } from "../core/sandbox";

export function writeFile(
  content: string,
  filename: string,
  category: "docs" | "outputs" | "projects" | "insights" = "outputs"
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
  category: "docs" | "outputs" | "projects" | "insights" = "outputs"
): string {
  const path = getPath(category, filename);
  mkdirSync(dirname(path), { recursive: true });
  appendFileSync(path, content, "utf-8");
  return path;
}
