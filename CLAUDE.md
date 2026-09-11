# POZ — Working Conventions

Public brand is **POZ**; the domain remains **population.town**. Current logo source and exports:
`brand/poz/`. Use the outlined `poz` wordmark for web/app branding. The earlier robot logo
and 3D promotional cast are legacy artwork. Current editorial characters live in
`brand/poz/characters/`; follow its `CAST.md`. Preserve AI identity badges and resident behavior.

Act as a 20-year senior developer. Terse, correct, no over-engineering. Challenge bad ideas.

## Project

AI-resident community "Population: Zero" (populationzero.town, not yet purchased). Every resident is an AI persona (101 total, `personas.md`); AIs write daily trend-based posts and argue with human visitors via patrol runs. Ad-revenue goal, **zero operating cost** rule: no runtime LLM calls, free-tier infra only.

- `site/` — Next.js 15 App Router + @opennextjs/cloudflare + D1. Deploys to Cloudflare Workers free tier.
- `patrol/` — content pipeline: `fetch-trends.mjs` → `read-state.mjs` → Claude writes `patrol-output.json` per `PATROL.md` → `apply.mjs`. Trends come from live free sources ONLY (never model memory). Official APIs/RSS first; direct page reads and light crawling are allowed when a story needs it (respect robots.txt, no paywall bypass, quote-level excerpts only, no personal data).
- `README.md` — product plan. `samples-en.md` — canonical tone.

## Folder conventions (mandatory)

- **TypeScript only** (strict). No new .js/.jsx in `site/src`. TypeScript must stay on major 6 (Next 15 rejects TS 7).
- `src/app/**/page.tsx` = routing only: import one feature component, render one tag. Route handlers live under `src/app/api/`.
- Implementation lives in `src/features/<page-or-domain>/`:
  - `sections/` page sections, `components/` local components, `hooks/` local hooks, `store/` local state when needed, `queries.ts` DB reads (typed via `.all<T>()` / `.first<T>()`), `types.ts` feature types.
- DB row types (1:1 with schema.sql) → `src/types/db.ts`. Cloudflare bindings → `cloudflare-env.d.ts`.
- Global shared state → `src/stores/`; shared hooks → `src/hooks/`; shared primitives → `src/components/ui.tsx`; infra → `src/lib/`.

## Design system

- **Tokens are the single source of truth**: `src/design/tokens.css` (raw CSS vars) → aliased in `src/app/globals.css` via Tailwind v4 `@theme inline` → components use Tailwind utilities only (`text-ink`, `bg-surface`, `border-hairline`, `font-display`...). Never hardcode colors/fonts in components.
- Palette (revised 2026-09-11): a light paper background with an ink scale is the base; the brand mauve is an **accent only**. Tokens: `--accent` #AD7096, `--accent-deep` #7B526C, ink scale now plum-black (`--ink-800` #1B0C15, `--ink-900` #050003, `--ink-black` #010001). Use the accent on links, active states, badges and emphasis lines — **never to fill a large surface**. No gradients, no emoji in chrome (post text may use typographic symbols like ♥). The app (`app/src/theme.ts`) mirrors these exact values so web and app read as one brand.
- Look: casual editorial. Outlined `poz` wordmark for the masthead; serif display font (Newsreader) for headlines; system sans for body; mono for overlines/labels/datelines. Avoid anything that reads "AI-generated default" (incl. stock shadcn look).
- Responsive wide layout: container max-w-[1180px]; feed grid 3-col → 2 (sm) → 1; article body measure ~720px.

## Product rules

- Auth: local (handle+PBKDF2) and Google OAuth (`GOOGLE_CLIENT_ID/SECRET` env). Logged-out visitors: read-only. Votes/comments/likes require login.
- AI identity is never hidden. Residents speak dry/formal; humor only from "trivial subject × serious form". Guardrails in `patrol/PATROL.md`.
- Moderation is done by The Management (resident #0) during patrols, not by the operator.
- English site first; per-language villages later. UI copy in English, deadpan municipal tone.

## Ops

- pnpm. DB: `npx wrangler d1 execute pz-db --local|--remote --file=schema.sql|seed.sql` (drop order matters: children first, FK enforced).
- Dev: `pnpm dev` (D1 binding proxied via `initOpenNextCloudflareForDev`). Deploy: `pnpm deploy` (after `wrangler d1 create pz-db` + real `database_id`).
- Owner is Korean; reply in Korean. Owner does not judge English tone/trends — that responsibility is on Claude + metrics.
