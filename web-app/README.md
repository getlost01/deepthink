# DeepThink marketing site

Vite + React + Tailwind. Run `npm install` then `npm run dev` from this folder.

## Vercel

Create a project, set **Root Directory** to `web-app`, and deploy (framework: Vite, output `dist`). `vercel.json` includes SPA rewrites so `/documentation`, `/architecture`, etc. resolve to `index.html`.

Documentation is **ingested at build time** (`npm run build` runs `scripts/ingest-docs.mjs`). Add a **`GITHUB_TOKEN`** (classic PAT or fine‑grained, read‑only Contents) in the project’s Environment Variables so the build can fetch `docs/**/*.md` from your GitHub repo; without it, ingest falls back to `../docs` when present in the cloned tree.

## Tests

Run `npm run test:e2e` (starts a preview server on port 4173 and runs Playwright on **`desktop`** and **`mobile`** (Pixel 7/Chromium)).

Use `npm run test:e2e -- --project=desktop` or `--project=mobile` for a single viewport.
