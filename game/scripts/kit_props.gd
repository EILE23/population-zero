class_name KitProps
extends RefCounted
## 팩 소품 놓기(Kenney Furniture Kit · Nature Kit, CC0 — assets/models/kenney/{furniture,nature}) — 모델 원점이 모서리라 바닥 가운데로 옮겨 놓고,
## 키가 30cm 넘는 것엔 상자 충돌을 붙인다(운영자 2026-10-13: "플레이어가 가면 부딪히면 막혀야"). 같은 팩은 빛깔 그림 한 장이라 합치기(mesh_merge)로 몇 번에 그린다

const F := "res://assets/models/kenney/furniture/"
const N := "res://assets/models/kenney/nature/"
const SF := 2.2          # 가구 팩 → m(의자 0.47 → 1m, 탁자 0.33 → 0.73m)

static var _box := {}    # 경로 -> AABB(배율 1)

static func _aabb_of(path: String, n: Node3D) -> AABB:
	if _box.has(path): return _box[path]
	var ab := AABB(); var first := true
	for m in n.find_children("*", "MeshInstance3D", true, false):
		var xf := Transform3D(); var p: Node = m
		while p != n and p != null: xf = (p as Node3D).transform * xf; p = p.get_parent()
		var a: AABB = xf * (m as MeshInstance3D).get_aabb()
		ab = a if first else ab.merge(a); first = false
	_box[path] = ab
	return ab

## 놓기 — at 은 바닥 가운데, yaw 는 y 회전, sc 배율. solid 면 키 0.3m 넘을 때 충돌 상자(가로세로 0.9배)
static func put(t, path: String, at: Vector3, yaw := 0.0, sc := 1.0, solid := true) -> Node3D:
	var ps: PackedScene = load(path)
	if ps == null: return null
	var m: Node3D = ps.instantiate()
	var ab := _aabb_of(path, m)
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
