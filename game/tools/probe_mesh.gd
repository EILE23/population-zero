extends SceneTree
## 이 점 위를 덮는 큰 메시(가로 8m 넘는 것) — 충돌 없는 판 찾기
func _init() -> void:
	var town: Node3D = (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 30: await physics_frame
	var at := Vector3(-30, 0.5, -80)
	town.body.global_position = at; town.gen.fill(at)
	for i in 10: await physics_frame
	var stack: Array = [town]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for ch in n.get_children(): stack.append(ch)
		if not (n is GeometryInstance3D) or not (n as Node3D).is_visible_in_tree(): continue
		var g := n as GeometryInstance3D
		var ab: AABB = g.global_transform * g.get_aabb()
		if ab.size.x < 8.0 and ab.size.z < 8.0: continue
		if at.x < ab.position.x or at.x > ab.end.x or at.z < ab.position.z or at.z > ab.end.z: continue
		if ab.end.y < 0.25 or ab.position.y > 3.0: continue
		print("MESH %s<%s<%s aabb=%s" % [n.name, n.get_parent().name, n.get_parent().get_parent().name, str(ab)])
	quit()
