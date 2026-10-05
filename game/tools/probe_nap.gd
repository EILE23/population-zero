extends SceneTree
## 낮잠방 점검(헤드리스, run 108 — "Elders and children" 6조각): 말뚝만 있는 공사장에서 시작하나, 8시를 넘길 때마다 기둥·지붕·벽이 한 단계씩 서나(문·집 등록),
## 13시에 주인이 흔들의자(rock)·아이들이 간이침대(rest)에 오나, 의자가 기우나, 사람이 문을 열면 아이 하나가 rub 로 깨나, 사람이 흔들의자에 앉으면 rock 이고 가까운 아이가 와서 눕나
## godot --headless --path game -s res://tools/probe_nap.gd
func _init() -> void:
	var save := ProjectSettings.globalize_path("user://town.json")
	if FileAccess.file_exists(save): DirAccess.remove_absolute(save)   # 단계 저장 — 점검은 늘 빈 땅에서
	var town: Node3D = (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 30: await physics_frame
	var nl: Dictionary = town.nap
	print("SITE stage=", nl.get("stage", -1), " at=", nl.get("at", Vector3.ZERO), " pile=", (nl["pile"] as Array).size(), " doors=", town.doors.size(), " houses=", town.houses.size(), " (want stage 0)")
	var doors0: int = town.doors.size(); var houses0: int = town.houses.size()
	for day in 3:
		town.clock = (7.995 - 6.0) / 24.0   # 한 시간이 30초 — 0.005시간은 9프레임 뒤에 8시를 넘는다
		for i in 60: await physics_frame
		print("MORNING ", day + 1, " stage=", nl["stage"], " sign='", (nl["sign"] as Label3D).text, "'")
	print("BUILT doors+", town.doors.size() - doors0, " houses+", town.houses.size() - houses0, " cots=", (nl["cots"] as Array).size(), " rocker=", not (nl["rocker"] as Dictionary).is_empty(), " saved=", FileAccess.file_exists(save), " (want 1 1 2 true true)")
	var sitter: Resident = null; var kids: Array = []
	for r: Resident in town.residents:
		if r.job == "storysitter": sitter = r
		if r.job == "child": kids.append(r)
	if sitter == null or kids.size() < 2: print("NAP no sitter/kids"); quit(); return
	town.weather = "clear"; town.clock = (13.05 - 6.0) / 24.0
	var front := (nl["door"]["pos"] as Vector3) + Vector3(0, 0.05, 3.0)
	for r: Resident in [sitter] + kids:
		r._leave(); r._release(); r.weather = "clear"; r.global_position = front + Vector3(randf_range(-1.0, 1.0), 0, randf_range(0.0, 1.0)); r.state = "routine"; r.busy_until = 0.0
	town.body.global_position = front + Vector3(4, 0, 0)
	var piv: Node3D = nl["chair"]; var tilt := 0.0
	for i in 900:
		await physics_frame
		tilt = maxf(tilt, absf(piv.rotation.x))
		if i % 90 == 0:
			for r: Resident in [sitter] + kids: print("   t=%.1f " % (i / 60.0), r.handle, " ", r.state, "/", r.spot.get("kind", ""), " at=", r.global_position.snapped(Vector3.ONE * 0.1), " tgt=", r.target.snapped(Vector3.ONE * 0.1), " route=", r.route.size(), " detours=", r.detours, " pose=", r.fig.pose_request)
	for r: Resident in [sitter] + kids:
		print("NAP ", r.handle, " job=", r.job, " state=", r.state, " spot=", r.spot.get("kind", ""), " pose=", r.fig.pose_request, " at=", r.global_position.snapped(Vector3.ONE * 0.01))
	print("CHAIR max tilt=%.3f (want ~0.12 while the sitter rocks)" % tilt)
	# 사람이 문을 연다 — 아이 하나가 rub 로 깬다
	var dr: Dictionary = nl["door"]
	town.body.global_position = (dr["pos"] as Vector3) + Vector3(0, 0.05, 0.9)
	town.set_door(dr, true)
	for i in 10: await physics_frame
	var woke := 0; var poses: Array = []
	for k: Resident in kids:
		poses.append(k.fig.pose_request)
		if k.fig.pose_request == "rub": woke += 1
	print("DOOR woke=", woke, " poses=", poses, " sitter says='", sitter.say_label.text, "' (want 1)")
	for i in 240: await physics_frame
	var outside := 0
	for k: Resident in kids:
		if k.global_position.z > (dr["pos"] as Vector3).z + 0.3: outside += 1
	print("AFTER rub: outside=", outside, " (want 1 — the woken child walked out), kid states=", kids.map(func(k): return k.state + "/" + k.spot.get("kind", "")))
	# 사람: 주인을 내보내고 흔들의자에 앉는다 — rock, 의자가 기운다, 깨어 나온 아이는 60초 동안 안 오지만 다른 아이가 아직 누워 있으면 그대로
	town.set_door(dr, false)
	sitter._leave(); sitter._release(); sitter.global_position = front + Vector3(3, 0, 0); sitter.state = "busy"; sitter.spot = { "kind": "greet" }; sitter.busy_until = Time.get_ticks_msec() / 1000.0 + 200.0
	await physics_frame
	town.clock = (15.2 - 6.0) / 24.0   # 낮잠 시간 밖 — 부르는 것만으로 와야 한다
	for k: Resident in kids:
		k._leave(); k._release(); k.nap_done = -999.0; k.global_position = front + Vector3(2 + 1.2 * kids.find(k), 0, 1); k.state = "busy"; k.spot = { "kind": "greet" }; k.busy_until = Time.get_ticks_msec() / 1000.0 + 200.0
	var rk: Dictionary = nl["rocker"]
	town.body.global_position = (rk["pos"] as Vector3) + Vector3(0.5, 0.05, 0)
	town.nap_use(rk, Time.get_ticks_msec() / 1000.0)
	for i in 30: await physics_frame
	print("PLAYER pose=", town.player.pose_request, " seated=", town.player.seated, " call=", (nl.get("call") as Node).handle if nl.get("call") != null else "none", " (want rock true <a child>)")
	var lay := false; var t_lay := -1.0
	for i in 600:
		await physics_frame
		if i % 60 == 0:
			print("   call=", (nl.get("call") as Node).handle if nl.get("call") != null else "none")
			for k: Resident in kids: print("   t=%.1f " % (i / 60.0), k.handle, " ", k.state, "/", k.spot.get("kind", ""), " at=", k.global_position.snapped(Vector3.ONE * 0.1), " tgt=", k.target.snapped(Vector3.ONE * 0.1), " route=", k.route.size(), " busy_until-now=%.1f" % (k.busy_until - Time.get_ticks_msec() / 1000.0), " with=", k._with(), " parent=", k.parent.state if k.parent else "none")
		for k: Resident in kids:
			if k.state == "busy" and k.spot.get("kind", "") == "cot": lay = true
		if lay: t_lay = i / 60.0; break
	print("CALLED child on cot=", lay, " after %.1fs" % t_lay, " chair tilt=%.3f" % absf(piv.rotation.x), " (want true, a few seconds)")
	town.seat = {}; town.player.seated = false
	for i in 5: await physics_frame
	print("PLAYER up pose='", town.player.pose_request, "' (want '')")
	if FileAccess.file_exists(save): DirAccess.remove_absolute(save)   # 다음 점검·CI 실행이 빈 땅에서 시작하게
	quit()
