extends SceneTree
## Climb 점검(헤드리스): 입구로 들어가면 마을이 멈추나, 발판에서 → + 점프로 다음 발판에 닿나, 꼭대기에서 기록을 들고 돌아오나
func _init() -> void:
	var town: Node3D = (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 20: await physics_frame
	var gate: Dictionary = town.spots.filter(func(s): return s["kind"] == "gate")[0]
	print("GATE at ", gate["pos"], " h=", town.gen.height(gate["pos"].x, gate["pos"].z))
	town.enter_game("climb")
	for i in 10: await physics_frame
	var g: Node3D = town.game_node
	print("ENTER game=", g != null, " town_mode=", town.process_mode, " town_visible=", town.visible)
	var ok := 0
	for k in [5, 13, 20, 30]:
		var p: Dictionary = g.plats[k]
		g.body.global_position = (p["node"] as Node3D).global_position + Vector3(0, 0.4, 0); g.body.velocity = Vector3.ZERO
		for i in 20: await physics_frame
		var landed := false
		for dirn in ["move_right"]:   # → 만 — 예전엔 둘 다 시도해서 ← 가 오르막인 것을 못 잡았다(운영자 2026-10-01)
			g.body.global_position = (p["node"] as Node3D).global_position + Vector3(0, 0.4, 0); g.body.velocity = Vector3.ZERO
			for i in 10: await physics_frame
			Input.action_press(dirn); for i in 3: await physics_frame
			Input.action_press("jump")
			for i in 50: await physics_frame
			Input.action_release("jump"); Input.action_release(dirn)
			for i in 20: await physics_frame
			var nxt: Vector3 = (g.plats[k + 1]["node"] as Node3D).global_position
			if g.body.global_position.distance_to(nxt + Vector3(0, 0.15, 0)) < 1.3 and g.body.is_on_floor():
				landed = true; print("JUMP from ", k, " with ", dirn, " landed"); break
		if landed: ok += 1
		else: print("JUMP from ", k, " missed; at ", g.body.global_position, " next ", (g.plats[k + 1]["node"] as Node3D).global_position)
	# 꼭대기
	g.body.global_position = Vector3(0, 0.6 + g.N * g.RISE + 1.0, 0); g.body.velocity = Vector3.ZERO
	for i in 60: await physics_frame
	print("TOP done=", g.done_at > 0.0)
	for i in 200: await physics_frame
	print("BACK game_gone=", town.game_node == null, " records=", town.records, " town_mode=", town.process_mode, " visible=", town.visible)
	quit()
