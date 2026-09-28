class_name TownSystems
extends TownBuild
## 매 프레임 도는 세계 시스템 — 낮밤, 날씨, 바람(나무), 동물 습성, 그네 물리, 컷어웨이, 구역 스트리밍, 던져진 물건, 범례.

## 스트리밍(첫 단계): 플레이어에서 34m 넘게 먼 구역은 끈다 — 그리기·물리·주민 처리 비용이 빠진다. 씬 단위 로딩은 맵이 더 커질 때
func _stream() -> void:
	var p := body.global_position
	for d in districts:
		var on: bool = absf(p.x - d["center"].x) < 34.0
		if on != d["on"]:
			d["on"] = on
			var n: Node3D = d["node"]
			n.visible = on
			n.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED

## 컷어웨이 — 플레이어가 집 안에 있으면 지붕·앞벽·천장·차양·앞창을 감춘다(운영자: 들어가면 캐릭터가 가려져 안 보였다)
## 2.5D 옆시점(카메라가 +z 에서 −z 를 본다)에서 집 **뒤**(더 −z, 같은 x 폭)에 서면 뒷벽·옆벽까지 감춘다 — 북쪽 골목이 가운데 집들에 가려져 안 보였다
func _cutaway() -> void:
	var p := body.global_position
	for h in houses:
		var mn: Vector3 = h["min"]; var mx: Vector3 = h["max"]
		var inside: bool = p.x > mn.x and p.x < mx.x and p.z > mn.z and p.z < mx.z and p.y < mx.y
		var near: bool = p.x > mn.x - 2.0 and p.x < mx.x + 2.0 and p.z > mn.z - 1.0 and p.z < mx.z + 2.5 and p.y < mx.y
		var behind: bool = view_25d and p.z < mn.z and p.x > mn.x - 1.5 and p.x < mx.x + 1.5 and p.y < mx.y
		var open := inside or near or behind   # 집 가까이 가면 열린다 — 안에서 쉬는 주민이 보이게(운영자: 들어가면 사라진다)
		if open != h["inside"]:
			h["inside"] = open
			for n in h["parts"]:
				n.visible = not open
		if behind != h["behind"]:
			h["behind"] = behind
			for n in h["shell"]:
				n.visible = not behind

## 진자 물리 — 매 프레임. 타고 있으면 몸이 좌석을 따라가고 ← → 가 흔들림 방향으로 밀어 준다
## 좌석의 세계 위치와 각도(주민이 탈 때 쓴다)
func swing_seat(sw: Dictionary) -> Vector3:
	var pv: Node3D = sw["pivot"]; var L: float = sw["len"]
	return pv.global_position + Vector3(0, -L * cos(sw["angle"]), -L * sin(sw["angle"]))

## 밀어 줄 주민 부르기 — 8m 안의 한가한 주민 하나
func _call_pusher(sw: Dictionary) -> void:
	for r in residents:
		if r.state in ["routine", "walk"] and r.global_position.distance_to(sw["at"]) < 8.0 and r.spot.get("kind", "") != "swing":
			r.go_push(sw); sw["pusher"] = r; return

func _swings(delta: float) -> void:
	for sw in swings:
		var g := 9.8; var L: float = sw["len"]
		var acc := -g / L * sin(sw["angle"])
		var me_on: bool = not riding.is_empty() and riding == sw
		if me_on:
			sw["rider"] = "player"
			var pump := Input.get_axis("move_up", "move_down")   # ↓ = 앞으로 밀기(+z), ↑ = 뒤로
			if absf(pump) > 0.1 and absf(sw["vel"]) > 0.05:
				acc += signf(sw["vel"]) * 2.2 * absf(pump) if (signf(pump) == signf(sw["vel"])) else 0.0
			elif absf(pump) > 0.1:
				acc += pump * 1.2   # 정지 상태에서 시동
			elif absf(sw["vel"]) > 0.05:
				acc += signf(sw["vel"]) * 0.35   # 조작 안 해도 몸이 저절로 조금 굴러 죽지 않는다
			# 아무도 안 밀면 8m 안의 한가한 주민을 불러 밀게 한다
			if sw["pusher"] == null and absf(Input.get_axis("move_up", "move_down")) < 0.1:
				_call_pusher(sw)
		elif sw["rider"] is Node and is_instance_valid(sw["rider"]):
			# 주민이 탐: 스스로 굴러 민다
			if absf(sw["vel"]) > 0.05: acc += signf(sw["vel"]) * 1.4
			else: acc += 1.0
		elif sw["rider"] == "player":
			sw["rider"] = null
		# 미는 사람: 좌석이 뒤(−z, 각 < 0)로 돌아와 멈추는 순간 앞으로 민다
		var pusher = sw["pusher"]
		if pusher != null:
			if not (pusher is Node and is_instance_valid(pusher)) and pusher != "player":
				sw["pusher"] = null
			elif sw["angle"] < -0.2 and sw["vel"] > -0.3 and sw["vel"] < 0.3 and Time.get_ticks_msec() / 1000.0 - sw["push_at"] > 1.0:
				sw["vel"] += 1.3; sw["push_at"] = Time.get_ticks_msec() / 1000.0
				if pusher is Node: pusher.fig.push_t = 0.0
				else: player.push_t = 0.0
		sw["vel"] += acc * delta
		sw["vel"] *= 1.0 - 0.15 * delta   # 공기 저항
		sw["angle"] += sw["vel"] * delta
		sw["angle"] = clampf(sw["angle"], -1.3, 1.3)
		(sw["pivot"] as Node3D).rotation.x = sw["angle"]
	if not riding.is_empty():
		var sw: Dictionary = riding
		var L: float = sw["len"]
		var pv: Node3D = sw["pivot"]
		var seat_world: Vector3 = pv.global_position + Vector3(0, -L * cos(sw["angle"]), -L * sin(sw["angle"]))   # x 축 회전: z 는 −L·sin(부호 버그 수정 — 몸이 그네와 반대로 갔다)
		body.global_position = seat_world + Vector3(0, -0.42 + 0.03, 0)   # 엉덩이가 좌석에
		body.velocity = Vector3.ZERO
		player.seated = false; player.pose_request = "swing"; player.swing_k = clampf(sw["vel"] / 3.0, -1.0, 1.0)
		player.face(0.0)
		player.rotation.x = sw["angle"]
		if Input.is_action_just_pressed("jump"):
			# 뛰어내리기: 접선 속도 그대로 + 위로
			var tang: Vector3 = Vector3(0, L * sin(sw["angle"]), -L * cos(sw["angle"])) * sw["vel"]
			body.velocity = tang * 1.15 + Vector3(0, 3.8, 0)
			riding = {}; player.pose_request = ""; sw["vel"] *= 0.35

func _weather(delta: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now >= weather_until:
		if _wrng.seed == 0: _wrng.seed = 20260928
		var r := _wrng.randf()
		weather = "rain" if (weather != "rain" and r < 0.35) else ("cloudy" if r < 0.6 else "clear")
		weather_until = now + _wrng.randf_range(150.0, 300.0)
		_apply_weather()
	if rain: rain.global_position = Vector3(body.global_position.x, 9.0, body.global_position.z)

func _apply_weather() -> void:
	if rain == null:
		rain = CPUParticles3D.new()
		rain.amount = 900; rain.lifetime = 1.4; rain.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX; rain.emission_box_extents = Vector3(14, 0.2, 10)
		rain.direction = Vector3(0.15, -1, 0); rain.spread = 3.0; rain.initial_velocity_min = 9.0; rain.initial_velocity_max = 11.0; rain.gravity = Vector3(0, -6, 0)
		rain.mesh = BoxMesh.new(); (rain.mesh as BoxMesh).size = Vector3(0.015, 0.22, 0.015)
		var rm := StandardMaterial3D.new(); rm.albedo_color = Color(0.62, 0.72, 0.8, 0.75); rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		rain.material_override = rm; rain.emitting = false; add_child(rain)
		wet = MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(WORLD_X * 2.0, WORLD_Z * 2.0 + 8.0); wet.mesh = pm
		var wm := StandardMaterial3D.new(); wm.albedo_color = Color(0.1, 0.12, 0.18, 0.0); wm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; wm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		wet.material_override = wm; wet.position = Vector3(0, 0.005, -2); add_child(wet)
	rain.emitting = weather == "rain"
	var tw := create_tween()
	tw.tween_property(wet.material_override, "albedo_color:a", 0.28 if weather == "rain" else (0.08 if weather == "cloudy" else 0.0), 2.0)
	for r in residents: r.on_weather(weather)

## 살아 있는 것은 움직인다 — 나무 잎이 바람에 흔들린다. 비·흐림이면 세게, 나무를 흔들면(shake_until) 그 나무가 크게
func _wind(delta: float) -> void:
	wind_t += delta
	var gust := 0.03 + (0.06 if weather == "cloudy" else (0.1 if weather == "rain" else 0.0))
	for c in crowns:
		var n: Node3D = c["node"]
		if not n.is_visible_in_tree(): continue
		var ph: float = c["phase"]
		var near := body.global_position.distance_to(n.global_position) < 1.6 and shake_until > 0.0
		var hit_t: float = c.get("hit_t", 0.0)
		if hit_t > 0.0: c["hit_t"] = hit_t - delta
		var amp: float = gust * (1.0 / float(c["k"])) + (0.12 if near else 0.0) + hit_t * 0.14   # 맞으면 잠깐 크게
		n.rotation.z = sin(wind_t * 1.7 + ph) * amp + sin(wind_t * 4.3 + ph * 2.0) * amp * 0.3 * (3.0 if (near or hit_t > 0.0) else 1.0)
		n.rotation.x = cos(wind_t * 1.3 + ph) * amp * 0.6

func _animals(delta: float) -> void:
	var p := body.global_position
	for a in animals:
		var n: Node3D = a["node"]
		if not n.is_visible_in_tree(): continue
		a["t"] += delta
		var d := p.distance_to(n.global_position)
		match a["kind"]:
			"duck":
				# 연못을 빙빙 헤엄치고, 사람이 2m 안이면 날개 치며 반대쪽으로 도망친다. 사과가 근처에 떨어져 있으면 먹으러 간다
				var bd: Bird3D = a["bird"]
				var ph: float = a["phase"] + a["t"] * 0.35
				var c: Vector3 = a["center"]
				var want := c + Vector3(cos(ph) * 2.0, 0, sin(ph) * 2.0)
				var scared := d < 2.0
				if scared: want = c + (n.global_position - p).normalized() * 2.6
				for it in items:
					if String(it.get_meta("kind", "")) == "apple" and it.global_position.distance_to(n.global_position) < 4.0:
						want = it.global_position
						if it.global_position.distance_to(n.global_position) < 0.35:
							items.erase(it); it.queue_free(); a["fed"] = a["t"] + 2.0
						break
				var before := n.global_position
				n.global_position = Vector3(lerpf(n.global_position.x, want.x, delta * (3.0 if scared else 1.5)), 0.03, lerpf(n.global_position.z, want.z, delta * (3.0 if scared else 1.5)))
				if want.distance_to(n.global_position) > 0.05:
					n.look_at(Vector3(want.x, n.global_position.y, want.z), Vector3.UP, true)
				bd.speed = n.global_position.distance_to(before) / maxf(delta, 0.001)
				bd.flying = scared; bd.swimming = not scared and n.global_position.distance_to(c) < 3.0; bd.feed = a.get("fed", 0.0) > a["t"]
			"fox":
				# 육식동물(운영자 2026-09-28): 새(비둘기·오리)를 살금살금 다가가 덮친다 — 새는 날아 도망. 사람이 때리면 6초간 쫓아와 문다
				var q: Quad3D = a["quad"]
				q.look = d < 5.0; q.look_at_pos = p + Vector3(0, 0.9, 0)
				var angry: bool = a.get("angry_until", 0.0) > a["t"]
				var want: Vector3 = a.get("wander", a["home"]); var spd := 0.0
				var stalking := false
				if angry:
					want = p; spd = 4.2
					if d < 0.9 and a.get("bite_at", 0.0) < a["t"]:
						a["bite_at"] = a["t"] + 1.1; q.act("bite"); resident_hits_player(n, (p - n.global_position).normalized())
				else:
					var prey: Dictionary = {}; var pd := 4.5
					for b in animals:
						if b["kind"] in ["pigeon", "duck"] and b.get("fly", 0.0) <= 0.0:
							var dd: float = (b["node"] as Node3D).global_position.distance_to(n.global_position)
							if dd < pd: pd = dd; prey = b
					if not prey.is_empty():
						want = (prey["node"] as Node3D).global_position
						stalking = pd > 1.8
						spd = 1.0 if stalking else 4.0   # 멀면 살금살금, 가까우면 덮친다
						if pd < 0.9:
							prey["fly"] = 1.6; prey["land"] = prey.get("home", want) + Vector3(randf_range(-3, 3), 0, randf_range(-2, 2)); q.act("bite")
							a["wander_until"] = a["t"] + 3.0; a["wander"] = n.global_position
					else:
						if a.get("wander_until", 0.0) < a["t"]:
							a["wander_until"] = a["t"] + randf_range(3.0, 7.0); a["wander"] = a["home"] + Vector3(randf_range(-6, 6), 0, randf_range(-4, 4))
						want = a.get("wander", a["home"]); spd = 1.3
				var to := want - n.global_position; to.y = 0.0
				if to.length() > 0.4 and spd > 0.0:
					n.global_position += to.normalized() * spd * delta
					n.look_at(n.global_position + to, Vector3.UP, true)
					q.speed = spd
					if q.state != "bite": q.state = "run" if spd > 2.5 else ("stalk" if stalking else "walk")
				else:
					q.speed = 0.0
					if q.state in ["walk", "run", "stalk"]: q.state = "idle"
			"dog", "cat", "marten", "squirrel":
				# 네발 동물 습성: 집 주변을 어슬렁(걷기/뛰기), 가끔 앉기·엎드리기·기지개·(개)놀자·구르기·(고양이)그루밍·등 세우기·하품,
				# 사람이 가까우면 쳐다보고: 개는 3초 따라오고, 고양이·담비는 1.4m 안이면 달아난다. 쓰다듬으면 앉아서 꼬리
				var q: Quad3D = a["quad"]
				var petted: bool = a.get("pet_until", 0.0) > a["t"]
				var shy: bool = a["kind"] != "dog"
				q.look = d < 4.0; q.look_at_pos = p + Vector3(0, 0.9, 0)
				var want: Vector3 = a.get("wander", a["home"])
				var spd := 0.0
				if petted:
					q.state = "sit"; q.look = true
				elif a["kind"] == "dog" and d < 3.0 and a.get("follow_until", 0.0) < a["t"]:
					a["follow_until"] = a["t"] + 3.0
				if not petted:
					if a["kind"] == "dog" and a.get("follow_until", 0.0) > a["t"]:
						want = p + (n.global_position - p).normalized() * 1.1; spd = 2.6
					elif shy and d < 1.4:
						want = n.global_position + (n.global_position - p).normalized() * 3.0; spd = 3.4; a["flee_until"] = a["t"] + 1.5
					elif a.get("flee_until", 0.0) > a["t"]:
						spd = 3.4
					else:
						if a.get("wander_until", 0.0) < a["t"]:
							a["wander_until"] = a["t"] + randf_range(2.5, 6.0)
							var r := randf()
							if r < 0.55:
								a["wander"] = a["home"] + Vector3(randf_range(-4, 4), 0, randf_range(-3, 3)); a["idle_act"] = ""
							else:
								# 서서 하는 동작 하나
								var acts: Array = ["sit", "lie", "stretch", "yawn"] + (["bow", "roll"] if a["kind"] == "dog" else ["groom", "arch"])
								a["idle_act"] = acts[randi() % acts.size()]; a["wander"] = n.global_position
								q.act(a["idle_act"])
						want = a.get("wander", a["home"]); spd = 1.4
					var to := want - n.global_position; to.y = 0.0
					if to.length() > 0.3 and spd > 0.0:
						n.global_position += to.normalized() * spd * delta
						n.look_at(n.global_position + to, Vector3.UP, true)
						q.speed = spd; q.state = "run" if spd > 2.2 else "walk"
					else:
						q.speed = 0.0
						if q.state in ["walk", "run"]: q.state = "idle"
			_:
				# 비둘기: 바닥을 쫀다(리그가 스스로), 1.6m 안이면 날아올라 3m 옆으로 갔다 내려앉는다, 가끔 종종걸음
				var bd: Bird3D = a["bird"]
				if d < 1.6 and a["fly"] <= 0.0:
					a["fly"] = 1.6; a["land"] = a["home"] + Vector3(randf_range(-3, 3), 0, randf_range(-2, 2))
				var before := n.global_position
				if a["fly"] > 0.0:
					a["fly"] -= delta
					var k: float = 1.0 - a["fly"] / 1.6
					var land: Vector3 = a["land"]
					n.global_position = Vector3(lerpf(n.global_position.x, land.x, delta * 2.5), sin(k * PI) * 1.4, lerpf(n.global_position.z, land.z, delta * 2.5))
					var to := land - n.global_position; to.y = 0.0
					if to.length() > 0.1: n.look_at(n.global_position + to, Vector3.UP, true)
					if a["fly"] <= 0.0: a["home"] = land; n.position.y = 0.0
				else:
					n.position.y = 0.0
					if fmod(a["t"], 4.0) < 1.2:
						var step := Vector3(sin(a["t"] * 3.0), 0, cos(a["t"] * 2.0)) * 0.3 * delta
						n.global_position += step
						if step.length() > 0.0001: n.look_at(n.global_position + step, Vector3.UP, true)
				bd.flying = a["fly"] > 0.0
				bd.speed = 0.0 if bd.flying else Vector2(n.global_position.x - before.x, n.global_position.z - before.z).length() / maxf(delta, 0.001)

## 주민이 나를 친다 — 같은 규칙: 움찔, 3초 안에 세 대면 넘어진다
func resident_hits_player(_r: Node3D, dir: Vector3) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if down_until > now or getup_until > now: return
	if now - my_last_hit > 3.0: my_hits = 0
	my_hits += 1; my_last_hit = now
	jet = false; throw_charge = -1.0; seat = {}; player.seated = false
	if my_hits >= 3:
		my_hits = 0
		down_until = now + 1.6; player.lying = true; player.action = ""; action_until = now
		body.velocity = dir * 3.5 + Vector3(0, 2.0, 0)
		if player.carrying:
			var it: Node3D = player.release(self, body.global_position + dir * 0.6 + Vector3(0, 0.1, 0)); items.append(it)
	else:
		player.action = "flinch"; action_until = now + 0.3
		body.velocity = dir * 1.6
	cam_kick = 0.05

## 사람이 동물을 때리면(타격 판정에서 호출) — 여우는 화난다, 나머지는 달아난다
func animal_hit(a: Dictionary, dir: Vector3) -> void:
	if a["kind"] == "fox": a["angry_until"] = a["t"] + 6.0
	else: a["flee_until"] = a["t"] + 2.0
	(a["node"] as Node3D).global_position += dir * 0.4

## 낮밤 — 해가 한 바퀴 돌고(12분), 저녁엔 빛이 붉어지며 가로등·실내 램프가 켜진다
func _daylight(delta: float) -> void:
	clock = fmod(clock + delta / DAY_LEN, 1.0)
	if _sun == null: return
	var ang := clock * TAU
	_sun.rotation_degrees = Vector3(-10.0 - 60.0 * maxf(0.0, sin(ang)), 28.0 + clock * 120.0, 0)
	var day := clampf(sin(ang) * 1.6 + 0.2, 0.0, 1.0)
	if weather == "rain": day *= 0.55
	elif weather == "cloudy": day *= 0.8
	_sun.light_energy = 0.12 + 0.6 * day   # 낮 최대 0.72 — 앰비언트와 합쳐 1.1배 근처(그 위는 밝은 색이 흰색으로 클리핑)
	_sun.light_color = Color(1.0, 0.86 + 0.14 * day, 0.72 + 0.28 * day)
	var env := ($WorldEnvironment as WorldEnvironment).environment
	env.ambient_light_energy = 0.15 + 0.15 * day
	env.background_color = Color(0.93, 0.94, 0.92, 1).lerp(Color(0.12, 0.10, 0.16, 1), 1.0 - day)
	var night := day < 0.35
	for l in lamps:
		l.visible = night; l.light_energy = 1.3 if night else 0.0

## 문 열기/닫기 — 사람도 주민도 이걸 쓴다
func set_door(dr: Dictionary, open: bool) -> void:
	if dr["open"] == open: return
	dr["open"] = open
	var tw := create_tween(); tw.set_ease(Tween.EASE_OUT); tw.set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(dr["hinge"], "rotation:y", 1.85 if open else 0.0, 0.45)

## 던져진 것의 포물선 — 중력, 바닥에 닿으면 멈추고 다시 집을 수 있는 목록으로
func _fly(delta: float) -> void:
	for f in flying.duplicate():
		var n: Node3D = f["node"]
		f["vel"] += Vector3(0, -G, 0) * delta
		n.global_position += f["vel"] * delta
		n.rotation.x += f["spin"] * delta
		if n.global_position.y <= 0.06:
			n.global_position.y = 0.06
			n.rotation = Vector3.ZERO
			flying.erase(f)
			items.append(n)

func is_night() -> bool:
	return sin(clock * TAU) * 1.6 + 0.2 < 0.35

func _hud(now: float) -> void:
	if now - _hud_at < 0.5: return
	_hud_at = now
	var c := { "routine": 0, "walk": 0, "busy": 0, "chase": 0, "down": 0, "getup": 0 }
	for r in residents: c[r.state] = c.get(r.state, 0) + 1
	var hour := int(fmod(clock * 24.0 + 6.0, 24.0))
	var leg := get_node_or_null("UI/Legend") as Label
	if leg: leg.text = "← → ↑ ↓ move · SPACE jump (hold: higher) · X punch · Z kick · C use · V view   |   %02d:00 · %s · residents walk %d busy %d chase %d down %d" % [hour, weather, c["walk"], c["busy"], c["chase"], c["down"]]
