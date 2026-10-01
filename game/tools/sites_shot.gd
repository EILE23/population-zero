extends SceneTree
## 장소·Climb 화면(창 모드) — user://shots/site-*.png
func _init() -> void:
	var town: Node3D = (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 20: await process_frame
	for s in WorldGen.SITES:
		var c: Vector3 = s["c"]
		town.body.global_position = c + Vector3(0, 0.05, 6.0); town.body.velocity = Vector3.ZERO
		for i in 120: await process_frame
		root.get_texture().get_image().save_png("user://shots/site-%s.png" % s["name"])
	town.enter_game("climb")
	for i in 10: await process_frame
	var g: Node3D = town.game_node
	g.body.global_position = (g.plats[9]["node"] as Node3D).global_position + Vector3(0, 0.4, 0)
	for i in 90: await process_frame
	root.get_texture().get_image().save_png("user://shots/site-climb-in.png")
	quit()
