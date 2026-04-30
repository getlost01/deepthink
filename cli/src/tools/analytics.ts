import { readFileSync } from "fs";
import { query } from "../core/llm";

interface ColumnStats {
  name: string;
  type: string;
  nullCount: number;
  uniqueCount: number;
  sample: string[];
}

interface DataSummary {
  rowCount: number;
  columnCount: number;
  columns: ColumnStats[];
}

export function parseCSV(filepath: string): string[][] {
  const raw = readFileSync(filepath, "utf-8");
  return raw
    .trim()
    .split("\n")
    .map((line) => line.split(",").map((cell) => cell.trim().replace(/^"|"$/g, "")));
}

export function summarizeData(filepath: string): DataSummary {
  const rows = parseCSV(filepath);
  if (rows.length === 0) return { rowCount: 0, columnCount: 0, columns: [] };

  const headers = rows[0];
  const dataRows = rows.slice(1);

  const columns: ColumnStats[] = headers.map((name, i) => {
    const values = dataRows.map((r) => r[i] ?? "");
    const nonEmpty = values.filter((v) => v !== "");
    const unique = new Set(nonEmpty);

    const isNumeric = nonEmpty.length > 0 && nonEmpty.every((v) => !isNaN(Number(v)));

    return {
      name,
      type: isNumeric ? "numeric" : "string",
      nullCount: values.length - nonEmpty.length,
      uniqueCount: unique.size,
      sample: [...unique].slice(0, 5),
    };
  });

  return {
    rowCount: dataRows.length,
    columnCount: headers.length,
    columns,
  };
}

export function computeNumericStats(
  filepath: string,
  columnName: string
): { min: number; max: number; mean: number; median: number; stddev: number } | null {
  const rows = parseCSV(filepath);
  if (rows.length < 2) return null;

  const headers = rows[0];
  const colIdx = headers.indexOf(columnName);
  if (colIdx === -1) return null;

  const values = rows
    .slice(1)
    .map((r) => Number(r[colIdx]))
    .filter((n) => !isNaN(n))
    .sort((a, b) => a - b);

  if (values.length === 0) return null;

  const sum = values.reduce((a, b) => a + b, 0);
  const mean = sum / values.length;
  const median =
    values.length % 2 === 0
      ? (values[values.length / 2 - 1] + values[values.length / 2]) / 2
      : values[Math.floor(values.length / 2)];
  const variance = values.reduce((acc, v) => acc + (v - mean) ** 2, 0) / values.length;

  return {
    min: values[0],
    max: values[values.length - 1],
    mean: Math.round(mean * 100) / 100,
    median,
    stddev: Math.round(Math.sqrt(variance) * 100) / 100,
  };
}

export async function analyzeFile(filepath: string, question?: string): Promise<string> {
  const isCSV = filepath.endsWith(".csv");

  if (isCSV) {
    const summary = summarizeData(filepath);
    const numericCols = summary.columns.filter((c) => c.type === "numeric");
    const stats = numericCols.map((c) => ({
      column: c.name,
      ...computeNumericStats(filepath, c.name),
    }));

    const prompt = [
      `Analyze this CSV dataset:`,
      `Rows: ${summary.rowCount}, Columns: ${summary.columnCount}`,
      `Columns: ${summary.columns.map((c) => `${c.name} (${c.type}, ${c.nullCount} nulls, ${c.uniqueCount} unique)`).join(", ")}`,
      stats.length > 0 ? `Numeric stats: ${JSON.stringify(stats)}` : "",
      question ? `\nSpecific question: ${question}` : "",
      `\nProvide key findings, data quality issues, and suggested analyses.`,
    ]
      .filter(Boolean)
      .join("\n");

    return query(prompt, "You are a data analyst. Be precise with numbers. Use bullet points.");
  }

  const content = readFileSync(filepath, "utf-8").slice(0, 5000);
  const prompt = question
    ? `Analyze this file and answer: ${question}\n\n${content}`
    : `Analyze this file. Describe purpose, key patterns, issues, suggestions:\n\n${content}`;

  return query(prompt, "You are a code and data analysis expert. Be concise and actionable.");
}

export function analyzeJSON(filepath: string): {
  type: string;
  count?: number;
  keys?: string[];
  sample?: any;
} {
  const raw = readFileSync(filepath, "utf-8");
  const data = JSON.parse(raw);

  if (Array.isArray(data)) {
    return {
      type: "array",
      count: data.length,
      keys: data.length > 0 && typeof data[0] === "object" ? Object.keys(data[0]) : undefined,
      sample: data.slice(0, 3),
    };
  }

  return {
    type: typeof data === "object" ? "object" : typeof data,
    keys: typeof data === "object" ? Object.keys(data) : undefined,
    sample: typeof data === "object" ? Object.fromEntries(Object.entries(data).slice(0, 5)) : data,
  };
}
