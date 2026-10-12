extends SceneTree
## 차선 주행을 눈으로(창 모드) — 달리는 차 하나를 따라가며 user://shots/rail-*.png 세 장, fps
func _init() -> void:
	var town: Node3D = (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 30: await process_frame
	town.clock = 0.45
	for e in town.commuters: e["until"] = 0.0
	for i in 60 * 25: await process_frame
	var pick: Car3D = null
	for c in town.cars:
		if c.rail != null and not c.rail.done and c.v > 3.0 and absf(c.global_position.z - 2.0) > 15.0: pick = c; break
	if pick == null:
		for c in town.cars:
			if c.rail != null and not c.rail.done: pick = c; break
	for k in 4:
		if pick:
			var p := pick.global_position + Vector3(0, 0, 4)
			town.body.global_position = Vector3(p.x, town.gen.height(p.x, p.z) + 0.3, p.z); town.body.velocity = Vector3.ZERO
			town.gen.fill(town.body.global_position)
		town.zoom_want = 4.5; town.zoom = 4.5
		for i in (60 if k == 0 else 12): await process_frame
		root.get_texture().get_image().save_png("user://shots/rail-%d.png" % k)
		print("SHOT %d car=%s v=%.1f fps=%d" % [k, str(pick.global_position.snapped(Vector3.ONE)) if pick else "-", pick.v if pick else 0.0, Engine.get_frames_per_second()])
	quit()
