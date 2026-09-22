# How the town grows — the architecture of the loop (2026-09-22)

One engine, three growers, one set of documents that circulate. Nothing here needs a human to keep going; the human adds direction (rules, ideas) and taste (reviews).

## The three growers
| Grower | Runs | Reads | Writes | Gate |
|---|---|---|---|---|
| **Town** (`patrol/square-grow.mjs`, Gemini/OpenAI) | every patrol (~90 min) | current `site_meta.square_content`, roster, yesterday's human actions, its own past wishes | props · maps · lines · angry list → `site_meta.square_content` (data, no deploy); one **wish** per patrol (a BIG one on Sundays) → `GROW-BACKLOG.md` | validation in the script (kinds, coordinates, caps: 3/patrol, 5/day, 200 total; 1 map/day) |
| **Developer** (`.github/workflows/grow-code.yml`, Claude Code) | 4×/day + manual bursts | `GROW.md` (rules), `GROW-BACKLOG.md` (open items only), tail of `GROW-LOG.md`/`GROW-DONE.md` | code in the engine + Square + Climb; marks the item `[x]`; appends `GROW-LOG.md`; adds ≥2 new ideas to the thinnest axes (Monday: a ten-item vision) | allowed paths · ≤900 lines · tsc · tests · build · deploy; conflict-safe push; kill switch `GROW_CODE=off` |
| **Game builder** (`.github/workflows/build-game.yml`, Claude Code) | 3×/day + manual | `GAMES.md`, one queued request from the `games` table (a person's prompt, or a `fix:` note) | `site/src/features/games/<slug>/` + one registry line; appends `GAMES-LOG.md`; sets the game to `review` | own folder only · ≤2500 lines · same build gate · **maker approval** before `live`; two failed rounds = failed |

Plus the **people**: feedback on resident posts (`feedback` table → patrol worklist → next piece changes; The Management sieves), game requests and reviews on `/play`, and the owner's rules.

## The documents and how they circulate
```
owner ideas ─┐
town wishes ─┼─► GROW-BACKLOG.md (open items only, grouped by axis)
dev's own  ──┘          │ picked, implemented, marked [x]
                        ▼
              GROW-LOG.md (one line per run: date, what, how)  ──► growth/GROW-LOG-YYYY-MM.md (rolled when >400 lines)
                        │ next run starts: grow-tidy.mjs
                        ▼
              GROW-DONE.md (the [x] lines, dated — what shipped, for anyone who asks "is X done?")
```
- `grow-tidy.mjs` runs at the start of every developer/builder run: `[x]` → `GROW-DONE.md`, empty sections dropped, long logs rolled into `patrol/growth/`. The backlog the model reads never carries finished work, so its reading cost stays flat while the history stays complete.
- `GAMES-LOG.md` rolls the same way. `GROW.md` and `GAMES.md` are the constitution: only humans edit them.
- The town's data (`site_meta.square_content`) is capped (props 200, maps 12, lines 300 per key); when a cap is hit the oldest entries fall off — growth there is a window, and anything worth keeping forever should become code via a wish.

## Invariants (the lines that never move)
- The engine is one source (`stickman`, `tower`, `world`, `goose`, `games/engine`), grows only through the developer job, and stays free of browser dependencies so it ports to the app (the end goal is a mini-game party app).
- Every player action has a resident counterpart; every behaviour has its own motion; every interaction has a task or quest; growth is unlocks and reputation, never levels; the town is open world.
- No human merge, but no unreviewed *game*: engine changes are gated by the build, games by their maker.
- Costs: no LLM on a request path; growers run on free-tier models or the owner's Claude subscription; the game pages ship no ads.

## What to watch (weekly)
- `GROW-DONE.md` growth rate vs backlog size (should be ~4/day and the backlog never < 10).
- `grow-code` runs with `CONFLICT` in the log (the merge path handled it, but a cluster means two writers are fighting).
- The town's wish quality (are they concrete?) and whether the developer picks them.
- Feedback counts per resident and the sieve's dismissal rate (too high = the sieve is hiding real signal).
