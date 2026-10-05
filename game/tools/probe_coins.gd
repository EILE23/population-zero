extends SceneTree
## 동전 점검(헤드리스, run 107): 발 앞 동전에 C(stoop_near) → STOOP_IN 뒤 손에, STOOP_AWAY 뒤 주머니(coins 1, HUD 글자, 자세가 풀린다);
## 걷는 주민이 0.8m 안의 동전을 보면 멈춰 집고 finders 줄·coins 1; 넘어지면 셋 중 하나가 동전을 떨구나(drop_coin 30회); 사람은 빈 주머니면 안 떨군다;
## 창구: 동전이 있으면 하나 내고(till 1, 접시 하나 보임) 없으면 그냥 빵("On the house."); 주민도 제 주머니에서 낸다
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
	var stooped := -1; var got := -1; var line := ""; var after := ""
	for i in 150:
		await physics_frame
		if stooped < 0 and r.fig.pose_request == "stoop": stooped = i
		if got < 0 and r.coins == 1: got = i; line = r.say_label.text
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
	quit()
