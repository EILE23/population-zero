extends SceneTree
func _init() -> void:
	var t0 := Time.get_ticks_msec()
	var town: Node3D = (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	print("WAIT ready %d ms" % (Time.get_ticks_msec() - t0))
	for i in 200: await physics_frame
	quit()
