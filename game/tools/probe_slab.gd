extends SceneTree
## 지은 블록 안의 실제 땅(충돌 레이) 높이 — 함수(gen.height)가 아니라 지어진 칸을 잰다. 0.2m 넘게 솟은 곳(집이 묻혀 보이는 판)을 블록별로
func _init() -> void:
	var town: Node3D = (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 30: await physics_frame
	var blocks := {}
	for h in town.houses:
		var c: Vector3 = ((h["min"] as Vector3) + (h["max"] as Vector3)) / 2.0
		if absf(c.x) < 74.0 and absf(c.z) < 28.0: continue
		blocks[CityMap.block_of(Vector2(c.x, c.z))] = true
	var bad := 0
	for b in blocks:
		var bc: Vector3 = CityMap.block_center(b)
		town.body.global_position = bc + Vector3(0, 30, 0); town.gen.fill(bc)
		for i in 8: await physics_frame
		var hi := -9.0; var at := Vector3.ZERO; var fn := func(x: float, z: float) -> float: return town.gen.height(x, z)
		for gx in 9:
			for gz in 9:
				var p := Vector3(TownPlan.OX + b.x * 40.0 + 2.0 + gx * 4.5, 20.0, TownPlan.OZ + b.y * 40.0 + 2.0 + gz * 4.5)
				var q := PhysicsRayQueryParameters3D.create(p, p + Vector3(0, -40, 0), 1)
				var hit := town.get_world_3d().direct_space_state.intersect_ray(q)
				if hit.is_empty(): continue
				var col: Object = hit["collider"]
				if not (col is StaticBody3D and (col as Node).get_parent() and (col as Node).get_parent().get_parent() and (col as Node).get_parent().get_parent().name == "World"): continue   # 땅 칸만
				var y: float = (hit["position"] as Vector3).y
				if y > hi: hi = y; at = hit["position"]
		if hi > 0.2:
			bad += 1
			print("SLAB block %s ground %.2f at %s fn=%.2f" % [str(b), hi, str(at.snapped(Vector3.ONE * 0.1)), float(fn.call(at.x, at.z))])
	print("SLAB blocks=%d raised=%d built=%d flat_limit=%d" % [blocks.size(), bad, town.built, town.gen.flat_limit])
	quit()
