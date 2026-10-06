extends SceneTree
## 심부름판 점검(헤드리스, run 115, money 3): 판이 섰나(spots "jobs", 카드 0, 게시판에서 3m); 주민이 pin 으로 카드를 꽂나(동전 −1, 카드 1, posted); 둘째 주민이 scan → pin 으로 떼나(taker, meta card, 판의 노드 삭제);
## 곁에서 더미가 둘 늘면 품삯(+1, job_done, 카드 없음); 사람이 빈손 C 로 떼나(종이 meta job); 화덕에서 반죽해 창구가 하나 늘면 빵 품삯 1 + 카드의 동전 1; 쓴 이가 17시에 떼면 동전이 돌아오나; 외상 여섯·빈 주머니면 창구가 거절하나
## godot --headless --path game -s res://tools/probe_jobs.gd
func _init() -> void:
	var town: Node3D = (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 30: await physics_frame
	town.weather = "clear"; town.weather_until = 1e12; town.clock = (10.0 - 6.0) / 24.0
	var jb: Dictionary = town.jobs
	if jb.is_empty(): print("JOBS none"); quit(); return
	var cards: Array = jb["cards"]
	print("BOARD pos=", jb["pos"], " cards=", cards.size(), " notice_dist=", snappedf((jb["at"] as Vector3).distance_to(town.notice["at"]), 0.1), " (want 0, 3.0)")
	var wc: Dictionary = town.woodcut
	while (wc["stack"] as Array).size() > 0: (town.pile_take() as Node3D).queue_free()   # 더미를 비운다 → "logs" 가 모자란 것
	var free: Array = town.residents.filter(func(x): return x.job == "" and x.state in ["routine", "walk", "busy"] and x.fig.carrying == null and not x.fig.seated and x.riding_swing.is_empty() and x.riding_seesaw == null and not x.in_boat and not x.has_umb and x.pair == null and not (x is ResidentKid))
	var a: Resident = free[0]; var b: Resident = free[1]
	# a 가 꽂는다
	_at(a, town, jb, "post"); a.coins = 2
	print("WANT a=", town.job_wanted(a), " (want logs)")
	a._post_arrive(Time.get_ticks_msec() / 1000.0)
	await create_timer(1.2).timeout
	print("POST cards=", cards.size(), " a_coins=", a.coins, " posted=", a.has_meta("posted"), " node=", (cards[0]["node"] != null) if cards.size() > 0 else false, " line='", a.say_label.text, "' (want 1, 1, true, true)")
	# b 가 뗀다 — 읽고(scan) 떼고(pin)
	_at(b, town, jb, "take"); b.coins = 0
	b._post_arrive(Time.get_ticks_msec() / 1000.0)
	var scan := -1; var pin := -1
	for i in 260:
		await physics_frame
		if scan < 0 and b.fig.pose_request == "scan": scan = i
		if pin < 0 and b.fig.pose_request == "pin": pin = i
		if b.has_meta("card") and b.fig.pose_request == "": break
	print("TAKE scan=", scan, " pin=", pin, " taker_is_b=", cards.size() > 0 and is_same(cards[0]["taker"], b), " meta=", b.has_meta("card"), " node_gone=", cards.size() > 0 and cards[0]["node"] == null, " line='", b.say_label.text, "'")
	# b 가 더미 곁에서 장작 둘을 쌓는다 → 품삯
	var pile: Dictionary = wc["pile"]
	b._release(); b.spot = {}; b.route = []; b.state = "busy"; b.busy_until = 1e9; b.global_position = (pile["pos"] as Vector3) + Vector3(0, 0.02, 0.3)
	town.pile_put(); await physics_frame; await physics_frame
	print("ONE done=", cards[0]["done"] if cards.size() > 0 else -1, " (want 1)")
	town.pile_put(); await physics_frame; await physics_frame
	print("PAID cards=", cards.size(), " b_coins=", b.coins, " meta=", b.has_meta("card"), " line='", b.say_label.text, "' (want 0, 1, false)")
	b.busy_until = 0.0
	# 사람: a 가 반죽 카드를 꽂고 사람이 뗀다 → 화덕에서 반죽 → 창구 +1 → 빵 품삯 1 + 카드 1
	var bc: Dictionary = town.oven["counter"]
	town.pile_put()   # 더미 셋 — 장작은 더는 모자라지 않다
	bc["stock"] = 0; town._show_stock(bc); a.mind.full = 0.2; a.set_meta("posted", -1e9); a.coins = 2
	_at(a, town, jb, "post")
	print("WANT2 a=", town.job_wanted(a), " (want knead)")
	a._post_arrive(Time.get_ticks_msec() / 1000.0)
	await create_timer(1.2).timeout
	a._release(); a.spot = {}; a.route = []; a.state = "routine"; a.busy_until = 0.0; a.global_position = Vector3(20, 0.02, 14)
	var body: Node3D = town.body
	while town.player.carrying: town.player.release(town, Vector3.ZERO).queue_free()
	for r: Resident in town.residents:   # 판 앞에 섰거나 판으로 오는 주민(카드를 떼러 오는 이)과 몸이 겹치면 사람이 밀려난다 — 비켜 세운다
		if r.global_position.distance_to(jb["pos"]) < 1.5 or is_same(r.spot, jb): r._release(); r.spot = {}; r.route = []; r.state = "routine"; r.global_position = Vector3(20, 0.02, 16)
	for i in 3: await physics_frame   # 옮긴 주민의 몸이 물리 서버에서 판 앞을 떠날 때까지
	body.global_position = (jb["pos"] as Vector3) + Vector3(0, 0.05, 0); body.velocity = Vector3.ZERO; town.player.pose_request = ""; town.use_until = -1.0; town.action_until = 0.0
	for i in 3: await physics_frame
	var ok: bool = town.jobs_use(Time.get_ticks_msec() / 1000.0)
	await create_timer(1.1).timeout
	var held: Node3D = town.player.carrying
	print("PLAYER TAKE ok=", ok, " paper=", held != null and held.has_meta("job"), " taker_player=", cards.size() > 0 and cards[0]["taker"] is String, " (want true true true)")
	var ov: Dictionary = town.oven["spot"]
	body.global_position = (ov["pos"] as Vector3) + Vector3(0, 0.05, 0); town.action_until = 0.0; town.use_until = -1.0
	var c0: int = town.coins
	town.oven_use(ov, Time.get_ticks_msec() / 1000.0)
	var paid := -1
	for i in 300:
		await physics_frame
		if paid < 0 and town.coins >= c0 + 2: paid = i   # 빵 품삯 1(money 1) + 카드의 동전 1
		if paid >= 0: break
	print("PLAYER PAID frame=", paid, " coins ", c0, "->", town.coins, " cards=", cards.size(), " stock=", bc["stock"], " paper_job=", held != null and is_instance_valid(held) and held.has_meta("job"), " (want +2, 0, 1, false)")
	# 저녁: a 의 안 뗀 카드 — 17시에 떼러 가서 동전을 돌려받는다
	bc["stock"] = 0; town._show_stock(bc); a.set_meta("posted", -1e9); a.coins = 2; a.mind.full = 0.2
	_at(a, town, jb, "post"); a._post_arrive(Time.get_ticks_msec() / 1000.0)
	await create_timer(1.2).timeout
	var ac: int = a.coins
	town.clock = (17.2 - 6.0) / 24.0
	a._release(); a.spot = {}; a.route = []; a.state = "routine"; a.busy_until = 0.0; a.global_position = (jb["pos"] as Vector3) + Vector3(1.5, 0.02, 2.0)
	var pick: bool = a._job_pick(Time.get_ticks_msec() / 1000.0)
	var down := -1
	for i in 900:
		await physics_frame
		if down < 0 and cards.is_empty(): down = i
		if down >= 0: break
	print("DUSK pick=", pick, " act=", a.get_meta("job_act", ""), " down_frame=", down, " a_coins ", ac, "->", a.coins, " line='", a.say_label.text, "' (want true down, +1)")
	# 외상 여섯·빈 주머니 → 창구가 거절; 둘이면 받는다(외상 셋)
	bc["stock"] = 3; town._show_stock(bc); b.coins = 0; b.mind.tab = 6
	var took: bool = town.counter_take(bc, b)
	b.mind.tab = 2
	var took2: bool = town.counter_take(bc, b)
	print("TAB CAP refused=", not took, " stock=", bc["stock"], " took_at_2=", took2, " tab_after=", b.mind.tab, " (want true 2 true 3)")
	quit()

## 주민을 판 앞에 세운다 — 닿은 것으로(_post_arrive 를 바로 부른다)
func _at(r: Resident, town: Node3D, jb: Dictionary, act: String) -> void:
	while r.fig.carrying: r.fig.release(town, Vector3.ZERO).queue_free()
	r.carrying_kind = ""; r._release(); r.route = []
	r.global_position = (jb["pos"] as Vector3) + Vector3(0, 0.02, 0)
	r.spot = jb; r.slot = 0; r._claim(jb, 0); r.state = "busy"; r.set_meta("job_act", act)
