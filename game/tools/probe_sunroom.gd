extends SceneTree
## 이야기방 점검(헤드리스, run 103): 주인이 정해지고 집이 그 사람 것인가, 14:48 에 주인은 안락의자(story)·아이들은 방석(crossleg)에 앉나,
## 사람이 빈 방석에 C 로 앉고 일어서면 자세가 풀리나, 16시가 지나면 모두 문으로 나오나
## godot --headless --path game -s res://tools/probe_sunroom.gd
func _init() -> void:
	var town: Node3D = (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 30: await physics_frame
	var sr: Dictionary = town.sunroom
	var sitter: Resident = null; var kids: Array = []
	for r: Resident in town.residents:
		if r.job == "storysitter": sitter = r
		if r.job == "child": kids.append(r)
	print("SITTER ", sitter.handle if sitter else "none", " home=sunroom ", sitter != null and is_same(sitter.home_door, sr["door"]), " social=%.2f energy=%.2f" % [sitter.mind.social, sitter.mind.energy] if sitter else "")
	town.clock = (14.8 - 6.0) / 24.0
	var front := (sr["door"]["pos"] as Vector3) + Vector3(0, 0.05, 2.5)
	for r: Resident in [sitter] + kids:
		r._leave(); r._release(); r.global_position = front + Vector3(randf_range(-1.0, 1.0), 0, randf_range(0.0, 1.0)); r.state = "routine"; r.busy_until = 0.0
	town.body.global_position = front + Vector3(3, 0, 0)
	for i in 1200:
		await physics_frame
	for r: Resident in [sitter] + kids:
		print("STORY ", r.handle, " job=", r.job, " state=", r.state, " spot=", r.spot.get("kind", ""), " pose=", r.fig.pose_request, " seated=", r.fig.seated, " at=", r.global_position.snapped(Vector3.ONE * 0.01), " carrying=", r.carrying_kind)
	# 사람: 빈 방석에 앉고 일어선다
	var free: Dictionary = {}
	for c: Dictionary in sr["cushions"]:
		var t: Array = c.get("taken", [])
		if t.is_empty() or t[0] == null: free = c; break
	if not free.is_empty():
		town.body.global_position = (free["pos"] as Vector3) + Vector3(0, 0, 0.5)
		town.cushion_use(free, Time.get_ticks_msec() / 1000.0)
		for i in 40: await physics_frame
		print("PLAYER sit pose=", town.player.pose_request, " seated=", town.player.seated, " pelvis_y=%.2f" % town.player.pelvis.position.y)
		town.seat = {}; town.player.seated = false
		for i in 40: await physics_frame
		print("PLAYER up pose='", town.player.pose_request, "' pelvis_y=%.2f" % town.player.pelvis.position.y)
	town.clock = (15.97 - 6.0) / 24.0
	for i in 1500: await physics_frame
	var dz: float = (sr["door"]["pos"] as Vector3).z
	for r: Resident in [sitter] + kids:
		print("AFTER ", r.handle, " state=", r.state, " spot=", r.spot.get("kind", ""), " pose=", r.fig.pose_request, " outside=", r.global_position.z > dz, " carrying=", r.carrying_kind)
	quit()
