class_name TownPlan
extends RefCounted
## 마을 도시계획(운영자 2026-10-06: "동물의 숲 느낌인데 마을이 엄청 커졌을 때 저 정도 규모(SimCity 스크린샷)가 되었으면", "빌딩을 실제로 짓는 건축가들").
## 한 번에 깔지 않는다 — 계획은 격자 필지 목록일 뿐이고, 건축가 주민이 허브에서 가까운 필지부터 하나씩 짓는다(town_growth.gd). 지어진 만큼만 마을이다.
## 격자: 남북 찻길 x = OX + k·PITCH(탑 길 x 16 과 같은 줄), 동서 찻길 z = OZ + j·20(큰길 z 2 와 같은 줄, 블록 가운데에도 하나). 찻길은 다 9m(ROAD_W).
## 블록 안에 동서 두 줄 × 넷 = 필지 여덟, 집은 다 남쪽 찻길을 보고 뒤뜰(5m)이 북쪽 찻길 인도까지 간다 — 빈 띠가 없다
## 허브(이미 있는 마을)·장소(탑·호숫가·오두막) 둘레·강 둘레엔 필지가 없다. 순서는 허브 가운데에서의 거리 — 마을이 둥글게 번진다

const PITCH := 40.0
const ROAD_W := 9.0          # 찻길(운영자 2026-10-13: "도로도 조금 현대화") — 아스팔트 두 차선 + 갓길 주차 + 양쪽 인도(Kenney City Kit 도로 판, road_tiles). 전엔 3.2m 흙·돌 골목
const OX := 16.0
const OZ := 2.0
const REACH := 640.0         # 계획이 닿는 반경(m) — 그 안 필지 수천 개, 다 지으려면 오래 걸린다(끝없는 성장)
const LOT := 7.2
const PER_ROW := 4           # 한 줄 네 채(7.75m 간격) — 찻길이 넓어져 다섯이면 차고집·방갈로가 옆집에 닿았다
const FRONT := 7.8           # 길 가운데에서 집 가운데까지(인도 4.5 + 앞마당 1.5 + 집 반 깊이 1.8)

static var _lots: Array = []   # [{id, c: Vector2, b: Vector2i, i, street_z}] — 순서 = 지을 순서

static func lots() -> Array:
	if not _lots.is_empty(): return _lots
	var n := int(REACH / PITCH)
	for bx in range(-n, n):
		for bz in range(-n, n):
			for sl in block_slots(bx, bz):
				if not _ok(sl["c"]): continue
				var l: Dictionary = sl.duplicate(); l["b"] = Vector2i(bx, bz)
				_lots.append(l)
	# 블록 단위로 — 가까운 블록부터 그 블록을 다 채우고 다음 블록(운영자 2026-10-08: 섹션마다 빼곡해야). 전엔 필지마다 거리순이라 블록들이 반쯤 빈 채 흩어졌다
	var bd := func(l: Dictionary) -> float: return Vector2(OX + (l["b"].x + 0.5) * PITCH, OZ + (l["b"].y + 0.5) * PITCH).length()
	_lots.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var da: float = bd.call(a); var db: float = bd.call(b)
		if absf(da - db) > 0.01: return da < db
		return String(a["id"]) < String(b["id"]))
	for k in _lots.size(): _lots[k]["order"] = k
	return _lots

## 블록 모양(운영자 2026-10-13: "블록마다 형태가 다양해져야") — 블록마다 늘 같은 하나(블록 좌표로 고른다). 한 줄 = 폭 31m 를 나눈 자리들:
##   rows 넷·넷 / villas 큰 집 둘(15.5m)·넷 / terrace 넷·붙은 집 다섯(6.2m) / apartment 연립 하나와 주차장·넷 / courtyard 넷·넷(가운데 찻길 없이 안마당) / mixed 큰 집 하나와 둘·붙은 집 다섯
##   번화가: rows 가게 넷·넷 / square 가게·광장(15.5m)·가게 / wide 큰 가게 셋. 공방가는 rows
const R4 := [[7.75, ""], [7.75, ""], [7.75, ""], [7.75, ""]]
const FORMS := {
	"rows": [R4, R4], "villas": [[[15.5, "villa"], [15.5, "villa"]], R4], "terrace": [R4, [[6.2, "terrace"], [6.2, "terrace"], [6.2, "terrace"], [6.2, "terrace"], [6.2, "terrace"]]],
	"apartment": [[[15.5, "apartment"], [15.5, "parking"]], R4], "courtyard": [R4, R4],
	"mixed": [[[15.5, "villa"], [7.75, ""], [7.75, ""]], [[6.2, "terrace"], [6.2, "terrace"], [6.2, "terrace"], [6.2, "terrace"], [6.2, "terrace"]]],
	"square": [[[7.75, ""], [15.5, "plaza"], [7.75, ""]], R4], "wide": [[[10.33, "wide"], [10.33, "wide"], [10.33, "wide"]], R4],
}
static func form_of(bx: int, bz: int) -> String:
	var zone := CityMap.zone_at(Vector2(OX + (bx + 0.5) * PITCH, OZ + (bz + 0.5) * PITCH))
	var h := absi(hash("form/%d,%d" % [bx, bz])) % 100
	if zone == "high_street": return "rows" if h < 45 else ("square" if h < 75 else "wide")
	if zone == "workshop": return "rows"
	if h < 24: return "rows"
	if h < 40: return "villas"
	if h < 56: return "terrace"
	if h < 70: return "apartment"
	if h < 88: return "courtyard"
	return "mixed"

## 블록의 자리들 — [{id, c, row, street_z, w, form}] (필지가 아니어도 — 강·장소 둘레에 걸린 자리도 town_city 가 채운다)
static func block_slots(bx: int, bz: int) -> Array:
	if is_hill(Vector2i(bx, bz)): return hill_slots(bx, bz)
	var out: Array = []
	var f: Array = FORMS[form_of(bx, bz)]
	for row in 2:
		var sz := OZ + bz * PITCH + (PITCH / 2.0 if row == 0 else PITCH)
		var x := OX + bx * PITCH + ROAD_W / 2.0
		var i := 0
		for cell in f[row]:
			var w: float = cell[0]
			out.append({ "id": "%d,%d,%d" % [bx, bz, row * 10 + i], "c": Vector2(x + w / 2.0, sz - FRONT), "row": row, "street_z": sz, "w": w, "form": String(cell[1]) })
			x += w; i += 1
	return out

## 산 블록 — 블록 가운데가 산 자락 안(꼭대기 둘레는 빼고). 찻길 격자 대신 비탈에 집이 흩어져 서고(PAD 터), 흙길로 이어진다
static func is_hill(b: Vector2i) -> bool:
	var c := Vector2(OX + (b.x + 0.5) * PITCH, OZ + (b.y + 0.5) * PITCH)
	return WorldGen.peak_k_s(c.x, c.y) > 0.03

## 산 블록의 집 자리 — 일곱까지, 서로 10.5m 넘게(시드로 늘 같은 곳). 꼭대기 둘레·계단 길 둘레는 뺀다
static func hill_slots(bx: int, bz: int) -> Array:
	var rng := RandomNumberGenerator.new(); rng.seed = hash("hill/%d,%d" % [bx, bz])
	var out: Array = []
	for tries in 26:
		if out.size() >= 7: break
		var c := Vector2(OX + bx * PITCH + rng.randf_range(5.0, PITCH - 5.0), OZ + bz * PITCH + rng.randf_range(5.0, PITCH - 5.0))
		if WorldGen.peak_k_s(c.x, c.y) > 0.72 or _near_trail(c): continue
		if out.any(func(o: Dictionary) -> bool: return (o["c"] as Vector2).distance_to(c) < 10.5): continue
		out.append({ "id": "%d,%d,h%d" % [bx, bz, out.size()], "c": c, "row": 0, "street_z": c.y + FRONT, "w": 9.0, "form": "hill", "hill": true })
	return out

static var _trail_grid := {}
static func _near_trail(c: Vector2) -> bool:
	if _trail_grid.is_empty():
		for pk in WorldGen.PEAKS:
			for p in WorldGen.trail_xz(pk): _trail_grid[Vector2i(floori(p.x / 6.0), floori(p.y / 6.0))] = true
	for dx in [-1, 0, 1]:
		for dz in [-1, 0, 1]:
			if _trail_grid.has(Vector2i(floori(c.x / 6.0) + dx, floori(c.y / 6.0) + dz)): return true
	return false

## 가운데 찻길이 없는 블록(안마당) — road_tiles·town_traffic 이 본다
static func no_lane(b: Vector2i) -> bool: return form_of(b.x, b.y) == "courtyard"

static var _by_id := {}
static func lot_by_id(id: String) -> Dictionary:
	if _by_id.is_empty():
		for l in lots(): _by_id[String(l["id"])] = l
	return _by_id.get(id, {})

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
	if CityMap.whole_block(CityMap.block_of(c)): return false   # 관공서·공원 블록은 통째로(data/map/town.json)
	return true

## 집이 실제로 서는 자리 — 필지 가운데에서 조금씩 앞뒤·좌우로(운영자 2026-10-06: "너무 규칙적이니까 별로") — 필지 순번마다 늘 같다
static func spot_of(l: Dictionary) -> Vector3:
	if l.get("hill", false): return Vector3(l["c"].x, float(l.get("y", 0.0)), l["c"].y)   # 산 집 — 제 터 높이(WorldGen _hill_setup)
	if String(l.get("form", "")) != "": return Vector3(l["c"].x, 0, l["c"].y)   # 붙은 집·큰 집·연립·광장은 줄을 맞춘다
	var rng := RandomNumberGenerator.new(); rng.seed = hash("at/" + String(l["id"]))
	return Vector3(l["c"].x + rng.randf_range(-0.45, 0.45), 0, l["c"].y + rng.randf_range(-0.7, 0.5))

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

static var extra_flat := {}   # 아직 안 지었지만 찻길을 깔고 채운 블록(town_city _grow_streets) — 이 블록도 평지
static func flat_dist(x: float, z: float, limit: int) -> float:
	var bx := floori((x - OX) / PITCH); var bz := floori((z - OZ) / PITCH)
	var best := 1e9
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			var b := Vector2i(bx + dx, bz + dz)
			if (block_order(b) >= limit and not extra_flat.has(b)) or is_hill(b): continue   # 산 블록은 깎지 않는다(집마다 제 터)
			var r := Rect2(OX + b.x * PITCH - 2.0, OZ + b.y * PITCH - 2.0, PITCH + 4.0, PITCH + 4.0)
			var ddx := maxf(maxf(r.position.x - x, x - r.end.x), 0.0); var ddz := maxf(maxf(r.position.y - z, z - r.end.y), 0.0)
			best = minf(best, Vector2(ddx, ddz).length())
	return best

## 필지의 집 사양 — 같은 필지는 언제나 같은 집(벽 색·지붕·크기·시드)
static func house_spec(l: Dictionary) -> Dictionary:
	var rng := RandomNumberGenerator.new(); rng.seed = hash(String(l["id"]))
	var th := District.of_block(l["b"])   # 동네 빛깔 묶음(district)
	var walls: Array = (th["walls"] as Array).map(func(h: String) -> Color: return Color(h))
	var roofs := ["wood", "brick", "shingle", "iron"]
	return { "size": Vector3(rng.randf_range(3.6, 4.8), rng.randf_range(2.5, 3.0), rng.randf_range(3.2, 3.8)), "wall": walls[rng.randi() % walls.size()], "roof": roofs[rng.randi() % roofs.size()], "seed": 100 + int(l["order"]) }
