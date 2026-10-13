extends SceneTree
## 솟은 판 옆 집 — 블록 (0,-3)(-2,-3)(-1,-3) 의 집마다 가운데·둘레 땅 높이, 블록 순번, 그 집이 어디서 왔나(필지·문)
func _init() -> void:
	var town: Node3D = (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 30: await physics_frame
	for h in town.houses:
		var c: Vector3 = ((h["min"] as Vector3) + (h["max"] as Vector3)) / 2.0
		var b := CityMap.block_of(Vector2(c.x, c.z))
		if not (b in [Vector2i(0, -3), Vector2i(-2, -3), Vector2i(-1, -3)]): continue
		var ring := ""
		for d in [Vector3(-8, 0, 0), Vector3(8, 0, 0), Vector3(0, 0, -8), Vector3(0, 0, 8), Vector3(0, 0, 14)]:
			ring += "%.1f " % town.gen.height(c.x + d.x, c.z + d.z)
		var lot := -1
		for l in TownPlan.lots():
			if (l["c"] as Vector2).distance_to(Vector2(c.x, c.z)) < 2.5: lot = int(l["order"]); break
		print("H %s block %s order %d lot %d ring %s wild %.2f" % [str(c.snapped(Vector3.ONE * 0.1)), str(b), TownPlan.block_order(b), lot, ring, town.gen.wild_k(c.x, c.z)])
	print("built=%d flat_limit=%d" % [town.built, town.gen.flat_limit])
	quit()
