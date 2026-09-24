# Town growth architecture

Population: Zero does **not** have a town level, XP bar, tier, or numeric progression rank.
The town grows because its physical world changes.

## What counts as growth

Visible growth is one or more of:
- a new map/district/street;
- a new building or usable civic place;
- construction that later becomes a usable place;
- new housing that can gain residents;
- a new job whose routine uses a real place;
- population changes that alter routines/housing;
- infrastructure such as bridges, docks, transit stops, clinics, schools, markets, parks.

Tiny interaction variants are depth, not town growth. They are still useful, but they must not crowd out physical expansion.

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

Before choosing a backlog item, inspect the last four shipped feature runs.
If none visibly expanded the map/building/infrastructure footprint, the next non-polish run must choose a feasible **places/buildings/infrastructure** item before another micro-interaction.

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
