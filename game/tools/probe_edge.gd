extends SceneTree
## 호숫가 직선 찾기 — 한 줄을 따라 깎기 정도·깎기 전·뒤 높이, 그 칸에 수면이 깔리나
func _init() -> void:
	var town: Node3D = (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 20: await physics_frame
	var g: WorldGen = town.gen
	for z in [50.0, 60.0, 70.0]:
		var row := ""
		for xi in range(-130, -70, 3):
			var x := float(xi)
			row += "%d:%.2f/%.1f/%.2f " % [xi, g.wild_k(x, z), g.raw(x, z), g.height(x, z)]
		print("E z=%d %s" % [int(z), row])
	print("E flat_limit=%d civic=%.1f" % [g.flat_limit, WorldGen._civic_dist(-100, 60)])
	quit()
