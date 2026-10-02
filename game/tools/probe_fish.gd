extends SceneTree
## 부두 낚시 점검(헤드리스): 사람이 부두 끝에서 던지면 찌가 물에 닿나, 입질에 C 면 물고기가 손에 오나, 입질 전 C 는 빈 줄인가, 놓치면 다음 입질이 오나, 주민이 혼자 낚아 먹나
## godot --headless --path game -s res://tools/probe_fish.gd
func _init() -> void:
	var town: Node3D = (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 30: await physics_frame
	var sp: Dictionary = {}
	for s in town.spots:
		if s.has("fish"): sp = s
	print("SPOT ", sp.get("pos"))
	var b: Node3D = town.body
	for r in town.residents: if r.spot == sp: r._leave()
	sp["taken"] = []
	b.global_position = sp["pos"] + Vector3(0, 0.05, 0)
	for i in 60: await physics_frame   # 땅(구역)이 붙을 때까지
	var now := Time.get_ticks_msec() / 1000.0
	town.fish_use(sp, now)
	for i in 100: await physics_frame
	var e: Dictionary = town._fisher(town.player)
	print("CAST state=", e.get("state"), " pose=", town.player.pose_request, " bob=", (e["bob"] as Node3D).global_position, " to=", e["to"], " pelvis=", town.player.pelvis.position.y)
	# 입질 전 C — 빈 줄
	e["bite"] = 1e9
	town.fish_c(Time.get_ticks_msec() / 1000.0)
	for i in 70: await physics_frame
	print("EARLY C carrying=", town.player.carrying, " pose='", town.player.pose_request, "' fishers=", town.fishers.size())
	# 다시 던지고 입질에 C
	town.action_until = 0.0
	town.fish_use(sp, Time.get_ticks_msec() / 1000.0)
	for i in 100: await physics_frame
	e = town._fisher(town.player)
	e["bite"] = Time.get_ticks_msec() / 1000.0
	for i in 20: await physics_frame
	print("DIP state=", e["state"], " bob y=", (e["bob"] as Node3D).global_position.y)
	town.fish_c(Time.get_ticks_msec() / 1000.0)
	for i in 70: await physics_frame
	var held: Node3D = town.player.carrying
	print("CATCH carrying=", held.get_meta("kind", "") if held else "none", " fishers=", town.fishers.size(), " pose='", town.player.pose_request, "'")
	if held: town.player.release(town, Vector3.ZERO).queue_free()
	# 놓치기 — 창이 지나면 다음 입질
	town.action_until = 0.0
	town.fish_use(sp, Time.get_ticks_msec() / 1000.0)
	for i in 100: await physics_frame
	e = town._fisher(town.player)
	e["bite"] = Time.get_ticks_msec() / 1000.0
	for i in 100: await physics_frame
	print("MISS state=", e["state"], " next bite in ", snappedf(float(e["bite"]) - Time.get_ticks_msec() / 1000.0, 0.1))
	town.player.pose_request = ""   # 움직인 것과 같다 — 거둔다
	for i in 5: await physics_frame
	print("STOOD fishers=", town.fishers.size())
	# 주민 — 셋에 하나가 될 때까지 같은 자리에 데려다 놓는다
	b.global_position = sp["pos"] + Vector3(6, 0.05, 6)
	var w: Resident = town.residents[0]
	var tries := 0
	while town.fishers.is_empty() and tries < 40:
		tries += 1
		w._release(); w.spot = sp; w.slot = 0; w._claim(sp, 0)
		w.global_position = sp["pos"] + Vector3(0, 0.05, 0)
		if w.fig.carrying: w.fig.release(town, w.global_position).queue_free()
		w._arrive(Time.get_ticks_msec() / 1000.0)
		await physics_frame
	print("RESIDENT tries=", tries, " fishing=", not town.fishers.is_empty(), " pose=", w.fig.pose_request)
	if not town.fishers.is_empty():
		town.fishers[0]["bite"] = Time.get_ticks_msec() / 1000.0 + 2.0
		var seen := {}
		for i in 60 * 8:
			await physics_frame
			var k: String = w.fig.pose_request + "/" + String(w.carrying_kind)
			if not seen.has(k): seen[k] = true; print("  w ", k, " state=", w.state)
		print("RESIDENT done carrying=", w.fig.carrying, " fishers=", town.fishers.size())
	quit()
