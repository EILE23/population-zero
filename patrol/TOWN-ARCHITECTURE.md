# Town growth architecture

Population: Zero does **not** have a town level, XP bar, tier, or numeric progression rank.
The town grows because its physical world changes.

## What counts as growth

Visible growth has two levels:

**Structural growth** — this is what resets the autonomous growth cadence:
- a new map/district/street/path;
- an enterable building interior connected by exits;
- new housing with an owner and a distinct interior;
- a new traversable map connection, bridge, dock, transit route, or equivalent;
- construction visibly advancing toward one of those.

**Density growth** — useful, but it does not reset the structural cadence:
- a façade or `PropKind` placed on an existing map;
- a civic spot with no enterable interior;
- a new job whose workplace is an existing spot;
- a new interaction, board, stall, bench, game court, or decorative facility.

Tiny interaction variants are depth, not structural growth. A clinic façade or dance deck on an existing map may make a district denser, but it is not the same thing as creating new traversable space.

## Code ownership

- `site/src/lib/world.ts`: stable built-in maps, buildings, spots, jobs, exits.
- `site/src/features/square/town/content.ts`: schema boundary for patrol-written maps/spots/dialogue from `site_meta.square_content`.
- `site/src/features/square/components/SquareGame.tsx`: rendering, input, multiplayer presentation; do not turn it into a database/schema file.
- `site/src/features/games/mobile.ts`: shared browser viewport/orientation behavior for canvas games.
- `site/src/features/games/engine/**`: pure cross-game rules only; no browser globals.
- `patrol/GROW-BACKLOG.md`: executable roadmap.
- `patrol/GROW.md`: autonomous-code rules.

When a town-growth feature starts needing multiple concerns, split by responsibility instead of extending a single 100k+ line component:
`town/` for dynamic-town parsing/planning, `components/` for rendering/input, `lib/world.ts` for pure world data.

## Autonomous growth rule

Before choosing a backlog item, inspect the last three shipped non-polish feature runs.
At least one of every three must be **structural growth** under the definition above. If none qualifies, the next non-polish run must choose a feasible map/interior/housing/connection item before another density or interaction feature.

Do not create a fake "Town Lv. 2" gate. Unlocks come from concrete state:
a place exists, a construction finishes, a resident/job appears, a relationship/population event happens, or a prerequisite system is present.

Prefer build chains such as:
proposal -> construction site -> builders working -> finished building -> job routine -> resident/player interaction.

Each link should remain small enough for one autonomous run and preserve mobile playability.

## Mobile acceptance

Every game change must be checked at:
- desktop;
- phone portrait;
- phone landscape (primary play layout on phones).

Landscape must fit the game surface inside the visual viewport, keep controls tappable, respect safe areas, and avoid page-level horizontal scrolling.
Touch targets should remain about 44px or larger. Do not hide required actions on touch devices.

## Quality gates

Before merge: TypeScript, existing schema/parity tests, no new dependency unless owner explicitly approves, no duplicated world rules, no browser APIs in pure engine modules, and no feature that only works for residents or only for humans when the reciprocal rule applies.
