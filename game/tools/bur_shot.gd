extends SceneTree
## 지도대로 지은 마을(창 모드) — user://shots/city2-*.png, 가게·주인·주민 수와 연 가게 수
func _init() -> void:
	var t0 := Time.get_ticks_msec()
	var town: Node3D = (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 10: await process_frame
	print("LOAD %d ms built=%d shops=%d keepers=%d residents=%d districts=%d" % [Time.get_ticks_msec() - t0, town.built, town.shops.size(), town.residents.filter(func(r): return r.job == "shopkeep").size(), town.residents.size(), town.districts.size()])
	var shots := [["y1", Vector3(-44, 0.05, 30), 1.8], ["y2", Vector3(36, 0.05, -50), 1.8], ["y3", Vector3(-4, 0.05, -58), 1.8]]
	for s in shots:
		var p: Vector3 = s[1]
		p.y = town.gen.height(p.x, p.z) + 0.3
		town.body.global_position = p; town.body.velocity = Vector3.ZERO
		town.gen.fill(p)
		town.zoom_want = s[2]; town.zoom = s[2]
		for i in 150: await process_frame
		root.get_texture().get_image().save_png("user://shots/bur-%s.png" % s[0])
	town.body.global_position = Vector3(0, 0.05, -40)
	for i in 10: await process_frame
	print("OPEN shops=%d/%d fps=%d draws=%d" % [town.shops.filter(func(sh): return town.shop_open(sh)).size(), town.shops.size(), Engine.get_frames_per_second(), Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)])
	quit()
