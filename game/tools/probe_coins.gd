extends SceneTree
## 동전 점검(헤드리스, run 107): 발 앞 동전에 C(stoop_near) → STOOP_IN 뒤 손에, STOOP_AWAY 뒤 주머니(coins 1, HUD 글자, 자세가 풀린다);
## 걷는 주민이 0.8m 안의 동전을 보면 멈춰 집고 finders 줄·coins 1; 넘어지면 셋 중 하나가 동전을 떨구나(drop_coin 30회); 사람은 빈 주머니면 안 떨군다;
## 창구: 동전이 있으면 하나 내고(till 1, 접시 하나 보임) 없으면 그냥 빵("On the house."); 주민도 제 주머니에서 낸다
## 2조각(run 110): 빈 주머니의 주민도 받고 no_coin 을 말한다; 접시 앞 C = palm 으로 집어 가고 주인이 "Those are mine."·stole 1; 8시엔 어른 주머니 +1; 17시엔 주인이 접시로 와 palm 으로 거둔다
## godot --headless --path game -s res://tools/probe_coins.gd
func _init() -> void:
	var town: Node3D = (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 30: await physics_frame
	town.weather = "clear"; town.weather_until = 1e12
	# 사람: 발 앞 0.5m 의 동전
	var b: Node3D = town.body
	b.global_position = Vector3(-3.0, 0.05, 14.0)
	for i in 5: await physics_frame
	var c: Node3D = town.make_item("coin", b.global_position + Vector3(0.5, 0, 0)); town.items.append(c)
	var ok: bool = town.stoop_near(Time.get_ticks_msec() / 1000.0)
	var in_hand := -1; var pocketed := -1; var pose_cleared := -1
	for i in 90:
		await physics_frame
		if in_hand < 0 and is_instance_valid(c) and c.get_parent() == town.player.hand_r: in_hand = i
		if pocketed < 0 and town.coins == 1: pocketed = i
		if pocketed >= 0 and pose_cleared < 0 and town.player.pose_request == "": pose_cleared = i
	var lbl: Label = town.get_node_or_null("UI/Coins") as Label
	print("PLAYER ok=", ok, " in_hand_frame=", in_hand, " pocketed_frame=", pocketed, " pose_cleared_frame=", pose_cleared, " coins=", town.coins, " hud='", lbl.text if lbl else "none", "' coin_left_on_ground=", town.coin_near(b.global_position, 2.0) != null)
	# 주민: 걷는 사람의 발 앞에 동전 — 멈춰 집고 주머니에, finders 줄
	var r: Resident = null
	for w in 600:
		for x: Resident in town.residents:
			if x.state == "walk" and x.pair == null and x.job != "child" and x.fig.pose_request == "" and not x.in_boat and x.global_position.distance_to(b.global_position) > 6.0 and absf(x.global_position.z - 2.0) > 3.0: r = x; break   # 큰길 띠의 동전은 일부러 두고 간다(_coins_tick) — 띠 밖의 주민으로
		if r != null: break
		await physics_frame
	if r == null: print("RESIDENT none walking"); quit(); return
	var c2: Node3D = town.make_item("coin", r.global_position + Vector3(0.3, 0, 0.3)); town.items.append(c2)
	var stooped := -1; var got := -1; var line := ""; var after := ""; var c0: int = r.coins
	for i in 150:
		await physics_frame
		if stooped < 0 and r.fig.pose_request == "stoop": stooped = i
		if got < 0 and r.coins == c0 + 1: got = i; line = r.say_label.text
		if got >= 0 and i == got + 60: after = r.state
	print("RESIDENT ", r.handle, " stoop_frame=", stooped, " got_frame=", got, " coins=", r.coins, " says='", line, "' finders=", line in r.mind.voice.get("finders", []), " state_after=", after, " pose='", r.fig.pose_request, "'")
	# 넘어지면: 30번 중 몇 번 동전이 튀나(주민 — 주머니가 비어도 하나); 사람은 빈 주머니면 없다
	r.coins = 0
	for k in 30: town.drop_coin(Vector3(20, 0.9, 14), Vector3(1, 0, 0), r)
	town.coins = 0; var fly0: int = town.flying.size()
	for k in 30: town.drop_coin(Vector3(-20, 0.9, 14), Vector3(1, 0, 0), "player")
	var fly1: int = town.flying.size()
	for i in 150: await physics_frame
	var drops := 0
	for it in town.items:
		if String(it.get_meta("kind", "")) == "coin" and it.global_position.x > 15.0: drops += 1
	print("DROP resident 30 knockdowns -> ", drops, " coins on the ground (expect ~9); player empty pocket -> +", fly1 - fly0, " (expect 0)")
	# 창구: 동전 하나로 빵을 사면 접시에 쌓이고, 빈 주머니면 그냥 받는다; 주민은 제 주머니에서
	var sp: Dictionary = town.spots.filter(func(s): return s["kind"] == "counter" and s.has("stock"))[0]
	sp["stock"] = 3; town._show_stock(sp)
	town._set_coins(1)
	b.global_position = sp["pos"]; town.player.rotation.y = PI
	while town.player.carrying: town.player.release(town, Vector3.ZERO).queue_free()
	town.action_until = 0.0
	town.counter_use(sp, Time.get_ticks_msec() / 1000.0)
	print("PAY coins=", town.coins, " till=", sp.get("till", 0), " shown=", (sp["till_shown"] as Array).map(func(d): return d.visible), " bread=", town.player.carrying != null, " stock=", sp["stock"])
	town.player.release(town, Vector3.ZERO).queue_free()
	town.counter_use(sp, Time.get_ticks_msec() / 1000.0)
	print("FREE coins=", town.coins, " till=", sp.get("till", 0), " bread=", town.player.carrying != null, " stock=", sp["stock"])
	r.coins = 2
	var took: bool = town.counter_take(sp, r)
	print("RESIDENT PAYS took=", took, " r_coins=", r.coins, " till=", sp["till"], " stock=", sp["stock"], " shown=", (sp["till_shown"] as Array).map(func(d): return d.visible))
	# 빈 주머니의 주민: 창구 도착 분기(resident.gd _arrive) — 그래도 빵, no_coin 한 줄
	r.coins = 0; sp["stock"] = 3; town._show_stock(sp)
	r._release(); r.spot = sp; r.slot = 0; r.state = "busy"; r.global_position = sp["pos"] + Vector3(0.3, 0, 0)
	while r.fig.carrying: r.fig.release(town, Vector3.ZERO).queue_free()
	r._arrive(Time.get_ticks_msec() / 1000.0)
	print("BROKE RESIDENT bread=", r.fig.carrying != null, " says='", r.say_label.text, "' no_coin=", r.say_label.text in r.mind.voice.get("no_coin", []), " stock=", sp["stock"], " till=", sp["till"])
	r.state = "routine"; r.busy_until = 0.0
	# 도둑: 접시 앞에서 C(stoop_near → palm) — 동전이 주머니로, 주인이 14m 안이면 한마디하고 기억한다
	var baker: Resident = null
	for x: Resident in town.residents:
		if x.job == "baker": baker = x; break
	if baker == null: print("THEFT no baker"); quit(); return
	baker.global_position = sp["pos"] + Vector3(2.0, 0, 1.0); baker.state = "routine"; baker.busy_until = Time.get_ticks_msec() / 1000.0 + 5.0; baker._release(); baker.spot = {}; baker.route = []
	town.coins = 0; town._set_coins(0)
	b.global_position = Vector3(town.till_pos(sp).x, sp["pos"].y, sp["pos"].z); town.player.pose_request = ""; town.use_until = -1.0; town.action_until = 0.0
	for i in 3: await physics_frame
	var till0: int = sp["till"]; var stole0: int = baker.mind.stole
	var ok2: bool = town.stoop_near(Time.get_ticks_msec() / 1000.0)
	var in_hand2 := -1; var got2 := -1; var said := ""
	for i in 70:
		await physics_frame
		if in_hand2 < 0 and town.player.hand_r.get_child_count() > 0 and String(town.player.hand_r.get_child(town.player.hand_r.get_child_count() - 1).get_meta("kind", "")) == "coin": in_hand2 = i
		if got2 < 0 and town.coins == 1: got2 = i; said = baker.say_label.text
	print("THEFT ok=", ok2, " pose_was_palm=", in_hand2 >= 0, " in_hand_frame=", in_hand2, " pocketed_frame=", got2, " coins=", town.coins, " till ", till0, "->", sp["till"], " shown=", (sp["till_shown"] as Array).map(func(d): return d.visible), " baker says='", said, "' till_mine=", said in baker.mind.voice.get("till_mine", []), " stole ", stole0, "->", baker.mind.stole, " status='", baker.mind.status(), "' pose='", town.player.pose_request, "'")
	# 아침 8시: 어른 주머니 +1, 아이는 그대로
	var before: Array = town.residents.map(func(x): return x.coins)
	town.clock = (8.0 - 6.0) / 24.0 - 0.0004   # 한 프레임에 0.00056시 — 열일곱 프레임쯤 뒤에 8시를 넘는다
	for i in 40: await physics_frame
	var up := 0; var kids_same := true
	for i in town.residents.size():
		var x: Resident = town.residents[i]
		if x.job == "child": kids_same = kids_same and x.coins == before[i]
		elif x.coins == before[i] + 1: up += 1
	print("MORNING adults +1: ", up, "/", town.residents.filter(func(x): return x.job != "child").size(), " children unchanged=", kids_same, " seeded(uid%3+1)=", town.residents.slice(0, 4).map(func(x): return [x.uid % 3 + 1, before[town.residents.find(x)]]))
	# 17시: 접시가 closing — 빵집 주인이 와서(resident_till _till_pick) palm 으로 다 거둔다
	town._set_coins(3)
	for k in 3: town.counter_use(sp, Time.get_ticks_msec() / 1000.0); town.player.release(town, Vector3.ZERO).queue_free(); town.action_until = 0.0
	b.global_position = Vector3(-3.0, 0.05, 14.0)
	sp["stock"] = 3; town._show_stock(sp)
	var till1: int = sp["till"]; var bc0: int = baker.coins
	town.clock = (17.0 - 6.0) / 24.0 - 0.0004
	for i in 40: await physics_frame
	while baker.fig.carrying: baker.fig.release(town, Vector3.ZERO).queue_free()   # 빵을 든 주인은 다 먹고 온다 — 여기선 비워 준다
	baker.carrying_kind = ""; baker.bites = 0
	baker.state = "routine"; baker.busy_until = 0.0; baker._release(); baker.spot = {}; baker.route = []
	var picked := -1; var arrived := -1; var emptied := -1; var closing_line := ""
	for i in 1500:
		await physics_frame
		if picked < 0 and baker.spot.get("kind", "") == "till": picked = i
		if arrived < 0 and baker.fig.pose_request == "palm": arrived = i; closing_line = baker.say_label.text
		if arrived >= 0 and emptied < 0 and int(sp["till"]) == 0 and not sp.has("closing"): emptied = i
		if emptied >= 0 and i > emptied + 60: break
	print("CLOSING closing_flag=", sp.get("closing", false), " till ", till1, "->", sp["till"], " picked_frame=", picked, " palm_frame=", arrived, " emptied_frame=", emptied, " baker_coins ", bc0, "->", baker.coins, " says='", closing_line, "' till_close=", closing_line in baker.mind.voice.get("till_close", []), " shown=", (sp["till_shown"] as Array).map(func(d): return d.visible), " baker_state=", baker.state, " pose='", baker.fig.pose_request, "'")
	quit()
