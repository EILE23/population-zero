extends SceneTree
## 품삯 점검(헤드리스, run 113, money 1): 빵집 주인이 화덕에서 구워 창구에 오른 빵마다 coins +1 (줄 끝에 paid 한마디); 사람이 화덕에서 반죽하면 빵 하나에 토스트 +1 coin, 창구가 셋이면 없다("The rack is full.");
## 건축가의 일 한 단위에 +1 (build_work by), 사람의 공사장 망치질(site_use) 2.5초 뒤 +1; 구두장이는 사람 손님(걸상) 하나에 +1, "Resoled." 뒤 1.8초에 paid 한마디
## godot --headless --path game -s res://tools/probe_wages.gd
func _init() -> void:
	var town: Node3D = (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 30: await physics_frame
	town.weather = "clear"; town.weather_until = 1e12; town.clock = 0.15
	print("WAGE table=", town.prices.get("wage", {}))
	# 빵집 주인: 창구 0 → 화덕 도착 분기(resident.gd _arrive "oven") — 세 덩이, 덩이마다 +1, 끝에 paid
	var baker: Resident = null
	for x: Resident in town.residents:
		if x.job == "baker": baker = x; break
	var sp: Dictionary = town.spots.filter(func(s): return s["kind"] == "counter" and s.has("stock"))[0]
	sp["stock"] = 0; town._show_stock(sp)
	var ov: Dictionary = town.oven["spot"]
	baker._release(); baker.spot = ov; baker.slot = 0; baker.state = "busy"; baker.global_position = ov["pos"]
	while baker.fig.carrying: baker.fig.release(town, Vector3.ZERO).queue_free()
	var c0: int = baker.coins
	baker._arrive(Time.get_ticks_msec() / 1000.0)
	var paid_line := ""; var first := -1
	for i in int((StickPoses.KNEAD_T * 3 + 1.0) * 60):
		await physics_frame
		if first < 0 and baker.coins == c0 + 1: first = i
		if baker.say_label.text in baker.mind.voice.get("paid", []): paid_line = baker.say_label.text
	print("BAKER coins ", c0, " -> ", baker.coins, " (expect +3) first_loaf_frame=", first, " stock=", sp["stock"], " paid_line='", paid_line, "'")
	baker.state = "routine"; baker.busy_until = 0.0; baker.fig.pose_request = ""; baker.global_position = ov["pos"] + Vector3(4, 0, 4)
	# 사람: 화덕에서 반죽 — 창구 2 → 3 이면 +1 코인, 꽉 찬 창구면 없다
	var b: Node3D = town.body
	sp["stock"] = 2; town._show_stock(sp)
	town.coins = 0; town._set_coins(0)
	b.global_position = ov["pos"]; town.action_until = 0.0; town.use_until = -1.0
	while town.player.carrying: town.player.release(town, Vector3.ZERO).queue_free()
	town.oven_use(ov, Time.get_ticks_msec() / 1000.0)
	for i in int((StickPoses.KNEAD_T + 0.6) * 60): await physics_frame
	print("PLAYER BAKE coins=", town.coins, " (expect 1) stock=", sp["stock"], " earned=", town.earned)
	town.action_until = 0.0; town.use_until = -1.0; town.player.pose_request = ""
	town.oven_use(ov, Time.get_ticks_msec() / 1000.0)
	for i in int((StickPoses.KNEAD_T + 0.6) * 60): await physics_frame
	print("PLAYER BAKE FULL coins=", town.coins, " (expect 1, rack full) stock=", sp["stock"])
	# 건축가: 일 한 단위 — build_work(sp, builder) → +1 과 paid
	var builder: Resident = null
	for x: Resident in town.residents:
		if x.job == "builder": builder = x; break
	if town._site_nodes.is_empty(): print("BUILDER no site"); quit(); return
	var bs: Dictionary = town.build_spot_of(int(town._site_nodes.keys()[0]))   # build_spot 은 빈 칸만 — 아침엔 건축가 둘이 차지하고 있다
	var w0: float = float(town.site_work.get(bs["lot"], 0.0)); var bc0: int = builder.coins
	town.build_work(bs, builder)
	await physics_frame
	print("BUILDER coins ", bc0, " -> ", builder.coins, " (expect +1) work ", w0, " -> ", town.site_work.get(bs["lot"], 0.0), " says='", builder.say_label.text, "' paid=", builder.say_label.text in builder.mind.voice.get("paid", []))
	# 사람: 공사장 앞 망치질 2.5초 → 일 한 단위와 +1
	b.global_position = bs["pos"]; town.action_until = 0.0; town.use_until = -1.0; town.player.pose_request = ""
	var pc0: int = town.coins; var pw0: float = float(town.site_work.get(bs["lot"], 0.0))
	town.site_use(bs, Time.get_ticks_msec() / 1000.0)
	for i in 170: await physics_frame
	print("PLAYER HAMMER coins ", pc0, " -> ", town.coins, " (expect +1) work ", pw0, " -> ", town.site_work.get(bs["lot"], 0.0), " pose='", town.player.pose_request, "'")
	# 구두장이: 작업대에서 일하는 중, 사람이 걸상에 앉아 고쳐 받는다 → "Resoled." 와 +1, 1.8초 뒤 paid
	var cob: Resident = null
	for x: Resident in town.residents:
		if x.job == "cobbler": cob = x; break
	if cob == null or town.cobbler.is_empty(): print("COBBLER none"); quit(); return
	var work: Dictionary = town.cobbler["work"]
	cob._release(); cob.spot = work; cob.slot = 0; cob._claim(work, 0); cob.state = "busy"; cob.busy_until = Time.get_ticks_msec() / 1000.0 + 30.0
	cob.global_position = work["pos"]; cob.fig.pose_request = "hammer"
	await physics_frame
	var cc0: int = cob.coins
	b.global_position = town.cobbler["stool"]["pos"] + Vector3(0.3, 0, 0.3); town.action_until = 0.0; town.use_until = -1.0; town.player.pose_request = ""
	town.cobbler_use(town.cobbler["stool"], Time.get_ticks_msec() / 1000.0)
	var resoled := -1; var paid := -1; var lines: Array = []
	for i in int((StickPoses.HAMMER_T * 2.0 + 2.6) * 60):
		await physics_frame
		if resoled < 0 and cob.say_label.text == "Resoled.": resoled = i
		if paid < 0 and cob.say_label.text in cob.mind.voice.get("paid", []): paid = i
		if not lines.has(cob.say_label.text): lines.append(cob.say_label.text)
	print("COBBLER at_work=", town.cobbler_at_work() == cob, " coins ", cc0, " -> ", cob.coins, " (expect +1) resoled_frame=", resoled, " paid_frame=", paid, " (expect ~+108) lines=", lines)
	quit()
