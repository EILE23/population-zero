class_name WorldGen
extends Node3D
## 열린 세계(운영자 2026-09-30: "마인크래프트·팰월드처럼 맵이 엄청 넓어야") — 시드 하나로 땅을 칸(CHUNK m)마다 만든다.
## 마을(허브)·큰길·강 둘레는 평지(y 0)로 깎이고, 그 밖은 언덕·숲·초원·솔숲 고지·호수가 끝없이 이어진다.
## 플레이어 둘레 RADIUS 칸만 짓고 멀어진 칸은 지운다 — 넓이와 상관없이 가볍다. 같은 시드면 칸은 언제나 똑같이 다시 지어진다.
## 칸의 자연(나무·덤불·바위·풀·꽃·버섯)은 MultiMesh(그리기 한 번) — 나무·바위만 몸통 충돌. 호수는 강과 같은 수면(Water3D)이라 헤엄 규칙도 같다

const CHUNK := 32.0
const RES := 16                # 칸 한 변 격자 수(2m 간격)
const RADIUS := 3              # 플레이어 칸 둘레 몇 칸(7×7 = 224m 사방)
const SEED := 20260930
const HUB_X := 72.0            # 허브(마을) 평지 반폭 — town_base WORLD_X 와 같다
const HUB_Z := 26.0
const ROAD_Z := 2.0

var town: TownBase
var _big := FastNoiseLite.new()
var _mid := FastNoiseLite.new()
var _moist := FastNoiseLite.new()
var chunks := {}               # Vector2i -> Node3D
var _src := {}                 # 모델 id -> {parts: [[Mesh, Transform3D]], h}
var _ground: StandardMaterial3D
var _lake: ShaderMaterial
var built := 0                 # 지금까지 지은 칸 수(점검용)

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

# ── 땅 ──
## 0 = 평지로 깎인 곳(허브·큰길·강), 1 = 자연 지형
func wild_k(x: float, z: float) -> float:
	var dh := Vector2(maxf(absf(x) - HUB_X, 0.0), maxf(absf(z) - HUB_Z, 0.0)).length()
	var k := smoothstep(0.0, 30.0, dh)
	k = minf(k, smoothstep(4.0, 16.0, absf(z - ROAD_Z)))
	k = minf(k, smoothstep(town.RIVER_HW + 2.0, town.RIVER_HW + 14.0, absf(z - town.RIVER_Z)))
	return k

## 깎기 전 높이 — 큰 굽이 + 작은 기복. 0 아래는 호수가 된다
func raw(x: float, z: float) -> float:
	return 3.4 + 13.0 * _big.get_noise_2d(x, z) + 2.4 * _mid.get_noise_2d(x, z)

func _h(x: float, z: float) -> float:
	return wild_k(x, z) * raw(x, z)

## 땅 높이(호수 바닥은 수면 바로 아래 -0.02 — 강과 같은 얕은 물이라 같은 헤엄 규칙)
func height(x: float, z: float) -> float:
	return maxf(_h(x, z), -0.02)

func lake_at(p: Vector3) -> bool:
	return p.y < 0.3 and _h(p.x, p.z) < -0.05

func _biome(x: float, z: float, h: float) -> String:
	if h > 7.5: return "high"
	var m := _moist.get_noise_2d(x, z)
	if m > 0.12: return "forest"
	if m < -0.3: return "dry"
	return "meadow"

func _tint(x: float, z: float, h: float, k: float, slope: float) -> Color:
	var c := Color.WHITE
	match _biome(x, z, h):
		"forest": c = Color(0.74, 0.86, 0.7)
		"high": c = Color(0.84, 0.88, 0.8)
		"dry": c = Color(1.0, 0.94, 0.72)
		_: c = Color(0.97, 1.0, 0.88)
	if h < 0.25 and _h(x, z) < 0.3: c = Color(0.96, 0.9, 0.74)   # 물가 모래
	c = c.lerp(Color(0.72, 0.7, 0.66), smoothstep(0.12, 0.35, slope))   # 가파르면 바위빛
	return Color.WHITE.lerp(c, smoothstep(0.0, 0.4, k))   # 허브 안은 원래 풀밭 그대로

# ── 칸 ──
## 매 프레임(town_systems _stream): 둘레의 빠진 칸을 가까운 것부터 한 프레임에 하나 짓고, RADIUS+1 밖 칸은 지운다
func stream(p: Vector3) -> void:
	var cx := floori(p.x / CHUNK); var cz := floori(p.z / CHUNK)
	var best := Vector2i.ZERO; var bd := 1e9; var need := false
	for dz in range(-RADIUS, RADIUS + 1):
		for dx in range(-RADIUS, RADIUS + 1):
			var key := Vector2i(cx + dx, cz + dz)
			if chunks.has(key): continue
			var d := dx * dx + dz * dz
			if d < bd: bd = d; best = key; need = true
	if need: _build(best)
	for key in chunks.keys():
		if absi(key.x - cx) > RADIUS + 1 or absi(key.y - cz) > RADIUS + 1:
			(chunks[key] as Node3D).queue_free(); chunks.erase(key)

## 처음 둘레 전부(시작할 때 한 번에 — 빈 땅이 보이지 않게)
func fill(p: Vector3) -> void:
	for i in (RADIUS * 2 + 1) * (RADIUS * 2 + 1): stream(p)

func _build(key: Vector2i) -> void:
	built += 1
	var n := Node3D.new(); n.name = "Chunk_%d_%d" % [key.x, key.y]; add_child(n); chunks[key] = n
	var o := Vector3(key.x * CHUNK, 0, key.y * CHUNK)
	var step := CHUNK / RES; var w := RES + 1
	var hs := PackedFloat32Array(); hs.resize(w * w)
	var wild := 0.0
	for j in w:
		for i in w:
			var x := o.x + i * step; var z := o.z + j * step
			hs[j * w + i] = height(x, z); wild = maxf(wild, wild_k(x, z))
	# 땅 메시(정점색 = 생물군 빛깔, UV = 세계 좌표라 칸 이음새가 없다)
	var verts := PackedVector3Array(); var norms := PackedVector3Array(); var cols := PackedColorArray(); var uvs := PackedVector2Array(); var idx := PackedInt32Array()
	for j in w:
		for i in w:
			var x := o.x + i * step; var z := o.z + j * step; var h := hs[j * w + i]
			var nx := height(x - step, z) - height(x + step, z); var nz := height(x, z - step) - height(x, z + step)
			var nrm := Vector3(nx, 2.0 * step, nz).normalized()
			verts.append(Vector3(i * step, h, j * step)); norms.append(nrm)
			cols.append(_tint(x, z, h, wild_k(x, z), 1.0 - nrm.y))
			uvs.append(Vector2(x, z) / town.TILE)
	var lake_idx := PackedInt32Array()
	for j in RES:
		for i in RES:
			var a := j * w + i
			idx.append_array([a, a + 1, a + w, a + 1, a + w + 1, a + w])
			# 물가 칸까지(네 모서리 중 하나라도 물) 수면을 깔면 더 높은 땅이 수면을 가려 물가선이 지형을 따라 매끈해진다 — 칸 단위로 자르면 2m 계단이 졌다
			var wet := false
			for cn in [[i, j], [i + 1, j], [i, j + 1], [i + 1, j + 1]]:
				if _h(o.x + cn[0] * step, o.z + cn[1] * step) < -0.05: wet = true
			if wet: lake_idx.append_array([a, a + 1, a + w, a + 1, a + w + 1, a + w])
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
		_nature(n, key, o)

## 칸의 자연 — 생물군마다 다른 밀도. 평지(허브·길·강)와 물·가파른 곳엔 안 놓는다
func _nature(n: Node3D, key: Vector2i, o: Vector3) -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = hash(Vector3i(key.x, key.y, SEED))
	var put := {}   # 모델 id -> [Transform3D]
	var body := StaticBody3D.new(); n.add_child(body)
	var c := o + Vector3(CHUNK / 2.0, 0, CHUNK / 2.0)
	var biome := _biome(c.x, c.z, height(c.x, c.z))
	var plan: Array = []   # [목록, 개수, 크기(목표 높이 m 또는 배율), 충돌 반지름]
	match biome:
		"forest": plan = [[FOREST, 16, 4.2, 0.28], [UNDER, 14, 0.6, 0.0], [BUSHES, 5, 1.0, 0.0], [GRASS, 18, 0.9, 0.0], [ROCKS, 1, 1.0, 0.5]]
		"high": plan = [[HIGH, 9, 5.0, 0.25], [ROCKS, 4, 1.2, 0.55], [PEBBLES, 8, 0.8, 0.0], [GRASS, 12, 0.8, 0.0]]
		"dry": plan = [[ROCKS, 3, 1.0, 0.5], [PEBBLES, 10, 0.9, 0.0], [GRASS, 22, 0.9, 0.0], [FOREST, 1, 3.8, 0.28]]
		_: plan = [[FLOWERS, 18, 1.0, 0.0], [GRASS, 40, 1.0, 0.0], [BUSHES, 3, 1.0, 0.0], [FOREST, 2, 4.0, 0.28], [PEBBLES, 2, 0.8, 0.0]]
	for row in plan:
		var ids: Array = row[0]
		for i in int(row[1]):
			var x := o.x + rng.randf() * CHUNK; var z := o.z + rng.randf() * CHUNK
			var k := wild_k(x, z)
			if k < 0.45 or _h(x, z) < 0.7 or rng.randf() > k: continue   # 물가 1m 안엔 안 난다(물속 풀)
			var h := height(x, z)
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
