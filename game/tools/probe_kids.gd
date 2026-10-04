extends SceneTree
## 아이 점검(헤드리스, run 102 — "Elders and children" 1조각): 아이 둘이 한 집에 들었나(0.62, 부모와 같은 문), 낮에 부모를 따라 붙어 다니나(간격),
## 걸을 때 skip 인가, 주먹·발차기가 머리 위로 지나가 넘어지지 않나, 12m 넘게 떨어지면 부모가 찾으러 오나, 사람의 SPACE 톡톡 skip
## godot --headless --path game -s res://tools/probe_kids.gd
func _init() -> void:
	var town: Node3D = (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 30: await physics_frame
	town.weather = "clear"; town.clock = (11.0 - 6.0) / 24.0
	for r in town.residents: r.weather = "clear"
	var kids: Array = town.residents.filter(func(x): return x is ResidentKid)
	print("KIDS n=", kids.size(), " (want 2)")
	if kids.size() < 2: quit(); return
	for k: ResidentKid in kids:
		print("  ", k.handle, " size=", snappedf(k.fig.base_scale.y, 0.01), " same_door=", is_same(k.home_door, k.parent.home_door), " parent=", k.parent.handle, " tie=", snappedf(k.parent.mind.relation_k(kids[0].parent if k == kids[1] else kids[1].parent), 0.01))
	# 따라다니기: 20초 동안 0.5초마다 부모와의 거리
	var gaps: Array = []; var skips := 0; var walks := 0
	for i in 40:
		await create_timer(0.5).timeout
		for k: ResidentKid in kids:
			gaps.append(k.global_position.distance_to(k.parent.global_position))
			if k.state == "walk": walks += 1; skips += int(k.fig.pose_request == "skip")
	gaps.sort()
	var near := gaps.filter(func(g): return g < 3.0).size()
	print("FOLLOW median=", snappedf(gaps[gaps.size() / 2], 0.01), " under3m=", near, "/", gaps.size(), " skip ", skips, "/", walks, " walking samples (want median < 2.5, skip ~ walks — a cup or umbrella pose keeps its own)")
	# 주먹: 넘어지지 않는다
	var kd: ResidentKid = kids[0]
	town.body.global_position = kd.global_position + Vector3(-0.8, 0, 0)
	kd.hit(Vector3(1, 0, 0), town.body, true, 6.0, 4.0)
	await physics_frame
	print("PUNCH state=", kd.state, " action=", kd.fig.action, " lying=", kd.fig.lying, " (want busy flinch false)")
	await create_timer(1.0).timeout
	town.body.global_position = Vector3(0, 0.02, 4)
	# 잃어버림: 아이를 15m 밖에 세워 두고 부모를 한가하게 — 부모가 찾으러 와야 한다
	var p: Resident = kd.parent
	var at := Vector3(0, 0.05, 6)   # 큰길 남쪽 풀밭 — 부모는 16m 서쪽에 세운다(집이 90m 밖일 때도 있어 기다림이 길어졌다)
	p._leave(); p.global_position = Vector3(-16, 0.05, 6.5); p.state = "routine"; p.busy_until = Time.get_ticks_msec() / 1000.0 + 100.0
	kd._release(); kd.global_position = at; kd.state = "busy"; kd.spot = { "kind": "greet" }; kd.busy_until = Time.get_ticks_msec() / 1000.0 + 40.0
	await physics_frame; await physics_frame
	print("LOST parent spot=", p.spot.get("kind", ""), " state=", p.state, " said='", p.say_label.text, "' (want fetch walk)")
	var met := false
	for i in 90:
		await create_timer(0.5).timeout
		if i % 6 == 0: print("   t=", i * 0.5, " d=", snappedf(p.global_position.distance_to(kd.global_position), 0.1), " p.state=", p.state, " spot=", p.spot.get("kind", ""), " route=", p.route.size(), " p=", p.global_position.snapped(Vector3.ONE * 0.1), " kid=", kd.global_position.snapped(Vector3.ONE * 0.1))
		if p.global_position.distance_to(kd.global_position) < 2.0: met = true; break
	await create_timer(1.5).timeout
	print("FETCH met=", met, " found=", p.spot.has("found"), " said='", p.say_label.text, "' (want true true)")
	# 사람: SPACE 두 번 톡톡 → 걸으면 skip, 3초 뒤 풀린다
	var f: Stick3D = town.player
	var t0 := 100.0
	KidPoses.player(f, t0, true, false); KidPoses.player(f, t0 + 0.2, true, false)
	KidPoses.player(f, t0 + 0.5, false, true)
	var a := f.pose_request
	KidPoses.player(f, t0 + 3.5, false, true)
	print("PLAYER skip='", a, "' after='", f.pose_request, "' (want skip '')")
	quit()
