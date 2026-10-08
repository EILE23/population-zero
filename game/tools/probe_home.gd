extends SceneTree
## 집 안 버그 점검(헤드리스): 집에 들어간 주민이 방에 보이나, 방에서 꺼낸 물건을 들고 나오나
func _init() -> void:
	var town: Node3D = (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 30: await physics_frame
	# 1) 집이 있는 주민 하나를 제 집 침대(바깥 껍데기 집의 자리)로
	var r: Resident = null
	for x in town.residents:
		if not x.home_door.is_empty() and x.job == "": r = x; break
	var bed: Array = town.spots.filter(func(sp): return sp.has("door") and sp["door"] is Dictionary and sp["door"] == r.home_door and sp["kind"] == "bed")
	print("HOME resident=%s beds_in_shell=%d door_pos=%s" % [r.handle, bed.size(), str(r.home_door["pos"])])
	var h: Dictionary = {}
	for hh in town.houses: if hh["door"] == r.home_door: h = hh
	print("  house entry found=%s min=%s max=%s" % [not h.is_empty(), str(h.get("min")), str(h.get("max"))])
	var inside_pos: Vector3 = (h["min"] + h["max"]) * 0.5 if not h.is_empty() else r.home_door["pos"]
	inside_pos.y = 0.05
	r.global_position = inside_pos; r.state = "busy"; r.busy_until = 1e9; r.fig.seated = true
	var di: int = town.doors.find(r.home_door)
	town._enter_room(di)
	for i in 80: await physics_frame
	var px: Dictionary = town.inside.get("proxies", {})
	print("  in room=%s proxies=%d (resident at %s)" % [town.is_inside(), px.size(), str(r.global_position)])
	for e in px.values(): print("  proxy at %s visible=%s in_tree=%s want=%s" % [str((e["node"] as Node3D).global_position), (e["node"] as Node3D).is_visible_in_tree(), (e["node"] as Node3D).is_inside_tree(), e["want"]])
	if DisplayServer.get_name() != "headless":
		for i in 30: await process_frame
		root.get_texture().get_image().save_png("user://shots/home-proxy.png")
	# 2) 냉장고에서 꺼내 들고 나오기
	var fr: Array = (town.inside["spots"] as Array).filter(func(s): return s["kind"] in ["fridge", "search"])
	if fr.is_empty(): print("  no fridge/search in this layout")
	else:
		while town.player.carrying: town.player.release(town, Vector3.ZERO).queue_free()
		town.body.global_position = (fr[0]["pos"] as Vector3) * Vector3(1, 0, 1) + Vector3(0, 0.05, 0); await physics_frame
		town.action_until = 0.0; town.inner_use(Time.get_ticks_msec() / 1000.0)
		var k0: String = town.player.carrying.get_meta("kind", "") if town.player.carrying else "-"
		town.body.global_position = town.inside["entry"]; await physics_frame
		Input.action_press("move_down"); for i in 50: await physics_frame
		Input.action_release("move_down"); for i in 30: await physics_frame
		print("ITEM took=%s inside_after=%s holding_after=%s" % [k0, town.is_inside(), town.player.carrying.get_meta("kind", "") if town.player.carrying else "-"])
	quit()
