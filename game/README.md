# POZ — the game

A 2.5D stick-figure town you can walk into. Godot 4.3, GDScript. The web site (`../site`) is the game's home:
account, invites, community, and the web export as a playable demo. Decided 2026-09-28 (see repo `CLAUDE.md`).

## What this is, in one line each
- **Not a community.** A real indie game. Square and Climb on the web were the prototype; this is the product.
- **2.5D**: depth `d` (0 back → 1 front) becomes screen y and scale. Same numbers as the web engine (`scripts/stage.gd` ↔ `site/src/features/games/engine/scene.ts`).
- **Stick figures drawn in code**: `scripts/figure.gd` is a port of `site/src/lib/stickman.ts` — same joints, same lengths, same pose names (≤6 chars). A new pose is one `match` arm, on both sides.
- **Residents are the cast**: the 148 town personas become NPCs, and **bots that fill empty slots when you invite a friend** (StarCraft's "computer" player). Their data comes from the site's D1 as JSON.
- **Multiplayer at zero cost**: Godot's high-level multiplayer over WebSocket, relayed by the existing Cloudflare Durable Object room. No dedicated servers.
- **Editor and map sharing come later.** First a game that is fun alone and with three friends.

## The bar (owner, 2026-09-28): at least Pokémon Omega Ruby
That means a **real low-poly 3D world** seen from a 3/4 camera, not paper cut-outs: box buildings with painted faces, trunk-and-sphere
trees, tiled ground with paths, one sun with soft shadows, toon-flat shading, and a **3D stick figure** whose walk is computed every frame
(no flip-books). `scenes/town3d.tscn` is the first cut of exactly that; `scripts/stick3d.gd` is the figure (capsule bones, sphere joints,
walk phase driven by distance so feet never slide, arms opposite legs, knees fold on the back swing, torso leans with speed, smooth turning).
Everything is still generated from code: geometry from primitives in GDScript, textures from `tools/assets.mjs` (`faces/`, `ground/`).
`scenes/reference/main.tscn` (2D stage) and `scenes/reference/diorama.tscn` (paper cut-outs) stay as references only; F5 runs `town3d.tscn`.
Jumping in the town is a short hop (no charge — that was Climb's), and the world has real collision: you can stand on benches, steps and low walls.

## Assets policy
Everything visual is **vector or procedural** (`_draw()`, SVG under `assets/svg/`), paper background, ink lines, the brand mauve
(`#AD7096`) only as an accent. Text assets diff in git, so the CI developer can make and fix them; the style cannot drift; the cost is zero.
Image models are for illustrations (covers, posters in the world), never for sprites. Audio: CC0 packs first, procedural later.

## Layout
```
game/
  project.godot        960×470 canvas, GL Compatibility (runs on the web export and phones), input map (arrows, SPACE, X, Z, C)
  scenes/main.tscn     paper → stage → world (player) → legend
  scripts/stage.gd     2.5D maths (dy, ds, dist, follow) + floor band
  scripts/figure.gd    the stick figure (poses)
  scripts/player.gd    control: walk, depth, charge-jump (tower.ts constants), punch, kick
  scripts/main.gd      camera
```

## Run / check
- Editor: open `game/` in Godot 4.3.
- Headless check (what CI does): `godot --headless --path game --import` then `godot --headless --path game --quit-after 5`.
  Headless has no renderer: 3D scenes (`diorama.tscn`) print harmless `Parameter "m" is null` lines from meshes; only `SCRIPT ERROR` / `Parse Error` count.
- Two stages to compare (owner, 2026-09-28): `scenes/main.tscn` is the 2D depth-scaled stage (like the web); `scenes/diorama.tscn` is the same assets as
  paper figures on a real 3D ground with a low camera, belt-scroll movement (8-way, double-tap dash, charge jump). Same SVGs, same numbers.
- Web export (later, CI): `godot --headless --path game --export-release Web export/web/index.html`, published to the site's `/play` as the demo.

## Code style (GDScript 4.x — the same rules as the `godot-code-gen` skill the owner asked for, 2026-09-28)
- Type everything: `var speed: float = 2.6`, `func f(a: int) -> void`, `Array[Node3D]`; `:=` only when the right side has a definite type (a `Dictionary`/`Array` element does not — annotate it).
- `@onready var x: Type = $Path` for node references; `@export` for tunables the owner may touch in the inspector.
- Prefer signals over reaching into other nodes: `signal hit(by: Node3D)`, `hit.emit(...)`, `node.hit.connect(_on_hit)`.
- Explicit state: an `enum State { IDLE, WALK, ... }` plus `match` per frame, `change_state()` with `_enter/_exit`; no string states in new code (existing `state: String` in `resident.gd` is legacy — migrate when touched).
- Data as `Resource`s when it is shared (an item type, a wearable spec), not ad-hoc dictionaries; dictionaries are fine for transient per-frame state.
- `_private` for internal members; PascalCase classes, snake_case functions and variables; `##` doc comments on every class and public function (in Korean, saying *why*).
- Tweens: `create_tween()` with `set_trans/set_ease`; `await` for timing, never busy loops. `instantiate()`, not `instance()`. Physics layers start at 1.
- Composition over inheritance for behaviours (the town chain is layering of one object, not behaviour reuse — new behaviours go in their own node/script).

## Growth
The autonomous developer (`patrol/GROW.md`, `.github/workflows/grow-code.yml`) is being retargeted here. Rules that carry over:
motions must be diverse and every behaviour has its own; residents do what players do; no levels (unlocks and reputation);
density rule — one prop per 200px, 150px gap; never make a core action stop working; every fourth run is a polish run.
