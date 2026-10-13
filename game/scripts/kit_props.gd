class_name KitProps
extends RefCounted
## 팩 소품 놓기(Kenney Furniture Kit · Nature Kit, CC0 — assets/models/kenney/{furniture,nature}) — 모델 원점이 모서리라 바닥 가운데로 옮겨 놓고,
## 키가 30cm 넘는 것엔 상자 충돌을 붙인다(운영자 2026-10-13: "플레이어가 가면 부딪히면 막혀야"). 같은 팩은 빛깔 그림 한 장이라 합치기(mesh_merge)로 몇 번에 그린다

const F := "res://assets/models/kenney/furniture/"
const N := "res://assets/models/kenney/nature/"
const SF := 2.2          # 가구 팩 → m(의자 0.47 → 1m, 탁자 0.33 → 0.73m)

static var _src := {}    # 경로 -> { parts: [[메시, 변환]], ab: AABB(배율 1) } — 모델 장면을 한 번만 펼쳐 두고, 놓을 땐 메시만 붙인다
## (장면을 놓을 때마다 instantiate 하면 판 하나에 6ms — 블록 찻길·소품 수천 개로 시작이 17초였다, 2026-10-13)
static func src(path: String) -> Dictionary:
	if _src.has(path): return _src[path]
	var ps: PackedScene = load(path)
	if ps == null: _src[path] = {}; return {}
	var n: Node3D = ps.instantiate()
	tone(path, n)
	var parts: Array = []; var ab := AABB(); var first := true
	for m in n.find_children("*", "MeshInstance3D", true, false):
		var xf := Transform3D(); var p: Node = m
		while p != n and p != null: xf = (p as Node3D).transform * xf; p = p.get_parent()
		parts.append([(m as MeshInstance3D).mesh, xf])
		var a: AABB = xf * (m as MeshInstance3D).get_aabb()
		ab = a if first else ab.merge(a); first = false
	n.free()
	_src[path] = { "parts": parts, "ab": ab }
	return _src[path]

## 모델 하나를 메시만으로 — 장면 대신(빠르다). 원점·회전·배율은 부르는 쪽이
static func mesh_node(path: String) -> Node3D:
	var d := src(path)
	var g := Node3D.new()
	for pt in d.get("parts", []):
		var mi := MeshInstance3D.new(); mi.mesh = pt[0]; mi.transform = pt[1]; g.add_child(mi)
	return g

## 팩 재질 손보기(한 경로에 한 번 — 재질은 그 모델의 모든 복제가 같이 쓴다): Nature Kit 은 금속 1 이라 하늘을 비춰 거무스름했고,
## 잎이 청록(70e6d6)이라 마을 풀빛과 따로 놀았다 → 금속 0, 청록·하늘빛 잎은 풀빛 쪽으로 돌린다
static var _toned := {}
static func tone(path: String, root: Node) -> void:
	if _toned.has(path): return
	_toned[path] = true
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (mi as MeshInstance3D).mesh
		if mesh == null: continue
		for si in mesh.get_surface_count():
			var mat := mesh.surface_get_material(si) as StandardMaterial3D
			if mat == null: continue
			mat.metallic = 0.0; mat.roughness = 1.0
			var c := mat.albedo_color
			var leafy := "/nature/" in path or "tree" in path.get_file() or "hedge" in path.get_file() or "grass" in path.get_file()   # 잎만 — 배·유리 같은 하늘빛은 그대로
			if leafy and c.h > 0.38 and c.h < 0.58 and c.s > 0.25: mat.albedo_color = Color.from_hsv(0.27 + (c.h - 0.38) * 0.2, minf(c.s * 1.1, 0.75), c.v * 0.8, c.a)

## 놓기 — at 은 바닥 가운데, yaw 는 y 회전, sc 배율. solid 면 키 0.3m 넘을 때 충돌 상자(가로세로 0.9배)
static func put(t, path: String, at: Vector3, yaw := 0.0, sc := 1.0, solid := true) -> Node3D:
	var d := src(path)
	if d.is_empty(): return null
	var m := mesh_node(path)
	var ab: AABB = d["ab"]
	var pivot := Node3D.new(); pivot.position = at; pivot.rotation.y = yaw
	m.scale = Vector3.ONE * sc
	m.position = Vector3(-(ab.position.x + ab.size.x / 2.0) * sc, -ab.position.y * sc, -(ab.position.z + ab.size.z / 2.0) * sc)
	pivot.add_child(m)
	var size := ab.size * sc
	if solid and size.y > 0.3:
		var sb := StaticBody3D.new(); var cs := CollisionShape3D.new(); var bs := BoxShape3D.new()
		bs.size = Vector3(maxf(size.x * 0.9, 0.2), size.y, maxf(size.z * 0.9, 0.2)); cs.shape = bs; cs.position.y = size.y / 2.0
		sb.add_child(cs); pivot.add_child(sb)
	t._add(pivot)
	return pivot

static func f(t, name: String, at: Vector3, yaw := 0.0, solid := true) -> Node3D: return put(t, F + name + ".glb", at, yaw, SF, solid)

## 팩마다 m 로 맞추는 배율(운영자 2026-10-13: "애셋들은 다양한 거 더 많이") — Kenney Survival·Fantasy Town·Retro Urban·Mini Market·Holiday·Food·Watercraft·Industrial·Platformer
const PACK := { "survival": 3.0, "fantasy": 2.4, "urban": 2.4, "market": 1.9, "holiday": 1.2, "food": 0.5, "watercraft": 0.55, "industrial": 2.0, "platformer": 1.5, "furniture": SF, "nature": 3.0, "roads": 9.0 }
static func k(t, pack: String, name: String, at: Vector3, yaw := 0.0, mul := 1.0, solid := true) -> Node3D:
	return put(t, "res://assets/models/kenney/%s/%s.glb" % [pack, name], at, yaw, float(PACK[pack]) * mul, solid)
static func n(t, name: String, at: Vector3, yaw := 0.0, sc := 3.0, solid := true) -> Node3D: return put(t, N + name + ".glb", at, yaw, sc, solid)

const FLOWERS := ["flower_redA", "flower_redB", "flower_yellowA", "flower_yellowB", "flower_purpleA", "flower_purpleB", "flower_redC", "flower_yellowC"]
const BUSHES := ["plant_bush", "plant_bushDetailed", "plant_bushSmall", "plant_bushLarge", "plant_bushTriangle"]

## 꽃·덤불 띠 — a 에서 b 까지 빽빽하게(덤불은 막는다, 꽃은 지나간다)
static func border(t, a: Vector3, b: Vector3, rng: RandomNumberGenerator, step := 0.55) -> void:
	var d := b - a; var n_ := maxi(1, int(d.length() / step))
	for k in n_ + 1:
		var p := a + d * (float(k) / n_) + Vector3(rng.randf_range(-0.12, 0.12), 0, rng.randf_range(-0.12, 0.12))
		if rng.randf() < 0.45: n(t, BUSHES[rng.randi() % BUSHES.size()], p, rng.randf() * TAU, rng.randf_range(2.4, 3.2))
		else: n(t, FLOWERS[rng.randi() % FLOWERS.size()], p, rng.randf() * TAU, rng.randf_range(1.6, 2.1), false)
