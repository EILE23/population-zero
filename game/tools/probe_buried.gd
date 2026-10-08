extends SceneTree
## 묻힌 집 찾기(헤드리스) — 지은 집마다 둘레(문 앞·네 모서리) 땅 높이가 0 보다 높으면 묻힌 것
func _init() -> void:
	var town: Node3D = (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 30: await physics_frame
	var bad := 0; var n := 0
	for h in town.houses:
		var mn: Vector3 = h["min"]; var mx: Vector3 = h["max"]
		var pts := [Vector2(mn.x, mn.z), Vector2(mx.x, mn.z), Vector2(mn.x, mx.z), Vector2(mx.x, mx.z), Vector2((mn.x + mx.x) / 2.0, mx.z + 1.0)]
		var hi := 0.0
		for p in pts: hi = maxf(hi, town.gen.height(p.x, p.y))
		n += 1
		if hi > 0.15:
			bad += 1
			if bad <= 8: print("BURIED house at %s ground=%.2f (block %s order? flat_limit=%d)" % [str((mn + mx) / 2.0), hi, str(CityMap.block_of(Vector2((mn.x + mx.x) / 2.0, (mn.z + mx.z) / 2.0))), town.gen.flat_limit])
	print("HOUSES %d buried %d built=%d" % [n, bad, town.built])
	quit()
