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

// The filename IS the record's identity here, so a name that slugifies to nothing
// (blank, or only punctuation) would write a nameless ".md" that no lookup can find
// and no delete can remove.
function requireSlug(name: unknown, entity: string): string {
  if (typeof name !== "string" || name.trim() === "")
    throw new Error(`'name' is required and must be a non-empty string`);
  const slug = slugify(name);
  if (!slug)
    throw new Error(`'name' must contain at least one letter or digit to form a ${entity} filename: ${name}`);
  return slug;
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

function findAgent(name: string) {
  return loadAgents().find(
    (a) => a.name.toLowerCase() === name.toLowerCase() || a.filename === name || a.filename === `${slugify(name)}.md`
  );
}

function findRule(name: string) {
  return loadRules().find((r) => r.name.toLowerCase() === name.toLowerCase() || r.filename === `${slugify(name)}.md`);
}

function findSkill(name: string) {
  const q = name.toLowerCase();
  return loadSkills().find(
    (s) => s.name.toLowerCase() === q || s.commandName === q || s.filename === `${slugify(name)}.md`
  );
}

export const CONFIG_TOOLS: MCPTool[] = [
  // ── Agents ──
  {
    name: "agent",
    description:
      "Manage AI agents. Set `action`:\n" +
      "- list: all agents (roles, icons, models, knowledge scopes)\n" +
      "- get: requires name → full details including system prompt\n" +
      "- create: requires name, role, systemPrompt; optional icon, model, skills, knowledgeScope\n" +
      "- delete: requires name",
    inputSchema: {
      type: "object",
      properties: {
        action: { type: "string", enum: ["list", "get", "create", "delete"], description: "Operation to perform" },
        name: { type: "string", description: "Agent name (get/create/delete)" },
        role: { type: "string", description: "Short role description (create)" },
        icon: { type: "string", description: "SF Symbol icon name (create, default: person.circle)" },
        model: { type: "string", description: "Model override, e.g. claude-sonnet-4-6 (create)" },
        systemPrompt: { type: "string", description: "System prompt / instructions (create)" },
        skills: { type: "array", items: { type: "string" }, description: "Skill names this agent can use (create)" },
        knowledgeScope: {
          type: "array",
          items: { type: "string" },
          description: "Knowledge scope tags for RAG filtering (create)",
        },
      },
      required: ["action"],
    },
    execute: (p) => {
      switch (p.action) {
        case "list": {
          const agents = loadAgents();
          return { agents: agents.map(({ systemPrompt: _, ...a }) => a), count: agents.length };
        }
        case "get": {
          if (!p.name) throw new Error(`'name' is required for action 'get'`);
          const agent = findAgent(p.name);
          if (!agent) throw new Error(`agent not found: ${p.name}`);
          return agent;
        }
        case "create": {
          if (!p.name || !p.role || !p.systemPrompt)
            throw new Error(`'name', 'role', and 'systemPrompt' are required for action 'create'`);
          const filename = `${requireSlug(p.name, "agent")}.md`;
          ensureDir(AGENTS_DIR);
          let md = buildFrontmatter({
            name: p.name,
            role: p.role,
            icon: p.icon ?? "person.circle",
            model: p.model,
            skills: p.skills?.length ? `[${p.skills.join(", ")}]` : undefined,
            knowledge_scope: p.knowledgeScope?.length ? `[${p.knowledgeScope.join(", ")}]` : undefined,
          });
          md += p.systemPrompt;
          writeFileSync(join(AGENTS_DIR, filename), md, "utf-8");
          return { name: p.name, filename, created: true };
        }
        case "delete": {
          if (!p.name) throw new Error(`'name' is required for action 'delete'`);
          const agent = findAgent(p.name);
          if (!agent) throw new Error(`agent not found: ${p.name}`);
          unlinkSync(join(AGENTS_DIR, agent.filename));
          return { name: agent.name, deleted: true };
        }
        default:
          throw new Error(`unknown action: ${p.action}. Use one of: list, get, create, delete`);
      }
    },
  },

  // ── Rules ──
  {
    name: "rule",
    description:
      "Manage AI rules (auto-inject instructions into prompts based on triggers). Set `action`:\n" +
      "- list: all rules (triggers, categories)\n" +
      "- get: requires name → full details including instruction text\n" +
      "- create: requires name, trigger, instruction; optional icon, category\n" +
      "- delete: requires name",
    inputSchema: {
      type: "object",
      properties: {
        action: { type: "string", enum: ["list", "get", "create", "delete"], description: "Operation to perform" },
        name: { type: "string", description: "Rule name (get/create/delete)" },
        trigger: {
          type: "string",
          description: "When to activate: 'always', 'note.tagged.X', 'content_type.code', etc. (create)",
        },
        icon: { type: "string", description: "SF Symbol icon name (create, default: bolt)" },
        category: { type: "string", description: "Category for grouping (create, default: General)" },
        instruction: { type: "string", description: "Instruction text injected into the system prompt (create)" },
      },
      required: ["action"],
    },
    execute: (p) => {
      switch (p.action) {
        case "list": {
          const rules = loadRules();
          return { rules: rules.map(({ instruction: _, ...r }) => r), count: rules.length };
        }
        case "get": {
          if (!p.name) throw new Error(`'name' is required for action 'get'`);
          const rule = findRule(p.name);
          if (!rule) throw new Error(`rule not found: ${p.name}`);
          return rule;
        }
        case "create": {
          if (!p.name || !p.trigger || !p.instruction)
            throw new Error(`'name', 'trigger', and 'instruction' are required for action 'create'`);
          const filename = `${requireSlug(p.name, "rule")}.md`;
          ensureDir(RULES_DIR);
          let md = buildFrontmatter({
            name: p.name,
            trigger: p.trigger,
            icon: p.icon ?? "bolt",
            category: p.category ?? "General",
          });
          md += p.instruction;
          writeFileSync(join(RULES_DIR, filename), md, "utf-8");
          return { name: p.name, trigger: p.trigger, filename, created: true };
        }
        case "delete": {
          if (!p.name) throw new Error(`'name' is required for action 'delete'`);
          const rule = findRule(p.name);
          if (!rule) throw new Error(`rule not found: ${p.name}`);
          unlinkSync(join(RULES_DIR, rule.filename));
          return { name: rule.name, deleted: true };
        }
        default:
          throw new Error(`unknown action: ${p.action}. Use one of: list, get, create, delete`);
      }
    },
  },

  // ── Skills ──
  {
    name: "skill",
    description:
      "Manage slash-command skills (reusable AI prompts with {{input}} interpolation). Set `action`:\n" +
      "- list: all skills (categories, triggers)\n" +
      "- get: requires name (or command name) → full details including system prompt and prompt template\n" +
      "- create: requires name, promptTemplate; optional category, icon, model, trigger, systemPrompt\n" +
      "- delete: requires name (or command name)",
    inputSchema: {
      type: "object",
      properties: {
        action: { type: "string", enum: ["list", "get", "create", "delete"], description: "Operation to perform" },
        name: {
          type: "string",
          description: "Skill name or command name (get/create/delete). On create becomes /command-name",
        },
        category: { type: "string", description: "Category for grouping (create, default: General)" },
        icon: { type: "string", description: "SF Symbol icon name (create, default: sparkles)" },
        model: { type: "string", description: "Model override (create)" },
        trigger: { type: "string", description: "Trigger type (create, default: manual)" },
        systemPrompt: { type: "string", description: "System prompt for the skill (create)" },
        promptTemplate: { type: "string", description: "Prompt template; use {{input}} for user input (create)" },
      },
      required: ["action"],
    },
    execute: (p) => {
      switch (p.action) {
        case "list": {
          const skills = loadSkills();
          return { skills: skills.map(({ systemPrompt: _, promptTemplate: __, ...s }) => s), count: skills.length };
        }
        case "get": {
          if (!p.name) throw new Error(`'name' is required for action 'get'`);
          const skill = findSkill(p.name);
          if (!skill) throw new Error(`skill not found: ${p.name}`);
          return skill;
        }
        case "create": {
          if (!p.name || !p.promptTemplate)
            throw new Error(`'name' and 'promptTemplate' are required for action 'create'`);
          const slug = requireSlug(p.name, "skill");
          const filename = `${slug}.md`;
          ensureDir(SKILLS_DIR);
          let md = buildFrontmatter({
            name: p.name,
            trigger: p.trigger ?? "manual",
            icon: p.icon ?? "sparkles",
            model: p.model,
            category: p.category ?? "General",
          });
          if (p.systemPrompt) md += `${p.systemPrompt}\n\n---\n\n`;
          md += p.promptTemplate;
          writeFileSync(join(SKILLS_DIR, filename), md, "utf-8");
          return { name: p.name, commandName: slug, filename, created: true };
        }
        case "delete": {
          if (!p.name) throw new Error(`'name' is required for action 'delete'`);
          const skill = findSkill(p.name);
          if (!skill) throw new Error(`skill not found: ${p.name}`);
          unlinkSync(join(SKILLS_DIR, skill.filename));
          return { name: skill.name, deleted: true };
        }
        default:
          throw new Error(`unknown action: ${p.action}. Use one of: list, get, create, delete`);
      }
    },
  },
];

export const CONFIG_TOOL_MAP: Record<string, MCPTool> = Object.fromEntries(CONFIG_TOOLS.map((t) => [t.name, t]));
