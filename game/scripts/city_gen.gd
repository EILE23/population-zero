class_name CityGen
extends RefCounted
## 도시(운영자 2026-10-06, SimCity 스크린샷: "내가 원하는 건 이런 느낌이야 위에서 봤을 때") — 허브 마을 북쪽 열린 세계에 격자 도로망과 블록.
## 블록마다 구역이 정해진다: 도심(고층 빌딩) → 중간(아파트·상가) → 바깥(박공지붕 주택가, 마당 나무) + 열에 하나는 공원. 장소(탑·호숫가·오두막) 둘레는 비운다.
## 계획은 좌표만으로 정해진다(시드 해시) — 칸(WorldGen CHUNK)마다 그 칸에 든 도로 토막과 건물만 짓는다(MultiMesh + 칸 하나의 충돌체). 멀어지면 칸째 지운다.
## 탑 가는 길(x 15.5)은 도시의 남북 큰길(x 16)과 겹친다 — 마을에서 걸어 나가면 그대로 도시다

const PITCH := 48.0           # 블록 간격(도로 중심 사이)
const ROAD := 10.0            # 도로 폭(차도 7 + 보도 1.5 ×2)
const OX := 16.0              # 남북 도로가 지나는 x(+ k·PITCH) — 탑 길과 같은 줄
const OZ := -60.0             # 첫 동서 도로 z(− k·PITCH, 북쪽으로)
const X0 := -560.0
const X1 := 600.0
const Z0 := -620.0            # 북쪽 끝
const Z1 := -44.0             # 남쪽 끝(허브 북쪽 녹지대 너머)
const DOWNTOWN := Vector2(16.0, -330.0)

static func in_city(x: float, z: float) -> bool:
	return x > X0 and x < X1 and z > Z0 and z < Z1 and not _near_site(x, z, 8.0)

static func _near_site(x: float, z: float, pad: float) -> bool:
	for s in WorldGen.SITES:
		var c: Vector3 = s["c"]
		if Vector2(x - c.x, z - c.z).length() < float(s["r"]) + pad: return true
	return false

static func block_of(x: float, z: float) -> Vector2i:
	return Vector2i(floori((x - OX) / PITCH), floori((OZ - z) / PITCH))

## 블록 안쪽 사각(도로를 뺀 땅) — [x0, z0(북), 한 변]
static func block_rect(b: Vector2i) -> Rect2:
	var x0 := OX + b.x * PITCH + ROAD / 2.0
	var z0 := OZ - (b.y + 1) * PITCH + ROAD / 2.0
	return Rect2(x0, z0, PITCH - ROAD, PITCH - ROAD)

static func zone(b: Vector2i) -> String:
	var r := block_rect(b); var c := r.get_center()
	if not (c.x > X0 and c.x < X1 and c.y > Z0 and c.y < Z1): return "none"
	if _near_site(c.x, c.y, 34.0): return "none"
	var hs: int = absi(hash(Vector2i(b.x * 7 + 3, b.y * 13 + 5)))
	var d := c.distance_to(DOWNTOWN)
	if hs % 10 == 0 and d > 70.0: return "park"
	if d < 105.0: return "down"
	if d < 220.0: return "mid"
	return "sub"

## 블록의 건물들 — {c: Vector2(중심 x,z), s: Vector3(폭, 높이, 깊이), kind, col, roof}
static func buildings(b: Vector2i) -> Array:
	var z := zone(b)
	if z in ["none", "park"]: return []
	var r := block_rect(b)
	var rng := RandomNumberGenerator.new(); rng.seed = hash(Vector3i(b.x, b.y, 20261006))
	var out: Array = []
	match z:
		"sub":   # 북쪽 줄·남쪽 줄 넷씩, 길 쪽으로 3m 물러난 박공지붕 집 — 마당 뒤엔 나무
			var walls := [Color("e8dccb"), Color("d9c08a"), Color("c8d2d8"), Color("a8bf98"), Color("e8bfa4"), Color("c4b0d0")]
			var roofs := [Color("b56a5a"), Color("7b526c"), Color("5b6a7a"), Color("8a6a4a"), Color("6e7a5a")]
			for row in [0, 1]:
				for i in 4:
					var w := rng.randf_range(6.0, 7.6); var d := rng.randf_range(6.0, 7.8); var h := 3.2 if rng.randf() < 0.6 else 5.6
					var cx := r.position.x + 4.75 + i * 9.5
					var cz := r.position.y + 3.0 + d / 2.0 if row == 0 else r.end.y - 3.0 - d / 2.0
					out.append({ "c": Vector2(cx, cz), "s": Vector3(w, h, d), "kind": "house", "col": walls[rng.randi() % walls.size()], "roof": roofs[rng.randi() % roofs.size()], "tree": Vector2(cx + rng.randf_range(-2.0, 2.0), r.get_center().y + (rng.randf_range(-3.0, -1.0) if row == 0 else rng.randf_range(1.0, 3.0))) })
		"mid":   # 2×2 아파트·상가, 높이 10~28m
			var cols := [Color("c9a88a"), Color("b8aea6"), Color("d1b48c"), Color("a89890"), Color("b5a58f"), Color("9fa8a0")]
			for gx in 2:
				for gz in 2:
					var w := rng.randf_range(13.0, 16.5); var d := rng.randf_range(13.0, 16.5)
					out.append({ "c": Vector2(r.position.x + 9.5 + gx * 19.0, r.position.y + 9.5 + gz * 19.0), "s": Vector3(w, rng.randf_range(10.0, 28.0), d), "kind": "apt", "col": cols[rng.randi() % cols.size()] })
		"down":  # 고층: 블록 하나에 한두 채(35~110m), 도심 중심일수록 높다
			var near := 1.0 - r.get_center().distance_to(DOWNTOWN) / 105.0
			var cols := [Color("7f93a8"), Color("9aa9b4"), Color("6e7e8c"), Color("a89f96"), Color("8a9aa5"), Color("7f9078"), Color("a08a7a")]
			if rng.randf() < 0.45:
				out.append({ "c": r.get_center(), "s": Vector3(rng.randf_range(22.0, 30.0), lerpf(40.0, 120.0, near) * rng.randf_range(0.75, 1.0), rng.randf_range(22.0, 30.0)), "kind": "tower", "col": cols[rng.randi() % cols.size()] })
			else:
				for k in 2:
					var w := rng.randf_range(13.0, 17.0)
					out.append({ "c": Vector2(r.position.x + 10.0 + k * 18.0, r.get_center().y + rng.randf_range(-6.0, 6.0)), "s": Vector3(w, lerpf(30.0, 95.0, near) * rng.randf_range(0.6, 1.0), w * rng.randf_range(0.9, 1.3)), "kind": "tower", "col": cols[rng.randi() % cols.size()] })
	return out

# ── 짓기(칸 하나) ──
static var _wall_mat: ShaderMaterial
static var _vcol_mat: StandardMaterial3D

static func _mats() -> void:
	if _wall_mat == null:
		_wall_mat = ShaderMaterial.new(); _wall_mat.shader = load("res://shaders/city_building.gdshader")
		_vcol_mat = StandardMaterial3D.new(); _vcol_mat.vertex_color_use_as_albedo = true; _vcol_mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON; _vcol_mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED; _vcol_mat.roughness = 1.0

static func _mm(n: Node3D, mesh: Mesh, mat: Material, xs: Array, cs: Array) -> void:
	if xs.is_empty(): return
	var mm := MultiMesh.new(); mm.transform_format = MultiMesh.TRANSFORM_3D; mm.use_colors = true; mm.mesh = mesh
	mm.instance_count = xs.size()
	for i in xs.size(): mm.set_instance_transform(i, xs[i]); mm.set_instance_color(i, cs[i])
	var mi := MultiMeshInstance3D.new(); mi.multimesh = mm; mi.material_override = mat; n.add_child(mi)

## 칸(o, CHUNK) 안의 도로 토막·보도·중앙선, 블록 바닥(도심 포장·공원 길), 건물·지붕·마당 나무, 충돌
static func build_chunk(gen: WorldGen, n: Node3D, o: Vector3, size: float) -> void:
	_mats()
	var xs_box: Array = []; var cs_box: Array = []        # 도로·보도·바닥(색 상자)
	var xs_wall: Array = []; var cs_wall: Array = []      # 건물 벽(창 셰이더)
	var xs_roof: Array = []; var cs_roof: Array = []      # 박공지붕(프리즘)
	var trees: Array = []
	var body := StaticBody3D.new(); n.add_child(body)
	var floor_cs := CollisionShape3D.new(); var fb := BoxShape3D.new(); fb.size = Vector3(size, 1.0, size); floor_cs.shape = fb; floor_cs.position = o + Vector3(size / 2.0, -0.5, size / 2.0); body.add_child(floor_cs)   # 도시는 평지 — 높이맵 대신 바닥 판
	var asphalt := Color("4f4f57"); var walk := Color("bfb8b0"); var dash := Color("efe9e2")
	# 도로: 남북 줄
	var k0 := ceili((o.x - ROAD / 2.0 - OX) / PITCH); var k1 := floori((o.x + size + ROAD / 2.0 - OX) / PITCH)
	for k in range(k0, k1 + 1):
		var rx := OX + k * PITCH
		var z := o.z
		while z < o.z + size:
			var zc := z + 4.0
			if in_city(rx, zc):
				xs_box.append(Transform3D(Basis().scaled(Vector3(7.0, 0.04, 8.0)), Vector3(rx, 0.02, zc))); cs_box.append(asphalt)
				for sd in [-1.0, 1.0]: xs_box.append(Transform3D(Basis().scaled(Vector3(1.5, 0.12, 8.0)), Vector3(rx + sd * 4.25, 0.06, zc))); cs_box.append(walk)
				if int(zc / 4.0) % 2 == 0: xs_box.append(Transform3D(Basis().scaled(Vector3(0.18, 0.05, 2.6)), Vector3(rx, 0.045, zc))); cs_box.append(dash)
			z += 8.0
	# 도로: 동서 줄
	var j0 := ceili((OZ - (o.z + size) - ROAD / 2.0) / PITCH); var j1 := floori((OZ - o.z + ROAD / 2.0) / PITCH)
	for j in range(maxi(j0, 0), j1 + 1):
		var rz := OZ - j * PITCH
		var x := o.x
		while x < o.x + size:
			var xc := x + 4.0
			if in_city(xc, rz):
				xs_box.append(Transform3D(Basis().scaled(Vector3(8.0, 0.04, 7.0)), Vector3(xc, 0.021, rz))); cs_box.append(asphalt)
				for sd in [-1.0, 1.0]: xs_box.append(Transform3D(Basis().scaled(Vector3(8.0, 0.12, 1.5)), Vector3(xc, 0.061, rz + sd * 4.25))); cs_box.append(walk)
				if int(xc / 4.0) % 2 == 0: xs_box.append(Transform3D(Basis().scaled(Vector3(2.6, 0.05, 0.18)), Vector3(xc, 0.046, rz))); cs_box.append(dash)
			x += 8.0
	# 블록: 이 칸에 걸친 블록마다 바닥, 그리고 중심이 이 칸 안인 건물만(칸 사이 중복 없이)
	var b0 := block_of(o.x, o.z + size); var b1 := block_of(o.x + size, o.z)
	for bx in range(b0.x, b1.x + 1):
		for bz in range(b0.y, b1.y + 1):   # 남쪽(작은 번호) → 북쪽
			var b := Vector2i(bx, bz)
			var zn := zone(b)
			if zn == "none": continue
			var br := block_rect(b)
			var cut := br.intersection(Rect2(o.x, o.z, size, size))
			if cut.size.x > 0.1 and cut.size.y > 0.1 and zn in ["down", "mid"]:   # 도심·중간은 포장
				xs_box.append(Transform3D(Basis().scaled(Vector3(cut.size.x, 0.05, cut.size.y)), Vector3(cut.get_center().x, 0.03, cut.get_center().y))); cs_box.append(Color("cfc8c0") if zn == "down" else Color("c8c2b6"))
			if zn == "park":
				var prng := RandomNumberGenerator.new(); prng.seed = hash(Vector2i(bx, bz))
				for i in 12:
					var tp := Vector2(br.position.x + prng.randf() * br.size.x, br.position.y + prng.randf() * br.size.y)
					if Rect2(o.x, o.z, size, size).has_point(tp): trees.append(tp)
				var pc := br.get_center()
				if Rect2(o.x, o.z, size, size).has_point(pc):
					xs_box.append(Transform3D(Basis().scaled(Vector3(br.size.x, 0.05, 2.0)), Vector3(pc.x, 0.03, pc.y))); cs_box.append(Color("d8c8a8"))
					xs_box.append(Transform3D(Basis().scaled(Vector3(2.0, 0.05, br.size.y)), Vector3(pc.x, 0.031, pc.y))); cs_box.append(Color("d8c8a8"))
			for bd in buildings(b):
				var c: Vector2 = bd["c"]
				if c.x < o.x or c.x >= o.x + size or c.y < o.z or c.y >= o.z + size: continue
				var s: Vector3 = bd["s"]
				xs_wall.append(Transform3D(Basis().scaled(s), Vector3(c.x, s.y / 2.0, c.y))); cs_wall.append(bd["col"])
				if bd["kind"] == "house":
					var rh := s.x * 0.32
					xs_roof.append(Transform3D(Basis(Vector3.UP, PI / 2.0).scaled(Vector3(s.z + 0.6, rh, s.x + 0.6)), Vector3(c.x, s.y + rh / 2.0, c.y))); cs_roof.append(bd["roof"])
					if bd.has("tree"): trees.append(bd["tree"])
				elif bd["kind"] == "tower" and s.y > 60.0:   # 꼭대기 기계실
					xs_box.append(Transform3D(Basis().scaled(Vector3(s.x * 0.4, 3.0, s.z * 0.4)), Vector3(c.x, s.y + 1.5, c.y))); cs_box.append(Color("8a8a92"))
				var cs := CollisionShape3D.new(); var bs := BoxShape3D.new(); bs.size = s; cs.shape = bs; cs.position = Vector3(c.x, s.y / 2.0, c.y); body.add_child(cs)
	var box := BoxMesh.new()
	_mm(n, box, _vcol_mat, xs_box, cs_box)
	_mm(n, box, _wall_mat, xs_wall, cs_wall)
	var prism := PrismMesh.new(); prism.size = Vector3.ONE
	_mm(n, prism, _vcol_mat, xs_roof, cs_roof)
	# 나무 — 열린 세계와 같은 MegaKit 모델(MultiMesh)
	if not trees.is_empty():
		var src: Dictionary = gen._model_src("CommonTree_" + str(1 + absi(int(o.x + o.z)) % 5))
		var sc := 4.6 / maxf(float(src["h"]), 0.3)
		for part in src["parts"]:
			var xs: Array = []; var cs: Array = []
			for tp in trees:
				xs.append(Transform3D(Basis(Vector3.UP, fmod(tp.x * 1.7, TAU)).scaled(Vector3.ONE * sc), Vector3(tp.x, 0.0, tp.y)) * (part[1] as Transform3D)); cs.append(Color.WHITE)
			var mm := MultiMesh.new(); mm.transform_format = MultiMesh.TRANSFORM_3D; mm.mesh = part[0]; mm.instance_count = xs.size()
			for i in xs.size(): mm.set_instance_transform(i, xs[i])
			var mmi := MultiMeshInstance3D.new(); mmi.multimesh = mm; n.add_child(mmi)
