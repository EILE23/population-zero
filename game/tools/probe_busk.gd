extends SceneTree
## 악사 점검(헤드리스, run 111): 악사가 뽑혔나(job busker, 가슴에 기타 meta); 12시에 상자로 가 올라서서 strum, busk_set 한 줄; 4m 안을 지나는 주민이 3초 wait 로 서고(heard 표),
## tip 표가 있으면 모자로 와 stoop 으로 한 닢(모자 till +1, 제 주머니 −1, 악사의 busk_thanks·nod_at); 사람이 동전 하나로 모자 앞에서 C → stoop, 주머니 0, 모자 +1; 빈 주머니로 C → 악사가 끄덕이고 한마디;
## 13:30 에 strum_end → 자세가 풀리고 악사가 모자로 와 stoop 으로 거둔다(till 0, 주머니 +n, 기타는 등으로); 같은 칸에 다시 올라서지 않는다(played);
## 악사가 없을 때 사람이 상자 앞에서 C → strum 과 상자 옆 기타가 숨고(가슴에 기타), 자세가 풀리면 돌아온다
## godot --headless --path game -s res://tools/probe_busk.gd
func _init() -> void:
	var town: Node3D = (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 30: await physics_frame
	town.weather = "clear"; town.weather_until = 1e12
	var bk: Dictionary = town.busk
	var bz: Resident = null
	for x: Resident in town.residents:
		if x.job == "busker": bz = x; break
	if bz == null: print("HIRE none"); quit(); return
	print("HIRE ", bz.handle, " social=", snappedf(bz.mind.social, 0.01), " guitar=", bz.fig.has_meta("guitar"), " stage=", bk["stage"]["pos"], " slot_now=", town.busk_slot())
	var at: Vector3 = bk["at"]
	# 12시 직전 — 악사를 가까이 두고 풀어 준다
	town.clock = (12.0 - 6.0) / 24.0 + 0.0002
	town.body.global_position = Vector3(-3.0, 0.05, 14.0)
	_free(bz, town, at + Vector3(3.0, 0, 2.0))
	var picked := -1; var strum := -1; var line := ""
	for i in 900:
		await physics_frame
		if picked < 0 and bz.spot.get("kind", "") == "stage": picked = i
		if strum < 0 and bz.fig.pose_request == "strum": strum = i; line = bz.say_label.text
		if strum >= 0 and i > strum + 20: break
	print("SET picked_frame=", picked, " strum_frame=", strum, " on=", bk["on"] == bz, " y=", snappedf(bz.global_position.y, 0.01), " says='", line, "' busk_set=", line in bz.mind.voice.get("busk_set", []), " played=", bk["played"], " end_in=", snappedf(float(bk["end"]) - Time.get_ticks_msec() / 1000.0, 0.1))
	if strum < 0: quit(); return
	# 지나는 주민: 4m 안에서 걷게 한다 — 3초 wait, heard 표; tip 표를 주고 모자로 보낸다
	var r: Resident = null
	for x: Resident in town.residents:
		if x != bz and x.job == "" and x.uid % 6 != 0 and x.state in ["routine", "walk", "busy"] and x.pair == null and not x.in_boat: r = x; break   # 일 없는 어른 — 빵집 주인은 화덕이 먼저라 팁이 늦다
	_free(r, town, at + Vector3(-2.5, 0, 2.5))
	r.route = [{ "pos": at + Vector3(6.0, 0, 2.5), "act": "" }]; r.target = r.route[0]["pos"]; r.state = "walk"
	r.mind.social = 0.9; r.coins = 2
	var waited := -1; var heard := -1
	for i in 120:
		await physics_frame
		if waited < 0 and r.fig.pose_request == "wait": waited = i
		if heard < 0 and int(r.get_meta("heard", -1)) == int(bk["n"]): heard = i
		if waited >= 0 and heard >= 0: break
	print("LISTEN wait_frame=", waited, " heard_frame=", heard, " state=", r.state, " tip_meta=", r.get_meta("tip", -1), " (social 0.9, coins 2 → tips two times in three)")
	r.set_meta("tip", int(bk["n"]))   # 표를 확실히 — 셋에 둘은 무작위다
	var hat: Dictionary = bk["hat"]; var till0: int = hat["till"]; var rc0: int = r.coins
	var to_hat := -1; var stooped := -1; var dropped := -1; var thanks := ""
	for i in 900:
		await physics_frame
		if to_hat < 0 and r.spot.get("kind", "") == "hat": to_hat = i
		if stooped < 0 and r.fig.pose_request == "stoop": stooped = i
		if dropped < 0 and int(hat["till"]) == till0 + 1: dropped = i; thanks = bz.say_label.text
		if dropped >= 0 and i > dropped + 40: break
	print("TIP to_hat_frame=", to_hat, " stoop_frame=", stooped, " dropped_frame=", dropped, " hat ", till0, "->", hat["till"], " r_coins ", rc0, "->", r.coins, " shown=", (hat["till_shown"] as Array).map(func(d): return d.visible), " busker says='", thanks, "' busk_thanks=", thanks in bz.mind.voice.get("busk_thanks", []), " nod=", bz.fig.has_meta("nod_at"), " r_state=", r.state, " r_pose='", r.fig.pose_request, "'")
	# 사람: 동전 하나로 모자 앞에서 C → stoop, 주머니 0, 모자 +1; 빈 주머니로 → 끄덕·한마디
	var b: Node3D = town.body
	b.global_position = (hat["pos"] as Vector3) + Vector3(0, 0.05, 0); town.player.pose_request = ""; town.use_until = -1.0; town.action_until = 0.0
	for i in 3: await physics_frame
	town._set_coins(1)
	var t1: int = hat["till"]
	var ok: bool = town.busk_tip(Time.get_ticks_msec() / 1000.0)
	var in_hand := -1; var paid := -1
	for i in 80:
		await physics_frame
		if in_hand < 0 and town.player.hand_r.get_child_count() > 0 and String(town.player.hand_r.get_child(town.player.hand_r.get_child_count() - 1).get_meta("kind", "")) == "coin": in_hand = i
		if paid < 0 and int(hat["till"]) == t1 + 1: paid = i
	print("PLAYER TIP ok=", ok, " pose_was_stoop=", in_hand >= 0, " in_hand_frame=", in_hand, " paid_frame=", paid, " coins=", town.coins, " hat ", t1, "->", hat["till"], " pose='", town.player.pose_request, "'")
	town.action_until = 0.0; bz.say_label.text = ""
	if bz.fig.has_meta("nod_at"): bz.fig.remove_meta("nod_at")
	var ok2: bool = town.busk_tip(Time.get_ticks_msec() / 1000.0)
	for i in 3: await physics_frame
	print("EMPTY POCKET ok=", ok2, " coins=", town.coins, " hat=", hat["till"], " nod=", bz.fig.has_meta("nod_at"), " says='", bz.say_label.text, "' busk_thanks=", bz.say_label.text in bz.mind.voice.get("busk_thanks", []))
	# 13:30 — 회수(strum_end) → 자세가 풀리고 → 악사가 모자로 와 stoop 으로 거둔다
	b.global_position = Vector3(-3.0, 0.05, 14.0); town.action_until = 0.0
	var bc0: int = bz.coins; var till2: int = hat["till"]
	town.clock = (13.5 - 6.0) / 24.0 - 0.0004
	var ending := -1; var cleared := -1; var collect := -1; var emptied := -1
	for i in 1500:
		await physics_frame
		if ending < 0 and bz.fig.has_meta("strum_end"): ending = i
		if ending >= 0 and cleared < 0 and bz.fig.pose_request != "strum": cleared = i
		if cleared >= 0 and collect < 0 and bz.spot.get("kind", "") == "hat" and bz.fig.pose_request == "stoop": collect = i
		if collect >= 0 and emptied < 0 and int(hat["till"]) == 0: emptied = i
		if emptied >= 0 and i > emptied + 60: break
	print("END end_frame=", ending, " cleared_frame=", cleared, " on_after=", bk["on"], " collect_frame=", collect, " emptied_frame=", emptied, " hat ", till2, "->", hat["till"], " busker_coins ", bc0, "->", bz.coins, " guitar_back=", (bz.fig.get_meta("guitar") as Node3D).position.is_equal_approx(BuskPoses.BACK))
	# 같은 칸엔 두 번 없다 — 12:30 으로 되돌려도 안 올라간다
	town.clock = (12.5 - 6.0) / 24.0
	_free(bz, town, at + Vector3(3.0, 0, 2.0))
	var again := false
	for i in 300:
		await physics_frame
		if bz.fig.pose_request == "strum": again = true; break
	print("COOLDOWN played=", bk["played"], " slot=", town.busk_slot(), " open=", town.busk_open(), " restarted=", again, " (expect false)")
	# 악사가 없을 때 사람이 상자 앞에서 C — strum, 상자 기타가 숨고, 자세가 풀리면 돌아온다
	town.clock = (10.0 - 6.0) / 24.0
	_free(bz, town, Vector3(20, 0, 14))
	b.global_position = at + Vector3(0, 0.05, 1.0); town.player.pose_request = ""; town.use_until = -1.0; town.action_until = 0.0
	while town.player.carrying: town.player.release(town, Vector3.ZERO).queue_free()
	for i in 3: await physics_frame
	var ok3: bool = town.busk_use(Time.get_ticks_msec() / 1000.0)
	for i in 10: await physics_frame
	print("PLAYER SET ok=", ok3, " pose='", town.player.pose_request, "' on=", bk["on"], " y=", snappedf(b.global_position.y, 0.01), " crate_guitar_hidden=", not (bk["guitar"] as Node3D).visible, " player_guitar=", town.player.has_meta("guitar"), " end_in=", snappedf(float(bk["end"]) - Time.get_ticks_msec() / 1000.0, 0.1))
	town.player.pose_request = ""   # 걸어 나간 것과 같다(town_player 가 움직이면 푼다)
	for i in 5: await physics_frame
	print("PLAYER OFF on=", bk["on"], " crate_guitar_visible=", (bk["guitar"] as Node3D).visible, " player_guitar=", town.player.has_meta("guitar"))
	quit()

## 주민을 풀어 가까이 둔다 — 일과를 다시 고르게
func _free(r: Resident, town: Node3D, at: Vector3) -> void:
	while r.fig.carrying: r.fig.release(town, Vector3.ZERO).queue_free()
	r.carrying_kind = ""; r.bites = 0
	r._release(); r.spot = {}; r.route = []; r.state = "routine"; r.busy_until = 0.0
	r.global_position = Vector3(at.x, 0.02, at.z)
