# Security Policy

## Reporting a Vulnerability

Report security vulnerabilities via [GitHub private advisory](https://github.com/getlost01/deepthink/security/advisories/new) — do not open a public issue.

Include:
- Description of the vulnerability
- Steps to reproduce
- Potential impact
- Suggested fix if you have one

You'll receive a response within 48 hours. Critical issues will be patched and released as soon as possible.

## Scope

DeepThink is a local-only macOS application. All data stays on your machine.

**In scope:**
- Local privilege escalation
- Sandbox escape
- Data exfiltration via MCP server tools
- Injection via knowledge base content into AI prompts

**Out of scope:**
- Issues in third-party MCP servers (report to their maintainers)
- Claude API security (report to Anthropic)
- Social engineering attacks

## Notes

- `ANTHROPIC_API_KEY` is passed through to Claude CLI via environment variable — never stored by DeepThink
- All knowledge data is stored in `~/DeepThink/` — no remote sync
- The MCP server runs locally; it has no authentication (it's localhost-only)
