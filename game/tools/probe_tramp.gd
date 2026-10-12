extends SceneTree
## 트램펄린(헤드리스) — 판 위에 떨어뜨리면 튀어 오르나, 해먹(bed 자리)이 있나
func _init() -> void:
	var town: Node3D = (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 30: await physics_frame
	print("TRAMP count=%d hammocks=%d pools=%d" % [town.trampolines.size(), town.spots.filter(func(s): return s["kind"] == "bed" and not s.has("door")).size(), town.water.bodies.filter(func(b): return b["kind"] == "disc").size()])
	if town.trampolines.is_empty(): quit(); return
	var tp: Vector3 = town.trampolines[0]
	town.body.global_position = tp + Vector3(0, 1.5, 0); town.body.velocity = Vector3.ZERO
	var top := 0.0
	for i in 240:
		await physics_frame
		top = maxf(top, town.body.global_position.y)
	print("TRAMP at %s max_y=%.2f now_y=%.2f" % [str(tp), top, town.body.global_position.y])
	quit()
