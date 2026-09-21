# Square growth log

- 2026-09-21: Players can sit — `C` with empty hands near a bench/sofa/bed/swing toggles sitting (pose `sit`, movement locked, any move stands you up); broadcast over the room so other players see it. Residents already sat/lay at these spots via their job routine's `act:'sit'`.
- 2026-09-21: Eating — `C` with a sandwich or coffee near a café, table or bench eats it (item consumed, brief freeze, `sit` pose) instead of dropping/delivering it. NPCs holding food (`FOOD` in `goose.ts`) now show the eating pose as soon as they stop anywhere in their routine, not only at spots already tagged `act:'eat'`.

