class_name Infill
extends RefCounted
## 빈 잔디 메우기(운영자 2026-10-13: "아직도 보면 녹지가 되게 많은데?", 옛 마을·집 둘레 사진) — 깎인 마을 땅(허브·찻길 블록)을 6m 칸으로 훑어
## 아무것도 없는 칸(물·찻길·돌길·집·문 앞 길목·자리(spots) 둘레·충돌체가 없는)마다 작은 장면 하나: 나무와 덤불, 벤치와 등, 둥근 탁자와 의자,
## 바위 정원, 생울타리와 조각, 작은 노점, 작은 분수, 채소 이랑, 수레와 통, 피크닉 깔개, 꽃 무더기. 칸마다 시드로 늘 같은 것. 구역마다 합친다

const CELL := 4.0
const TUFT := 1.6   # 풀·꽃 덮개 칸 — 장면이 안 들어간 잔디에도 풀 포기·꽃(부딪히지 않는다)

static func run(t, rect: Rect2) -> int:
	var space: PhysicsDirectSpaceState3D = t.get_world_3d().direct_space_state
	var q := PhysicsShapeQueryParameters3D.new(); var bx := BoxShape3D.new(); bx.size = Vector3(CELL - 1.2, 1.2, CELL - 1.2); q.shape = bx; q.collision_mask = 1
	var spot_grid := {}
	for sp in t.spots:
		var sp_p: Vector3 = sp["pos"]
		var sk := Vector2i(floori(sp_p.x / CELL), floori(sp_p.z / CELL))
		if not spot_grid.has(sk): spot_grid[sk] = []
		spot_grid[sk].append(sp_p)
	var placed := 0
	var by_root := {}
	var x := rect.position.x + CELL / 2.0
	while x < rect.end.x:
		var z := rect.position.y + CELL / 2.0
		while z < rect.end.y:
			var p := Vector3(x, 0, z)
			if false and _free(t, p, spot_grid, space, q):   # 아무 장면이나 흩뿌리던 것은 뺐다(운영자 2026-10-14: "누가 이렇게 어질러놓으랬어") — 빈 땅은 집으로 채운다
				var root: Node3D = t._root_for(p)
				var keep: Node3D = t._build_parent; t._build_parent = root
				if not by_root.has(root): by_root[root] = t._merge_mark()
				_scene(t, p, absi(hash("infill/%d,%d" % [int(x), int(z)])))
				t._build_parent = keep
				var gk := Vector2i(floori(x / CELL), floori(z / CELL))
				if not spot_grid.has(gk): spot_grid[gk] = []
				spot_grid[gk].append(p)
				placed += 1
			z += CELL
		x += CELL
	_tufts(t, rect, space, by_root)
	for r in by_root: t._merge_done(by_root[r])
	return placed

static func _free(t, p: Vector3, spot_grid: Dictionary, space: PhysicsDirectSpaceState3D, q: PhysicsShapeQueryParameters3D) -> bool:
	var gen: WorldGen = t.gen
	if gen.wild_k(p.x, p.z) > 0.05: return false
	for d in [Vector2(-2.0, -2.0), Vector2(2.0, 2.0), Vector2(2.0, -2.0), Vector2(-2.0, 2.0), Vector2.ZERO]:
		var hh := gen.height(p.x + d.x, p.z + d.y)
		if hh < -0.005 or hh > 0.3: return false   # 물·비탈
		if gen._on_road(p.x + d.x, p.z + d.y): return false
	if absf(p.z - WorldGen.ROAD_Z) < 4.2 or absf(p.z - t.RIVER_Z) < t.RIVER_HW + 2.5: return false   # 큰길·강
	var k := Vector2i(floori(p.x / CELL), floori(p.z / CELL))
	for dx in [-1, 0, 1]:
		for dz in [-1, 0, 1]:
			for sp_p in spot_grid.get(k + Vector2i(dx, dz), []):
				if Vector2((sp_p as Vector3).x - p.x, (sp_p as Vector3).z - p.z).length() < 1.7: return false
	for h in t.houses:
		var mn: Vector3 = h["min"]; var mx: Vector3 = h["max"]
		if p.x > mn.x - 2.4 and p.x < mx.x + 2.4 and p.z > mn.z - 2.4 and p.z < mx.z + 2.4: return false
	for dr in t.doors:   # 문 앞 길목(문에서 남쪽 9m)
		var dp: Vector3 = dr["pos"]
		if absf(p.x - dp.x) < 2.2 and p.z > dp.z - 1.0 and p.z < dp.z + 7.0: return false
	for pa in t.paths:
		if _seg_d(Vector2(p.x, p.z), pa[0], pa[1]) < float(pa[2]) / 2.0 + 1.8: return false
	q.transform = Transform3D(Basis(), p + Vector3(0, 0.85, 0))
	return space.intersect_shape(q, 1).is_empty()

## 풀·꽃 덮개 — 깎인 잔디의 1.6m 칸마다 무엇도 없으면(충돌체·돌길·찻길·물·집이 아니면) 풀 포기나 꽃 한두 송이. 맨 잔디가 넓게 비어 보였다(운영자 2026-10-14)
static func _tufts(t, rect: Rect2, space: PhysicsDirectSpaceState3D, by_root: Dictionary) -> void:
	var gen: WorldGen = t.gen
	var big := rect.grow(10.0)   # 이 칸 둘레의 집·문·돌길만 본다(전부 훑으면 시작이 느렸다)
	var hs: Array = t.houses.filter(func(h: Dictionary) -> bool: return big.has_point(Vector2((h["min"] as Vector3).x, (h["min"] as Vector3).z)) or big.has_point(Vector2((h["max"] as Vector3).x, (h["max"] as Vector3).z)))
	var ds: Array = t.doors.filter(func(d: Dictionary) -> bool: return big.has_point(Vector2((d["pos"] as Vector3).x, (d["pos"] as Vector3).z)))
	var ps: Array = t.paths.filter(func(pa: Array) -> bool: return big.intersects(Rect2(pa[0], Vector2.ZERO).expand(pa[1]).grow(float(pa[2]))))
	var q := PhysicsShapeQueryParameters3D.new(); var bx := BoxShape3D.new(); bx.size = Vector3(TUFT * 0.8, 0.8, TUFT * 0.8); q.shape = bx; q.collision_mask = 1
	var put := {}   # root -> {종류 -> [Transform3D]} — 풀 포기는 MultiMesh 한 장씩(노드 수천 개를 만들면 시작이 5초 늘었다)
	var kinds := ["grass", "grass_large", "grass_leafs", "grass"]   # 풀 포기만(꽃·버섯·돌은 어질러 보였다)
	var x := rect.position.x + TUFT / 2.0
	while x < rect.end.x:
		var z := rect.position.y + TUFT / 2.0
		while z < rect.end.y:
			var h := absi(hash("tuft/%d,%d" % [int(x * 10.0), int(z * 10.0)]))
			if h % 3 == 0:   # 셋에 한 칸
				var p := Vector3(x + float(h % 7) * 0.15 - 0.45, 0, z + float(h % 5) * 0.18 - 0.36)
				if _tuft_ok(t, gen, p, hs, ds, ps):
					q.transform = Transform3D(Basis(), p + Vector3(0, 0.5, 0))
					if space.intersect_shape(q, 1).is_empty():
						var root: Node3D = t._root_for(p)
						if not put.has(root): put[root] = {}
						var kind: String = kinds[h % kinds.size()]
						if not (put[root] as Dictionary).has(kind): put[root][kind] = []
						var sc := 1.6 + float(h % 9) * 0.12
						(put[root][kind] as Array).append(Transform3D(Basis(Vector3.UP, float(h % 360) * 0.0174).scaled(Vector3.ONE * sc), p))
			z += TUFT
		x += TUFT
	for root in put:
		for kind in put[root]:
			var d := KitProps.src(KitProps.N + String(kind) + ".glb")
			if d.is_empty(): continue
			var ab: AABB = d["ab"]
			var base := Transform3D(Basis(), Vector3(-(ab.position.x + ab.size.x / 2.0), -ab.position.y, -(ab.position.z + ab.size.z / 2.0)))
			var xs: Array = put[root][kind]
			for pt in d["parts"]:
				var mm := MultiMesh.new(); mm.transform_format = MultiMesh.TRANSFORM_3D; mm.mesh = pt[0]; mm.instance_count = xs.size()
				for i in xs.size(): mm.set_instance_transform(i, (xs[i] as Transform3D) * base * (pt[1] as Transform3D))
				var mmi := MultiMeshInstance3D.new(); mmi.multimesh = mm; mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; mmi.visibility_range_end = 90.0
				(root as Node3D).add_child(mmi)

static func _tuft_ok(t, gen: WorldGen, p: Vector3, hs: Array, ds: Array, ps: Array) -> bool:
	if gen.wild_k(p.x, p.z) > 0.05: return false
	var hh := gen.height(p.x, p.z)
	if hh < -0.005 or hh > 0.3 or gen._on_road(p.x, p.z): return false
	if absf(p.z - WorldGen.ROAD_Z) < 3.0 or absf(p.z - t.RIVER_Z) < t.RIVER_HW + 0.8: return false
	for h in hs:
		var mn: Vector3 = h["min"]; var mx: Vector3 = h["max"]
		if p.x > mn.x - 0.4 and p.x < mx.x + 0.4 and p.z > mn.z - 0.4 and p.z < mx.z + 1.2: return false
	for dr in ds:
		var dp: Vector3 = dr["pos"]
		if absf(p.x - dp.x) < 1.2 and p.z > dp.z - 0.5 and p.z < dp.z + 7.0: return false   # 문 앞 길
	for pa in ps:
		if _seg_d(Vector2(p.x, p.z), pa[0], pa[1]) < float(pa[2]) / 2.0 + 0.3: return false
	return true

static func _seg_d(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var tt := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return p.distance_to(a + ab * tt)

static func _scene(t, p: Vector3, h: int) -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = h
	var yaw := float(h % 4) * PI / 2.0
	var off := func(x: float, z: float) -> Vector3: return p + Vector3(x, 0, z).rotated(Vector3.UP, yaw)
	match h % 12:
		0, 1:   # 나무와 덤불
			t._tree(off.call(0, 0), rng.randf_range(0.85, 1.1))
			for i in 4: KitProps.n(t, KitProps.BUSHES[(h + i) % KitProps.BUSHES.size()], off.call(cos(i * 1.6) * 1.6, sin(i * 1.6) * 1.6), rng.randf() * TAU, rng.randf_range(2.4, 3.2))
			for i in 5: KitProps.n(t, KitProps.FLOWERS[(h + i) % KitProps.FLOWERS.size()], off.call(rng.randf_range(-2, 2), rng.randf_range(-2, 2)), 0.0, 1.8, false)
		2:   # 벤치와 등, 꽃 띠
			t._bench(off.call(0, 0.4)); t._lamp(off.call(1.4, -0.4))
			KitProps.border(t, off.call(-2.2, -1.0), off.call(2.2, -1.0), rng, 0.55)
		3:   # 둥근 탁자와 의자, 화분
			KitProps.f(t, "tableRound", off.call(0, 0))
			for a in 3: KitProps.f(t, "chairModernCushion", off.call(sin(a * TAU / 3.0) * 1.0, cos(a * TAU / 3.0) * 1.0), a * TAU / 3.0 + PI)
			KitProps.k(t, "food", ["cake", "cup-tea", "pie", "mug"][h % 4], off.call(0, 0) + Vector3(0, 0.82, 0), 0.0, 1.0, false)
			KitProps.f(t, "pottedPlant", off.call(2.0, 1.6))
			t.spots.append({ "pos": off.call(0, 1.3), "kind": "bench", "yaw": PI })
		4:   # 바위 정원
			for i in 3: KitProps.n(t, ["rock_largeA", "rock_largeB", "stone_largeC", "rock_tallB"][(h + i) % 4], off.call(-1.4 + i * 1.4, rng.randf_range(-0.8, 0.8)), rng.randf() * TAU, rng.randf_range(1.0, 1.5))
			for i in 6: KitProps.n(t, ["grass_leafsLarge", "grass_large", "plant_flatTall"][i % 3], off.call(rng.randf_range(-2.2, 2.2), rng.randf_range(-2.2, 2.2)), rng.randf() * TAU, 2.4, false)
		5:   # 생울타리와 조각
			for s in [-1.0, 1.0]: KitProps.k(t, "fantasy", "hedge-large", off.call(s * 1.8, 0), yaw, 1.0)
			KitProps.n(t, ["statue_column", "statue_obelisk", "statue_head", "statue_ring"][h % 4], off.call(0, 0), 0.0, 1.6)
			for i in 4: KitProps.n(t, KitProps.FLOWERS[(h + i) % KitProps.FLOWERS.size()], off.call(-0.9 + i * 0.6, 1.4), 0.0, 1.8, false)
		6:   # 작은 노점과 궤짝
			KitProps.k(t, "fantasy", ["stall-green", "stall-red"][h % 2], off.call(0, -0.6), yaw)
			for i in 2: KitProps.k(t, "platformer", "crate", off.call(1.6, 0.6) + Vector3(0, i * 0.75, 0), rng.randf())
			KitProps.k(t, "market", "display-fruit", off.call(-1.6, 0.8), 0.0)
		7:   # 작은 분수
			KitProps.k(t, "fantasy", "fountain-round", off.call(0, 0), 0.0, 0.8)
			for s in [-1.0, 1.0]: KitProps.k(t, "holiday", "bench", off.call(s * 2.3, 0), yaw + s * PI / 2.0)
		8:   # 채소 이랑
			for r in 3:
				for hx in [-1.0, 1.0]: KitProps.n(t, "crops_dirtRow", off.call(hx, -1.4 + r * 1.4), yaw, 3.0, false)
				var kind: String = ["crop_carrot", "crop_turnip", "crop_pumpkin", "crops_leafsStageB"][(h + r) % 4]
				for c in 5: KitProps.n(t, kind, off.call(-2.0 + c, -1.4 + r * 1.4) + Vector3(0, 0.05, 0), rng.randf() * TAU, 1.1, false)
			KitProps.k(t, "survival", "bucket", off.call(2.4, 2.0), 0.0)
		9:   # 통·궤짝
			for i in 3: KitProps.k(t, "survival", ["barrel", "box-large", "chest"][i], off.call(-1.8 + i * 0.8, 1.8), rng.randf())
		10:   # 나무 둘과 피크닉 깔개
			t._tree(off.call(-1.6, -1.2), 0.95); t._tree(off.call(1.8, 1.0), 0.9)
			KitProps.f(t, "rugRectangle", off.call(0.2, 0.2), yaw, false)
			KitProps.k(t, "food", ["watermelon", "pie", "cake"][h % 3], off.call(0.2, 0.2) + Vector3(0, 0.03, 0), 0.0, 1.2, false)
			t.spots.append({ "pos": off.call(0.2, 0.2), "kind": "grass", "yaw": PI, "r": 1.1 })
		_:   # 꽃 무더기
			for i in 14: KitProps.n(t, KitProps.FLOWERS[(h + i) % KitProps.FLOWERS.size()], off.call(rng.randfn(0, 1.1), rng.randfn(0, 1.1)), 0.0, rng.randf_range(1.6, 2.4), false)
			for i in 3: KitProps.n(t, KitProps.BUSHES[(h + i) % KitProps.BUSHES.size()], off.call(rng.randfn(0, 1.4), rng.randfn(0, 1.4)), rng.randf() * TAU, 2.6)
