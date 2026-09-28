class_name TownCombat
extends TownSystems
## 타격과 피격 — 내 타격 판정(_strike: 나무·동물·주민·벽), 주민이 나를 침, 동물이 맞음, 벽의 금과 먼지. town_player 에서 떼어 냈다(500줄 상한).

## 앞 부채꼴(70°) 안, 사거리 안의 주민을 맞힌다. 무거운 한 방(제트킥·점프 주먹·훅)은 바로 넘어진다
func _strike(kind: String) -> void:
	var reach := 1.3 if kind == "jet" else (1.15 if kind == "kick" or kind == "runkick" else 0.95)
	var heavy := kind == "jet" or kind == "air" or kind == "runkick" or (kind == "punch" and player.punch_kind == "hook")
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
		if r.state == "down" or (kind == "jet" and float(r.get_meta("jet_hit_at", -9.0)) > now - 1.0):
			continue
		var to: Vector3 = r.global_position - p; to.y = 0.0
		var d := to.length()
		if d < reach and d > 0.05 and f.dot(to.normalized()) > 0.34:
			r.hit(f, body, heavy); hit_someone = true
			if kind == "jet": r.set_meta("jet_hit_at", now)
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
		return true
	return false

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
	var q: Quad3D = a["quad"]
	q.act("hurt"); q.sulk = true
	a["sulk_until"] = a["t"] + 20.0; a["freeze_until"] = a["t"] + 0.5
	a["follow_until"] = 0.0; a["pet_until"] = 0.0
	if a["kind"] == "fox": a["angry_until"] = a["t"] + 6.0
	else: a["flee_until"] = a["t"] + 2.5; a["wander"] = (a["node"] as Node3D).global_position + dir * 3.0
	(a["node"] as Node3D).global_position += dir * 0.4

func fwd_dir() -> Vector3:
	return Vector3(sin(player.rotation.y), 0, cos(player.rotation.y))
