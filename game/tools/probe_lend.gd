extends SceneTree
## 책 건네기 점검(헤드리스, run 106): 14:48 읽는 이가 안락의자에 앉으면 사람이 책을 들고 앞에서 건네나(story_new 줄, 받은 책이 손에, 아이들 keen_until),
## 16시가 지나면 그 책이 선반(stock 1)에 남나, 다음 날 10시대 주인이 선반에서 집어 들고 나가 책 상자에 꽂나(상자 재고 +1, 선반 0)
## godot --headless --path game -s res://tools/probe_lend.gd
func _init() -> void:
	var town: Node3D = (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 30: await physics_frame
	var sr: Dictionary = town.sunroom; var sh: Dictionary = sr["shelf"]
	var sitter: Resident = null; var kids: Array = []; var adult: Resident = null
	for r: Resident in town.residents:
		if r.job == "storysitter": sitter = r
		elif r.job == "child": kids.append(r)
		elif adult == null and r.job == "" and r.uid % 6 != 0: adult = r
	if sitter == null or adult == null: print("LEND no sitter/adult"); quit(); return
	town.weather = "clear"; town.weather_until = 1e12   # 비가 오면 모두 실내로 — 이 점검은 책의 길만 본다
	town.clock = (14.8 - 6.0) / 24.0
	var front := (sr["door"]["pos"] as Vector3) + Vector3(0, 0.05, 2.5)
	for r: Resident in [sitter] + kids:
		r._leave(); r._release(); r.global_position = front + Vector3(randf_range(-1.0, 1.0), 0, randf_range(0.0, 1.0)); r.state = "routine"; r.busy_until = 0.0
	town.body.global_position = front + Vector3(3, 0, 0)
	for i in 1200: await physics_frame
	# 주민 반쪽: 책을 든 어른이 문 앞 5m 에 — 읽는 이가 의자에 있으니 들어가 건네고 방석에 잠깐 앉는다
	adult._leave(); adult._release(); adult.global_position = front + Vector3(-1.0, 0, 2.5); adult.state = "routine"; adult.busy_until = 0.0
	adult.fig.hold(town.make_item("book", Vector3.ZERO)); adult.carrying_kind = "book"
	var lent_at := -1; var sat_at := -1
	for i in 900:
		await physics_frame
		if lent_at < 0 and sitter.fig.carrying != null and sitter.fig.carrying.has_meta("lent"): lent_at = i   # 어른의 손은 주머니 것이 올라올 수 있어 읽는 이의 책으로 본다
		if sat_at < 0 and adult.state == "busy" and adult.spot.get("kind", "") == "cushion": sat_at = i
	print("RESIDENT ", adult.handle, " lent_frame=", lent_at, " sat_frame=", sat_at, " sitter_lent=", sitter.fig.carrying != null and sitter.fig.carrying.has_meta("lent"), " shelf=", sh["stock"], " adult_now=", adult.state, "/", adult.spot.get("kind", ""))
	print("READER in_chair=", town.storysitter_here() != null, " pose=", sitter.fig.pose_request, " carrying=", sitter.carrying_kind)
	# 사람: 책을 들고 의자 앞(+x) 1m 에서 -x 를 보고 C
	var cp: Vector3 = sr["chair"]["pos"]
	town.body.global_position = cp + Vector3(0.9, 0.02, 0); town.player.rotation.y = -PI / 2.0
	town.player.hold(town.make_item("book", Vector3.ZERO))
	var ok: bool = town.sunroom_give(Time.get_ticks_msec() / 1000.0)
	await physics_frame
	var fresh: Array = sitter.mind.voice.get("story_new", [])
	print("GIVE ok=", ok, " player_hand=", town.player.carrying == null, " sitter_lent=", sitter.fig.carrying != null and sitter.fig.carrying.has_meta("lent"), " says='", sitter.say_label.text, "' new=", sitter.say_label.text in fresh, " newbook_at=%.1f" % float(sitter.fig.get_meta("newbook_at", -1.0)), " shelf=", sh["stock"])
	for k: Resident in kids: print("KEEN ", k.handle, " on_cushion=", k.spot.get("kind", "") == "cushion", " keen=", float(k.fig.get_meta("keen_until", -1.0)) > k.fig._t)
	town.clock = (15.97 - 6.0) / 24.0
	for i in 1500: await physics_frame
	print("CLOSED shelf=", sh["stock"], " sitter_carrying='", sitter.carrying_kind, "' sitter_state=", sitter.state)
	# 다음 날 10시 — 주인은 집 밖 문 앞에서 시작한다
	var box0: int = int(town.bookbox["stock"])
	sitter._leave(); sitter._release(); sitter.global_position = front; sitter.state = "routine"; sitter.busy_until = 0.0
	town.body.global_position = front + Vector3(6, 0, 3)
	town.clock = (10.05 - 6.0) / 24.0
	var took := -1; var at_box := -1
	for i in 3600:
		await physics_frame
		if took < 0 and sitter.carrying_kind == "book" and sitter.fig.carrying != null and sitter.fig.carrying.has_meta("lent"): took = i
		if at_box < 0 and sitter.state == "busy" and is_same(sitter.spot, town.bookbox): at_box = i
		if at_box >= 0 and i > at_box + 240: break
	print("RETURN took_frame=", took, " at_box_frame=", at_box, " shelf=", sh["stock"], " box=", box0, "->", town.bookbox["stock"], " sitter_carrying='", sitter.carrying_kind, "' hand_lent=", sitter.fig.carrying != null and sitter.fig.carrying.has_meta("lent"), " state=", sitter.state, " spot=", sitter.spot.get("kind", ""), " at=", sitter.global_position.snapped(Vector3.ONE * 0.1))
	quit()
