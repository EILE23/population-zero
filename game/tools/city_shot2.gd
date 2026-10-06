extends SceneTree
## 지도대로 지은 마을(창 모드) — user://shots/city2-*.png, 가게·주인·주민 수와 연 가게 수
func _init() -> void:
	var t0 := Time.get_ticks_msec()
	var town: Node3D = (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 10: await process_frame
	print("LOAD %d ms built=%d shops=%d keepers=%d residents=%d districts=%d" % [Time.get_ticks_msec() - t0, town.built, town.shops.size(), town.residents.filter(func(r): return r.job == "shopkeep").size(), town.residents.size(), town.districts.size()])
	var shots := [["tower_road", Vector3(15.5, 0.05, -34), 1.6], ["high_street", Vector3(-4, 0.05, -40), 1.4], ["hall", Vector3(76, 0.05, -40), 1.8], ["above", Vector3(10, 0.05, -40), 6.0], ["south", Vector3(0, 0.05, 50), 3.0], ["park", Vector3(116, 0.05, 66), 2.0]]
	for s in shots:
		var p: Vector3 = s[1]
		town.body.global_position = p; town.body.velocity = Vector3.ZERO
		town.zoom_want = s[2]; town.zoom = s[2]
		for i in 150: await process_frame
		root.get_texture().get_image().save_png("user://shots/city2-%s.png" % s[0])
	town.body.global_position = Vector3(0, 0.05, -40)
	for i in 1800: await process_frame
	print("OPEN shops=%d/%d fps=%d draws=%d" % [town.shops.filter(func(sh): return town.shop_open(sh)).size(), town.shops.size(), Engine.get_frames_per_second(), Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)])
	quit()
