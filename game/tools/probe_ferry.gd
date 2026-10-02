extends SceneTree
## 남쪽 나루 점검(헤드리스, run 94): 건너편에 매인 배는 못 타나, 북쪽에서 타고 남쪽 부두에 대어 내리면 남쪽 둑에 서서 moor 하고 배가 거기 매이나,
## 주민이 나룻배 길(crossings 의 board/land)로 남→북을 헤엄 없이 건너 목적지에 닿나, 배가 떠난 뒤엔 다리·디딤돌로 다시 짜나
## godot --headless --path game -s res://tools/probe_ferry.gd
func _init() -> void:
	var town: Node3D = (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 30: await physics_frame
	var b: Node3D = town.body
	var north: Dictionary = {}; var south: Dictionary = {}
	for s in town.spots:
		if s["kind"] == "boat": (north if (s["pos"] as Vector3).z < town.RIVER_Z else south).merge(s)
	print("SPOTS north=", north.get("pos"), " south=", south.get("pos"), " docked=", town.docked_at(), " tied=", town.boat["tied"])
	for r in town.residents: if r.in_boat: town.unboard(r)
	# 남쪽 부두에서 C — 배는 북쪽에 있다
	b.global_position = south["pos"] + Vector3(0, 0.1, 0)
	for i in 30: await physics_frame
	town.boat_use(Time.get_ticks_msec() / 1000.0)
	print("SOUTH C with boat north: rowing=", town.rowing, " (want false)")
	# 북쪽에서 타고 남쪽 부두로 저어 가서 내린다
	b.global_position = north["pos"] + Vector3(0, 0.1, 0)
	for i in 30: await physics_frame
	town.boat_use(Time.get_ticks_msec() / 1000.0)
	print("NORTH C: rowing=", town.rowing, " tied=", town.boat["tied"])
	town.boat["x"] = town.SOUTH_X; town.boat["v"] = 0.0
	for i in 5: await physics_frame
	town.boat_leave(Time.get_ticks_msec() / 1000.0)
	for i in 10: await physics_frame
	print("LANDED pos=", b.global_position, " pose=", town.player.pose_request, " home=", town.boat["home"], " in_water=", town.in_water(b.global_position))
	for i in 100: await physics_frame
	print("MOORED tied=", town.boat["tied"], " rope=", (town.boat["rope"] as Node3D).visible, " pose='", town.player.pose_request, "' boat x=", snappedf(float(town.boat["x"]), 0.01))
	for i in 120: await physics_frame
	print("DRIFT boat x=", snappedf(float(town.boat["x"]), 0.01), " (want ~", town.SOUTH_X, ")")
	# 주민: 남쪽 언덕 발치에서 시장(북)으로 — 나룻배 길이 나올 때까지 다시 묻는다(열에 셋)
	b.global_position = Vector3(-20, 0.1, -2)
	var r: Node = null
	for x in town.residents:
		if x.state in ["routine", "walk", "busy"] and not x.fig.seated and x.riding_swing.is_empty() and x.riding_seesaw == null: r = x; break
	r._leave(); r.global_position = Vector3(20.0, 0.1, 14.6)
	for i in 10: await physics_frame
	var dest := Vector3(6, 0, 5)
	var route: Array = []
	for k in 60:
		route = town.crossings(r.global_position, dest)
		if route.size() > 0 and route.any(func(st: Dictionary) -> bool: return st["act"] == "board"): break
	print("ROUTE ", route.map(func(st: Dictionary) -> String: return "%s%s" % [str(Vector2((st["pos"] as Vector3).x, (st["pos"] as Vector3).z).snapped(Vector2(0.1, 0.1))), st["act"]]))
	r.spot = { "kind": "bank", "pos": dest, "yaw": 0.0 }; r.route = route + [{ "pos": dest, "act": "" }]; r.target = r.route[0]["pos"]; r.state = "walk"; r.busy_until = 1e9
	var swam := 0; var boarded := false; var moored := false
	for i in 2400:
		await physics_frame
		if r.fig.pose_request == "swim": swam += 1
		if r.in_boat: boarded = true
		if r.fig.pose_request == "moor": moored = true
		if r.state != "walk" and boarded: break
	print("RESIDENT boarded=", boarded, " moored=", moored, " swim frames=", swam, " pos=", r.global_position.snapped(Vector3(0.1, 0.1, 0.1)), " state=", r.state, " boat home=", town.boat["home"], " tied=", town.boat["tied"])
	# 배는 이제 북쪽 — 남쪽에서 나룻배 길을 타면 — 다리·디딤돌로 다시 짠다
	r._leave(); r.global_position = Vector3(19.0, 0.1, 14.2)
	for i in 10: await physics_frame
	r.spot = { "kind": "bank", "pos": dest, "yaw": 0.0 }
	r.route = [{ "pos": Vector3(town.SOUTH_X, 0, town.RIVER_S + 0.6), "act": "board" }, { "pos": Vector3(town.DOCK_X, 0, town.RIVER_N - 0.6), "act": "land" }, { "pos": dest, "act": "" }]
	r.target = r.route[0]["pos"]; r.state = "walk"
	for i in 120: await physics_frame
	print("REPLAN in_boat=", r.in_boat, " route=", r.route.map(func(st: Dictionary) -> String: return "%s%s" % [str(Vector2((st["pos"] as Vector3).x, (st["pos"] as Vector3).z).snapped(Vector2(0.1, 0.1))), st["act"]]))
	quit()
