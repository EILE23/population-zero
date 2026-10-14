class_name Valley
extends RefCounted
## 산골 도시(운영자 2026-10-14: 체르마트 사진 — "싹 다 뒤집어 엎자", "산맥 마을의 느낌이라 도로도 불규칙하게, 집들도 불규칙하지만 자연스럽게 어우러지게",
## "산으로 막혀 미니게임 만들기 적합한 오픈월드 크기") — 강(z 11.5)을 따라 동서로 누운 골짜기. 바닥은 평평하고(마을이 빽빽), 북·남·양 끝은 산이 둘러막는다.
## 길: 골짜기 큰길(강 북쪽, 굽이진다) + 큰길에서 갈라져 비탈을 오르는 골목(경사를 지키며 저절로 구불구불·지그재그) + 같은 높이의 골목끼리 잇는 옆길, 남쪽은 다리로 건너 오른다.
## 집: 길 양옆에 고르지 않은 간격·물림으로(가운데는 빽빽, 멀어질수록 듬성), 비탈에선 집마다 제 높이의 터(WorldGen pad). 집은 모두 남쪽(골짜기 아래)을 본다
## 이 파일은 순수 계산(정적) — 땅 높이 바탕, 길 그물, 필지. 그리기는 town_city(길·집), world_gen(땅)

const RIVER_Z := 11.5
const FLOOR_N := 110.0     # 강 중심에서 북쪽으로 평평한 바닥 폭(탑 −82·호숫가 −50·오두막 −38 이 바닥에)
const FLOOR_S := 45.0
const END_X := 450.0       # 동서 이 밖은 산이 닫는다
const MAIN_W := 8.0
## 관공서 자리 — 큰길가(북쪽). 둘레 15m 엔 집·마디가 없다(광장)
const CIVIC := [["town_hall", "Town Hall", Vector2(-128.0, -26.0)], ["library", "Library", Vector2(142.0, -28.0)], ["school", "School", Vector2(-232.0, -30.0)]]
const LANE_W := 5.0

static var _n1: FastNoiseLite
static var _n2: FastNoiseLite
static func _noise() -> void:
	if _n1: return
	_n1 = FastNoiseLite.new(); _n1.seed = 4401; _n1.frequency = 0.006; _n1.fractal_octaves = 4
	_n2 = FastNoiseLite.new(); _n2.seed = 4402; _n2.frequency = 0.03; _n2.fractal_octaves = 2

## 비탈까지 거리(0 = 바닥) — 북·남·양 끝 중 가장 깊은 쪽
static func slope_u(x: float, z: float) -> float:
	_noise()
	var d := z - RIVER_Z
	var wob := 18.0 * _n1.get_noise_2d(x * 0.5, 0.0)   # 바닥 가장자리가 출렁인다
	var un := maxf(-d - (FLOOR_N + wob), 0.0)
	var us := maxf(d - (FLOOR_S - wob * 0.6), 0.0)
	var ue := maxf(absf(x) - (END_X + 30.0 * _n1.get_noise_2d(0.0, z * 0.5)), 0.0)
	return maxf(maxf(un, us), ue * 0.9)

## 땅 바탕 높이 — 바닥 0, 비탈은 u 에 따라 가팔라지고(벽), 잔기복은 높을수록 거칠다
static func base_h(x: float, z: float) -> float:
	var u := slope_u(x, z)
	var pk := WorldGen.peak_h_s(x, z).x   # 봉우리(계단 산·큰 봉우리)
	if u <= 0.0: return pk
	var h := 0.005 * u * u + 0.00002 * u * u * u
	h += smoothstep(0.0, 40.0, u) * (6.0 * _n1.get_noise_2d(x, z) + (1.5 + 0.06 * h) * _n2.get_noise_2d(x, z))
	return maxf(maxf(h, 0.0), pk) if pk < h else h + pk * 0.85

# ── 길 그물 ──
## roads: [{pts: PackedVector2Array, w, ys: PackedFloat32Array}] — 0 번이 큰길. junctions: [{road, i, pos}]
static var _roads: Array = []

static func main_z(x: float) -> float:
	var ax := absf(x)
	if ax < 78.0: return 2.0
	return 2.0 - 9.0 * sin((ax - 78.0) / 70.0) * smoothstep(78.0, 120.0, ax) - 6.0 * smoothstep(250.0, 420.0, ax)

static func roads() -> Array:
	if not _roads.is_empty(): return _roads
	var rng := RandomNumberGenerator.new(); rng.seed = 20261014
	var main := PackedVector2Array()
	var x := -END_X
	while x <= END_X:
		main.append(Vector2(x, main_z(x))); x += 6.0
	_roads.append({ "pts": main, "w": MAIN_W, "main": true })
	# 바닥의 골목 그물 — 흔들린 격자(34m × 30m, 마디마다 ±9m)를 굽은 골목으로 잇는다(옛 도시처럼 고르지 않게). 옛 마을(허브)·장소 둘레엔 마디가 없다
	var cols: Array = []
	x = -430.0
	while x <= 430.0: cols.append(x); x += 34.0
	var north_rows := [30.0, 58.0, 86.0]
	var nodes := {}   # Vector2i(col, row) -> Vector2 ; row −1..−3 북, 1 남
	for ci in cols.size():
		for ri in north_rows.size():
			var cx: float = cols[ci]
			var q := Vector2(cx + rng.randf_range(-9.0, 9.0), main_z(cx) - float(north_rows[ri]) + rng.randf_range(-7.0, 7.0))
			if q.y < RIVER_Z - FLOOR_N + 6.0 or _blocked(q): continue
			nodes[Vector2i(ci, -1 - ri)] = q
		var sq := Vector2(float(cols[ci]) + rng.randf_range(-8.0, 8.0), RIVER_Z + 24.0 + rng.randf_range(-5.0, 5.0))
		if not _blocked(sq): nodes[Vector2i(ci, 1)] = sq
	for key in nodes:
		var k: Vector2i = key; var q: Vector2 = nodes[k]
		var right := k + Vector2i(1, 0)
		if nodes.has(right) and rng.randf() < 0.86: _link(q, nodes[right], rng)
		if k.y < 0:
			var up := k + Vector2i(0, -1)
			if nodes.has(up) and rng.randf() < 0.75: _link(q, nodes[up], rng)
			if k.y == -1 and rng.randf() < 0.85: _link(Vector2(q.x + rng.randf_range(-4.0, 4.0), main_z(q.x)), q, rng)   # 큰길로
			if k.y == -3 and k.x % 2 == 0:   # 바닥 끝에서 비탈로 오르는 골목(지그재그)
				var lane := _climb(q, -1.0, rng)
				if lane.size() > 3: _roads.append({ "pts": lane, "w": LANE_W })
		elif k.x % 3 == 1:   # 남쪽 — 다리로 강을 건너 큰길과 잇고, 남쪽 비탈로 오른다
			var br := PackedVector2Array()
			var x0 := q.x
			for t in 9: br.append(Vector2(x0, lerpf(main_z(x0), q.y, t / 8.0)))
			_roads.append({ "pts": br, "w": LANE_W, "bridge": true })
			var lane := _climb(q, 1.0, rng)
			if lane.size() > 3: _roads.append({ "pts": lane, "w": LANE_W })
	for r in _roads:
		r["pts"] = _smooth(r["pts"])
		var ys := PackedFloat32Array()
		for p in r["pts"]: ys.append(maxf(base_h(p.x, p.y), 0.0))
		for pass_ in 3:   # 높이를 길 따라 고른다(턱 없이)
			var ys2 := ys.duplicate()
			for i in range(1, ys.size() - 1): ys2[i] = (ys[i - 1] + ys[i] * 2.0 + ys[i + 1]) / 4.0
			ys = ys2
		r["ys"] = ys
	return _roads

## 마디 둘을 굽은 골목으로(가운데가 옆으로 ±5m 휜다)
static func _link(a: Vector2, b: Vector2, rng: RandomNumberGenerator) -> void:
	var d := b - a
	if d.length() < 8.0: return
	var mid := (a + b) * 0.5 + Vector2(-d.y, d.x).normalized() * rng.randf_range(-5.0, 5.0)
	var pts := PackedVector2Array()
	var n := maxi(3, int(d.length() / 6.0))
	for t in n + 1:
		var f := float(t) / n
		pts.append(a.lerp(mid, f).lerp(mid.lerp(b, f), f))
	_roads.append({ "pts": pts, "w": LANE_W })

## 마디를 놓을 수 없는 곳 — 옛 마을(허브), 장소 둘레와 그리 가는 길, 강
static func _blocked(q: Vector2) -> bool:
	if absf(q.x) < 84.0 and q.y > -36.0 and q.y < 30.0: return true
	for cv in CIVIC: if q.distance_to(cv[2]) < 17.0: return true
	if absf(q.y - RIVER_Z) < 9.0: return true
	for s in WorldGen.SITES:
		var sc: Vector3 = s["c"]
		if q.distance_to(Vector2(sc.x, sc.z)) < float(s["r"]) + 14.0: return true
	return false

## 골목 하나 — 큰길에서 dir(−1 북, +1 남)으로 오르며 한 걸음(6m)에 0.55m 넘게 오르지 않게 방향을 튼다(그래서 구불구불·지그재그). 너무 높거나 길면 멈춘다
static func _climb(start: Vector2, dir: float, rng: RandomNumberGenerator) -> PackedVector2Array:
	var out := PackedVector2Array([start])
	var p := start; var head := Vector2(rng.randf_range(-0.25, 0.25), dir).normalized()
	var stop_h := rng.randf_range(28.0, 55.0); var max_len := rng.randf_range(140.0, 300.0)
	var len := 0.0
	if dir > 0.0:   # 남쪽은 먼저 강을 곧게 건넌다(다리)
		while p.y < RIVER_Z + 7.0:
			p += Vector2(0, 6.0); out.append(p); len += 6.0
	while len < max_len:
		var h0 := base_h(p.x, p.y)
		if h0 > stop_h: break
		var best := Vector2.ZERO; var bs := -1e9
		for da in [0.0, 0.3, -0.3, 0.6, -0.6, 0.95, -0.95, 1.3, -1.3]:
			var hd := head.rotated(da)
			var q := p + hd * 6.0
			if absf(q.x) > END_X + 20.0: continue
			var rise := base_h(q.x, q.y) - h0
			if rise > 0.55: continue
			var score := hd.y * dir * 1.0 - absf(da) * 0.25 + rng.randf() * 0.15   # 오르막 쪽으로, 덜 꺾을수록
			if rise < -0.1: score -= 1.0
			if score > bs: bs = score; best = hd
		if best == Vector2.ZERO: break
		head = best; p += head * 6.0; out.append(p); len += 6.0
	return out

static func _smooth(pts: PackedVector2Array) -> PackedVector2Array:
	if pts.size() < 3: return pts
	var out := PackedVector2Array([pts[0]])
	for i in pts.size() - 1:
		var a := pts[i]; var b := pts[i + 1]
		out.append(a.lerp(b, 0.25)); out.append(a.lerp(b, 0.75))
	out.append(pts[pts.size() - 1])
	return out

## 가장 가까운 길 — [거리, 점, 방향, 높이, 길 번호, 점 번호]
static var _grid := {}
static func _index() -> void:
	if not _grid.is_empty(): return
	var rs := roads()
	for ri in rs.size():
		var pts: PackedVector2Array = rs[ri]["pts"]
		for i in pts.size() - 1:
			var a := pts[i]; var b := pts[i + 1]
			for f in [0.0, 0.5, 1.0]:
				var q := a.lerp(b, f)
				var k := Vector2i(floori(q.x / 12.0), floori(q.y / 12.0))
				if not _grid.has(k): _grid[k] = []
				if not (_grid[k] as Array).has(Vector2i(ri, i)): _grid[k].append(Vector2i(ri, i))

static func near(p: Vector2, reach := 1) -> Array:
	_index()
	var rs := roads()
	var best: Array = [1e9, p, Vector2.RIGHT, 0.0, -1, -1]
	var c := Vector2i(floori(p.x / 12.0), floori(p.y / 12.0))
	for dx in range(-reach, reach + 1):
		for dz in range(-reach, reach + 1):
			for e in _grid.get(c + Vector2i(dx, dz), []):
				var pts: PackedVector2Array = rs[e.x]["pts"]; var ys: PackedFloat32Array = rs[e.x]["ys"]
				var a := pts[e.y]; var b := pts[e.y + 1]
				var ab := b - a
				var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
				var q := a + ab * t; var d := p.distance_to(q)
				var de := d - float(rs[e.x]["w"]) / 2.0   # 길 가장자리까지
				if de < float(best[0]):
					best = [de, q, ab.normalized(), lerpf(ys[e.y], ys[e.y + 1], t), e.x, e.y]
	return best

# ── 필지 ──
static var _lots: Array = []
static func lots() -> Array:
	if not _lots.is_empty(): return _lots
	var rng := RandomNumberGenerator.new(); rng.seed = 7714
	var rs := roads()
	var taken: Array = []   # Vector2
	var cell := {}
	for ri in rs.size():
		var pts: PackedVector2Array = rs[ri]["pts"]
		var w: float = rs[ri]["w"]
		var acc := 0.0; var next := rng.randf_range(3.0, 9.0)
		for i in pts.size() - 1:
			var a := pts[i]; var b := pts[i + 1]
			var seg := a.distance_to(b)
			while acc + seg >= next:
				var f := (next - acc) / seg
				var p := a.lerp(b, f); var dirv := (b - a).normalized(); var nrm := Vector2(-dirv.y, dirv.x)
				var dist_hub := p.length()
				for side in [-1.0, 1.0]:
					if rng.randf() < 0.12: continue   # 빈 자리도 조금(풀밭 틈)
					var setback := w / 2.0 + rng.randf_range(5.2, 7.5)
					var c: Vector2 = p + nrm * float(side) * setback + dirv * rng.randf_range(-1.5, 1.5)
					if not _lot_ok(c, taken, cell): continue
					taken.append(c)
					var k := Vector2i(floori(c.x / 16.0), floori(c.y / 16.0))
					if not cell.has(k): cell[k] = []
					cell[k].append(c)
					_lots.append({ "id": "v%d,%d,%d" % [ri, i, int(side)], "c": c, "road": ri, "road_pt": p, "b": Vector2i(floori((c.x - 16.0) / 40.0), floori((c.y - 2.0) / 40.0)),
						"row": 0, "street_z": c.y + 7.8, "w": 9.0, "form": "", "y": base_h(c.x, c.y), "slope": base_h(c.x, c.y) > 0.5 })
				next += clampf(8.5 + dist_hub * 0.01, 8.5, 13.0) + rng.randf_range(-1.0, 2.0)   # 가운데는 빽빽, 멀수록 듬성
			acc += seg
	# 안쪽 채우기 — 길가 집 뒤의 빈 땅에도 집(골목 그물 칸 안이 빽빽하게, 체르마트처럼). 길에서 30m 안, 비탈은 높이 45m 까지
	var z := RIVER_Z - FLOOR_N - 60.0
	while z < RIVER_Z + FLOOR_S + 40.0:
		var xx := -END_X
		while xx < END_X:
			var c := Vector2(xx + rng.randf_range(-2.5, 2.5), z + rng.randf_range(-2.5, 2.5))
			var nr: Array = near(c, 3)
			if float(nr[0]) < 30.0 and base_h(c.x, c.y) < 45.0 and _lot_ok(c, taken, cell):
				taken.append(c)
				var k := Vector2i(floori(c.x / 16.0), floori(c.y / 16.0))
				if not cell.has(k): cell[k] = []
				cell[k].append(c)
				_lots.append({ "id": "f%d,%d" % [int(xx), int(z)], "c": c, "road": int(nr[4]), "road_pt": nr[1], "b": Vector2i(floori((c.x - 16.0) / 40.0), floori((c.y - 2.0) / 40.0)),
					"row": 0, "street_z": c.y + 7.8, "w": 9.0, "form": "", "y": base_h(c.x, c.y), "slope": base_h(c.x, c.y) > 0.5, "inner": true })
			xx += 10.5
		z += 10.5
	_lots.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var da: float = (a["c"] as Vector2).length() + (0.0 if a["road"] == 0 else 12.0)
		var db: float = (b["c"] as Vector2).length() + (0.0 if b["road"] == 0 else 12.0)
		if absf(da - db) > 0.01: return da < db
		return String(a["id"]) < String(b["id"]))
	var shops := 0
	for k in _lots.size():
		var l: Dictionary = _lots[k]
		l["order"] = k
		var on_main: bool = l["road"] == 0
		var ax := absf((l["c"] as Vector2).x)
		if on_main and ax < 230.0 and shops < 18 and not l["slope"]: l["kind"] = "shop"; shops += 1
		elif on_main and ax > 300.0 and k % 3 == 0: l["kind"] = "workshop"
		elif k % 11 == 7: l["kind"] = "green"
		else: l["kind"] = "house"
	return _lots

static func _lot_ok(c: Vector2, taken: Array, cell: Dictionary) -> bool:
	if absf(c.x) < 80.0 and absf(c.y) < 32.0: return false   # 옛 마을(허브)
	if absf(c.x) > END_X + 10.0: return false
	if absf(c.y - RIVER_Z) < 8.0: return false
	for cv in CIVIC: if c.distance_to(cv[2]) < 17.0: return false
	if TownPlan._near_trail(c): return false   # 산 계단 길 둘레
	var h := base_h(c.x, c.y)
	if h > 60.0: return false
	if absf(base_h(c.x + 5.0, c.y) - base_h(c.x - 5.0, c.y)) > 4.5 or absf(base_h(c.x, c.y + 5.0) - base_h(c.x, c.y - 5.0)) > 4.5: return false   # 너무 가파르다
	for s in WorldGen.SITES:
		var sc: Vector3 = s["c"]
		if c.distance_to(Vector2(sc.x, sc.z)) < float(s["r"]) + 10.0: return false
		if _seg(c, Vector2(s["from"].x, s["from"].z), Vector2(sc.x, sc.z)) < 6.0: return false
	if float(near(c, 2)[0]) < 4.2: return false   # 다른 길 위
	var k := Vector2i(floori(c.x / 16.0), floori(c.y / 16.0))
	for dx in [-1, 0, 1]:
		for dz in [-1, 0, 1]:
			for o in cell.get(k + Vector2i(dx, dz), []):
				if (o as Vector2).distance_to(c) < 9.0: return false
	return true

static func _seg(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return p.distance_to(a + ab * t)

# ── 차 길 그래프(car_rail) — 마디 = 길 끝과 다른 길이 닿는 점(2.5m 안은 한 마디), 가지 = 마디 사이 길 조각 ──
static var _g_nodes: Array = []   # Vector2
static var _g_edges: Array = []   # {a, b, pts: PackedVector2Array, w, road, i0, i1}
static var _g_adj: Array = []     # 마디 -> [가지 번호]
static var _g_of := {}            # Vector2i(길, 점) -> 가지 번호
static func graph() -> void:
	if not _g_nodes.is_empty(): return
	var rs := roads()
	var node_of := func(p: Vector2) -> int:
		for i in _g_nodes.size():
			if (_g_nodes[i] as Vector2).distance_to(p) < 2.5: return i
		_g_nodes.append(p); return _g_nodes.size() - 1
	var cuts := {}   # 길 -> {점 번호: 마디}
	for ri in rs.size():
		var pts: PackedVector2Array = rs[ri]["pts"]
		for end in [0, pts.size() - 1]:
			var p := pts[end]
			var nd: int = node_of.call(p)
			if not cuts.has(ri): cuts[ri] = {}
			cuts[ri][end] = nd
			for rj in rs.size():   # 이 끝이 다른 길 가운데에 닿으면 그 길을 여기서 자른다
				if rj == ri: continue
				var q: PackedVector2Array = rs[rj]["pts"]
				var bi := -1; var bd := 3.2
				for k in q.size():
					var dd := q[k].distance_to(p)
					if dd < bd: bd = dd; bi = k
				if bi >= 0:
					if not cuts.has(rj): cuts[rj] = {}
					cuts[rj][bi] = nd
	for ri in cuts:
		var ks: Array = (cuts[ri] as Dictionary).keys(); ks.sort()
		var pts: PackedVector2Array = rs[ri]["pts"]
		for m in ks.size() - 1:
			var i0: int = ks[m]; var i1: int = ks[m + 1]
			if i1 <= i0: continue
			var seg := pts.slice(i0, i1 + 1)
			var e := { "a": cuts[ri][i0], "b": cuts[ri][i1], "pts": seg, "w": rs[ri]["w"], "road": ri, "i0": i0, "i1": i1 }
			_g_edges.append(e)
			for k in range(i0, i1): _g_of[Vector2i(ri, k)] = _g_edges.size() - 1
	_g_adj.resize(_g_nodes.size())
	for i in _g_adj.size(): _g_adj[i] = []
	for ei in _g_edges.size():
		_g_adj[_g_edges[ei]["a"]].append(ei); _g_adj[_g_edges[ei]["b"]].append(ei)

static func g_nodes() -> Array: graph(); return _g_nodes
static func g_edges() -> Array: graph(); return _g_edges
static func g_adj() -> Array: graph(); return _g_adj
static func edge_of(road: int, i: int) -> int: graph(); return int(_g_of.get(Vector2i(road, i), -1))
