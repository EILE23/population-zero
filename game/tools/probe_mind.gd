extends SceneTree
## 주민 자아 점검(헤드리스): 성격이 사람마다 다른가, 때리면 곁의 주민이 보고 기억하나, 쫓거나 피하나, 소문이 옮나, 기억이 저장되나
## godot --headless --path game -s res://tools/probe_mind.gd
func _init() -> void:
	var town: Node3D = (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 30: await physics_frame
	var rs: Array = town.residents
	for r in rs.slice(0, 6):
		var m: ResidentMind = r.mind
		print("MIND ", r.handle, " social=%.2f temper=%.2f curious=%.2f lazy=%.2f brave=%.2f likes=%s" % [m.social, m.temper, m.curious, m.lazy, m.brave, m.likes])
	# 가장 성미 급한 사람과 가장 겁 많은 사람을 사람 곁에 세우고 때린다
	var walkers: Array = rs.filter(func(x): return x.state != "drive")
	walkers.sort_custom(func(a, b): return a.mind.temper > b.mind.temper)
	var hot: Resident = walkers[0]; var shy: Resident = walkers[walkers.size() - 1]
	var b: Node3D = town.body
	for pair in [[hot, "hot"], [shy, "shy"]]:
		var r: Resident = pair[0]
		b.global_position = Vector3(10, 0.05, 12); r.global_position = b.global_position + Vector3(0.7, 0, 0); r.state = "routine"
		var near: Resident = walkers[3]; near.global_position = b.global_position + Vector3(-2, 0, 1); near.state = "routine"
		var f0: float = near.mind.fond
		for k in 3:
			r.hit(Vector3(1, 0, 0), b, true); r.down_until = 0.0
			for i in 150: await physics_frame
		print("HIT ", pair[1], " ", r.handle, " temper=%.2f brave=%.2f fond=%.2f state=%s spot=%s status=%s" % [r.mind.temper, r.mind.brave, r.mind.fond, r.state, r.spot.get("kind", ""), r.mind.status()])
		print("WITNESS ", near.handle, " fond %.2f -> %.2f" % [f0, near.mind.fond])
	# 소문: 미워하는 사람이 다른 주민과 수다 — 듣는 사람의 호감이 내려가야 한다
	var talker: Resident = hot; var listener: Resident = walkers[5]
	for x in [talker, listener]: x._release(); x.state = "busy"; x.fig.pose_request = ""; x.fig.seated = false; x.busy_until = Time.get_ticks_msec() / 1000.0 + 30.0
	talker.global_position = Vector3(-10, 0.05, 12); listener.global_position = Vector3(-9, 0.05, 12)
	var lf: float = listener.mind.fond
	var said := false
	for t in 12:
		listener.fig.pose_request = ""; talker.fig.pose_request = ""
		if talker._chat_force(): said = true
		if listener.mind.fond < lf - 0.01: break
	print("GOSSIP talker fond=%.2f listener fond %.2f -> %.2f said=%s" % [talker.mind.fond, lf, listener.mind.fond, said])
	# 선물: 사과를 건네면 호감이 오르고 먹는다
	var g: Resident = walkers[7]; g._release(); g.state = "routine"; g.global_position = Vector3(20, 0.05, 12)
	while g.fig.carrying: g.fig.release(town, Vector3.ZERO).queue_free()
	var gf: float = g.mind.fond
	g.take_gift(town.make_item("apple", Vector3.ZERO))
	for i in 300: await physics_frame
	print("GIFT ", g.handle, " fond %.2f -> %.2f full=%.2f carrying=%s" % [gf, g.mind.fond, g.mind.full, g.fig.carrying])
	# 고르기 분포: 게으른 사람 vs 호기심 많은 사람 — 거르는 목록은 resident.gd _pick_spot 의 pool 과 같게(polish run 105: 일터·이야기방 자리가 섞여 버그처럼 보였다)
	for who in [walkers.reduce(func(a, x): return x if x.mind.lazy > a.mind.lazy else a), walkers.reduce(func(a, x): return x if x.mind.curious > a.mind.curious else a)]:
		var tally := {}
		for i in 200:
			var sp: Dictionary = who.mind.pick(town.spots.filter(func(s): return not (s["kind"] in ["oven", "rack", "cobbler", "stool", "wheel", "whet", "stitch", "fitting", "chop", "pile", "stove", "swap", "letters", "notice", "story", "cushion", "cot", "rocker", "stage", "hat", "jobs", "pawn", "pawn_keep"]) and (s["kind"] != "ledger" or who._ledger_ok())), who._schedule_kinds())   # run 116: resident.gd 의 목록과 다시 같게(심부름판·전당포 — 전엔 run 112 까지만)
			tally[sp["kind"]] = tally.get(sp["kind"], 0) + 1
		print("PICK ", who.handle, " lazy=%.2f curious=%.2f energy=%.2f " % [who.mind.lazy, who.mind.curious, who.mind.energy], tally)
	quit()
