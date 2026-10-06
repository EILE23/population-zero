extends SceneTree
## Climb(탑 안 세상) 화면(창 모드) — 층마다 user://shots/climb-<n>.png
func _init() -> void:
	var town: Node3D = (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 20: await process_frame
	town.enter_game("climb")
	for i in 120: await process_frame
	var g: Node3D = town.game_node
	for n in [0, 5, 8, 31]:
		var p: Dictionary = g.band(n)[1 if n % 5 != 0 else 0]
		g.x = p["x"] + p["w"] / 2.0; g.y = p["y"]; g.on = p; g.vy = 0.0
		for i in 80: await process_frame
		root.get_texture().get_image().save_png("user://shots/climb-%d.png" % n)
	quit()
