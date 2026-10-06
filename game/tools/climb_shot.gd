extends SceneTree
## Climb 구간별 화면(창 모드) — user://shots/climb-<n>.png
func _init() -> void:
	var town: Node3D = (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 20: await process_frame
	town.enter_game("climb")
	for i in 10: await process_frame
	var g: Node3D = town.game_node
	for k in [4, 17, 29, 41]:
		g.body.global_position = (g.plats[k]["node"] as Node3D).global_position + Vector3(0, 0.4, 0); g.body.velocity = Vector3.ZERO
		for i in 70: await process_frame
		root.get_texture().get_image().save_png("user://shots/climb-%d.png" % k)
	quit()
