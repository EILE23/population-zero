extends SceneTree
## 2층집·방 물건(창 모드면 user://shots/storey-*.png): 계단으로 걸어 올라가 위층, 구멍으로 내려오기, 탁자 위 물건 들고 나오기
func _init() -> void:
	var town: Node3D = (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 30: await physics_frame
	var di := -1
	for i in town.doors.size():
		var dr: Dictionary = town.doors[i]
		if int(dr.get("storeys", 1)) == 2 and not dr.has("shop_id") and not dr.has("civic"): di = i; break
	print("STOREY door=%d of %d two-storey=%d" % [di, town.doors.size(), town.doors.filter(func(d): return int(d.get("storeys", 1)) == 2).size()])
	town._enter_room(di)
	for i in 30: await physics_frame
	var rm: Dictionary = town.inside
	var r: Rect2 = rm["stair"]; var o: Vector3 = rm["o"]
	var ground_items: int = town.items.filter(func(it): return (rm["node"] as Node3D).is_ancestor_of(it)).size()
	print("  ground beds=%d items=%d" % [(rm["spots"] as Array).filter(func(s): return s["kind"] == "bed").size(), ground_items])
	if DisplayServer.get_name() != "headless": root.get_texture().get_image().save_png("user://shots/storey-ground.png")
	# 계단 아래에서 위로 걷는다
	town.body.global_position = o + Vector3(r.position.x + r.size.x / 2.0, 0.05, r.position.y + r.size.y + 0.5); town.body.velocity = Vector3.ZERO
	Input.action_press("move_up"); for i in 160:
		await physics_frame
		if town.inside.get("upper", false): break
	Input.action_release("move_up")
	for i in 40: await physics_frame
	print("UP upper=%s y=%.2f beds=%d" % [town.inside.get("upper", false), town.body.global_position.y, (town.inside["spots"] as Array).filter(func(s): return s["kind"] == "bed").size()])
	if DisplayServer.get_name() != "headless": root.get_texture().get_image().save_png("user://shots/storey-upper.png")
	var kit: Dictionary = town.inside["kit"]
	print("  upper layout=%s shape=%s mirror=%s spots=%s stair=%s w=%.1f d=%.1f" % [kit["layout"]["name"], kit["shape"], kit["mirror"], str((town.inside["spots"] as Array).map(func(s): return s["kind"])), str(town.inside["stair"]), town.inside["w"], town.inside["d"]])
	print("  layout bedroom pieces=%s" % str((kit["layout"]["pieces"] as Array).filter(func(pc): return pc[0] in RoomKit.BEDROOM)))
	# 구멍으로
	var ur: Rect2 = town.inside["stair"]; var uo: Vector3 = town.inside["o"]
	await create_timer(1.0).timeout
	town.body.global_position = uo + Vector3(ur.position.x + ur.size.x / 2.0, 0.05, ur.position.y + ur.size.y / 2.0)
	for i in 40: await physics_frame
	print("DOWN upper=%s inside=%s" % [town.inside.get("upper", false), town.is_inside()])
	# 탁자 위 물건 집기 → 들고 나가기
	var mine: Array = town.items.filter(func(it): return (town.inside["node"] as Node3D).is_ancestor_of(it))
	if mine.is_empty(): print("ITEM none in room"); quit(); return
	while town.player.carrying: town.player.release(town, Vector3.ZERO).queue_free()
	var it: Node3D = mine[0]
	town.body.global_position = Vector3(it.global_position.x, 0.05, it.global_position.z + 0.65); for i in 10: await physics_frame
	print("  item %s at %s body %s reach=%.2f" % [it.get_meta("kind", ""), str(it.global_position), str(town.body.global_position), town._reach(town.body.global_position, it.global_position)])
	town.action_until = 0.0
	var kd := InputEventKey.new(); kd.keycode = KEY_C; kd.physical_keycode = KEY_C; kd.pressed = true; Input.parse_input_event(kd)
	for i in 2: await physics_frame
	print("  after press act_down_at=%.2f action_until=%.2f now=%.2f inside=%s carrying=%s" % [town.act_down_at, town.action_until, Time.get_ticks_msec() / 1000.0, town.is_inside(), town.player.carrying])
	var ku := InputEventKey.new(); ku.keycode = KEY_C; ku.physical_keycode = KEY_C; ku.pressed = false; Input.parse_input_event(ku)
	for i in 5: await physics_frame
	print("  after release act_down_at=%.2f action=%s" % [town.act_down_at, town.player.action])
	var took: String = town.player.carrying.get_meta("kind", "") if town.player.carrying else "-"
	town.body.global_position = town.inside["entry"]; await physics_frame
	Input.action_press("move_down"); for i in 60: await physics_frame
	Input.action_release("move_down"); for i in 30: await physics_frame
	print("ITEM took=%s out=%s holding=%s" % [took, not town.is_inside(), town.player.carrying.get_meta("kind", "") if town.player.carrying else "-"])
	quit()
