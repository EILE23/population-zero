extends SceneTree
## 달래는 방석 점검(헤드리스, run 104): 이야기 시간에 문 가까이서 넘어졌다 일어난(쫓을 상대 없음) 어른이 방석에 와 crossleg 로 앉고 last_hurt 가 15초 밀리나,
## 10초 안에 일어나 나오나; 사람이 방금 일어난 채 방석에 앉으면 읽는 이가 story_calm 줄을 하고, 사람이 때리는 걸 본 아이가 끄덕이나(meta nod_at)
## godot --headless --path game -s res://tools/probe_calm.gd
func _init() -> void:
	var town: Node3D = (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 30: await physics_frame
	var sr: Dictionary = town.sunroom
	var sitter: Resident = null; var kids: Array = []; var adult: Resident = null
	for r: Resident in town.residents:
		if r.job == "storysitter": sitter = r
		elif r.job == "child": kids.append(r)
		elif adult == null and r.job == "" and r.uid % 6 != 0: adult = r
	if sitter == null or adult == null: print("CALM no sitter/adult"); quit(); return
	town.clock = (14.8 - 6.0) / 24.0
	var front := (sr["door"]["pos"] as Vector3) + Vector3(0, 0.05, 2.5)
	for r: Resident in [sitter] + kids:
		r._leave(); r._release(); r.global_position = front + Vector3(randf_range(-1.0, 1.0), 0, randf_range(0.0, 1.0)); r.state = "routine"; r.busy_until = 0.0
	town.body.global_position = front + Vector3(3, 0, 0)
	for i in 600: await physics_frame
	# 어른: 문 앞 4m 에서 넘어졌다 일어난다 — 일어서면 routine 이고 shaken_at 이 찍힌다(resident.gd getup)
	var now := Time.get_ticks_msec() / 1000.0
	adult._leave(); adult._release(); adult.global_position = front + Vector3(0, 0, 4.0); adult.quarry = null
	adult.mind.last_hurt = now; var hurt0: float = adult.mind.last_hurt
	adult.state = "down"; adult.down_until = now + 0.2; adult.fig.lying = true; adult.collision_layer = 0; adult.collision_mask = 1
	var sat := false; var sat_pose := ""; var sat_at := -1.0; var left_at := -1.0
	for i in 1500:
		await physics_frame
		var on: bool = adult.state == "busy" and adult.spot.get("kind", "") == "cushion"
		if not sat and on: sat = true; sat_pose = adult.fig.pose_request; sat_at = Time.get_ticks_msec() / 1000.0
		elif sat and left_at < 0.0 and not on: left_at = Time.get_ticks_msec() / 1000.0
	print("SHAKEN ", adult.handle, " shaken_at_set=", adult.shaken_at > 0.0 or sat, " sat=", sat, " pose=", sat_pose, " last_hurt_pushed=%.1f" % (hurt0 - adult.mind.last_hurt), " sat_for=%.1f" % (left_at - sat_at if left_at > 0.0 else -1.0), " now_state=", adult.state, " spot=", adult.spot.get("kind", ""), " outside=", adult.global_position.z > (sr["door"]["pos"] as Vector3).z)
	# 사람: 방금 일어난 채 빈 방석에 앉는다 — 읽는 이의 달래는 줄, 사람이 때리는 걸 본 아이의 끄덕
	for k: Resident in kids: k.mind.witnessed()
	var free: Dictionary = {}
	for c: Dictionary in sr["cushions"]:
		var t: Array = c.get("taken", [])
		if t.is_empty() or t[0] == null: free = c; break
	town.player_up_at = Time.get_ticks_msec() / 1000.0
	if free.is_empty(): print("PLAYER no free cushion"); quit(); return
	town.body.global_position = (free["pos"] as Vector3) + Vector3(0, 0, 0.5)
	town.cushion_use(free, Time.get_ticks_msec() / 1000.0)
	await physics_frame
	var calm: Array = sitter.mind.voice.get("story_calm", [])
	print("PLAYER pose=", town.player.pose_request, " sitter_in_chair=", town.storysitter_here() != null, " says='", sitter.say_label.text, "' calm=", sitter.say_label.text in calm)
	for k: Resident in kids:
		print("NOD ", k.handle, " on_cushion=", k.spot.get("kind", "") == "cushion", " nod_at=", k.fig.get_meta("nod_at", -1.0))
	quit()
