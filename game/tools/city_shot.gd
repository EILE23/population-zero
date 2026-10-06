extends SceneTree
## 도시 화면(창 모드) — 자리·줌별 user://shots/city-<이름>.png, 도시 칸 짓기 시간
func _init() -> void:
	var town: Node3D = (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 20: await process_frame
	var stops := [["down", Vector3(16, 0, -300), [1.0, 6.0, 20.0]], ["sub", Vector3(-250, 0, -470), [1.0, 10.0]], ["edge", Vector3(16, 0, -50), [14.0]]]
	for st in stops:
		town.body.global_position = st[1] + Vector3(0, 0.6, 0); town.body.velocity = Vector3.ZERO
		for z in st[2]:
			town.zoom_want = z; town.zoom = z
			for i in 260: await process_frame
			root.get_texture().get_image().save_png("user://shots/city-%s-%d.png" % [st[0], int(z)])
			print("CITY ", st[0], " zoom ", z, " chunks=", town.gen.chunks.size(), " fps=", Engine.get_frames_per_second(), " build_max_ms=", town.gen.build_us_max / 1000.0)
	quit()
