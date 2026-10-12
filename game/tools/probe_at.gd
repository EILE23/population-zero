extends SceneTree
## 이 자리 둘레(2.5m)에 있는 충돌체와 그 부모 사슬 — 차가 걸리는 것 찾기
func _init() -> void:
	var town: Node3D = (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 20: await physics_frame
	for at in [Vector3(17, 0.6, -14)]:
		var q := PhysicsShapeQueryParameters3D.new(); var sh := SphereShape3D.new(); sh.radius = 2.5; q.shape = sh; q.transform = Transform3D(Basis(), at); q.collision_mask = 7
		for h in town.get_world_3d().direct_space_state.intersect_shape(q, 16):
			var n: Node = h["collider"]; var chain := ""
			var m: Node = n
			for k in 4:
				if m == null: break
				chain += "%s(%s) < " % [m.name, m.get_class()]; m = m.get_parent()
			var gp: Variant = (n as Node3D).global_position if n is Node3D else null
			var shp := ""
			if n is CollisionObject3D:
				for o in (n as CollisionObject3D).get_shape_owners():
					var cs: Node = (n as CollisionObject3D).shape_owner_get_owner(o)
					if cs is Node3D and (cs as Node3D).global_position.distance_to(at) < 3.5: shp += str((cs as Node3D).global_position.snapped(Vector3.ONE * 0.1)) + ":" + str((cs as CollisionShape3D).shape.get_class() if cs is CollisionShape3D else "") + " "
			print("AT %s: %s pos=%s shapes=%s" % [str(at), chain, str(gp), shp.substr(0, 120)])
	var hs := ""
	for x in range(124, 136, 2):
		for z in [-1.0, 0.0, 1.0, 2.0, 3.0]: hs += "%d,%d:%.2f " % [x, z, town.gen.height(float(x), z)]
	print("H ", hs)
	quit()
