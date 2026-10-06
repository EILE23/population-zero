extends SceneTree
## 외상 장부 점검(헤드리스, run 112): 탁자·그릇이 섰나(spots 에 "ledger", 원판 다섯 숨김); 빈 주머니의 주민이 창구에서 빵을 받으면 mind.tab +1(빵은 그대로);
## 빈 주머니의 사람이 C 로 빵을 받으면 tab +1 과 토스트; 외상 1·동전 2 의 주민을 풀어 주면 장부 자리를 고르고 → scan → sigh → stoop → 그릇 +1, 주머니 −1, tab 0, tabbed 표, tab_pay 한 줄;
## 사람이 장부 앞에서 C → 같은 세 박자, 그릇 +1, 주머니 −1, tab −1; 외상 0 으로 C → 읽기만(토스트 "Nothing on the tab.", 한숨 없음); 17시 → closing → 빵집 주인이 와서 stoop 으로 거둔다(그릇 0, 주머니 +n)
## godot --headless --path game -s res://tools/probe_ledger.gd
func _init() -> void:
	var town: Node3D = (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 30: await physics_frame
	town.weather = "clear"; town.weather_until = 1e12
	town.clock = (10.0 - 6.0) / 24.0
	var lg: Dictionary = town.ledger
	if lg.is_empty(): print("LEDGER none"); quit(); return
	var bc: Dictionary = town.spots.filter(func(sp): return sp["kind"] == "counter" and sp.has("stock"))[0]
	print("PLACE pos=", lg["pos"], " bowl=", lg["bowl"], " discs=", (lg["till_shown"] as Array).size(), " hidden=", (lg["till_shown"] as Array).all(func(d): return not d.visible), " slots=", town.residents[0]._free_slot(lg) >= 0, " counter_dist=", snappedf((lg["at"] as Vector3).distance_to(bc["pos"]), 0.1))
	# 빈 주머니의 주민이 창구에서 빵을 받는다 → tab +1, 빵은 손에
	var r: Resident = null; var baker: Resident = null
	for x: Resident in town.residents:
		if x.job == "baker": baker = x
		elif r == null and x.job == "" and x.uid % 6 != 0 and x.pair == null and not x.in_boat: r = x
	bc["stock"] = 3; town._show_stock(bc)
	r.coins = 0; r.mind.tab = 0
	var took: bool = town.counter_take(bc, r)
	print("RESIDENT ON THE HOUSE took=", took, " tab=", r.mind.tab, " coins=", r.coins, " stock=", bc["stock"], " (expect tab 1)")
	# 빈 주머니의 사람이 C 로 빵을 받는다 → tab +1
	var b: Node3D = town.body
	b.global_position = (bc["pos"] as Vector3) + Vector3(0, 0.05, 0); town.player.pose_request = ""; town.use_until = -1.0; town.action_until = 0.0
	while town.player.carrying: town.player.release(town, Vector3.ZERO).queue_free()
	for i in 3: await physics_frame
	town.coins = 0; town.tab = 0
	town.counter_use(bc, Time.get_ticks_msec() / 1000.0)
	print("PLAYER ON THE HOUSE tab=", town.tab, " coins=", town.coins, " holding=", town.player.carrying != null, " (expect tab 1)")
	while town.player.carrying: town.player.release(town, Vector3.ZERO).queue_free()
	# 외상 1·동전 2 의 주민 — 장부 자리를 고르고 세 박자
	_free(r, town, (lg["pos"] as Vector3) + Vector3(1.5, 0, 2.5))
	r.coins = 2; r.mind.tab = 1; r.mind.full = 1.0; r.mind.energy = 1.0; r.mind.fun = 1.0; r.mind.company = 1.0
	print("OK ok=", r._ledger_ok(), " score=", snappedf(r.mind.score(lg, []), 0.01))
	var picked := -1; var scan := -1; var sigh := -1; var stoop := -1; var paid := -1; var read_line := ""; var pay_line := ""
	for i in 1500:
		await physics_frame
		if picked < 0 and r.spot.get("kind", "") == "ledger": picked = i
		if picked >= 0 and picked < 20 and r.spot.get("kind", "") != "ledger" and scan < 0: _free(r, town, (lg["pos"] as Vector3) + Vector3(1.5, 0, 2.5)); picked = -1
		if scan < 0 and r.fig.pose_request == "scan" and r.spot.get("kind", "") == "ledger": scan = i; read_line = r.say_label.text
		if sigh < 0 and r.fig.pose_request == "sigh": sigh = i
		if stoop < 0 and r.fig.pose_request == "stoop" and sigh >= 0: stoop = i
		if paid < 0 and r.mind.tab == 0 and stoop >= 0: paid = i; pay_line = r.say_label.text
		if paid >= 0 and i > paid + 50: break
		if picked < 0 and i % 200 == 199: _free(r, town, (lg["pos"] as Vector3) + Vector3(1.5, 0, 2.5))   # 다른 자리를 골랐으면 다시(가중 무작위)
	print("RESIDENT TURN picked_frame=", picked, " scan=", scan, " sigh=", sigh, " stoop=", stoop, " paid=", paid, " x_off=", snappedf(r.global_position.x - (lg["pos"] as Vector3).x, 0.01), " bowl=", lg["till"], " coins=", r.coins, " tab=", r.mind.tab, " tabbed=", r.has_meta("tabbed"), " ok_after=", r._ledger_ok(), " read='", read_line, "' tab_read=", read_line in r.mind.voice.get("tab_read", []), " pay='", pay_line, "' tab_pay=", pay_line in r.mind.voice.get("tab_pay", []), " shown=", (lg["till_shown"] as Array).map(func(d): return d.visible))
	# 사람: 외상 1·동전 1 로 장부 앞에서 C → scan → sigh → stoop → 그릇 +1
	_free(r, town, Vector3(20, 0, 14))
	b.global_position = (lg["pos"] as Vector3) + Vector3(0, 0.05, 0); town.player.pose_request = ""; town.use_until = -1.0; town.action_until = 0.0
	for i in 3: await physics_frame
	town._set_coins(1); town.tab = 1
	var t0: int = lg["till"]
	town.ledger_use(Time.get_ticks_msec() / 1000.0)
	var ps := -1; var pg := -1; var pst := -1; var pp := -1
	for i in 400:
		await physics_frame
		if ps < 0 and town.player.pose_request == "scan": ps = i
		if pg < 0 and town.player.pose_request == "sigh": pg = i
		if pst < 0 and town.player.pose_request == "stoop": pst = i
		if pp < 0 and int(lg["till"]) == t0 + 1: pp = i
		if pp >= 0 and i > pp + 40: break
	print("PLAYER TURN scan=", ps, " sigh=", pg, " stoop=", pst, " paid_frame=", pp, " bowl ", t0, "->", lg["till"], " coins=", town.coins, " tab=", town.tab, " pose='", town.player.pose_request, "' use_until_over=", Time.get_ticks_msec() / 1000.0 >= town.use_until)
	# 외상 0 — 읽기만, 한숨 없음
	town.action_until = 0.0; town.use_until = -1.0; town._set_coins(1)
	town.ledger_use(Time.get_ticks_msec() / 1000.0)
	var any_sigh := false; var cleared := -1
	for i in 220:
		await physics_frame
		if town.player.pose_request == "sigh": any_sigh = true
		if cleared < 0 and i > 5 and town.player.pose_request == "": cleared = i
	print("NOTHING OWED sighed=", any_sigh, " (expect false) cleared_frame=", cleared, " coins=", town.coins, " bowl=", lg["till"])
	# 17시 → closing → 빵집 주인이 거둔다
	b.global_position = Vector3(-3.0, 0.05, 14.0); town.action_until = 0.0
	var bk0: int = baker.coins; var till2: int = lg["till"]
	bc["stock"] = 3; town._show_stock(bc)   # 창구가 차 있어야 화덕이 먼저 끌지 않는다(_pick_spot 은 화덕 → … → _post_pick 순)
	_free(baker, town, (lg["pos"] as Vector3) + Vector3(2.0, 0, 2.0))
	town.clock = (17.0 - 6.0) / 24.0 - 0.0004
	var closing := -1; var came := -1; var emptied := -1
	for i in 1800:
		await physics_frame
		if closing < 0 and lg.get("closing", false): closing = i
		if came < 0 and baker.spot.get("kind", "") == "ledger" and baker.fig.pose_request == "stoop": came = i
		if came >= 0 and emptied < 0 and int(lg["till"]) == 0: emptied = i
		if emptied >= 0 and i > emptied + 90: break   # 마지막 동전은 셈이 먼저 줄고(palm_till) 주머니는 STOOP_AWAY 에 는다 — 그만큼 더 본다
		if closing >= 0 and came < 0 and i % 300 == 299: _free(baker, town, (lg["pos"] as Vector3) + Vector3(2.0, 0, 2.0))   # 화덕이나 창구 접시가 먼저면 다시 풀어 준다
	print("CLOSING closing_frame=", closing, " came=", came, " emptied=", emptied, " bowl ", till2, "->", lg["till"], " baker_coins ", bk0, "->", baker.coins, " closing_after=", lg.get("closing", false), " baker_tab=", baker.mind.tab, " (baker never on the tab)")
	quit()

## 주민을 풀어 가까이 둔다 — 일과를 다시 고르게
func _free(r: Resident, town: Node3D, at: Vector3) -> void:
	while r.fig.carrying: r.fig.release(town, Vector3.ZERO).queue_free()
	r.carrying_kind = ""; r.bites = 0
	r._release(); r.spot = {}; r.route = []; r.state = "routine"; r.busy_until = 0.0
	r.global_position = Vector3(at.x, 0.02, at.z)
