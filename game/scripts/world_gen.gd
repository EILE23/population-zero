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
var chunks := {}               # Vector2i -> Node3D
var _src := {}                 # 모델 id -> {parts: [[Mesh, Transform3D]], h}
var _ground: StandardMaterial3D
var _lake: ShaderMaterial
var built := 0                 # 지금까지 지은 칸 수(점검용)
var build_us_max := 0          # 한 프레임 칸 일(땅 또는 자연)의 최대·합계 시간(µs, probe_perf 가 읽는다)
var build_us_sum := 0
var _later: Array = []         # 땅만 지어 둔 칸의 자연 [노드, 칸, 원점] — 다음 프레임에 짓는다

const FOREST := ["CommonTree_1", "CommonTree_2", "CommonTree_3", "CommonTree_4", "CommonTree_5", "TwistedTree_1", "TwistedTree_3"]
const HIGH := ["Pine_1", "Pine_2", "Pine_3", "Pine_4", "Pine_5"]
const ROCKS := ["Rock_Medium_1", "Rock_Medium_2", "Rock_Medium_3"]
const PEBBLES := ["Pebble_Round_1", "Pebble_Round_2", "Pebble_Round_3", "Pebble_Round_4", "Pebble_Round_5"]
const GRASS := ["Grass_Common_Short", "Grass_Common_Tall", "Grass_Wispy_Short", "Grass_Wispy_Tall"]
const FLOWERS := ["Flower_3_Group", "Flower_4_Group", "Flower_3_Single", "Flower_4_Single", "Clover_1", "Clover_2"]
const UNDER := ["Fern_1", "Plant_1", "Plant_7", "Mushroom_Common", "Mushroom_Laetiporus", "Bush_Common"]
const BUSHES := ["Bush_Common", "Bush_Common_Flowers", "Plant_1_Big", "Plant_7_Big"]

func setup(t: TownBase) -> void:
	town = t
	_big.seed = SEED; _big.frequency = 0.0045; _big.fractal_octaves = 4
	_mid.seed = SEED + 1; _mid.frequency = 0.022; _mid.fractal_octaves = 2
	_moist.seed = SEED + 2; _moist.frequency = 0.006; _moist.fractal_octaves = 2
	_ground = t._mat(Color.WHITE, t._tex("ground/grass"))
	_ground.vertex_color_use_as_albedo = true
	_lake = Water3D.surface(); _lake.set_shader_parameter("flow", 0.05)
	# 지평선: 지은 칸 너머는 낮은 초록 판(안개가 흐린다) — 세계 끝이 허공으로 안 보이게
	var hz := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(12000, 12000); hz.mesh = pm
	hz.material_override = t._mat(Color("7fa65e")); hz.position.y = -2.5; add_child(hz)
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
			var h := height(x, z) - 0.6
			verts.append(Vector3(x, h, z))
			cols.append(Color(0.42, 0.56, 0.38).lerp(Color(0.62, 0.64, 0.6), smoothstep(40.0, 70.0, h)))
	for j in n:
		for i in n:
			var a := j * (n + 1) + i
			idx.append_array([a, a + 1, a + n + 1, a + 1, a + n + 2, a + n + 1])
	var arr := []; arr.resize(Mesh.ARRAY_MAX); arr[Mesh.ARRAY_VERTEX] = verts; arr[Mesh.ARRAY_COLOR] = cols; arr[Mesh.ARRAY_INDEX] = idx
	var st := SurfaceTool.new(); st.create_from_arrays(arr); st.generate_normals()
	var mi := MeshInstance3D.new(); mi.mesh = st.commit(); mi.name = "Far_" + String(pk["name"])
	var m := StandardMaterial3D.new(); m.vertex_color_use_as_albedo = true; mi.material_override = m
	add_child(mi)

# ── 땅 ──
## 0 = 평지로 깎인 곳(허브·큰길·강), 1 = 자연 지형
func wild_k(x: float, z: float) -> float:
	var dh := Vector2(maxf(absf(x) - HUB_X, 0.0), maxf(absf(z) - HUB_Z, 0.0)).length()
	var k := smoothstep(0.0, 30.0, dh)
	k = minf(k, smoothstep(4.0, 16.0, absf(z - ROAD_Z)))
	k = minf(k, smoothstep(town.RIVER_HW + 2.0, town.RIVER_HW + 14.0, absf(z - town.RIVER_Z)))
	if flat_limit > 0: k = minf(k, smoothstep(0.0, 26.0, TownPlan.flat_dist(x, z, flat_limit)))   # 지은·짓는 집 블록은 평지 — 둘레 26m 에 걸쳐 산으로
	for s in SITES:
		var c: Vector3 = s["c"]; var r: float = s["r"]
		k = minf(k, smoothstep(r, r + 22.0, Vector2(x - c.x, z - c.z).length()))
		k = minf(k, smoothstep(3.0, 13.0, _seg_dist(Vector2(x, z), Vector2(s["from"].x, s["from"].z), Vector2(c.x, c.z))))   # 장소로 가는 길
	return k

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
func on_trail(x: float, z: float) -> bool:
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

func lake_at(p: Vector3) -> bool:
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
			# 물가 칸까지(네 모서리 중 하나라도 물) 수면을 깔면 더 높은 땅이 수면을 가려 물가선이 지형을 따라 매끈해진다 — 칸 단위로 자르면 2m 계단이 졌다
			var q := (j + 1) * pw + i + 1
			if minf(minf(raws[q], raws[q + 1]), minf(raws[q + pw], raws[q + pw + 1])) < -0.05:
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
		"forest": plan = [[FOREST, 16, 4.2, 0.28], [UNDER, 14, 0.6, 0.0], [BUSHES, 5, 1.0, 0.0], [GRASS, 18, 0.9, 0.0], [ROCKS, 1, 1.0, 0.5]]
		"high": plan = [[HIGH, 9, 5.0, 0.25], [ROCKS, 4, 1.2, 0.55], [PEBBLES, 8, 0.8, 0.0], [GRASS, 12, 0.8, 0.0]]
		"dry": plan = [[ROCKS, 3, 1.0, 0.5], [PEBBLES, 10, 0.9, 0.0], [GRASS, 22, 0.9, 0.0], [FOREST, 1, 3.8, 0.28]]
		_: plan = [[FLOWERS, 18, 1.0, 0.0], [GRASS, 40, 1.0, 0.0], [BUSHES, 3, 1.0, 0.0], [FOREST, 2, 4.0, 0.28], [PEBBLES, 2, 0.8, 0.0]]
	for row in plan:
		var mountain: bool = row[0] is String
		var ids: Array = FOREST if mountain else row[0]
		for i in int(row[1]):
			var x := o.x + rng.randf() * CHUNK; var z := o.z + rng.randf() * CHUNK
			if on_trail(x, z): continue   # 계단 길은 비운다
			if mountain: ids = HIGH if height(x, z) > 24.0 + 8.0 * rng.randf() else FOREST
			var k := wild_k(x, z)
			if k < 0.45: continue
			var h := k * raw(x, z)   # = _h — 한 번만 잰다
			if h < 0.7 or rng.randf() > k: continue   # 물가 1m 안엔 안 난다(물속 풀)
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
	for id in put:
		var src := _model_src(id)
		for part in src["parts"]:
			var mm := MultiMesh.new(); mm.transform_format = MultiMesh.TRANSFORM_3D; mm.mesh = part[0]
			var xs: Array = put[id]; mm.instance_count = xs.size()
			for i in xs.size(): mm.set_instance_transform(i, (xs[i] as Transform3D) * (part[1] as Transform3D))
			var mmi := MultiMeshInstance3D.new(); mmi.multimesh = mm; n.add_child(mmi)

## 모델 하나를 한 번만 읽어 메시 조각과 그 변환(뿌리 기준), 높이를 기억한다 — MultiMesh 재료
func _model_src(id: String) -> Dictionary:
	if _src.has(id): return _src[id]
	var root: Node3D = town._model("nature/quaternius/" + id)
	var parts: Array = []; var hi := 0.0
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var xf := Transform3D.IDENTITY; var nd: Node = mi
		while nd != root and nd is Node3D:
			xf = (nd as Node3D).transform * xf; nd = nd.get_parent()
		parts.append([(mi as MeshInstance3D).mesh, xf])
		var b: AABB = xf * (mi as MeshInstance3D).get_aabb()
		hi = maxf(hi, b.position.y + b.size.y)
	root.free()
	_src[id] = { "parts": parts, "h": hi }
	return _src[id]

## 새 공사장이 산 위면 그 둘레 칸을 지워 다시 짓는다(이번엔 깎인 땅으로) — town_growth._open_sites
func reflat(c: Vector2) -> void:
	for key in chunks.keys():
		var o := Vector2(key.x * CHUNK + CHUNK / 2.0, key.y * CHUNK + CHUNK / 2.0)
		if o.distance_to(c) < 80.0:
			(chunks[key] as Node3D).queue_free(); chunks.erase(key)

func rebuild_all(p: Vector3) -> void:
	for key in chunks.keys(): (chunks[key] as Node3D).queue_free()
	chunks.clear(); _later.clear()
	fill(p)
