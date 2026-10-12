extends SceneTree
## 판 찾기 — 블록 둘레 격자에서 위로부터 레이(모든 층), 0.2m 넘게 높은 것의 이름·부모·높이
func _init() -> void:
	var town: Node3D = (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 30: await physics_frame
	for c in [Vector3(36, 0, -84), Vector3(-44, 0, -84), Vector3(-4, 0, -84)]:
		town.body.global_position = c + Vector3(0, 40, 0); town.gen.fill(c)
		for i in 10: await physics_frame
		var seen := {}
		for gx in range(-12, 13, 2):
			for gz in range(-12, 13, 2):
				var p: Vector3 = c + Vector3(gx * 1.5, 30, gz * 1.5)
				var hit := town.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(p, p + Vector3(0, -40, 0), 0xFFFF, [town.body.get_rid()]))
				if hit.is_empty(): continue
				var y: float = (hit["position"] as Vector3).y
				if y < 0.2: continue
				var col: Node = hit["collider"]
				var key := "%s<%s<%s" % [col.name, col.get_parent().name, col.get_parent().get_parent().name if col.get_parent().get_parent() else "-"]
				if not seen.has(key): seen[key] = [y, p, town.gen.height(p.x, p.z)]
		for k in seen: print("COL2 %s %s y=%.2f at %s fn=%.2f" % [str(c), k, seen[k][0], str((seen[k][1] as Vector3).snapped(Vector3.ONE)), seen[k][2]])
	quit()
