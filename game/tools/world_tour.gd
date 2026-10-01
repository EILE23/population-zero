extends SceneTree
## 열린 세계 둘러보기(창 모드): 몇 곳으로 순간이동해 두 시점 화면을 user://shots/tour-*.png 로 — godot --path game -s res://tools/world_tour.gd
const STOPS := [["hub-edge-w", Vector3(-80, 0, -2)], ["north", Vector3(10, 0, -70)], ["forest", Vector3(-150, 0, 60)], ["lake", Vector3(-110, 0, -140)], ["high", Vector3(70, 0, -230)], ["road-far", Vector3(300, 0, 2)], ["hub", Vector3(0, 0, 4)]]
func _init() -> void:
	var town: Node3D = (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 20: await process_frame
	DirAccess.make_dir_recursive_absolute("user://shots")
	for st in STOPS:
		var p: Vector3 = st[1]
		p.y = town.gen.height(p.x, p.z) + 0.5
		town.body.global_position = p; town.body.velocity = Vector3.ZERO
		for v in [false, true]:
			town.view_25d = v
			for i in 90: await process_frame
			var img := root.get_texture().get_image()
			img.save_png("user://shots/tour-%s-%s.png" % [st[0], "25d" if v else "34"])
		print("TOUR ", st[0], " y=", town.body.global_position.y, " chunks=", town.gen.chunks.size(), " fps=", Engine.get_frames_per_second())
	quit()
