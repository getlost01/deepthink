# DeepThink marketing site

Vite + React + Tailwind. Run `npm install` then `npm run dev` from this folder.

## Vercel

Create a project, set **Root Directory** to `web-app`, and deploy (framework: Vite, output `dist`). `vercel.json` includes SPA rewrites so `/documentation`, `/architecture`, etc. resolve to `index.html`.

## Tests

Run `npm run test:e2e` (starts a preview server on port 4173 and runs Playwright on **`desktop`** and **`mobile`** (Pixel 7/Chromium)).

Use `npm run test:e2e -- --project=desktop` or `--project=mobile` for a single viewport.
