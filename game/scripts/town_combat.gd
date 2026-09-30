class_name TownCombat
extends TownSystems
## 타격과 피격 — 내 타격 판정(_strike: 나무·동물·주민·벽), 주민이 나를 침, 동물이 맞음, 벽의 금과 먼지. town_player 에서 떼어 냈다(500줄 상한).

## 앞 부채꼴(70°) 안, 사거리 안의 주민을 맞힌다. 무거운 한 방(제트킥·점프 주먹·훅)은 바로 넘어진다
func _strike(kind: String) -> void:
	var reach := 1.3 if kind == "round" else (1.15 if kind == "kick" else 0.95)
	var heavy := kind == "round"   # 돌려차기(연속 마무리)는 한 방에 넘어뜨린다 — 앞차기·주먹은 쌓여서(3초 안 세 대)
	var f := fwd_dir(); var p := body.global_position
	var now := Time.get_ticks_msec() / 1000.0
	for c in crowns:
		var ct: Vector3 = c["at"] - p; ct.y = 0.0
		if ct.length() < reach + 0.4 and f.dot(ct.normalized()) > 0.34:
			c["hit_t"] = 1.2   # 잎이 크게 출렁
			if not (c["fruit"] as Array).is_empty():
				var fr: Node3D = (c["fruit"] as Array).pop_back(); var fp := fr.global_position; fr.queue_free()
				var apple := make_item("apple", fp)
				flying.append({ "node": apple, "vel": f * 1.2 + Vector3(0, 0.4, 0), "spin": 3.0 })
			cam_kick = maxf(cam_kick, 0.02)
	for a in animals:
		if not a.has("quad"): continue
		var an: Node3D = a["node"]
		var ta: Vector3 = an.global_position - p; ta.y = 0.0
		if ta.length() < reach and f.dot(ta.normalized()) > 0.34:
			animal_hit(a, f); cam_kick = 0.03
	var hit_someone := false
	for r in residents:
		if r.state == "down":
			continue
		var to: Vector3 = r.global_position - p; to.y = 0.0
		var d := to.length()
		if d < reach and d > 0.05 and f.dot(to.normalized()) > 0.34:
			r.hit(f, body, heavy); hit_someone = true
			FightPoses.spark(self, r.global_position + Vector3(0, 0.85 if kind == "punch" else (0.75 if kind == "round" else 0.6), 0) - f * 0.15, heavy)
			FightPoses.hitstop(get_tree(), heavy or r.state == "down")
			cam_kick = 0.06 if heavy else 0.03
	if not hit_someone and _crack_wall(f, p):
		cam_kick = maxf(cam_kick, 0.04)

## 벽 타격(운영자 2026-09-28: "건물 표면에 데미지") — 앞 0.6m 지점이 집 상자 안이면 가장 가까운 면에 금을 낸다: 어두운 가는 조각 셋이 무작위 각도로,
## 먼지 한 줌. 금은 그 벽과 함께 컷어웨이로 숨는다. 집마다 12개까지(그 뒤로는 먼지만). 고치는 일(수리공 일과)은 백로그
func _crack_wall(f: Vector3, p: Vector3) -> bool:
	var q := p + f * 0.6 + Vector3(0, 0.9 + randf_range(-0.15, 0.15), 0)
	for h in houses:
		var mn: Vector3 = h["min"]; var mx: Vector3 = h["max"]
		if q.x < mn.x - 0.25 or q.x > mx.x + 0.25 or q.z < mn.z - 0.25 or q.z > mx.z + 0.25 or q.y > mx.y: continue
		var d: Array = [absf(q.z - mx.z), absf(q.z - mn.z), absf(q.x - mx.x), absf(q.x - mn.x)]
		var face := 0
		for i in 4:
			if d[i] < d[face]: face = i
		var at: Vector3; var yaw := 0.0
		match face:
			0: at = Vector3(q.x, q.y, mx.z + 0.012)
			1: at = Vector3(q.x, q.y, mn.z - 0.012); yaw = PI
			2: at = Vector3(mx.x + 0.012, q.y, q.z); yaw = PI / 2.0
			_: at = Vector3(mn.x - 0.012, q.y, q.z); yaw = -PI / 2.0
		_dust(at + f * -0.15)
		if h.get("cracks", 0) >= 12: return true
		var n := Node3D.new(); n.position = at; n.rotation.y = yaw; add_child(n)
		var ink := _mat(Color("3a2f36"))
		for i in 3:
			var len := randf_range(0.14, 0.3)
			var seg := _box(Vector3(0.02, len, 0.012), Vector3(randf_range(-0.06, 0.06), randf_range(-0.06, 0.06) - len / 2.0, 0), ink, false, n)
			seg.rotation.z = randf_range(-1.2, 1.2)
		h["cracks"] = h.get("cracks", 0) + 1
		(h["parts"] if face == 0 else h["shell"]).append(n)
		var out: Vector3 = [Vector3(0, 0, 1), Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(-1, 0, 0)][face]
		cracks.append({ "node": n, "house": h, "at": Vector3(at.x, 0, at.z), "out": out, "by": null })
		return true
	return false

## 금 하나 고침 — 잉크 조각이 사라지고 먼지 한 줌
func repair_crack(c: Dictionary) -> void:
	if not cracks.has(c): return
	cracks.erase(c)
	if c.get("kind", "") == "wreck":
		# 부서진 소품을 그 자리에 다시 세운다(흩어진 조각은 치운다)
		for piece in c["pieces"]:
			if is_instance_valid(piece): (piece as Node).queue_free()
		(c["rebuild"] as Callable).call()
		_dust(c["at"] + Vector3(0, 0.3, 0))
		return
	var n: Node3D = c["node"]; var h: Dictionary = c["house"]
	h["parts"].erase(n); h["shell"].erase(n); h["cracks"] = maxi(0, h.get("cracks", 1) - 1)
	_dust(n.global_position); n.queue_free()

## 소품 부서짐 — 조각(메시)이 속도대로 흩날려 바닥에 남고, 자리는 수리 목록에 오른다
func smash(w: Dictionary, push: Vector3) -> void:
	wreckables.erase(w)
	if w.has("bench"): benches.erase(w["bench"])
	if w.has("spot"): spots.erase(w["spot"])
	if w.has("light"): lamps.erase(w["light"]); (w["light"] as Node).queue_free()
	var root: Node3D = w["node"]
	var at: Vector3 = w["at"]
	var spd := push.length()
	var pieces: Array = []
	if w.get("splinter", false):
		# 울타리: 한 판이 눕는 대신 기둥 둘·가로대 둘·나뭇조각으로 쪼개져 날아간다(운영자: 그냥 누워버려 타격감 없다)
		root.queue_free()
		var wood := _mat(Color("8a6a4a"))
		for spec in [[Vector3(0.08, 0.7, 0.07), Vector3(-0.4, 0.35, 0)], [Vector3(0.08, 0.7, 0.07), Vector3(0.4, 0.35, 0)], [Vector3(0.95, 0.07, 0.05), Vector3(0, 0.28, 0)], [Vector3(0.95, 0.07, 0.05), Vector3(0, 0.55, 0)], [Vector3(0.3, 0.05, 0.04), Vector3(0.1, 0.4, 0)], [Vector3(0.22, 0.05, 0.04), Vector3(-0.15, 0.2, 0)]]:
			var m := _box(spec[0], at + spec[1], wood, false)
			m.get_parent().remove_child(m); add_child(m); m.global_position = at + spec[1]
			pieces.append(m)
	else:
		var meshes: Array = root.find_children("*", "MeshInstance3D", true, false)
		if root is MeshInstance3D: meshes.append(root)
		if w.get("whole", false):
			# 가로등: 기둥째 한 덩어리로 넘어가며 날아간다(유리만 따로 튄다)
			root.get_parent().remove_child(root); add_child(root)
			for sb in root.find_children("*", "StaticBody3D", true, false): sb.queue_free()
			pieces.append(root)
		else:
			for mi in meshes:
				var m := mi as MeshInstance3D
				var gt := m.global_transform
				m.get_parent().remove_child(m); add_child(m); m.global_transform = gt
				for sb in m.get_children(): if sb is StaticBody3D: sb.queue_free()
				pieces.append(m)
			if is_instance_valid(root) and root.get_parent(): root.queue_free()
	for m in pieces:
		m.set_meta("debris", true)
		var k := randf_range(0.6, 1.05)
		flying.append({ "node": m, "vel": push * k + Vector3(randf_range(-1.5, 1.5), randf_range(2.5, 4.0) + spd * 0.25, randf_range(-1.5, 1.5)),
			"spin": randf_range(6.0, 14.0) * (1.0 + spd * 0.08), "axis": Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized(), "bounce": 1 })
	_splinters(at + Vector3(0, 0.5, 0), push, spd)
	_dust(at + Vector3(0, 0.3, 0)); cam_kick = maxf(cam_kick, 0.03 + spd * 0.006)
	cracks.append({ "kind": "wreck", "at": Vector3(at.x, 0, at.z), "out": w["out"], "by": null, "pieces": pieces, "rebuild": w["rebuild"] })

## 부서질 때 파편 한 줌(나뭇조각·먼지·유리) — 진행 방향으로 뿌려지고 사라진다
func _splinters(at: Vector3, push: Vector3, spd: float) -> void:
	var p := CPUParticles3D.new(); p.amount = int(12 + spd * 3.0); p.lifetime = 0.9; p.one_shot = true; p.explosiveness = 0.95
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE; p.emission_sphere_radius = 0.25
	p.direction = (push.normalized() + Vector3(0, 0.8, 0)).normalized(); p.spread = 55.0
	p.initial_velocity_min = 2.0 + spd * 0.3; p.initial_velocity_max = 4.0 + spd * 0.6; p.gravity = Vector3(0, -12, 0)
	p.angular_velocity_min = -600.0; p.angular_velocity_max = 600.0; p.scale_amount_min = 0.5; p.scale_amount_max = 1.5
	var bm := BoxMesh.new(); bm.size = Vector3(0.09, 0.025, 0.025); p.mesh = bm
	var m := StandardMaterial3D.new(); m.albedo_color = Color("8a6a4a"); m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; p.material_override = m
	p.position = at; add_child(p); p.emitting = true
	get_tree().create_timer(1.5).timeout.connect(p.queue_free)

## 차에 치임(나) — 속도만큼 날아가 누웠다 일어난다. 들고 있던 건 흩어진다
func car_hits_player(vel: Vector3, stun: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if down_until > now or getup_until > now: return
	jet = false; seat = {}; player.seated = false; resting = false; reading = false; leaning = false
	if not riding.is_empty(): dismount()
	if seesaw_ride: seesaw_ride.leave("player"); seesaw_ride = null; body.global_position += Vector3(0, 0, 0.7)   # 그네·시소에 탄 채 치이면 내린다(판 앞으로 — 판 속에 겹친 채 마스크가 켜지면 바닥 밑으로 밀렸다) — 그 가지들이 먼저 return 해 누운 채 그네를 타고 일어나지 못했다(polish 79)
	down_until = now + stun; player.lying = true; player.action = ""; action_until = now
	body.velocity = vel; cam_kick = 0.08
	if Wear.tear(player.worn.get("back")): say_toast("Torn. The tailor on the east plaza mends these.")   # 차에 친 주민은 찢어지는데(hit heavy) 사람만 멀쩡했다(polish 83)
	while player.carrying:   # 흩어진 건 넘어져 떨어뜨린 것 — 여우가 노린다(_fox, 주먹에 넘어질 때와 같은 표시; polish 83)
		var it: Node3D = player.release(self, body.global_position + Vector3(randf_range(-0.6, 0.6), 0.1, randf_range(-0.6, 0.6))); it.set_meta("dropped_at", now); items.append(it)

## 먼지 한 줌 — 벽을 칠 때
func _dust(at: Vector3) -> void:
	var p := CPUParticles3D.new(); p.amount = 10; p.lifetime = 0.5; p.one_shot = true; p.explosiveness = 0.9
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE; p.emission_sphere_radius = 0.1
	p.direction = Vector3.UP; p.spread = 80.0; p.initial_velocity_min = 0.6; p.initial_velocity_max = 1.4; p.gravity = Vector3(0, -2.0, 0)
	p.mesh = BoxMesh.new(); (p.mesh as BoxMesh).size = Vector3(0.05, 0.05, 0.05)
	var m := StandardMaterial3D.new(); m.albedo_color = Color(0.75, 0.7, 0.66); m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; p.material_override = m
	p.position = at; add_child(p); p.emitting = true
	get_tree().create_timer(1.0).timeout.connect(p.queue_free)

## 사람이 동물을 때리면(타격 판정에서 호출) — 여우는 화난다, 나머지는 달아난다
func animal_hit(a: Dictionary, dir: Vector3) -> void:
	# 아파한다(운영자 2026-09-28): 0.5초 움찔(몸 낮추고 고개 들고 귀 접고 "!"), 20초 동안 꼬리 내리고 따라오지도 쓰다듬게 두지도 않는다. 여우는 화낸다
	var q = a["quad"]   # Quad3D 또는 Animal3D
	q.act("hurt"); q.sulk = true
	a["sulk_until"] = a["t"] + 20.0; a["freeze_until"] = a["t"] + 0.5
	a["follow_until"] = 0.0; a["pet_until"] = 0.0
	if a["kind"] == "fox": a["angry_until"] = a["t"] + 6.0
	else: a["flee_until"] = a["t"] + 2.5; a["wander"] = (a["node"] as Node3D).global_position + dir * 3.0
	(a["node"] as Node3D).global_position += dir * 0.4

func fwd_dir() -> Vector3:
	return Vector3(sin(player.rotation.y), 0, cos(player.rotation.y))
