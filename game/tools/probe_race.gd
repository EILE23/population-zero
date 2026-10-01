extends SceneTree
## Race 점검(헤드리스): 차고 입구로 들어가면 마을이 멈추나, 주민 둘이 트랙을 따라 바퀴를 도나(길 밖으로 안 새나), 내 차가 ↑ 로 달리나,
## 세 바퀴를 마치면 가장 빠른 바퀴를 들고 돌아와 표지판에 남나
func _init() -> void:
	var town: Node3D = (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 20: await physics_frame
	var gate: Dictionary = town.spots.filter(func(s): return s["kind"] == "gate" and s["game"] == "race")[0]
	print("GATE at ", gate["pos"], " h=", town.gen.height(gate["pos"].x, gate["pos"].z))
	town.enter_game("race")
	for i in 10: await physics_frame
	var g: Node3D = town.game_node
	print("ENTER game=", g != null, " town_mode=", town.process_mode, " rivals=", g.rivals.map(func(r): return r["handle"]))
	for i in 200: await physics_frame   # 출발 신호(3초)
	Input.action_press("move_up")
	var off := 0.0
	for i in 60 * 50:
		await physics_frame
		for r in g.racers.slice(1):
			var p: Vector3 = (r["car"] as Car3D).global_position; p.y = 0.0
			off = maxf(off, p.distance_to(g.pts[int(r["idx"])]))
	Input.action_release("move_up")
	for r in g.racers: print("RACER ", r["name"], " lap=", r["lap"], " idx=", r["idx"], " v=", snappedf((r["car"] as Car3D).v, 0.1))
	print("RIVAL max off-centre ", snappedf(off, 0.1), " m (road half ", g.HALF, ")")
	var me: Dictionary = g.racers[0]
	print("ME lap=", me["lap"], " best_lap=", snappedf(g.best_lap, 0.1))
	# 끝내기: 마지막 바퀴 끝 직전으로 옮겨 선을 넘긴다
	me["lap"] = g.LAPS; me["idx"] = g.N - 2
	if g.best_lap <= 0.0: g.best_lap = 42.0
	var car: Car3D = me["car"]
	car.global_position = g.pts[g.N - 2] + Vector3(0, 0.05, 0)
	car.rotation.y = atan2(-(g.pts[0] - g.pts[g.N - 2]).x, -(g.pts[0] - g.pts[g.N - 2]).z)
	Input.action_press("move_up")
	for i in 90: await physics_frame
	Input.action_release("move_up")
	print("DONE place=", g.place, " done_at>0=", g.done_at > 0.0)
	for i in 320: await physics_frame
	print("BACK game_gone=", town.game_node == null, " records=", town.records, " visible=", town.visible)
	quit()
