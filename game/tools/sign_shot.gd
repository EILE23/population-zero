extends SceneTree
## Climb 안내판(창 모드) — user://shots/sign-*.png
func _init() -> void:
	var town: Node3D = (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 20: await process_frame
	town._start_game("climb")
	for i in 120: await process_frame
	var g: Node3D = town.game_node
	var s: Dictionary = g.signs.signs[0]
	g.x = float(s["x"]) + 20.0; g.y = float(s["y"])
	for i in 40: await process_frame
	root.get_texture().get_image().save_png("user://shots/sign-near.png")
	print("SIGN near tag=%s signs=%d" % [(s["tag"] as Label3D).visible, g.signs.signs.size()])
	g.signs.tick(g.x, g.y, true)
	for i in 10: await process_frame
	root.get_texture().get_image().save_png("user://shots/sign-open.png")
	print("SIGN reading=%s" % g.signs.reading)
	quit()
