extends SceneTree
## 문 열고 들어가는 방(창 모드로 돌리면 user://shots/room-*.png): 가게 — 진열대에서 집고, 주인 앞 계산대에서 치르고, 나오기 / 집 — 앉기·눕기
func _walk(town: Node3D, act: String, frames: int) -> void:
	Input.action_press(act)
	for i in frames: await physics_frame
	Input.action_release(act)

func _go_in(town: Node3D, dr: Dictionary) -> void:
	town.set_door(dr, true)
	town.body.global_position = (dr["pos"] as Vector3) + Vector3(0, 0.05, 1.0); town.body.velocity = Vector3.ZERO
	for i in 20: await physics_frame
	await _walk(town, "move_up", 40)
	for i in 30: await physics_frame

func _shot(name: String) -> void:
	for i in 40: await process_frame
	if DisplayServer.get_name() != "headless": root.get_texture().get_image().save_png("user://shots/room-%s.png" % name)

func _init() -> void:
	var t0 := Time.get_ticks_usec()
	var town: Node3D = (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 30: await physics_frame
	var shop_i := -1; var house_i := -1
	for i in town.doors.size():
		if town.doors[i].has("shop_id") and shop_i < 0: shop_i = i
		if not town.doors[i].has("shop_id") and not town.doors[i].has("civic") and house_i < 0 and (town.doors[i]["pos"] as Vector3).z < -40.0: house_i = i
	var u0 := Time.get_ticks_usec(); town._room(house_i); print("ROOM build %d us (house)" % (Time.get_ticks_usec() - u0))
	# 가게: 주인을 계산대 뒤에 세운다(일과를 기다리지 않고)
	var sh: Dictionary = town.shops[int(town.doors[shop_i]["shop_id"])]
	var k: Node = town._keeper(sh)
	k.spot = sh["keeper"]; k.state = "busy"; k.busy_until = 1e9; k.global_position = sh["keeper"]["inner"]
	await _go_in(town, town.doors[shop_i])
	print("SHOP inside=%s kind=%s open=%s pos=%s" % [town.is_inside(), town.inside.get("kind", ""), town.shop_open(sh), str(town.body.global_position)])
	await _shot("shop")
	var shelf: Dictionary = (town.inside["spots"] as Array).filter(func(s): return s["kind"] == "shelf")[0]
	town.body.global_position = (shelf["pos"] as Vector3) + Vector3(0, 0.05, 0); await physics_frame
	town.coins = 20
	town.inner_use(Time.get_ticks_msec() / 1000.0)
	print("  took %s unpaid=%s" % [town.player.carrying.get_meta("kind", "") if town.player.carrying else "-", town.player.carrying.has_meta("unpaid") if town.player.carrying else false])
	var ct: Dictionary = (town.inside["spots"] as Array).filter(func(s): return s["kind"] == "counter")[0]
	town.body.global_position = (ct["pos"] as Vector3) + Vector3(0, 0.05, 0); await physics_frame
	town.action_until = 0.0; town.inner_use(Time.get_ticks_msec() / 1000.0)
	print("  paid: unpaid=%s coins=%d keeper_coins=%d" % [town.player.carrying.has_meta("unpaid") if town.player.carrying else "?", town.coins, k.coins])
	town.body.global_position = town.inside["entry"]; await physics_frame
	await _walk(town, "move_down", 50)
	for i in 30: await physics_frame
	print("  left: inside=%s holding=%s pos=%s" % [town.is_inside(), town.player.carrying.get_meta("kind", "") if town.player.carrying else "-", str(town.body.global_position)])
	while town.player.carrying: town.player.release(town, Vector3.ZERO).queue_free()
	# 집
	await _go_in(town, town.doors[house_i])
	print("HOUSE inside=%s spots=%s" % [town.is_inside(), str((town.inside.get("spots", []) as Array).map(func(s): return s["kind"]))])
	await _shot("house")
	var sit: Dictionary = (town.inside["spots"] as Array).filter(func(s): return s["kind"] == "sit")[0]
	town.body.global_position = (sit["pos"] as Vector3) * Vector3(1, 0, 1) + Vector3(0, 0.05, 0.3); await physics_frame
	town.action_until = 0.0; town.inner_use(Time.get_ticks_msec() / 1000.0)
	for i in 20: await physics_frame
	print("  sit seated=%s seat=%s" % [town.player.seated, not town.seat.is_empty()])
	await _walk(town, "move_down", 10)
	print("  stood seated=%s y=%.2f" % [town.player.seated, town.body.global_position.y])
	for i in 30: await physics_frame   # 일어나는 트윈(0.25초)이 끝나야 옮긴다
	var bed: Dictionary = (town.inside["spots"] as Array).filter(func(s): return s["kind"] == "bed")[0]
	town.body.global_position = (bed["pos"] as Vector3) + Vector3(0, 0, 0.9); await physics_frame
	town.action_until = 0.0
	print("  bed use=%s resting=%s pose=%s carrying=%s" % [town.inner_use(Time.get_ticks_msec() / 1000.0), town.resting, town.player.pose_request, town.player.carrying])
	for i in 20: await physics_frame
	print("  bed pose=%s y=%.2f" % [town.player.pose_request, town.body.global_position.y])
	await _shot("bed")
	print("TOTAL %d ms rooms=%d" % [(Time.get_ticks_usec() - t0) / 1000, town._rooms.size()])
	quit()
