extends SceneTree
## 마을 틱(town_systems._tick)의 각 시스템을 따로 재기 — 100번씩 불러 평균 µs
func _init() -> void:
	var town: Node3D = (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 60: await process_frame
	while not town._due.is_empty(): await process_frame
	for i in 120: await process_frame
	town.set_physics_process(false)
	var now := Time.get_ticks_msec() / 1000.0; var dt := 1.0 / 60.0
	var calls := [["_fly", [dt]], ["_cutaway", []], ["_daylight", [dt]], ["_stream", []], ["_weather", [dt]], ["_animals", [dt]], ["_swings", [dt]], ["_wind", [dt]], ["_crops", [now]], ["_bakery", [now]], ["_smoke", [now]], ["_boats", [dt, now]], ["_trades", [dt, now]], ["_water", [dt]], ["_seesaws", [dt]], ["_meal_tick", [now]], ["_woodcut", [now]], ["_fish", [now]], ["_story_tick", [now]], ["_coins_tick", [now]], ["_nap_tick", [now]], ["_busk_tick", [now]], ["_ledger_tick", [now]], ["_jobs_tick", [now]], ["_pawn_tick", [now]], ["_social_tick", [now, Vector3.ZERO]], ["_interact_check", [now]], ["_streets_tick", []], ["_refresh_sale", []], ["_growth_tick", []], ["_signal_tick", []], ["_hire_shopkeepers", []], ["_hud", [now]], ["_process", [dt]], ["_physics_process", [dt]], ["_inner_tick", [now, Vector3.ZERO]], ["_cabin_tick", [now]], ["_board_cam", [dt]], ["_cabin_cam", [dt]]]
	var out: Array = []
	for c in calls:
		if not town.has_method(c[0]): continue
		var t := Time.get_ticks_usec()
		for i in 10: town.callv(c[0], c[1])
		out.append([(Time.get_ticks_usec() - t) / 10.0, c[0]])
	out.sort(); out.reverse()
	for o in out.slice(0, 14): print("PT %7.0f us %s" % o)
	var tp := Time.get_ticks_usec()
	for i in 5:
		var a := Time.get_ticks_usec()
		var cc: Car3D = town.cars[i]
		var rr = CarRail.plan(null, cc, Vector3(randf_range(-300, 300), 0, -40))
		print("PT plan %.1f ms ok=%s" % [(Time.get_ticks_usec() - a) / 1000.0, str(rr != null)])
	var spikes: Array = []
	for i in 240:
		var a := Time.get_ticks_usec()
		await process_frame
		spikes.append((Time.get_ticks_usec() - a) / 1000.0)
	spikes.sort(); spikes.reverse()
	print("PT worst frames ", spikes.slice(0, 8), " median ", spikes[120])
	var t2 := Time.get_ticks_usec()
	for i in 30: await physics_frame
	town.set_physics_process(true)
	var t3 := Time.get_ticks_usec()
	for i in 60: await physics_frame
	print("PT frame with town physics %.1f ms vs without %.1f" % [(Time.get_ticks_usec() - t3) / 60000.0, (t3 - t2) / 30000.0])
	quit()
