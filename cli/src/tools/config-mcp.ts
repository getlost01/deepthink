import { mkdirSync, readdirSync, readFileSync, unlinkSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { DEEPTHINK_ROOT } from "../config";

export interface MCPTool {
  name: string;
  description: string;
  inputSchema: Record<string, any>;
  execute: (params: Record<string, any>) => any;
}

const CLAUDE_DIR = join(DEEPTHINK_ROOT, ".claude");
const AGENTS_DIR = join(CLAUDE_DIR, "agents");
const RULES_DIR = join(CLAUDE_DIR, "rules");
const SKILLS_DIR = join(CLAUDE_DIR, "commands");

function ensureDir(dir: string) {
  mkdirSync(dir, { recursive: true });
}

function slugify(s: string): string {
  return s
    .toLowerCase()
    .replace(/\s+/g, "-")
    .replace(/[^a-z0-9-]/g, "");
}

// ── Frontmatter parser ──

function parseFrontmatter(text: string): { meta: Record<string, string>; body: string } {
  const meta: Record<string, string> = {};
  if (!text.startsWith("---")) return { meta, body: text };

  const end = text.indexOf("---", 3);
  if (end === -1) return { meta, body: text };

  const header = text.slice(3, end).trim();
  const body = text.slice(end + 3).trim();

  for (const line of header.split("\n")) {
    const idx = line.indexOf(":");
    if (idx === -1) continue;
    const key = line.slice(0, idx).trim();
    const val = line.slice(idx + 1).trim();
    meta[key] = val;
  }

  return { meta, body };
}

function buildFrontmatter(fields: Record<string, string | undefined>): string {
  let md = "---\n";
  for (const [k, v] of Object.entries(fields)) {
    if (v !== undefined && v !== "") md += `${k}: ${v}\n`;
  }
  md += "---\n\n";
  return md;
}

// ── Agent helpers ──

interface AgentInfo {
  name: string;
  role: string;
  icon: string;
  model: string | null;
  skills: string[];
  knowledgeScope: string[];
  systemPrompt: string;
  filename: string;
  isBuiltIn: boolean;
}

function parseListField(val: string): string[] {
  return val
    .replace(/^\[|]$/g, "")
    .split(",")
    .map((s) => s.trim())
    .filter(Boolean);
}

function loadAgents(): AgentInfo[] {
  ensureDir(AGENTS_DIR);
  const files = readdirSync(AGENTS_DIR).filter((f) => f.endsWith(".md"));
  return files.map((f) => {
    const text = readFileSync(join(AGENTS_DIR, f), "utf-8");
    const { meta, body } = parseFrontmatter(text);
    return {
      name: meta.name ?? f.replace(".md", ""),
      role: meta.role ?? "",
      icon: meta.icon ?? "person.circle",
      model: meta.model ?? null,
      skills: meta.skills ? parseListField(meta.skills) : [],
      knowledgeScope: meta.knowledge_scope ? parseListField(meta.knowledge_scope) : [],
      systemPrompt: body,
      filename: f,
      isBuiltIn: meta.built_in === "true",
    };
  });
}

// ── Rule helpers ──

interface RuleInfo {
  name: string;
  trigger: string;
  icon: string;
  category: string;
  instruction: string;
  filename: string;
  isBuiltIn: boolean;
}

function loadRules(): RuleInfo[] {
  ensureDir(RULES_DIR);
  const files = readdirSync(RULES_DIR).filter((f) => f.endsWith(".md"));
  return files.map((f) => {
    const text = readFileSync(join(RULES_DIR, f), "utf-8");
    const { meta, body } = parseFrontmatter(text);
    return {
      name: meta.name ?? f.replace(".md", ""),
      trigger: meta.trigger ?? "always",
      icon: meta.icon ?? "bolt",
      category: meta.category ?? "General",
      instruction: body,
      filename: f,
      isBuiltIn: meta.built_in === "true",
    };
  });
}

// ── Skill helpers ──

interface SkillInfo {
  name: string;
  trigger: string;
  icon: string;
  model: string | null;
  category: string;
  systemPrompt: string;
  promptTemplate: string;
  filename: string;
  isBuiltIn: boolean;
  isPinned: boolean;
  commandName: string;
}

function loadSkills(): SkillInfo[] {
  ensureDir(SKILLS_DIR);
  const files = readdirSync(SKILLS_DIR).filter((f) => f.endsWith(".md"));
  return files.map((f) => {
    const text = readFileSync(join(SKILLS_DIR, f), "utf-8");
    const { meta, body } = parseFrontmatter(text);

    const parts = body.split("\n---\n");
    const systemPrompt = parts.length > 1 ? parts[0].trim() : "";
    const promptTemplate = parts.length > 1 ? parts.slice(1).join("\n---\n").trim() : body;

    const name = meta.name ?? f.replace(".md", "");
    return {
      name,
      trigger: meta.trigger ?? "manual",
      icon: meta.icon ?? "sparkles",
      model: meta.model ?? null,
      category: meta.category ?? "General",
      systemPrompt,
      promptTemplate,
      filename: f,
      isBuiltIn: meta.built_in === "true",
      isPinned: meta.pinned === "true",
      commandName: slugify(name),
    };
  });
}

// ── MCP Tools ──

export const CONFIG_TOOLS: MCPTool[] = [
  // ── Agents ──
  {
    name: "agent_list",
    description: "List all AI agents with their roles, icons, models, and knowledge scopes.",
    inputSchema: { type: "object", properties: {} },
    execute: () => {
      const agents = loadAgents();
      return { agents: agents.map(({ systemPrompt: _, ...a }) => a), count: agents.length };
    },
  },
  {
    name: "agent_get",
    description: "Get full details of an agent by name, including system prompt.",
    inputSchema: {
      type: "object",
      properties: { name: { type: "string", description: "Agent name" } },
      required: ["name"],
    },
    execute: (p) => {
      const agent = loadAgents().find(
        (a) =>
          a.name.toLowerCase() === p.name.toLowerCase() ||
          a.filename === p.name ||
          a.filename === `${slugify(p.name)}.md`
      );
      if (!agent) throw new Error(`agent not found: ${p.name}`);
      return agent;
    },
  },
  {
    name: "agent_create",
    description: "Create a new AI agent with a name, role, system prompt, and optional knowledge scope.",
    inputSchema: {
      type: "object",
      properties: {
        name: { type: "string", description: "Agent name" },
        role: { type: "string", description: "Short role description" },
        icon: { type: "string", description: "SF Symbol icon name (default: person.circle)" },
        model: { type: "string", description: "Model override (e.g. claude-sonnet-4-6)" },
        systemPrompt: { type: "string", description: "System prompt / instructions for the agent" },
        skills: { type: "array", items: { type: "string" }, description: "Skill names this agent can use" },
        knowledgeScope: {
          type: "array",
          items: { type: "string" },
          description: "Knowledge scope tags for RAG filtering",
        },
      },
      required: ["name", "role", "systemPrompt"],
    },
    execute: (p) => {
      ensureDir(AGENTS_DIR);
      const filename = `${slugify(p.name)}.md`;
      const filepath = join(AGENTS_DIR, filename);

      let md = buildFrontmatter({
        name: p.name,
        role: p.role,
        icon: p.icon ?? "person.circle",
        model: p.model,
        skills: p.skills?.length ? `[${p.skills.join(", ")}]` : undefined,
        knowledge_scope: p.knowledgeScope?.length ? `[${p.knowledgeScope.join(", ")}]` : undefined,
      });
      md += p.systemPrompt;

      writeFileSync(filepath, md, "utf-8");
      return { name: p.name, filename, created: true };
    },
  },
  {
    name: "agent_delete",
    description: "Delete an agent by name.",
    inputSchema: {
      type: "object",
      properties: { name: { type: "string", description: "Agent name" } },
      required: ["name"],
    },
    execute: (p) => {
      const agent = loadAgents().find(
        (a) => a.name.toLowerCase() === p.name.toLowerCase() || a.filename === `${slugify(p.name)}.md`
      );
      if (!agent) throw new Error(`agent not found: ${p.name}`);
      unlinkSync(join(AGENTS_DIR, agent.filename));
      return { name: agent.name, deleted: true };
    },
  },

  // ── Rules ──
  {
    name: "rule_list",
    description: "List all AI rules with their triggers, categories, and instructions.",
    inputSchema: { type: "object", properties: {} },
    execute: () => {
      const rules = loadRules();
      return { rules: rules.map(({ instruction: _, ...r }) => r), count: rules.length };
    },
  },
  {
    name: "rule_get",
    description: "Get full details of a rule by name, including the instruction text.",
    inputSchema: {
      type: "object",
      properties: { name: { type: "string", description: "Rule name" } },
      required: ["name"],
    },
    execute: (p) => {
      const rule = loadRules().find(
        (r) => r.name.toLowerCase() === p.name.toLowerCase() || r.filename === `${slugify(p.name)}.md`
      );
      if (!rule) throw new Error(`rule not found: ${p.name}`);
      return rule;
    },
  },
  {
    name: "rule_create",
    description: "Create a new AI rule. Rules auto-inject instructions into prompts based on triggers.",
    inputSchema: {
      type: "object",
      properties: {
        name: { type: "string", description: "Rule name" },
        trigger: {
          type: "string",
          description: "When to activate: 'always', 'note.tagged.X', 'content_type.code', etc.",
        },
        icon: { type: "string", description: "SF Symbol icon name (default: bolt)" },
        category: { type: "string", description: "Category for grouping (default: General)" },
        instruction: { type: "string", description: "The instruction text injected into the system prompt" },
      },
      required: ["name", "trigger", "instruction"],
    },
    execute: (p) => {
      ensureDir(RULES_DIR);
      const filename = `${slugify(p.name)}.md`;
      const filepath = join(RULES_DIR, filename);

      let md = buildFrontmatter({
        name: p.name,
        trigger: p.trigger,
        icon: p.icon ?? "bolt",
        category: p.category ?? "General",
      });
      md += p.instruction;

      writeFileSync(filepath, md, "utf-8");
      return { name: p.name, trigger: p.trigger, filename, created: true };
    },
  },
  {
    name: "rule_delete",
    description: "Delete a rule by name.",
    inputSchema: {
      type: "object",
      properties: { name: { type: "string", description: "Rule name" } },
      required: ["name"],
    },
    execute: (p) => {
      const rule = loadRules().find(
        (r) => r.name.toLowerCase() === p.name.toLowerCase() || r.filename === `${slugify(p.name)}.md`
      );
      if (!rule) throw new Error(`rule not found: ${p.name}`);
      unlinkSync(join(RULES_DIR, rule.filename));
      return { name: rule.name, deleted: true };
    },
  },

  // ── Skills ──
  {
    name: "skill_list",
    description: "List all slash-command skills with their categories and triggers.",
    inputSchema: { type: "object", properties: {} },
    execute: () => {
      const skills = loadSkills();
      return {
        skills: skills.map(({ systemPrompt: _, promptTemplate: __, ...s }) => s),
        count: skills.length,
      };
    },
  },
  {
    name: "skill_get",
    description: "Get full details of a skill by name, including system prompt and prompt template.",
    inputSchema: {
      type: "object",
      properties: { name: { type: "string", description: "Skill name or command name" } },
      required: ["name"],
    },
    execute: (p) => {
      const q = p.name.toLowerCase();
      const skill = loadSkills().find(
        (s) => s.name.toLowerCase() === q || s.commandName === q || s.filename === `${slugify(p.name)}.md`
      );
      if (!skill) throw new Error(`skill not found: ${p.name}`);
      return skill;
    },
  },
  {
    name: "skill_create",
    description: "Create a new slash-command skill. Skills are reusable AI prompts with {{input}} interpolation.",
    inputSchema: {
      type: "object",
      properties: {
        name: { type: "string", description: "Skill name (becomes /command-name)" },
        category: { type: "string", description: "Category for grouping (default: General)" },
        icon: { type: "string", description: "SF Symbol icon name (default: sparkles)" },
        model: { type: "string", description: "Model override" },
        trigger: { type: "string", description: "Trigger type (default: manual)" },
        systemPrompt: { type: "string", description: "System prompt for the skill" },
        promptTemplate: { type: "string", description: "Prompt template. Use {{input}} for user input." },
      },
      required: ["name", "promptTemplate"],
    },
    execute: (p) => {
      ensureDir(SKILLS_DIR);
      const filename = `${slugify(p.name)}.md`;
      const filepath = join(SKILLS_DIR, filename);

      let md = buildFrontmatter({
        name: p.name,
        trigger: p.trigger ?? "manual",
        icon: p.icon ?? "sparkles",
        model: p.model,
        category: p.category ?? "General",
      });
      if (p.systemPrompt) md += `${p.systemPrompt}\n\n---\n\n`;
      md += p.promptTemplate;

      writeFileSync(filepath, md, "utf-8");
      return { name: p.name, commandName: slugify(p.name), filename, created: true };
    },
  },
  {
    name: "skill_delete",
    description: "Delete a skill by name.",
    inputSchema: {
      type: "object",
      properties: { name: { type: "string", description: "Skill name or command name" } },
      required: ["name"],
    },
    execute: (p) => {
      const q = p.name.toLowerCase();
      const skill = loadSkills().find(
        (s) => s.name.toLowerCase() === q || s.commandName === q || s.filename === `${slugify(p.name)}.md`
      );
      if (!skill) throw new Error(`skill not found: ${p.name}`);
      unlinkSync(join(SKILLS_DIR, skill.filename));
      return { name: skill.name, deleted: true };
    },
  },
];

export const CONFIG_TOOL_MAP: Record<string, MCPTool> = Object.fromEntries(CONFIG_TOOLS.map((t) => [t.name, t]));
