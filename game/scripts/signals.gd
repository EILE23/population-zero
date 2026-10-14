class_name Signals
extends RefCounted
## 신호등과 횡단보도(운영자 2026-10-14: "도로 사이를 횡단하게 하려면 육교를 만들던지 아니면 신호등을 만들어") —
## 큰길과 골목(다리)이 만나는 마디 중 80m 마다 하나에 신호등과 횡단보도. 사람·주민은 큰길을 그 횡단보도로만 건넌다(town_places.crossings).
## 나머지 큰길 갈림목은 골목 쪽 멈춤(골목 차가 한 번 서고 큰길 차에 양보). 큰길 차는 신호만 본다.
## 한 바퀴 23초(모든 신호가 같은 시계 — 서버 시계가 아니어도 판정이 차·주민 쪽에서 같다):
##   0..11 큰길 초록, 11..13.5 모두 빨강, 13.5..21 골목 초록·건널 수 있음(걷기 시작은 16 까지), 21..23 모두 빨강
## 길이 더해지면(RoadNet.version) 다음 물음 때 다시 고른다 — 새 길의 마디도 같은 규칙

const CYCLE := 23.0
const SPACING := 80.0
const XW_OFF := 5.0   # 마디에서 큰길 따라 횡단보도 가운데까지

static var list: Array = []    # [{node, p: Vector2, dir: Vector2(큰길 방향, 동쪽으로), y}]
static var _of := {}           # 마디 -> list 번호(신호 마디, 가까운 이웃 마디도 같은 신호)
static var _yield := {}        # 마디 -> 큰길 방향(멈춤 마디)
static var _ver := -1
static var main_mat: StandardMaterial3D
static var side_mat: StandardMaterial3D
static var walk_mat: StandardMaterial3D

static func phase_t() -> float: return fmod(Time.get_ticks_msec() / 1000.0, CYCLE)

static func build() -> void:
	if _ver == RoadNet.version: return
	_ver = RoadNet.version; list.clear(); _of.clear(); _yield.clear()
	var nodes := RoadNet.nodes(); var edges := RoadNet.edges(); var adj := RoadNet.adj()
	var cand: Array = []
	for ni in nodes.size():
		if (adj[ni] as Array).size() < 3: continue
		var mdir := Vector2.ZERO; var side := false
		for ei in adj[ni]:
			var e: Dictionary = edges[ei]
			if bool(RoadNet.roads[int(e["road"])]["main"]):
				var pts: PackedVector2Array = e["pts"]
				var d := pts[1] - pts[0] if pts[0].distance_to(nodes[ni]) < pts[pts.size() - 1].distance_to(nodes[ni]) else pts[pts.size() - 1] - pts[pts.size() - 2]
				mdir = d.normalized() * signf(d.x if absf(d.x) > 0.01 else 1.0)
			else: side = true
		if mdir != Vector2.ZERO and side: cand.append([ni, mdir])
	cand.sort_custom(func(a: Array, b: Array) -> bool: return (nodes[a[0]] as Vector2).x < (nodes[b[0]] as Vector2).x)
	var last := -1e9
	for c in cand:
		var p: Vector2 = nodes[c[0]]
		if not list.is_empty() and p.distance_to(list[list.size() - 1]["p"]) < 14.0:   # 엇갈린 골목 둘(북·남이 몇 m 어긋남) — 한 신호가 둘 다
			_of[c[0]] = list.size() - 1; continue
		if p.x - last < SPACING or Valley.SQUARE.grow(4.0).has_point(p): _yield[c[0]] = c[1]; continue
		last = p.x
		var d: Vector2 = c[1]
		list.append({ "node": c[0], "p": p, "dir": d, "y": float(RoadNet.near(p)[3]) })
		_of[c[0]] = list.size() - 1

## 차가 갈림목에 다가갈 때(car_rail) — 0 가도 된다, 1 빨간불, 2 멈춤 표지. from = 마디에서 본 차가 오는 쪽(Vector2)
static func rule(nd: Variant, from: Variant) -> int:
	build()
	if not (nd is int) or not (from is Vector2): return 0
	var f: Vector2 = (from as Vector2).normalized()
	if _of.has(nd):
		var s: Dictionary = list[_of[nd]]
		var t := phase_t()
		if absf(f.dot(s["dir"])) > 0.6: return 0 if t < 11.0 else 1
		return 0 if t >= 13.5 and t < 21.0 else 1
	if _yield.has(nd): return 0 if absf(f.dot(_yield[nd])) > 0.6 else 2
	return 0

## 큰길 건너기 — 출발·도착이 큰길 다른 편이면 가까운 횡단보도의 이쪽 발치(파란불 기다림, act "xwalk")와 건너편 발치
static func walk_steps(from: Vector3, to: Vector3) -> Array:
	var sa := signf(from.z - Valley.main_z(from.x)); var sb := signf(to.z - Valley.main_z(to.x))
	if sa == sb or absf(from.x) > Valley.END_X or absf(to.x) > Valley.END_X: return []
	build()
	var best := -1; var bd := 1e9
	for i in list.size():
		var px: float = (list[i]["p"] as Vector2).x
		var d := absf(px - from.x) + absf(px - to.x)
		if d < bd: bd = d; best = i
	if best < 0: return []
	var s: Dictionary = list[best]
	var c: Vector2 = s["p"] + (s["dir"] as Vector2) * XW_OFF
	var half := Valley.MAIN_W / 2.0 + 0.9
	var near_side := Vector2(c.x, Valley.main_z(c.x) + sa * half); var far_side := Vector2(c.x, Valley.main_z(c.x) - sa * half)
	near_side = c + ((near_side - c).normalized() if near_side != c else Vector2.UP) * half
	far_side = c + ((far_side - c).normalized() if far_side != c else Vector2.DOWN) * half
	return [{ "pos": Vector3(near_side.x, 0, near_side.y), "act": "xwalk" }, { "pos": Vector3(far_side.x, 0, far_side.y), "act": "" }]

## 건너기 시작해도 되나(파란불이 켜지고 2.5초 안 — 그 뒤에 들어서면 다 못 건넌다)
static func walk_ok() -> bool:
	var t := phase_t()
	return t >= 13.5 and t < 16.0

## 불빛 — 모든 신호가 한 시계라 재질 셋을 함께 쓴다(매 프레임 빛깔만 바꾼다)
static func tick() -> void:
	if main_mat == null: return
	var t := phase_t()
	_paint(main_mat, Color("5fd35f") if t < 9.0 else (Color("f2c84b") if t < 11.0 else Color("e05050")))
	_paint(side_mat, Color("5fd35f") if t >= 13.5 and t < 19.0 else (Color("f2c84b") if t >= 19.0 and t < 21.0 else Color("e05050")))
	var walk := Color("e05050")
	if t >= 13.5 and t < 16.0: walk = Color("f7f4ef")
	elif t >= 16.0 and t < 21.0 and fmod(t, 0.8) < 0.4: walk = Color("f7f4ef")   # 깜박이면 들어서지 말 것
	_paint(walk_mat, walk)

static func _paint(m: StandardMaterial3D, c: Color) -> void:
	if m.albedo_color != c: m.albedo_color = c; m.emission = c

static func _bulb_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.emission_enabled = true; m.emission_energy_multiplier = 1.6; m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m

## 그리기(town_city) — 횡단보도 흰 줄, 정지선, 신호등 기둥 넷(큰길 양쪽 차 보는 것 둘, 골목 차 보는 것, 건너는 사람 보는 것은 기둥마다 아래 불)
static func draw(t: TownCity) -> void:
	build()
	if main_mat == null: main_mat = _bulb_mat(); side_mat = _bulb_mat(); walk_mat = _bulb_mat()
	var white: StandardMaterial3D = t._mat(Color("efe9e2"))
	var keep: Node3D = t._build_parent
	for s in list:
		var p: Vector2 = s["p"]; var d: Vector2 = s["dir"]; var n := Vector2(-d.y, d.x)
		var y: float = s["y"]
		var c := p + d * XW_OFF
		var at := Vector3(c.x, y, c.y)
		t._build_parent = t._root_for(at)
		var yaw := -atan2(d.y, d.x)
		var w := -Valley.MAIN_W / 2.0 + 0.6
		while w <= Valley.MAIN_W / 2.0 - 0.5:   # 얼룩말 줄 — 큰길 방향으로 2.6m, 폭 0.5m, 1m 간격
			var q := c + n * w
			var st: MeshInstance3D = t._box(Vector3(2.6, 0.012, 0.5), Vector3(q.x, y + 0.058, q.y), white, false)
			st.rotation.y = yaw
			w += 1.0
		for sg in [-1.0, 1.0]:   # 정지선 — 횡단보도 앞, 제 차로만
			var sp: Vector2 = c + d * sg * 2.4 + n * (-sg) * (Valley.MAIN_W / 4.0)
			var sl: MeshInstance3D = t._box(Vector3(0.35, 0.012, Valley.MAIN_W / 2.0 - 0.3), Vector3(sp.x, y + 0.058, sp.y), white, false)
			sl.rotation.y = yaw
		for sg in [-1.0, 1.0]:   # 기둥 — 큰길 양쪽 길가, 횡단보도 바로 옆
			var lp2: Vector2 = c + d * sg * 2.0 + n * sg * (Valley.MAIN_W / 2.0 + 0.7)
			var lp := Vector3(lp2.x, y, lp2.y)
			var face := atan2(d.x * sg, d.y * sg)   # 다가오는 차 쪽을 본다
			var pole: Node3D = KitProps.put(t, RoadTiles.DIR + "traffic-light.glb", lp, face, 9.0, false)   # 상자 몸은 팔까지 덮어 찻길을 막는다 — 기둥만 둥글게
			if pole: pole.set_meta("nomerge", true)
			var sb := StaticBody3D.new(); var cs := CollisionShape3D.new(); var cy := CylinderShape3D.new(); cy.radius = 0.15; cy.height = 2.4; cs.shape = cy
			cs.position = lp + Vector3(0, 1.2, 0); sb.add_child(cs); t._add(sb)
			_bulb(t, lp + Vector3(0, 4.9, 0), main_mat, 0.17)
			_bulb(t, lp + Vector3(0, 2.4, 0) + Vector3(-n.x * sg, 0, -n.y * sg) * 0.18, walk_mat, 0.11)   # 건너편 사람이 보는 불
			_bulb(t, lp + Vector3(0, 4.2, 0) + Vector3(-d.x * sg, 0, -d.y * sg) * 0.18, side_mat, 0.12)   # 골목 차가 보는 불
	t._build_parent = keep
	tick()

static func _bulb(t: TownCity, at: Vector3, m: Material, r: float) -> void:
	var b := MeshInstance3D.new(); var sm := SphereMesh.new(); sm.radius = r; sm.height = r * 2.0; sm.radial_segments = 10; sm.rings = 5
	b.mesh = sm; b.material_override = m; b.position = at; b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; b.set_meta("nomerge", true)
	t._add(b)
