class_name WorldGen
extends Node3D
## 열린 세계(운영자 2026-09-30: "마인크래프트·팰월드처럼 맵이 엄청 넓어야") — 시드 하나로 땅을 칸(CHUNK m)마다 만든다.
## 마을(허브)·큰길·강 둘레는 평지(y 0)로 깎이고, 그 밖은 언덕·숲·초원·솔숲 고지·호수가 끝없이 이어진다.
## 플레이어 둘레 RADIUS 칸만 짓고 멀어진 칸은 지운다 — 넓이와 상관없이 가볍다. 같은 시드면 칸은 언제나 똑같이 다시 지어진다.
## 칸의 자연(나무·덤불·바위·풀·꽃·버섯)은 MultiMesh(그리기 한 번) — 나무·바위만 몸통 충돌. 호수는 강과 같은 수면(Water3D)이라 헤엄 규칙도 같다

const CHUNK := 32.0
const RES := 16                # 칸 한 변 격자 수(2m 간격)
const RADIUS := 3              # 플레이어 칸 둘레 몇 칸(7×7 = 224m 사방) — 기본값. 카메라를 멀리 빼면 radius 가 커진다(town3d 줌)
var radius := RADIUS
var flat_limit := 0             # 이 순번 미만의 필지(지은·짓는 집)가 있는 블록은 평지로 깎는다(town_growth, TownPlan)
const CITY_ON := false         # 한 번에 까는 도시(city_gen.gd)는 끈다 — 운영자: "가짜 도시는 없어, 다 진짜여야 해". 마을은 건축가가 지은 만큼만
const SEED := 20260930
const HUB_X := 72.0            # 허브(마을) 평지 반폭 — town_base WORLD_X 와 같다
const HUB_Z := 26.0
const ROAD_Z := 2.0
## 장소(운영자 2026-10-01: 열린 세계에 실제 장소 — 숲 오두막, 호숫가 마을, Climb 탑 언덕). 둘레 r 은 평지로 깎이고, from 에서 장소까지 길이 깎여 이어진다.
## 짓는 건 town_sites.gd(_site_<name>). 새 장소는 여기에 한 줄 + 빌더 하나
const SITES := [
	{ "name": "cabin", "c": Vector3(-150, 0, -38), "r": 15.0, "from": Vector3(-150, 0, 3.8) },
	{ "name": "lakeside", "c": Vector3(135, 0, -50), "r": 24.0, "from": Vector3(135, 0, 0.2) },
	{ "name": "tower", "c": Vector3(16, 0, -82), "r": 18.0, "from": Vector3(15.5, 0, -13.0) },
	{ "name": "pell", "c": Vector3(-58, 0, -80), "r": 8.0, "from": Vector3(-58, 0, -13.0) },     # 산 들머리(PEAKS head) — 표지판·볼라드·벤치(town_mountain)
	{ "name": "gorse", "c": Vector3(104, 0, -108), "r": 8.0, "from": Vector3(104, 0, 0.2) },
]

## 산(운영자 2026-10-06: "언덕 같은 곳에 나무가 엄청 많이 생기면서 실제 산이 돼야", "차로는 도저히 못 올라갈 길… 사람만 올라갈 수 있게", "산스장도") —
## 마을 뒤(북쪽)에 봉우리. 아랫자락은 차도 오르는 숲 비탈, 꼭대기 둘레는 벼랑 띠(65° 안팎: 차 42°·사람 45° 한계를 넘는다), 꼭대기는 평평한 마당.
## 꼭대기로 가는 건 나선 돌계단 하나(한 단 28cm, 경사판 없음 — 사람은 턱 오르기 42cm 로 오르고 차 바퀴는 못 넘는다). 들머리엔 볼라드(차 폭보다 좁다)
## head = 들머리(마을 쪽 자락), top = 꼭대기 마당 반지름, turns = 계단이 산을 몇 바퀴 감는지. 짓는 건 town_mountain.gd
const PEAKS := [
	{ "name": "pell", "title": "MT. PELL", "c": Vector3(-80, 0, -210), "r": 135.0, "h": 64.0, "top": 13.0, "head": Vector3(-58, 0, -80), "turns": 1.15, "gym": true },
	{ "name": "gorse", "title": "GORSE HILL", "c": Vector3(125, 0, -195), "r": 95.0, "h": 40.0, "top": 9.0, "head": Vector3(104, 0, -108), "turns": 0.9, "gym": false },
]
const TREAD := 0.6             # 계단 한 칸 길이(m)
const RISE := 0.28             # 한 단 높이 — town_base STEP(0.42) 보다 낮고 차의 바닥 붙기(0.25)보다 높다

var town: TownBase
var _big := FastNoiseLite.new()
var _mid := FastNoiseLite.new()
var _moist := FastNoiseLite.new()
var _paths := FastNoiseLite.new()   # 들판의 흙길 — 이 잡음의 0 근처 등고선을 따라 구불구불(사람이 다녀 생긴 길처럼)
var chunks := {}               # Vector2i -> Node3D
var _src := {}                 # 모델 id -> {parts: [[Mesh, Transform3D]], h}
var _ground: StandardMaterial3D
var _lake: ShaderMaterial
var built := 0                 # 지금까지 지은 칸 수(점검용)
var build_us_max := 0          # 한 프레임 칸 일(땅 또는 자연)의 최대·합계 시간(µs, probe_perf 가 읽는다)
var build_us_sum := 0
var _later: Array = []         # 땅만 지어 둔 칸의 자연 [노드, 칸, 원점] — 다음 프레임에 짓는다

## 자연(개편 2026-10-13: 운영자 "지형 지물들도 별로") — Kenney Nature Kit(CC0, assets/models/kenney/nature). 찻길·소품과 같은 팩이라 한 그림으로 보인다.
## 이름 앞 "k:" = Kenney(배율 K 를 구워 넣는다 — 팩이 1/2 크기), 없으면 옛 Quaternius
const K := 2.2
const FOREST := ["CommonTree_1", "CommonTree_2", "CommonTree_3", "CommonTree_4", "CommonTree_5", "TwistedTree_1", "TwistedTree_3"]   # 나무는 Quaternius 그대로 — Kenney 나무(각진 덩어리)는 운영자가 빼자고 했다(2026-10-13)
const HIGH := ["Pine_1", "Pine_2", "Pine_3", "Pine_4", "Pine_5"]
const ROCKS := ["k:rock_largeA", "k:rock_largeB", "k:rock_largeC", "k:rock_largeD", "k:rock_tallA", "k:rock_tallC"]
const PEBBLES := ["k:rock_smallA", "k:rock_smallB", "k:rock_smallC", "k:rock_smallD", "k:stone_smallFlatA"]
const GRASS := ["k:grass", "k:grass_large", "k:grass_leafs", "k:grass_leafsLarge"]
const FLOWERS := ["k:flower_redA", "k:flower_redB", "k:flower_yellowA", "k:flower_yellowB", "k:flower_purpleA", "k:flower_purpleB", "k:flower_yellowC", "k:flower_redC"]
const UNDER := ["k:plant_flatShort", "k:plant_flatTall", "k:mushroom_redGroup", "k:mushroom_tanGroup", "k:plant_bushSmall"]
const BUSHES := ["k:plant_bush", "k:plant_bushDetailed", "k:plant_bushLarge", "k:plant_bushTriangle", "k:plant_bushLargeTriangle"]

func setup(t: TownBase) -> void:
	town = t
	_big.seed = SEED; _big.frequency = 0.0045; _big.fractal_octaves = 4
	_mid.seed = SEED + 1; _mid.frequency = 0.022; _mid.fractal_octaves = 2
	_moist.seed = SEED + 2; _moist.frequency = 0.006; _moist.fractal_octaves = 2
	_paths.seed = SEED + 3; _paths.frequency = 0.0035; _paths.fractal_octaves = 2
	_ground = t._mat(Color.WHITE, t._tex("ground/grass"))
	_ground.vertex_color_use_as_albedo = true
	_lake = Water3D.surface(); _lake.set_shader_parameter("flow", 0.05)
	# 지평선: 지은 칸 너머는 낮은 초록 판(안개가 흐린다) — 세계 끝이 허공으로 안 보이게
	var hz := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(12000, 12000); hz.mesh = pm
	hz.material_override = t._mat(Color("7fa65e")); hz.position.y = -2.5; add_child(hz)
	var floor := StaticBody3D.new(); var fcs := CollisionShape3D.new(); var wb := WorldBoundaryShape3D.new()   # 높이 0 바닥 판 — 깎인 마을 땅은 칸이 지어지기 전에도 밟힌다(차·주민이 멀리서도 떨어지지 않게)
	wb.plane = Plane(Vector3.UP, -0.03); fcs.shape = wb; floor.add_child(fcs); add_child(floor)
	for pk in PEAKS:
		for p in trail_xz(pk):
			for dx in [-1, 0, 1]:
				for dz in [-1, 0, 1]: _trail_cells[Vector2i(floori(p.x / 3.0) + dx, floori(p.y / 3.0) + dz)] = true
		_far_peak(pk)

## 멀리서 보이는 산 — 칸(지은 땅)은 플레이어 둘레만 있어서 마을에선 산이 안 보였다. 거친 격자 한 장(충돌 없음)을 늘 두고, 가까워져 칸이 지어지면 그 밑에 묻힌다(0.6m 낮게)
func _far_peak(pk: Dictionary) -> void:
	var c: Vector3 = pk["c"]; var r: float = pk["r"]; var n := 28; var step := r * 2.0 / n
	var verts := PackedVector3Array(); var cols := PackedColorArray(); var idx := PackedInt32Array()
	for j in n + 1:
		for i in n + 1:
			var x := c.x - r + i * step; var z := c.z - r + j * step
			var h := height(x, z)
			for d in [Vector2(-0.6, 0), Vector2(0.6, 0), Vector2(0, -0.6), Vector2(0, 0.6), Vector2(-0.6, -0.6), Vector2(0.6, 0.6), Vector2(-0.6, 0.6), Vector2(0.6, -0.6)]:
				h = minf(h, height(x + d.x * step, z + d.y * step))   # 둘레 낮은 쪽으로 — 거친 격자의 삼각형이 깎인 블록(마을) 위로 1m 떠서 집이 묻혀 보였다(운영자 2026-10-12)
			h -= 0.6
			verts.append(Vector3(x, h, z))
			cols.append(Color(0.42, 0.56, 0.38).lerp(Color(0.62, 0.64, 0.6), smoothstep(40.0, 70.0, h)))
	for j in n:
		for i in n:
			var a := j * (n + 1) + i
			idx.append_array([a, a + 1, a + n + 1, a + 1, a + n + 2, a + n + 1])
	var arr := []; arr.resize(Mesh.ARRAY_MAX); arr[Mesh.ARRAY_VERTEX] = verts; arr[Mesh.ARRAY_COLOR] = cols; arr[Mesh.ARRAY_INDEX] = idx
	var st := SurfaceTool.new(); st.create_from_arrays(arr); st.generate_normals()
	var old := get_node_or_null("Far_" + String(pk["name"]))
	if old: old.name = "Far_old"; old.queue_free()
	var mi := MeshInstance3D.new(); mi.mesh = st.commit(); mi.name = "Far_" + String(pk["name"])
	var m := StandardMaterial3D.new(); m.vertex_color_use_as_albedo = true; mi.material_override = m
	add_child(mi)

## 깎인 블록이 바뀌면(마을이 넓어짐) 먼 산도 다시 — 처음 것은 성장 상태를 읽기 전(깎기 없음)에 지어져 새 블록 위를 덮었다
func _refresh_far() -> void:
	for pk in PEAKS: _far_peak(pk)

# ── 땅 ──
## 0 = 평지로 깎인 곳(허브·큰길·강), 1 = 자연 지형
func wild_k(x: float, z: float) -> float:
	# 호수(깎기 전 높이 < 0)는 깎는 둘레(허브·큰길·강·블록의 비탈)에선 깎지 않는다 — 깎으면 물이 얕아져 호숫가가 그 둘레를 따라 직선으로 잘렸다(2026-10-13).
	# 깎아야 하는 한가운데(허브·큰길 판·강·블록 안)는 그대로. 깎기 전 높이는 비탈 안에서만 한 번 잰다
	var lake := 0   # 0 모름, 1 호수, -1 아님
	var dh := Vector2(maxf(absf(x) - HUB_X, 0.0), maxf(absf(z) - HUB_Z, 0.0)).length()
	var k := 1.0
	if dh < 30.0:
		if dh > 3.0: lake = 1 if raw(x, z) < 0.0 else -1
		if lake != 1: k = smoothstep(0.0, 30.0, dh)
	var dr := absf(z - ROAD_Z)
	if dr < 16.0:
		if dr > 7.0 and lake == 0: lake = 1 if raw(x, z) < 0.0 else -1
		if not (dr > 7.0 and lake == 1): k = minf(k, smoothstep(4.0, 16.0, dr))
	k = minf(k, smoothstep(town.RIVER_HW + 2.0, town.RIVER_HW + 14.0, absf(z - town.RIVER_Z)))
	if flat_limit > 0:   # 지은·짓는 집 블록은 평지 — 둘레 26m 에 걸쳐 산으로
		var fd := TownPlan.flat_dist(x, z, flat_limit)
		if fd < 26.0:
			if lake == 0: lake = 1 if raw(x, z) < 0.0 else -1
			if lake != 1 or fd < 0.5: k = minf(k, smoothstep(0.0, 26.0, fd))   # 블록 안은 다 땅으로(찻길에 둘린 네모 호수가 됐다) — 블록 밖 비탈의 호수는 그대로
	var cd := _civic_dist(x, z)   # 관공서·공원 블록도 평지 — 필지가 없어 빠졌고, 시청·학교·도서관이 언덕에 묻혔다(운영자 2026-10-08)
	if cd < 26.0:
		if lake == 0: lake = 1 if raw(x, z) < 0.0 else -1
		var keep_lake := lake == 1 and cd >= 0.5   # 비탈의 호수는 그대로(호숫가가 블록 사각형에서 잘렸다). 공원 블록 안은 깎는다 — 찻길에 둘린 네모 연못이 됐다
		if not keep_lake: k = minf(k, smoothstep(0.0, 26.0, cd))
	for s in SITES:
		var c: Vector3 = s["c"]; var r: float = s["r"]
		k = minf(k, smoothstep(r, r + 22.0, Vector2(x - c.x, z - c.z).length()))
		k = minf(k, smoothstep(3.0, 13.0, _seg_dist(Vector2(x, z), Vector2(s["from"].x, s["from"].z), Vector2(c.x, c.z))))   # 장소로 가는 길
	return k

## 블록 안에서 꼭 깎아야 하는 자리 — 찻길(9m 판과 인도) 위거나 필지(집·마당) 안. 그 밖의 블록 안 호수는 그대로 둔다(블록 사각형에서 호숫가가 직선으로 잘렸다)
func _built_spot(x: float, z: float) -> bool:
	var gx := fposmod(x - TownPlan.OX, TownPlan.PITCH); var gz := fposmod(z - TownPlan.OZ, TownPlan.PITCH / 2.0)
	var rw := TownPlan.ROAD_W / 2.0 + 1.0
	if gx < rw or gx > TownPlan.PITCH - rw or gz < rw or gz > TownPlan.PITCH / 2.0 - rw: return true
	for l in _lots_near(CityMap.block_of(Vector2(x, z))):
		var c: Vector2 = l["c"]
		if absf(x - c.x) < float(l.get("w", 7.75)) / 2.0 + 1.0 and absf(z - c.y) < 9.0: return true
	return false

## 관공서·공원 블록(data/map/town.json)까지 거리 — 블록 사각형 밖이면 그 거리, 안이면 0
static var _civic_rects: Array = []
static func _civic_dist(x: float, z: float) -> float:
	if _civic_rects.is_empty():
		for key in (CityMap.data()["blocks"] as Dictionary):
			var pp := String(key).split(","); var b := Vector2i(int(pp[0]), int(pp[1]))
			if CityMap.whole_block(b): _civic_rects.append(Rect2(TownPlan.OX + b.x * TownPlan.PITCH, TownPlan.OZ + b.y * TownPlan.PITCH, TownPlan.PITCH, TownPlan.PITCH))
		if _civic_rects.is_empty(): _civic_rects.append(Rect2(1e6, 1e6, 1, 1))
	var best := 1e9
	for r in _civic_rects:
		var dx := maxf(maxf(r.position.x - x, x - r.end.x), 0.0); var dz := maxf(maxf(r.position.y - z, z - r.end.y), 0.0)
		best = minf(best, Vector2(dx, dz).length())
	return best

static func _seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return p.distance_to(a + ab * t)

## 깎기 전 높이 — 큰 굽이 + 작은 기복 + 산. 0 아래는 호수가 된다
func raw(x: float, z: float) -> float:
	var pk := peak_h(x, z)
	return 3.4 + 13.0 * _big.get_noise_2d(x, z) + (2.4 + 3.5 * pk.y) * _mid.get_noise_2d(x, z) + pk.x

## 산이 더하는 높이(x)와 거친 정도(y, 0..1 — 자락의 잔기복을 키우되 꼭대기 마당 둘레는 0 이라 평평하다)
func peak_h(x: float, z: float) -> Vector2:
	var add := 0.0; var rough := 0.0
	for pk in PEAKS:
		var c: Vector3 = pk["c"]; var r: float = pk["r"]; var h: float = pk["h"]; var top: float = pk["top"]
		var d := Vector2(x - c.x, z - c.z).length()
		if d >= r: continue
		var tp := top / r
		var t := maxf(d / r, tp)
		var v := h * pow(1.0 - t, 1.35) + 0.18 * h * (1.0 - smoothstep(tp, tp + 0.08, t))   # 자락 + 꼭대기 둘레 벼랑 띠
		add = maxf(add, v)
		rough = maxf(rough, smoothstep(1.0, 0.6, d / r) * smoothstep(top, top + 3.0, d))
	return Vector2(add, rough)

## 꼭대기 마당 높이 — 지을 때 쓴다
func summit_y(pk: Dictionary) -> float:
	var c: Vector3 = pk["c"]
	return height(c.x, c.z)

## 산의 0..1(자락 바깥 0) — 숲 밀도
func peak_k(x: float, z: float) -> float:
	var k := 0.0
	for pk in PEAKS:
		var c: Vector3 = pk["c"]
		k = maxf(k, 1.0 - Vector2(x - c.x, z - c.z).length() / float(pk["r"]))
	return k

## 계단 길(나선) — 들머리에서 꼭대기 마당 안까지 TREAD 간격의 점(x, z). 높이는 짓는 쪽이 정한다(town_mountain)
static func trail_xz(pk: Dictionary) -> PackedVector2Array:
	var c := Vector2(pk["c"].x, pk["c"].z); var hd := Vector2(pk["head"].x, pk["head"].z)
	var a0 := (hd - c).angle(); var d0 := (hd - c).length(); var d1 := float(pk["top"]) - 3.0
	var turn := float(pk["turns"]) * TAU
	var out := PackedVector2Array([hd]); var u := 0.0; var last := hd
	while u < 1.0:
		u = minf(1.0, u + 0.0004)
		var p := c + Vector2.from_angle(a0 + turn * u) * lerpf(d0, d1, pow(u, 0.85))
		if p.distance_to(last) >= TREAD or u >= 1.0:
			out.append(p); last = p
	return out

var _trail_cells := {}   # 3m 칸 → 계단 길이 지나간다(나무를 안 심는다)
## 들판 흙길 위인가(잡음 등고선 ±폭) — 깎인 마을 안·산·호수엔 없다
func dirt_at(x: float, z: float) -> bool:
	return (absf(_paths.get_noise_2d(x, z)) < 0.018 and peak_k(x, z) < 0.05 and _h(x, z) > 0.2) or loop_at(x, z)

## 둘레길(운영자 2026-10-06: "둘레길도 존재해야") — 마을을 한 바퀴 도는 흙길. 반지름이 출렁이고(산 자락·호숫가를 스친다), 깎인 마을 땅에선 마을 것을 피한다
const LOOP_C := Vector2(20.0, -10.0)
static func loop_r(a: float) -> float:
	return 128.0 + 9.0 * sin(3.0 * a + 1.0) + 5.0 * sin(5.0 * a + 0.4)
func loop_at(x: float, z: float) -> bool:
	var v := Vector2(x, z) - LOOP_C
	if absf(v.length() - loop_r(v.angle())) > 1.25 or peak_k(x, z) > 0.4: return false
	return wild_k(x, z) > 0.3   # 마을(깎인 땅)은 지나지 않는다 — 마을이 넓어지자 흙길이 블록·찻길을 비스듬히 가로질렀다(운영자 2026-10-14)

## 깔린 찻길(town_city _segs) 위인가 — 판 폭 + 0.8m
func _on_road(x: float, z: float) -> bool:
	var segs: Variant = town.get("_segs")
	if not (segs is Dictionary) or (segs as Dictionary).is_empty(): return false
	var fx := (x - TownPlan.OX) / TownPlan.PITCH; var fz := (z - TownPlan.OZ) / 20.0
	var hw := TownPlan.ROAD_W / 2.0 + 0.8
	var j := roundi(fz)
	if absf(z - (TownPlan.OZ + j * 20.0)) < hw:
		var i0 := floori(fx)
		if (segs as Dictionary).has(RoadTiles.seg_key(Vector2i(i0, j), Vector2i(i0 + 1, j))): return true
	var i := roundi(fx)
	if absf(x - (TownPlan.OX + i * TownPlan.PITCH)) < hw:
		var j0 := floori(fz)
		if (segs as Dictionary).has(RoadTiles.seg_key(Vector2i(i, j0), Vector2i(i, j0 + 1))): return true
	return false

func on_trail(x: float, z: float) -> bool:
	if dirt_at(x, z): return true
	if _trail_cells.has(Vector2i(floori(x / 3.0), floori(z / 3.0))): return true
	for pk in PEAKS:   # 꼭대기 마당도 비운다(산스장·정자 자리)
		if Vector2(x - pk["c"].x, z - pk["c"].z).length() < float(pk["top"]) + 1.0: return true
	return false

func _h(x: float, z: float) -> float:
	return wild_k(x, z) * raw(x, z)

## 땅 높이(호수 바닥은 수면 바로 아래 -0.02 — 강과 같은 얕은 물이라 같은 헤엄 규칙)
func height(x: float, z: float) -> float:
	return maxf(_h(x, z), -0.02)

## 이 자리 밑에 땅(충돌)이 있나 — 허브 바닥 상자 안이거나 지어 둔 칸. 플레이어가 멀어져 칸이 지워지면 거기 있던 차·주민은 서서 기다린다(떨어지지 않게)
func has_ground(p: Vector3) -> bool:
	return (absf(p.x) < HUB_X + 4.0 and absf(p.z) < HUB_Z + 4.0) or chunks.has(Vector2i(floori(p.x / CHUNK), floori(p.z / CHUNK)))

## 차가 달려도 되나 — 지은 칸이거나, 마을 260m 안의 깎인 평지(아직 칸이 없어도 밑에 바닥 판이 있다: setup).
## 전엔 먼 칸이 안 지어져 있으면 차가 칸 경계에서 서서 기다렸다 — 볼일 보는 차가 x −96(칸 경계)에 줄지어 섰다(2026-10-08)
func car_ground(p: Vector3) -> bool:
	return has_ground(p) or (Vector2(p.x, p.z).length() < 260.0 and wild_k(p.x, p.z) < 0.05)

func lake_at(p: Vector3) -> bool:
	if p.x > TownInterior.ZONE.x - 60.0 and p.z > TownInterior.ZONE.y - 60.0: return false   # 방 구역(town_interior) — 그 자리 땅 높이가 물 아래라 방 안에서 헤엄쳤다
	return p.y < 0.3 and _h(p.x, p.z) < -0.05

func _biome(x: float, z: float, h: float) -> String:
	if h > 7.5: return "high"
	var m := _moist.get_noise_2d(x, z)
	if m > 0.12: return "forest"
	if m < -0.3: return "dry"
	return "meadow"

func _tint(x: float, z: float, h: float, k: float, slope: float, hr: float) -> Color:
	var c := Color.WHITE
	match _biome(x, z, h):
		"forest": c = Color(0.74, 0.86, 0.7)
		"high": c = Color(0.84, 0.88, 0.8)
		"dry": c = Color(1.0, 0.94, 0.72)
		_: c = Color(0.97, 1.0, 0.88)
	if h < 0.25 and hr < 0.3: c = Color(0.96, 0.9, 0.74)   # 물가 모래(hr = 깎은 높이 _h — 부르는 쪽이 이미 쟀다)
	c = c.lerp(Color(0.72, 0.7, 0.66), smoothstep(0.12, 0.35, slope))   # 가파르면 바위빛
	return Color.WHITE.lerp(c, smoothstep(0.0, 0.4, k))   # 허브 안은 원래 풀밭 그대로

# ── 칸 ──
## 매 프레임(town_systems _stream): 둘레의 빠진 칸을 가까운 것부터 한 프레임에 하나 짓고, RADIUS+1 밖 칸은 지운다.
## 땅과 자연은 다른 프레임에 — 한 프레임에 둘 다 지으면 4ms 를 넘었다(2026-10-01 성능 패스: 데스크톱 60fps 는 프레임당 16.6ms)
func stream(p: Vector3, defer := true) -> void:
	var cx := floori(p.x / CHUNK); var cz := floori(p.z / CHUNK)
	var t0 := Time.get_ticks_usec()
	if not _later.is_empty():
		var job: Array = _later.pop_front()
		if is_instance_valid(job[0]) and not (job[0] as Node3D).is_queued_for_deletion():
			if job.size() > 3: CityGen.build_chunk(self, job[0], job[2], CHUNK)   # 도시 칸도 다음 프레임에(33ms 걸려 한 프레임을 넘겼다)
			else: _nature(job[0], job[1], job[2])   # 그사이 멀어져 지운 칸은 건너뛴다
	else:
		var best := Vector2i.ZERO; var bd := 1e9; var need := false
		for dz in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				var key := Vector2i(cx + dx, cz + dz)
				if chunks.has(key): continue
				var d := dx * dx + dz * dz
				if d < bd: bd = d; best = key; need = true
		if need: _build(best, defer)
	var us := Time.get_ticks_usec() - t0
	build_us_sum += us; build_us_max = maxi(build_us_max, us)
	for key in chunks.keys():
		if absi(key.x - cx) > radius + 1 or absi(key.y - cz) > radius + 1:
			(chunks[key] as Node3D).queue_free(); chunks.erase(key)

## 처음 둘레 전부(시작할 때 한 번에 — 빈 땅이 보이지 않게)
func fill(p: Vector3) -> void:
	for i in (radius * 2 + 1) * (radius * 2 + 1): stream(p, false)

## 칸 하나 — defer 면 자연(나무·풀 MultiMesh·충돌)은 _later 에 맡기고 다음 stream 이 짓는다
func _build(key: Vector2i, defer := false) -> void:
	built += 1
	var n := Node3D.new(); n.name = "Chunk_%d_%d" % [key.x, key.y]; add_child(n); chunks[key] = n
	var o := Vector3(key.x * CHUNK, 0, key.y * CHUNK)
	var step := CHUNK / RES; var w := RES + 1
	# 격자를 한 칸씩 넓혀(법선용 이웃) 깎기 정도·깎은 높이를 한 번씩만 잰다 — 전엔 점마다 height()를 다섯 번, 물가 판정에 또 네 번 불러 칸 하나가 12ms 였다(2026-10-01 성능 패스)
	var pw := w + 2
	var ks := PackedFloat32Array(); ks.resize(pw * pw)
	var raws := PackedFloat32Array(); raws.resize(pw * pw)   # 깎은 높이(_h) — 0 아래면 호수
	for j in pw:
		for i in pw:
			var x := o.x + (i - 1) * step; var z := o.z + (j - 1) * step
			var k := wild_k(x, z); ks[j * pw + i] = k; raws[j * pw + i] = k * raw(x, z)
	var hs := PackedFloat32Array(); hs.resize(w * w)
	var wild := 0.0
	for j in w:
		for i in w:
			var q := (j + 1) * pw + i + 1
			hs[j * w + i] = maxf(raws[q], -0.02); wild = maxf(wild, ks[q])
	# 땅 메시(정점색 = 생물군 빛깔, UV = 세계 좌표라 칸 이음새가 없다)
	var verts := PackedVector3Array(); var norms := PackedVector3Array(); var cols := PackedColorArray(); var uvs := PackedVector2Array(); var idx := PackedInt32Array()
	for j in w:
		for i in w:
			var x := o.x + i * step; var z := o.z + j * step; var h := hs[j * w + i]; var q := (j + 1) * pw + i + 1
			var nx := maxf(raws[q - 1], -0.02) - maxf(raws[q + 1], -0.02); var nz := maxf(raws[q - pw], -0.02) - maxf(raws[q + pw], -0.02)
			var nrm := Vector3(nx, 2.0 * step, nz).normalized()
			verts.append(Vector3(i * step, h, j * step)); norms.append(nrm)
			cols.append(_tint(x, z, h, ks[q], 1.0 - nrm.y, raws[q]))
			uvs.append(Vector2(x, z) / town.TILE)
	var lake_idx := PackedInt32Array()
	for j in RES:
		for i in RES:
			var a := j * w + i
			idx.append_array([a, a + 1, a + w, a + 1, a + w + 1, a + w])
			var q := (j + 1) * pw + i + 1
			# 물가선 = 땅(깎은 높이)이 수면(0.04)을 넘는 곳 — 꼭짓점 하나라도 수면 아래면 그 칸에 수면을 깔고, 땅이 그 위로 솟는 데서 저절로 가려진다(전엔 −0.05 기준이라
			# 칸 경계에서 끊겨 물가가 계단처럼 졌다, 운영자 2026-10-13 "지형 지물"). 깎인 마을 땅(높이 0)엔 안 깐다 — 둘레에 진짜 물(−0.05 아래)이 있어야
			var lo := minf(minf(raws[q], raws[q + 1]), minf(raws[q + pw], raws[q + pw + 1]))
			var wet := false
			if lo < Water3D.SURFACE_Y + 0.02 and ks[q] > 0.05:
				for vj in range(j, j + 4):
					for vi in range(i, i + 4):
						if raws[vj * pw + vi] < -0.05: wet = true; break
					if wet: break
			if wet:
				lake_idx.append_array([a, a + 1, a + w, a + 1, a + w + 1, a + w])
	var arr := []; arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts; arr[Mesh.ARRAY_NORMAL] = norms; arr[Mesh.ARRAY_COLOR] = cols; arr[Mesh.ARRAY_TEX_UV] = uvs; arr[Mesh.ARRAY_INDEX] = idx
	var am := ArrayMesh.new(); am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var gm := MeshInstance3D.new(); gm.mesh = am; gm.material_override = _ground; gm.position = o; n.add_child(gm)
	# 호수 수면: 호수 칸(깎기 전 높이 < 0)만 — 같은 격자, 높이는 수면(Water3D.SURFACE_Y)
	if not lake_idx.is_empty():
		var lv := PackedVector3Array(); var ln := PackedVector3Array()
		for v in verts: lv.append(Vector3(v.x, Water3D.SURFACE_Y, v.z)); ln.append(Vector3.UP)
		var la := []; la.resize(Mesh.ARRAY_MAX); la[Mesh.ARRAY_VERTEX] = lv; la[Mesh.ARRAY_NORMAL] = ln; la[Mesh.ARRAY_INDEX] = lake_idx
		var lm := ArrayMesh.new(); lm.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, la)
		var lmi := MeshInstance3D.new(); lmi.mesh = lm; lmi.material_override = _lake; lmi.position = o; n.add_child(lmi)
		var brng := RandomNumberGenerator.new(); brng.seed = hash(Vector3i(key.x, key.y, SEED + 7))
		if brng.randf() < 0.3:   # 호수에 배 한 척(Kenney Watercraft — 노 젓는 배·낚싯배·돛배)
			for tries in 12:
				var vi := brng.randi_range(2, RES - 2); var vj := brng.randi_range(2, RES - 2)
				if raws[(vj + 1) * pw + vi + 1] < -1.2:
					var bp := Vector3(o.x + vi * step, Water3D.SURFACE_Y - 0.12, o.z + vj * step)
					var bm := KitProps.mesh_node("res://assets/models/kenney/watercraft/%s.glb" % ["boat-row-small", "boat-row-large", "boat-fishing-small", "boat-sail-a"][brng.randi() % 4])
					bm.position = bp; bm.rotation.y = brng.randf() * TAU; bm.scale = Vector3.ONE * 0.55; n.add_child(bm)
					break
	# 충돌: 높이맵(허브 평지는 이미 바닥이 있으니 자연이 섞인 칸만)
	if wild > 0.01:
		var sb := StaticBody3D.new(); var cs := CollisionShape3D.new(); var hm := HeightMapShape3D.new()
		hm.map_width = w; hm.map_depth = w; hm.map_data = hs; cs.shape = hm
		cs.position = o + Vector3(CHUNK / 2.0, 0, CHUNK / 2.0); cs.scale = Vector3(step, 1, step)
		sb.add_child(cs); n.add_child(sb)
		if defer: _later.append([n, key, o])
		else: _nature(n, key, o)
	elif absf(o.x + CHUNK / 2.0) > HUB_X or absf(o.z + CHUNK / 2.0) > HUB_Z:   # 허브 바깥의 완전한 평지 칸(도시·길) — 바닥 충돌판(허브는 _solid_floor 가 있다)
		var city := CITY_ON and Rect2(CityGen.X0, CityGen.Z0, CityGen.X1 - CityGen.X0, CityGen.Z1 - CityGen.Z0).intersects(Rect2(o.x, o.z, CHUNK, CHUNK))
		if not city:
			var sb := StaticBody3D.new(); var cs := CollisionShape3D.new(); var bx := BoxShape3D.new(); bx.size = Vector3(CHUNK, 1.0, CHUNK); cs.shape = bx
			cs.position = o + Vector3(CHUNK / 2.0, -0.5, CHUNK / 2.0); sb.add_child(cs); n.add_child(sb)
			if defer: _later.append([n, key, o])   # 평지도 비워 두지 않는다 — 길·골목·필지·강을 피해 풀·꽃·덤불(운영자 2026-10-06: "이런 공간들 디테일하게 다 채워")
			else: _nature(n, key, o)
	if CITY_ON and Rect2(CityGen.X0, CityGen.Z0, CityGen.X1 - CityGen.X0, CityGen.Z1 - CityGen.Z0).intersects(Rect2(o.x, o.z, CHUNK, CHUNK)):
		if defer: _later.append([n, key, o, "city"])
		else: CityGen.build_chunk(self, n, o, CHUNK)   # 도시 칸: 도로·건물·나무(city_gen.gd)

## 칸의 자연 — 생물군마다 다른 밀도. 평지(허브·길·강)와 물·가파른 곳엔 안 놓는다
func _nature(n: Node3D, key: Vector2i, o: Vector3) -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = hash(Vector3i(key.x, key.y, SEED))
	var put := {}   # 모델 id -> [Transform3D]
	var body := StaticBody3D.new(); n.add_child(body)
	var c := o + Vector3(CHUNK / 2.0, 0, CHUNK / 2.0)
	var biome := _biome(c.x, c.z, height(c.x, c.z))
	var plan: Array = []   # [목록, 개수, 크기(목표 높이 m 또는 배율), 충돌 반지름]
	var pkk := peak_k(c.x, c.z)
	if pkk > 0.03: biome = "mountain"   # 산: 빽빽한 숲 — 아래는 활엽, 위로 갈수록 솔(그 자리 높이로 고른다)
	match biome:
		"mountain": plan = [["MOUNTAIN", int(18 + 22 * minf(1.0, pkk * 2.5)), 5.2, 0.28], [UNDER, 16, 0.7, 0.0], [BUSHES, 6, 1.0, 0.0], [ROCKS, 5, 1.3, 0.55], [GRASS, 14, 0.9, 0.0], [PEBBLES, 6, 0.8, 0.0]]
		"forest": plan = [[FOREST, 22, 4.6, 0.28], [UNDER, 24, 0.9, 0.0], [BUSHES, 10, 1.1, 0.0], [GRASS, 40, 1.1, 0.0], [ROCKS, 2, 1.0, 0.5]]
		"high": plan = [[HIGH, 9, 5.0, 0.25], [ROCKS, 4, 1.2, 0.55], [PEBBLES, 8, 0.8, 0.0], [GRASS, 12, 0.8, 0.0]]
		"dry": plan = [[ROCKS, 3, 1.0, 0.5], [PEBBLES, 10, 0.9, 0.0], [GRASS, 22, 0.9, 0.0], [FOREST, 1, 3.8, 0.28]]
		_: plan = [[FLOWERS, 60, 1.2, 0.0], [GRASS, 120, 1.3, 0.0], [BUSHES, 16, 1.2, 0.0], [FOREST, 6, 4.6, 0.28], [PEBBLES, 6, 0.9, 0.0], [ROCKS, 2, 1.0, 0.5], [UNDER, 8, 0.9, 0.0]]   # Kenney 풀은 작아 두 배쯤
	var flat := wild_k(c.x, c.z) < 0.05 and wild_k(o.x, o.z) < 0.05 and wild_k(o.x + CHUNK, o.z + CHUNK) < 0.05
	if flat: plan = [[GRASS, 90, 1.2, 0.0], [FLOWERS, 40, 1.1, 0.0], [BUSHES, 12, 1.1, 0.0], [FOREST, 4, 4.4, 0.28], [PEBBLES, 4, 0.9, 0.0]]   # 마을 가의 평지 — 빈 잔디로 두지 않는다
	var clusters: Array = []   # 꽃·덤불은 무리로(고르게 흩으면 멀리선 안 보였다)
	for q in 4: clusters.append(Vector2(o.x + rng.randf() * CHUNK, o.z + rng.randf() * CHUNK))
	for row in plan:
		var mountain: bool = row[0] is String
		var ids: Array = FOREST if mountain else row[0]
		var grouped: bool = ids == FLOWERS or ids == BUSHES or ids == UNDER
		var tall_row := float(row[2]) > 2.0
		for i in int(row[1]):
			var x := o.x + rng.randf() * CHUNK; var z := o.z + rng.randf() * CHUNK
			if grouped and rng.randf() < 0.75:
				var cc: Vector2 = clusters[rng.randi() % clusters.size()]
				x = clampf(cc.x + rng.randfn(0.0, 2.2), o.x, o.x + CHUNK); z = clampf(cc.y + rng.randfn(0.0, 2.2), o.z, o.z + CHUNK)
			if on_trail(x, z) or _on_road(x, z): continue   # 계단 길·찻길은 비운다(찻길 위에 나무가 섰다, 운영자 2026-10-13)
			if mountain: ids = HIGH if height(x, z) > 24.0 + 8.0 * rng.randf() else FOREST
			var k := wild_k(x, z)
			var h := k * raw(x, z)   # = _h — 한 번만 잰다
			if k < 0.45:   # 깎인 땅(마을 가·길 가): 키 작은 것만, 마을 것을 피해서. 나무는 길·필지에서 멀 때만
				if not _town_clear(x, z, 4.5 if tall_row else 1.4): continue
				if tall_row and k < 0.05 and rng.randf() < 0.5: continue
				h = maxf(h, 0.0)
			elif h < 0.7 or rng.randf() > k: continue   # 물가 1m 안엔 안 난다(물속 풀)
			if absf(height(x + 1.0, z) - h) > 0.9 or absf(height(x, z + 1.0) - h) > 0.9: continue   # 벼랑엔 안 선다
			var id: String = ids[rng.randi() % ids.size()]
			var src := _model_src(id)
			var tall := float(row[2]) > 2.0   # 2 넘으면 목표 높이(m) — 나무, 아니면 배율 — 풀·꽃·바위
			var sc: float = (float(row[2]) / maxf(src["h"], 0.3) if tall else float(row[2])) * rng.randf_range(0.8, 1.2)
			var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * sc), Vector3(x, h - 0.05, z))
			if not put.has(id): put[id] = []
			put[id].append(xf)
			if float(row[3]) > 0.0:
				var cs := CollisionShape3D.new(); var cy := CylinderShape3D.new(); cy.radius = float(row[3]) * (1.0 if tall else sc); cy.height = 1.6
				cs.shape = cy; cs.position = Vector3(x, h + 0.8, z); body.add_child(cs)
	if not flat and biome in ["meadow", "forest", "dry"] and rng.randf() < 0.32: _feature(put, o, rng, body)
	if not flat and biome in ["meadow", "dry"] and Vector2(c.x, c.z).length() < 300.0 and rng.randf() < 0.45: _farm(n, put, o, rng)
	_dirt_patches(n, o)
	for id in put:
		var src := _model_src(id)
		for part in src["parts"]:
			var mm := MultiMesh.new(); mm.transform_format = MultiMesh.TRANSFORM_3D; mm.mesh = part[0]
			var xs: Array = put[id]; mm.instance_count = xs.size()
			for i in xs.size(): mm.set_instance_transform(i, (xs[i] as Transform3D) * (part[1] as Transform3D))
			var mmi := MultiMeshInstance3D.new(); mmi.multimesh = mm; n.add_child(mmi)
			if id in FOREST or id in HIGH or id in ROCKS:
				mmi.visibility_range_end = 240.0; mmi.visibility_range_end_margin = 20.0   # 나무·바위도 240m 넘으면 안 그린다(안개 속)
			if not (id in FOREST or id in HIGH or id in ROCKS):   # 풀·꽃·덤불 — 그림자 없이, 70m 넘으면 안 그린다(채운 들판에 44fps 로 떨어졌다)
				mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; mmi.visibility_range_end = 70.0; mmi.visibility_range_end_margin = 8.0

## 흙길 조각 — 1.4m 격자에서 길 위인 점마다 납작한 원반(땅 기울기대로), 한 칸에 MultiMesh 하나
static var _dirt_mesh: CylinderMesh
func _dirt_patches(n: Node3D, o: Vector3) -> void:
	var xs: Array[Transform3D] = []
	var step := 1.4
	for j in int(CHUNK / step):
		for i in int(CHUNK / step):
			var x := o.x + (i + 0.5) * step; var z := o.z + (j + 0.5) * step
			if not dirt_at(x, z) or (wild_k(x, z) < 0.3 and not loop_at(x, z)): continue
			var h := height(x, z)
			var nrm := Vector3(height(x - 0.7, z) - height(x + 0.7, z), 1.4, height(x, z - 0.7) - height(x, z + 0.7)).normalized()
			var b := Basis(Quaternion(Vector3.UP, nrm)) * Basis(Vector3.UP, fposmod(x * 1.7 + z, TAU))
			xs.append(Transform3D(b.scaled(Vector3(1.0 + fposmod(x * 0.37, 0.4), 1.0, 1.0 + fposmod(z * 0.29, 0.4))), Vector3(x, h + 0.02, z)))
	if xs.is_empty(): return
	if _dirt_mesh == null:
		_dirt_mesh = CylinderMesh.new(); _dirt_mesh.top_radius = 0.95; _dirt_mesh.bottom_radius = 0.95; _dirt_mesh.height = 0.02; _dirt_mesh.radial_segments = 10
		var m := StandardMaterial3D.new(); m.albedo_color = Color("b59a74"); _dirt_mesh.material = m
	var mm := MultiMesh.new(); mm.transform_format = MultiMesh.TRANSFORM_3D; mm.mesh = _dirt_mesh; mm.instance_count = xs.size()
	for k in xs.size(): mm.set_instance_transform(k, xs[k])
	var mmi := MultiMeshInstance3D.new(); mmi.multimesh = mm; mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; n.add_child(mmi)

## 마을 것을 피하나 — 허브·큰길·강·골목(필지 격자)·장소 길·필지 둘레(r)
func _town_clear(x: float, z: float, r: float) -> bool:
	if absf(x) < HUB_X + 2.0 and absf(z) < HUB_Z + 2.0: return false
	if absf(z - ROAD_Z) < 3.4 + r * 0.3: return false
	if absf(z - town.RIVER_Z) < town.RIVER_HW + 1.5: return false
	var gx := fposmod(x - TownPlan.OX, TownPlan.PITCH); var gz := fposmod(z - TownPlan.OZ, TownPlan.PITCH / 2.0)
	var rw := TownPlan.ROAD_W / 2.0 + 0.4
	if gx < rw or gx > TownPlan.PITCH - rw or gz < rw or gz > TownPlan.PITCH / 2.0 - rw: return false   # 찻길(남북 40m, 동서 20m 마다)
	for s in SITES:
		var sc: Vector3 = s["c"]
		if Vector2(x - sc.x, z - sc.z).length() < float(s["r"]) + 1.0: return false
		if _seg_dist(Vector2(x, z), Vector2(s["from"].x, s["from"].z), Vector2(sc.x, sc.z)) < 3.5: return false
	var b := CityMap.block_of(Vector2(x, z))
	if flat_limit > 0 and TownPlan.block_order(b) < flat_limit: return false   # 지은 블록 안은 들풀을 안 띄운다 — 마당·공용지(town_city)가 채운다. 갈대·들꽃이 가게 옆에 무성했다(운영자 2026-10-08)
	if CityMap.whole_block(b) and Vector2(x, z).distance_to(Vector2(CityMap.block_center(b).x, CityMap.block_center(b).z)) < 19.0: return false   # 관공서·공원 블록
	for l in _lots_near(b):
		if Vector2(x, z).distance_to(l["c"]) < 3.6 + r * 0.5: return false   # 집 둘레만(필지 간격 7.4m)
	return true

var _lots_by_block := {}
func _lots_near(b: Vector2i) -> Array:
	if _lots_by_block.is_empty():
		for l in TownPlan.lots():
			var k: Vector2i = l["b"]
			if not _lots_by_block.has(k): _lots_by_block[k] = []
			_lots_by_block[k].append(l)
	return _lots_by_block.get(b, [])

## 밭(운영자 2026-10-08 사진: 마을 둘레는 밭·과수원) — 마을 300m 안의 완만한 들 칸에 밭 하나: 채소 이랑·밀밭·꽃밭·과수원 중 하나, 흙 이랑은 땅 기울기대로
func _farm(n: Node3D, put: Dictionary, o: Vector3, rng: RandomNumberGenerator) -> void:
	var c := Vector2(o.x + 6.0 + rng.randf() * (CHUNK - 12.0), o.z + 6.0 + rng.randf() * (CHUNK - 12.0))
	if wild_k(c.x, c.y) < 0.7 or on_trail(c.x, c.y) or _h(c.x, c.y) < 0.5: return
	var ang := rng.randf() * PI; var ax := Vector2.from_angle(ang); var ay := Vector2(-ax.y, ax.x)
	var kind := rng.randi() % 4
	var rows := 7; var cols := 12
	var soil: Array[Transform3D] = []
	var add := func(id: String, p: Vector2, sc: float) -> void:
		if not put.has(id): put[id] = []
		put[id].append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * sc), Vector3(p.x, height(p.x, p.y) - 0.02, p.y)))
	for r in rows:
		for q in cols:
			var p := c + ax * ((q - cols / 2.0) * 0.9) + ay * ((r - rows / 2.0) * 1.3)
			if absf(height(p.x, p.y) - height(c.x, c.y)) > 2.5: continue   # 가파르면 그 칸은 비운다
			match kind:
				0: add.call(["k:crop_carrot", "k:crop_turnip", "k:crop_pumpkin", "k:crops_leafsStageB"][(r + q) % 4], p, 0.42)   # 채소
				1: add.call("k:crops_wheatStageB", p, 0.55); add.call("k:crops_wheatStageA", p + ax * 0.45, 0.55)   # 밀
				2: add.call(FLOWERS[(r * 3 + q) % FLOWERS.size()], p, 0.9)   # 꽃밭
				_: if q % 3 == 0 and r % 2 == 0: add.call(FOREST[(r + q) % 3], p, 0.55)   # 과수원(낮은 나무 줄)
			if kind != 3 and q % 2 == 0:
				var h := height(p.x, p.y)
				soil.append(Transform3D(Basis(Vector3.UP, -ang) * Basis.from_scale(Vector3(1.9, 1.0, 0.55)), Vector3(p.x, h + 0.01, p.y)))
	if soil.is_empty(): return
	if _soil_mesh == null:
		_soil_mesh = BoxMesh.new(); _soil_mesh.size = Vector3(1.0, 0.04, 1.0)
		var m := StandardMaterial3D.new(); m.albedo_color = Color("8a6a48"); _soil_mesh.material = m
	var mm := MultiMesh.new(); mm.transform_format = MultiMesh.TRANSFORM_3D; mm.mesh = _soil_mesh; mm.instance_count = soil.size()
	for k in soil.size(): mm.set_instance_transform(k, soil[k])
	var mmi := MultiMeshInstance3D.new(); mmi.multimesh = mm; mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; n.add_child(mmi)
	# 밭 가 — 울타리 한 줄, 짐수레나 허수아비 대신 팻말, 밭 넷에 하나는 풍차(Kenney Fantasy Town)
	var corner := c - ax * (cols / 2.0 * 0.9 + 1.4) - ay * (rows / 2.0 * 1.3 + 0.6)
	for q in 6: _solid(n, "fantasy/fence", Vector2(corner.x, corner.y) + ax * (q * 2.4 + 1.2), -ang + PI / 2.0, 2.4, false)
	if rng.randf() < 0.5: _solid(n, "fantasy/cart", c + ay * (rows / 2.0 * 1.3 + 2.0), -ang, 2.2)
	else: _solid(n, "survival/signpost", c + ay * (rows / 2.0 * 1.3 + 1.6), -ang, 3.0)
	if rng.randf() < 0.25: _solid(n, "fantasy/windmill", c + ax * (cols / 2.0 * 0.9 + 4.0), -ang + PI / 2.0, 2.6)
static var _soil_mesh: BoxMesh

## 팩 모델 하나를 칸에(칸이 지워지면 같이) — 메시만(KitProps 캐시) + 상자 충돌(키 30cm 넘으면). p 는 땅 위 xz
func _solid(n: Node3D, pack_name: String, p: Vector2, yaw: float, sc: float, collide := true) -> void:
	var path := "res://assets/models/kenney/%s.glb" % pack_name
	var d := KitProps.src(path)
	if d.is_empty(): return
	var ab: AABB = d["ab"]
	var pivot := Node3D.new(); pivot.position = Vector3(p.x, height(p.x, p.y) - 0.03, p.y); pivot.rotation.y = yaw
	var m := KitProps.mesh_node(path); m.scale = Vector3.ONE * sc
	m.position = Vector3(-(ab.position.x + ab.size.x / 2.0) * sc, -ab.position.y * sc, -(ab.position.z + ab.size.z / 2.0) * sc)
	pivot.add_child(m)
	if collide and ab.size.y * sc > 0.3:
		var sb := StaticBody3D.new(); var cs := CollisionShape3D.new(); var bs := BoxShape3D.new()
		bs.size = Vector3(maxf(ab.size.x * sc * 0.85, 0.2), ab.size.y * sc, maxf(ab.size.z * sc * 0.85, 0.2)); cs.shape = bs; cs.position.y = ab.size.y * sc / 2.0
		sb.add_child(cs); pivot.add_child(sb)
	n.add_child(pivot)

## 들판의 볼거리 — 들 칸 다섯에 하나: 버섯 고리·바윗들·고사리 숲·꽃밭(모양만, MultiMesh 에 같이 넣는다)
func _feature(put: Dictionary, o: Vector3, rng: RandomNumberGenerator, body: StaticBody3D = null) -> void:
	var c := Vector2(o.x + 8.0 + rng.randf() * (CHUNK - 16.0), o.z + 8.0 + rng.randf() * (CHUNK - 16.0))
	if wild_k(c.x, c.y) < 0.6 or on_trail(c.x, c.y): return
	var add := func(id: String, p: Vector2, sc: float) -> void:
		var h := height(p.x, p.y)
		if not put.has(id): put[id] = []
		put[id].append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * sc), Vector3(p.x, h - 0.03, p.y)))
	match rng.randi() % 7:
		0:
			for i in 11: add.call(["k:mushroom_redGroup", "k:mushroom_tanGroup", "k:mushroom_redTall"][i % 3], c + Vector2.from_angle(i * TAU / 11.0) * 2.4, 1.1)
		1:
			for i in 7:
				var rp := c + Vector2(rng.randfn(0, 3.0), rng.randfn(0, 3.0)); var rs := rng.randf_range(1.2, 2.4)
				add.call(ROCKS[i % ROCKS.size()], rp, rs)
				if body:   # 바위는 막는다 — 전엔 볼거리 바위를 그냥 지나갔다(운영자 2026-10-08)
					var cs := CollisionShape3D.new(); var cy := CylinderShape3D.new(); cy.radius = 0.5 * rs; cy.height = 1.2 * rs
					cs.shape = cy; cs.position = Vector3(rp.x, height(rp.x, rp.y) + 0.6 * rs, rp.y); body.add_child(cs)
		2:
			for i in 16: add.call(["k:plant_flatTall", "k:plant_bushLarge", "k:grass_leafsLarge"][i % 3], c + Vector2(rng.randfn(0, 2.5), rng.randfn(0, 2.5)), rng.randf_range(0.9, 1.5))
		3:
			for i in 40: add.call(FLOWERS[i % FLOWERS.size()], c + Vector2(rng.randfn(0, 3.2), rng.randfn(0, 3.2)), rng.randf_range(0.9, 1.4))
		4:   # 들 야영지 — 텐트, 모닥불, 통나무, 장작(Kenney Survival)
			if body:
				var n := body.get_parent() as Node3D
				_solid(n, "survival/tent", c, rng.randf() * TAU, 3.0)
				_solid(n, "survival/campfire-pit", c + Vector2(2.6, 0.8), 0.0, 3.0, false)
				_solid(n, "nature/log", c + Vector2(2.6, 2.2), 0.0, 2.6)
				_solid(n, "survival/resource-wood", c + Vector2(-1.8, 2.0), rng.randf(), 3.0, false)
		5:   # 전망 자리 — 벤치 둘, 팻말, 등(Kenney Holiday·Survival)
			if body:
				var n := body.get_parent() as Node3D
				for k in 2: _solid(n, "holiday/bench", c + Vector2(k * 2.0 - 1.0, 0), PI, 1.2)
				_solid(n, "survival/signpost-single", c + Vector2(2.4, -0.6), 0.0, 3.0)
				_solid(n, "fantasy/lantern", c + Vector2(-2.4, -0.6), 0.0, 1.8)
		_:   # 버려진 짐수레와 통·궤짝(Kenney Fantasy·Survival)
			if body:
				var n := body.get_parent() as Node3D
				_solid(n, "fantasy/cart-high", c, rng.randf() * TAU, 2.2)
				for k in 3: _solid(n, ["survival/barrel", "survival/box-large", "survival/chest"][k], c + Vector2.from_angle(k * 2.1) * 2.0, rng.randf(), 3.0)

## 모델 하나를 한 번만 읽어 메시 조각과 그 변환(뿌리 기준), 높이를 기억한다 — MultiMesh 재료
func _model_src(id: String) -> Dictionary:
	if _src.has(id): return _src[id]
	var kenney := id.begins_with("k:")
	var root: Node3D = town._model("kenney/nature/" + id.substr(2) if kenney else "nature/quaternius/" + id)
	if kenney: KitProps.tone("res://assets/models/kenney/nature/" + id.substr(2) + ".glb", root)
	var parts: Array = []; var hi := 0.0
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var xf := Transform3D.IDENTITY; var nd: Node = mi
		while nd != root and nd is Node3D:
			xf = (nd as Node3D).transform * xf; nd = nd.get_parent()
		if kenney: xf = Transform3D(Basis().scaled(Vector3.ONE * K), Vector3.ZERO) * xf
		parts.append([(mi as MeshInstance3D).mesh, xf])
		var b: AABB = xf * (mi as MeshInstance3D).get_aabb()
		hi = maxf(hi, b.position.y + b.size.y)
	root.free()
	_src[id] = { "parts": parts, "h": hi }
	return _src[id]

## 새 공사장이 산 위면 그 둘레 칸을 지워 다시 짓는다(이번엔 깎인 땅으로) — town_growth._open_sites
func reflat(c: Vector2, far := true) -> void:
	if far: _refresh_far()
	for key in chunks.keys():
		var o := Vector2(key.x * CHUNK + CHUNK / 2.0, key.y * CHUNK + CHUNK / 2.0)
		if o.distance_to(c) < 80.0:
			(chunks[key] as Node3D).queue_free(); chunks.erase(key)

func rebuild_all(p: Vector3) -> void:
	_refresh_far()
	for key in chunks.keys(): (chunks[key] as Node3D).queue_free()
	chunks.clear(); _later.clear()
	fill(p)
