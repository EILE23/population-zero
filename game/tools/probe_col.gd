extends SceneTree
## 한 줄을 따라 위에서 레이 — 무엇에 맞는지·높이(묻혀 보이는 판 찾기)
func _init() -> void:
	var town: Node3D = (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 30: await physics_frame
	town.body.global_position = Vector3(-47, 1, 30); town.gen.fill(Vector3(-47, 0, 30))
	for i in 20: await physics_frame
	for z in range(14, 44, 2):
		var p := Vector3(-47, 30, float(z))
		var hit := town.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(p, p + Vector3(0, -40, 0), 1, [town.body.get_rid()]))
		var col: Variant = hit.get("collider")
		print("COL z=%d y=%.2f fn=%.2f %s<%s" % [z, (hit.get("position", Vector3.ZERO) as Vector3).y, town.gen.height(-47.0, float(z)), str(col.name) if col else "-", str(col.get_parent().name) if col else "-"])
	print("BODY y=%.2f" % town.body.global_position.y)
	quit()
