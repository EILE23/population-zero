extends SceneTree
## Climb(탑 안 세상) 화면(창 모드) — 층마다 user://shots/climb-<n>.png
func _init() -> void:
	var town: Node3D = (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 20: await process_frame
	town.enter_game("climb")
	for i in 120: await process_frame
	var g: Node3D = town.game_node
	for n in [3, 8, 31, 60]:
		var p: Dictionary = g.band(n)[1 if n % 5 != 0 else 0]
		g.x = p["x"] + p["w"] / 2.0; g.y = p["y"]; g.z = float(p.get("z", 0.0)); g.on = p; g.vy = 0.0
		if n == 60:   # 바위벽에 매달린 모습
			var wl: Dictionary = g._walls[60][0]; g.gear = "axe-shot"; g.on = {}; g.x = float(wl["x0"]) - 10.0; g.y = float(wl["y0"]) + 200.0; g.z = 0.0; g.hanging = wl; g.hang_side = 1.0
		for i in 80: await process_frame
		root.get_texture().get_image().save_png("user://shots/climb-%d.png" % n)
	quit()
