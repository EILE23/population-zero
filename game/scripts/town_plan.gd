class_name TownPlan
extends RefCounted
## 마을 도시계획(운영자 2026-10-06: "동물의 숲 느낌인데 마을이 엄청 커졌을 때 저 정도 규모(SimCity 스크린샷)가 되었으면", "빌딩을 실제로 짓는 건축가들").
## 한 번에 깔지 않는다 — 계획은 격자 필지 목록일 뿐이고, 건축가 주민이 허브에서 가까운 필지부터 하나씩 짓는다(town_growth.gd). 지어진 만큼만 마을이다.
## 격자: 남북 골목 x = OX + k·PITCH(탑 길 x 16 과 같은 줄), 동서 골목 z = OZ + j·PITCH(큰길 z 2 와 같은 줄). 블록 안에 남북 두 줄 × 셋 = 필지 여섯(12m 사방, 마당 있는 집).
## 허브(이미 있는 마을)·장소(탑·호숫가·오두막) 둘레·강 둘레엔 필지가 없다. 순서는 허브 가운데에서의 거리 — 마을이 둥글게 번진다

const PITCH := 40.0
const PATH_W := 3.2          # 동물의 숲 같은 흙·돌 골목(차도가 아니다)
const OX := 16.0
const OZ := 2.0
const REACH := 640.0         # 계획이 닿는 반경(m) — 그 안 필지 수천 개, 다 지으려면 오래 걸린다(끝없는 성장)
const LOT := 12.0

static var _lots: Array = []   # [{id, c: Vector2, b: Vector2i, i, street_z}] — 순서 = 지을 순서

static func lots() -> Array:
	if not _lots.is_empty(): return _lots
	var n := int(REACH / PITCH)
	for bx in range(-n, n):
		for bz in range(-n, n):
			var x0 := OX + bx * PITCH + PATH_W / 2.0; var z0 := OZ + bz * PITCH + PATH_W / 2.0
			var inner := PITCH - PATH_W
			for row in 2:
				for i in 3:
					var c := Vector2(x0 + inner / 6.0 * (1 + 2 * i), z0 + inner * (0.27 if row == 0 else 0.73))
					if not _ok(c): continue
					_lots.append({ "id": "%d,%d,%d" % [bx, bz, row * 3 + i], "c": c, "b": Vector2i(bx, bz), "row": row, "street_z": z0 + inner + PATH_W / 2.0 if row == 1 else z0 - PATH_W / 2.0 })
	_lots.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return (a["c"] as Vector2).length_squared() < (b["c"] as Vector2).length_squared())
	for k in _lots.size(): _lots[k]["order"] = k
	return _lots

## 필지가 될 수 있는 자리 — 허브 밖, 장소·강·큰길에서 떨어져, 계획 반경 안
static func _ok(c: Vector2) -> bool:
	if c.length() > REACH: return false
	if absf(c.x) < WorldGen.HUB_X + 6.0 and absf(c.y) < WorldGen.HUB_Z + 6.0: return false
	if absf(c.y - 11.5) < 11.0: return false   # 강(z 11.5) 둘레
	if absf(c.y - OZ) < 8.0: return false      # 큰길
	for s in WorldGen.SITES:
		var sc: Vector3 = s["c"]
		if c.distance_to(Vector2(sc.x, sc.z)) < float(s["r"]) + 12.0: return false
		if _seg(c, Vector2(s["from"].x, s["from"].z), Vector2(sc.x, sc.z)) < 7.0: return false   # 장소 가는 길 위
	return true

static func _seg(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return p.distance_to(a + ab * t)

## 이 점에서 가장 가까운 '깎인'(지은·짓는) 필지 블록까지 거리 — 땅 깎기(WorldGen)가 쓴다. limit = 이 순번 미만 필지가 깎인다
static var _blocks_upto := {}   # Vector2i -> 그 블록의 가장 이른 순번
static func block_order(b: Vector2i) -> int:
	if _blocks_upto.is_empty():
		for l in lots():
			var k: Vector2i = l["b"]
			_blocks_upto[k] = mini(int(_blocks_upto.get(k, 1 << 30)), int(l["order"]))
	return int(_blocks_upto.get(b, 1 << 30))

static func flat_dist(x: float, z: float, limit: int) -> float:
	var bx := floori((x - OX) / PITCH); var bz := floori((z - OZ) / PITCH)
	var best := 1e9
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			var b := Vector2i(bx + dx, bz + dz)
			if block_order(b) >= limit: continue
			var r := Rect2(OX + b.x * PITCH - 2.0, OZ + b.y * PITCH - 2.0, PITCH + 4.0, PITCH + 4.0)
			var ddx := maxf(maxf(r.position.x - x, x - r.end.x), 0.0); var ddz := maxf(maxf(r.position.y - z, z - r.end.y), 0.0)
			best = minf(best, Vector2(ddx, ddz).length())
	return best

## 필지의 집 사양 — 같은 필지는 언제나 같은 집(벽 색·지붕·크기·시드)
static func house_spec(l: Dictionary) -> Dictionary:
	var rng := RandomNumberGenerator.new(); rng.seed = hash(String(l["id"]))
	var walls := [Color("e6d3a5"), Color("dfe6ea"), Color("efe9e2"), Color("b56a5a"), Color("8fb8cc"), Color("b5c9a8"), Color("e8bfa4"), Color("c4b0d0")]
	var roofs := ["wood", "brick", "shingle", "iron"]
	return { "size": Vector3(rng.randf_range(3.6, 4.8), rng.randf_range(2.5, 3.0), rng.randf_range(3.2, 3.8)), "wall": walls[rng.randi() % walls.size()], "roof": roofs[rng.randi() % roofs.size()], "seed": 100 + int(l["order"]) }
