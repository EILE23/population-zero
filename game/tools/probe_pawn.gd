extends SceneTree
## 전당포 점검(헤드리스, run 116, money 3b): 부스가 섰나(spots "pawn"/"pawn_keep", 주인 job); 주인이 선반 뒤에 서면 셔터가 열리나; 빈 주머니에 배고픈 주민이 모자를 벗어(doff) 건네고(pass) 값(cap 4 → 2)을 받나;
## 값이 모이면 put ×3 으로 접시에 내고 모자를 되찾아 쓰나(don); 사람이 장작을 맡기고(sell 1) 되찾나(put ×2); 8시 경계에 재고가 되고 buy 값에 팔리나; 16시에 주인이 접시를 palm 으로 거두나
## godot --headless --path game -s res://tools/probe_pawn.gd
func _init() -> void:
	var town: Node3D = (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 30: await physics_frame
	town.weather = "clear"; town.weather_until = 1e12; town.clock = (10.5 - 6.0) / 24.0
	var pw: Dictionary = town.pawn
	if pw.is_empty(): print("PAWN none"); quit(); return
	var b: Resident = pw.get("broker")
	print("BOOTH at=", pw["at"], " broker=", b != null, " job=", b.job if b else "", " open0=", pw["open"], " (want true pawnbroker false)")
	# 주인이 자리에 선다 → 셔터
	_at(b, town, pw["keep"], "keep"); b._post_arrive(_now())
	for i in 40: await physics_frame
	print("OPEN open=", pw["open"], " shutter_x=", snappedf((pw["shutter"] as Node3D).rotation.x, 0.01), " inner=", b.global_position.distance_to(pw["inner"]) < 0.3, " line='", b.say_label.text, "' (want true -1.45 true)")
	# 손님 a: 빈 주머니·배고픔·모자 → 벗어 맡긴다
	var free: Array = town.residents.filter(func(x): return x.job == "" and x.state in ["routine", "walk", "busy"] and x.fig.carrying == null and not x.fig.seated and x.riding_swing.is_empty() and x.riding_seesaw == null and not x.in_boat and not x.has_umb and x.pair == null and not (x is ResidentKid))
	var a: Resident = free[0]
	for s in a.fig.worn.keys(): (a.fig.take_off(s) as Node3D).queue_free()
	a.fig.wear(town.make_wearable("cap", Vector3.ZERO, Color("ad7096")))
	a.coins = 0; a.mind.full = 0.2; a.global_position = (pw["spot"] as Dictionary)["pos"] + Vector3(2.0, 0.02, 2.0); a._release(); a.spot = {}; a.route = []; a.state = "routine"; a.busy_until = 0.0
	var pick: bool = a._pawn_pick(_now())
	print("PICK pick=", pick, " act=", a.get_meta("pawn_act", ""), " (want true hock)")
	_at(a, town, pw["spot"], "hock"); a._post_arrive(_now())
	var doff := -1; var pas := -1; var bpass := -1
	for i in 260:
		await physics_frame
		if doff < 0 and a.fig.pose_request == "doff": doff = i
		if pas < 0 and a.fig.pose_request == "pass": pas = i
		if bpass < 0 and b.fig.pose_request == "pass": bpass = i
		if a.coins > 0 and b.fig.pose_request == "": break
	var items: Array = pw["items"]
	print("HOCK doff=", doff, " pass=", pas, " broker_pass=", bpass, " a_coins=", a.coins, " hat_gone=", not a.fig.worn.has("hat"), " shelf=", items.size(), " pawned=", a.has_meta("pawned"), " line='", a.say_label.text, "' (want frames, 2, true, 1, true)")
	# a 가 값을 모아 되찾는다 — put ×3
	a.coins = 5; a._release(); a.spot = {}; a.route = []; a.state = "routine"; a.busy_until = 0.0
	var pick2 := false
	for i in 6: pick2 = pick2 or a._pawn_pick(_now())   # 둘에 하나 들른다 — 여섯 번이면 거의 늘
	print("PICK2 pick=", pick2, " act=", a.get_meta("pawn_act", ""), " cost=", town.pawn_cost(a.get_meta("pawned")), " (want true back 3)")
	_at(a, town, pw["spot"], "back"); a._post_arrive(_now())
	var put := -1; var don := -1
	for i in 400:
		await physics_frame
		if put < 0 and a.fig.pose_request == "put": put = i
		if don < 0 and a.fig.pose_request == "don": don = i
		if a.fig.worn.has("hat") and a.fig.pose_request == "": break
	var dish: Dictionary = pw["dish"]
	print("BACK put=", put, " don=", don, " a_coins=", a.coins, " hat=", a.fig.worn.has("hat"), " shelf=", items.size(), " dish=", dish["till"], " pawned=", a.has_meta("pawned"), " (want frames, 2, true, 0, 3, false)")
	# 사람: 장작(sell 1)을 맡기고 되찾는다
	a._release(); a.spot = {}; a.route = []; a.state = "routine"; a.global_position = Vector3(20, 0.02, 14)
	for i in 3: await physics_frame   # 옮긴 주민의 몸이 물리 서버에서 자리를 떠날 때까지(probe_jobs 와 같다) — 아니면 사람이 밀려난다
	var body: Node3D = town.body
	while town.player.carrying: town.player.release(town, Vector3.ZERO).queue_free()
	town.player.hold(town.make_item("log", Vector3.ZERO))
	body.global_position = (pw["spot"] as Dictionary)["pos"] + Vector3(0, 0.05, 0); body.velocity = Vector3.ZERO; town.player.pose_request = ""; town.use_until = -1.0; town.action_until = 0.0
	for i in 3: await physics_frame
	print("STAND dist=", snappedf(body.global_position.distance_to((pw["spot"] as Dictionary)["pos"]), 0.01), " seat=", town.seat.is_empty(), " held=", String(town.player.carrying.get_meta("kind", "")), " value=", town.pawn_value("log"), " open=", pw["open"])
	var c0: int = town.coins
	var ok: bool = town.pawn_use(_now())
	for i in 200:
		await physics_frame
		if town.coins > c0 and b.fig.pose_request == "": break
	print("PLAYER HOCK ok=", ok, " coins ", c0, "->", town.coins, " empty=", town.player.carrying == null, " shelf=", items.size(), " (want true +1 true 1)")
	town._set_coins(5); town.use_until = -1.0; town.action_until = 0.0
	var ok2: bool = town.pawn_use(_now())
	for i in 200:
		await physics_frame
		if town.player.carrying != null and town.player.pose_request == "": break
	print("PLAYER BACK ok=", ok2, " coins=", town.coins, " held=", String(town.player.carrying.get_meta("kind", "")) if town.player.carrying else "", " shelf=", items.size(), " dish=", dish["till"], " (want true 3 log 0 5)")
	# 8시 경계: 책(sell 1)을 맡기고 밤을 넘기면 재고 — buy 3 에 산다
	town.player.release(town, Vector3.ZERO).queue_free(); town.player.hold(town.make_item("book", Vector3.ZERO)); town.use_until = -1.0; town.action_until = 0.0
	town.pawn_use(_now())
	for i in 200:
		await physics_frame
		if town.player.carrying == null and b.fig.pose_request == "": break
	town.clock = (7.9 - 6.0) / 24.0; await physics_frame; await physics_frame
	town.clock = (8.1 - 6.0) / 24.0; await physics_frame; await physics_frame
	var e: Dictionary = items[0] if items.size() > 0 else {}
	print("STOCK stock=", e.get("stock", false), " by_none=", e.get("by", 1) == null, " cost=", town.pawn_cost(e) if not e.is_empty() else -1, " (want true true 3)")
	town.clock = (10.5 - 6.0) / 24.0; _at(b, town, pw["keep"], "keep"); b._post_arrive(_now())
	for i in 20: await physics_frame
	town._set_coins(4); town.use_until = -1.0; town.action_until = 0.0
	var ok3: bool = town.pawn_use(_now())
	for i in 300:
		await physics_frame
		if town.player.carrying != null and town.player.pose_request == "": break
	print("BUY ok=", ok3, " open=", pw["open"], " coins=", town.coins, " held=", String(town.player.carrying.get_meta("kind", "")) if town.player.carrying else "", " shelf=", items.size(), " dish=", dish["till"], " (want true true 1 book 0 8)")
	# 16시: 주인이 접시를 palm 으로 거둔다 → 셔터가 내려간다
	var bc: int = b.coins
	town.clock = (16.05 - 6.0) / 24.0
	var palm := -1
	for i in 600:
		await physics_frame
		if palm < 0 and b.fig.pose_request == "palm": palm = i
		if int(dish["till"]) == 0 and b.fig.pose_request == "": break
	print("CLOSE palm=", palm, " dish=", dish["till"], " b_coins ", bc, "->", b.coins, " open=", pw["open"], " (want frames, 0, +8, false)")
	quit()

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

## 주민을 자리에 세운다 — 닿은 것으로(_post_arrive 를 바로 부른다)
func _at(r: Resident, town: Node3D, sp: Dictionary, act: String) -> void:
	while r.fig.carrying: r.fig.release(town, Vector3.ZERO).queue_free()
	r.carrying_kind = ""; r._release(); r.route = []
	r.global_position = (sp["pos"] as Vector3) + Vector3(0, 0.02, 0)
	r.spot = sp; r.slot = 0; r._claim(sp, 0); r.state = "busy"; r.set_meta("pawn_act", act)
