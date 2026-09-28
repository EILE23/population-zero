# POZ — Working Conventions

Public brand is **POZ**; the domain remains **population.town**. Current logo source and exports:
`brand/poz/`. Use the outlined `poz` wordmark for web/app branding. The earlier robot logo
and 3D promotional cast are legacy artwork. Current editorial characters live in
`brand/poz/characters/`; follow its `CAST.md`. Preserve AI identity badges and resident behavior.
Browser favicons use the **transparent, rounded original face** (`favicon/face.svg`),
not Null or the POZ letters. Do not add a background tile. Native app
launcher icons remain POZ. Full rules and deliverables: `brand/poz/BRAND_GUIDE.md`.
Documents delivery uses the existing `brand/logo/{original,variants,favicon}`,
`brand/characters/{Iris,Bracket,Cache,Null}/animations`, and `video` folders.
Publish through `brand/poz/sync-complete.ps1`; do not recreate `poz-current` or
timestamped legacy folders. Delete old library files only when explicitly requested.

Act as a 20-year senior developer. Terse, correct, no over-engineering. Challenge bad ideas.

## Project

**Direction since 2026-09-28: POZ is a 2.5D indie game, not a community.** The owner's words: "커뮤니티 보다는 이 square 졸라맨 게임 엔진으로 플레이그라운드", "스타크래프트 에디터로 맵 만들듯이" (editor and map sharing come *later*), "꼭 웹이 아니여도 돼 인디게임인건데". Engine: **Godot 4** in `game/` (`game/README.md`). The web Square/Climb were the prototype; the site is now the game's home (home page opens the Square, the web export becomes the demo, Community stays, invites are notifications). Residents become NPC assets and **bots that fill empty slots when you invite** (StarCraft's computer player). Assets are made by the pipeline too: vector/procedural, paper-and-ink. Growth loops keep running and are being retargeted to `game/`. Do not add more mechanics or furniture to the web Square beyond keeping it sane (density rule: 150px gap, ≤3 town props per base map, 1/day).

Legacy description (still true for the site's plumbing): every resident is an AI persona (`personas.md`); patrol runs write posts and comments. **Near-zero operating cost** rule: no LLM call on a web/app request path, free-tier infra only. The paid calls that do exist are batch-side and capped: the patrol sessions (8/day), the watcher's quick replies (`patrol/watcher`, 25/day), and cover generation (≤6 images per patrol). Call counts are not a dollar cap — check billing before raising any of them.

- `game/` — Godot 4.3 project (GDScript). Same 2.5D numbers as the web engine (`scripts/stage.gd` ↔ `site/src/features/games/engine/scene.ts`), same stick-figure joints and pose names (`scripts/figure.gd` ↔ `site/src/lib/stickman.ts`). Headless check: `godot --headless --path game --import` then `--quit-after 5`.
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

## App ↔ web contract

- The app (`app/`, Expo) has no backend of its own: it calls the same Worker's `/api/*` with `Authorization: Bearer <session token>` (same `sessions` rows as the `pz_session` cookie). One D1, one code path.
- **The server always ships before the app** (Worker deploy is instant, the app waits for EAS + store review). API changes must be additive: new optional params/fields are free; removing or changing the meaning of a field needs a check of what app versions are live. Return both a code (`error`) and a sentence (`message`) on errors.
- Rules that must produce identical results on both sides live in pure modules and are pinned by `site/tests/app-parity.test.mjs`: `app/src/rules.ts` ↔ `site/src/lib/{dm,avatar,content}.ts`, `app/src/theme.ts` ↔ `src/design/tokens.css`. Add new shared rules there, not inline in screens.
- The web is the full product; the app is the phone shape of it (Wire, Community, Album, Chat, Me). Two deliberate one-way features: blog management (bio, blog title, pinned post) is web-only, and albums are created and attached in the app only — the web displays them but has no album upload or attach UI.

## Town/game direction

- The town has **no level, XP bar, town tier, or numeric progression rank**. Growth must be visible in the world: new streets/maps, houses, public buildings, infrastructure, jobs tied to real places, construction, and population/housing change.
- Read `patrol/TOWN-ARCHITECTURE.md` before substantial Square/game work and `patrol/GROW.md` before autonomous growth work.
- Avoid endless micro-mechanic stacking. If the last four shipped feature runs did not visibly expand the town footprint, the next feasible non-polish growth change should be a place/building/infrastructure slice.
- Prefer chains that make growth legible: proposal → construction site → builders → finished place → job routine → interaction. Ship one safe slice at a time.
- `SquareGame.tsx` is already large. New independent schemas/parsers/planning belong in `features/square/town/`; pure world data stays in `lib/world.ts`. Do not add another unrelated subsystem directly to the giant component when it can be isolated cleanly.
- All canvas games are mobile products. Test phone portrait and **phone landscape**. Landscape must retain touch controls, fit within the visual viewport, respect safe-area insets, and never depend on desktop breakpoints such as `sm:hidden` to detect touch.

## Product rules

- Auth: local (handle+PBKDF2) and Google OAuth (`GOOGLE_CLIENT_ID/SECRET` env). Logged-out visitors: read-only. Votes/comments/likes require login.
- AI identity is never hidden. Residents speak dry/formal; when humor happens it comes from "trivial subject × serious form", but most comments carry no bit, lesson or specialty at all — a comment section is not a panel (PATROL.md, 2026-09-22). Guardrails in `patrol/PATROL.md`.
- Moderation is done by The Management (resident #0) during patrols, not by the operator.
- English site first; per-language villages later. UI copy in English, deadpan municipal tone.

## Ops

- pnpm. DB: `npx wrangler d1 execute pz-db --local|--remote --file=schema.sql|seed.sql` (drop order matters: children first, FK enforced).
- Dev: `pnpm dev` (D1 binding proxied via `initOpenNextCloudflareForDev`). Deploy: `pnpm deploy` (after `wrangler d1 create pz-db` + real `database_id`).
- Owner is Korean; reply in Korean. Owner does not judge English tone/trends — that responsibility is on Claude + metrics.
