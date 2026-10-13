class_name RoadTiles
extends RefCounted
## 찻길 판(운영자 2026-10-13: "도로도 이런 느낌? 조금 현대화") — Kenney City Kit Roads(CC0, assets/models/kenney/roads) 1×1 판을 9m 로 늘려 깐다.
## 길 그물은 차선 주행(car_rail)과 같은 노드 격자: 노드 (i, j) = (OX + 40i, OZ + 20j). 노드 사이 토막: 동서 31m(판 넷 — 양 끝은 건널목), 남북 11m(판 하나).
## 노드 판은 이어진 팔 수로 고른다: 넷 = 사거리, 셋 = 삼거리, 둘(꺾임) = 모퉁이, 둘(곧음) = 곧은 판, 하나 = 막다른 길. 토막이 새로 깔리면 양 끝 노드 판을 다시 고른다

const DIR := "res://assets/models/kenney/roads/"
const W := TownPlan.ROAD_W
const LIFT := 0.03             # 옛 큰길 판(3.6m 자갈) 위로 — 겹치면 깜빡였다

static func npos(n: Vector2i) -> Vector3: return Vector3(TownPlan.OX + n.x * TownPlan.PITCH, 0, TownPlan.OZ + n.y * 20.0)

## 옛 마을(허브) 안 — 그 안의 큰길은 옛 판 그대로(가게·벤치가 길가에 붙어 있다)
static func in_hub(p: Vector3) -> bool: return absf(p.x) < WorldGen.HUB_X + 4.0 and absf(p.z) < WorldGen.HUB_Z + 4.0

static func seg_key(a: Vector2i, b: Vector2i) -> String:
	return "%d,%d|%d,%d" % ([a.x, a.y, b.x, b.y] if (a.x < b.x or (a.x == b.x and a.y < b.y)) else [b.x, b.y, a.x, a.y])

## 한 블록을 두르는 토막(북·가운데·남 동서 셋, 서·동 남북 넷) — 블록에 첫 필지가 설 때 다 깐다
static func block_segs(b: Vector2i) -> Array:
	var out: Array = []
	for dj in 3:
		if dj == 1 and TownPlan.no_lane(b): continue   # 안마당 블록은 가운데 찻길이 없다
		out.append([Vector2i(b.x, b.y * 2 + dj), Vector2i(b.x + 1, b.y * 2 + dj)])
	for di in 2:
		for dj in 2: out.append([Vector2i(b.x + di, b.y * 2 + dj), Vector2i(b.x + di, b.y * 2 + dj + 1)])
	return out

static var _toned := {}
static func _piece(t, file: String, at: Vector3, yaw: float, sc: Vector3, parent: Node3D) -> Node3D:
	var path := DIR + file + ".glb"
	if not _toned.has(file):   # 팩 빛깔이 하늘빛 회색이라 찻길이 하얗게 떴다 — 한 번만(재질은 판마다 같은 것) 어둡게
		_toned[file] = true
		for pt in KitProps.src(path).get("parts", []):
			var mesh: Mesh = pt[0]
			for si in mesh.get_surface_count():
				var mat := mesh.surface_get_material(si) as StandardMaterial3D
				if mat: mat.albedo_color = Color(0.64, 0.64, 0.68)
	var n := KitProps.mesh_node(path)
	n.position = at + Vector3(0, LIFT, 0); n.rotation.y = yaw; n.scale = sc
	parent.add_child(n)
	return n

## 토막 하나 — 노드 판 사이를 메운다. 반환: 깐 판들(합치기용)
static func seg(t, a: Vector2i, b: Vector2i, parent: Node3D) -> Array:
	var pa := npos(a); var pb := npos(b)
	var d := (pb - pa); var len := d.length() - W
	var dir := d.normalized()
	var yaw := 0.0 if absf(dir.x) > 0.5 else PI / 2.0
	var out: Array = []
	if absf(dir.x) > 0.5:
		var n := 4; var tl := len / n
		for k in n:
			var at := pa + dir * (W / 2.0 + tl * (k + 0.5))
			out.append(_piece(t, "road-crossing" if k == 0 or k == n - 1 else "road-straight", at, yaw, Vector3(tl, 1, W), parent))
	else:
		out.append(_piece(t, "road-straight", (pa + pb) / 2.0, yaw, Vector3(len, 1, W), parent))
	return out

## 노드 판 — arms: 이어진 쪽(서 W·동 E·북 N·남 S)
const BASE := {   # 판 이름 -> 기본 방향의 팔
	"road-crossroad": ["W", "E", "N", "S"], "road-intersection": ["W", "E", "S"], "road-bend-square": ["W", "S"], "road-straight": ["W", "E"], "road-end": ["E"],
}
const V := { "W": Vector2(-1, 0), "E": Vector2(1, 0), "N": Vector2(0, -1), "S": Vector2(0, 1) }

static func node(t, n: Vector2i, arms: Array, parent: Node3D) -> Node3D:
	if arms.is_empty(): return null
	var want := {}
	for a in arms: want[a] = true
	for file in BASE:
		var base: Array = BASE[file]
		if base.size() != arms.size(): continue
		for k in 4:
			var ang := k * PI / 2.0
			var ok := true
			for a in base:
				var v: Vector2 = V[a]
				var r := Vector2(v.x * cos(ang) + v.y * sin(ang), -v.x * sin(ang) + v.y * cos(ang))   # y 축 회전(ang)으로 돌린 팔
				var hit := ""
				for nm in V: if (V[nm] as Vector2).distance_to(r) < 0.1: hit = nm
				if not want.has(hit): ok = false; break
			if ok: return _piece(t, file, npos(n), ang, Vector3(W, 1, W), parent)
	return null
