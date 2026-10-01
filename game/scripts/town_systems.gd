class_name TownSystems
extends TownCritters
## 매 프레임 도는 세계 시스템 — 낮밤, 날씨, 바람(나무), 동물 습성, 그네 물리, 컷어웨이, 구역 스트리밍, 던져진 물건, 범례.

## 매 프레임 도는 세계 — 조작이 어느 가지로 빠져나가든(앉음·넘어짐·그네·거룻배) 세계는 멈추지 않는다
## (run 78: 전엔 town_player 의 앉기·그네·넘어짐 가지가 이 호출들 앞에서 return 해 벤치에 앉거나 그네를 타는 동안 낮밤·날씨·동물·강물·굴뚝이 다 멈췄다)
func _tick(delta: float, now: float) -> void:
	_fly(delta)
	_cutaway()
	_daylight(delta)
	_stream()
	_weather(delta)
	_animals(delta)
	_swings(delta)
	_wind(delta)
	_crops(now)
	_bakery(now)
	_smoke(now)
	_boats(delta, now)
	_trades(delta, now)
	_water(delta)
	_seesaws(delta)
	if has_method("_meal_tick"): call("_meal_tick", now)   # 위층(town_meals)

## 스트리밍(첫 단계): 플레이어에서 34m 넘게 먼 구역은 끈다 — 그리기·물리·주민 처리 비용이 빠진다. 씬 단위 로딩은 맵이 더 커질 때
func _stream() -> void:
	var p := focus_pos()
	gen.stream(p)   # 열린 세계 칸 — 둘레를 짓고 먼 칸을 지운다
	for d in districts:
		var on: bool = Vector2(p.x - d["center"].x, p.z - d["center"].z).length() < 48.0   # 열린 세계의 장소는 남북으로도 멀다 — x 만 보면 북쪽 탑이 늘 켜져 있었다
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
		var open := inside or behind   # near 는 뺐다 — 집 앞에 서기만 해도 지붕이 열려 안이 다 보였다(운영자 2026-09-29)   # 집 가까이 가면 열린다 — 안에서 쉬는 주민이 보이게(운영자: 들어가면 사라진다)
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

## 시소 — 판 물리, 주민 탑승자는 낮을 때 박차고, 튀어 오른 사람은 날려 보낸다
func _seesaws(delta: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	for ss in seesaws:
		for i in 2:
			var r = ss.riders[i]
			if r is Resident and ss.riders[1 - i] != null and now > float(r.get_meta("ss_push_at", 0.0)):   # 짝이 있을 때만 박찬다
				r.set_meta("ss_push_at", now + randf_range(0.9, 1.5)); ss.push(i)
		for l in ss.step(delta):
			var vy: float = l["vy"]
			if l["who"] is Resident:
				var r: Resident = l["who"]; r.seesaw_launch(vy)
			elif l["who"] == "player":
				seesaw_ride = null; resting = false; player.seated = false; player.pose_request = ""
				body.collision_layer = 4; body.collision_mask = 7
				body.velocity = Vector3(0, vy, 0.6); was_airborne = true; player.squash = 1.0
				say_toast("Up you go.")

## 짧은 한 줄(시소 등) — 지금은 출력만, UI 토스트가 생기면 그리로
func say_toast(t: String) -> void:
	print("TOAST ", t)

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
			dismount(); sw["vel"] *= 0.35
			if absf(sw["angle"]) > 0.8:
				# 꼭대기에서 뛰면 몸이 뒤집혀 누운 채 떨어지고 잠깐 아파하다 일어난다(운영자 2026-09-29). 낮을 때 뛰면 보통 착지
				down_until = Time.get_ticks_msec() / 1000.0 + 1.3; player.lying = true; player.action = ""

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
	gust = 0.03 + (0.06 if weather == "cloudy" else (0.1 if weather == "rain" else 0.0))
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
		if a.has("lv"):
			# 차에 치여 날아간다: 포물선·공중 회전, 닿으면 기절했다 일어난다
			var lv: Vector3 = a["lv"]; lv.y -= 18.0 * delta; n.global_position += lv * delta; n.rotation.z += delta * 9.0
			if n.global_position.y <= 0.0 and lv.y < 0.0:
				n.global_position.y = 0.0; lv = Vector3(lv.x * 0.4, 0.0, lv.z * 0.4)
				if lv.length() < 0.5:
					a.erase("lv"); n.rotation.z = 0.0; a["stun_until"] = a["t"] + float(a.get("stun_for", 2.0))
					var qa = a["quad"]; qa.act("stun" if qa is Animal3D else "lie"); continue
			a["lv"] = lv; continue
		if a.get("stun_until", 0.0) > a["t"]: continue
		var d := p.distance_to(n.global_position)
		# 달리는 차가 가까우면 차 진행 방향 옆으로 도망친다. 한 번 치인 동물은 30초 동안 멀리서부터 피한다(일어나자마자 다시 치이던 것)
		var fled := false
		for car in cars:
			if absf(car.v) < 1.0: continue
			var to_a: Vector3 = n.global_position - car.global_position; to_a.y = 0.0
			var fear: float = 9.0 if a.get("car_fear_until", 0.0) > a["t"] else 5.0
			if to_a.length() < fear:
				var cf := -car.global_transform.basis.z * signf(car.v)
				var away := car.global_transform.basis.x * signf(car.global_transform.basis.x.dot(to_a)) + cf * 0.3
				n.global_position += away.normalized() * 3.6 * delta
				n.look_at(n.global_position + away, Vector3.UP, true)
				if a.has("quad"): a["quad"].speed = 3.6; a["quad"].state = "run"
				elif a.has("bird"): a["bird"].flying = true
				a["follow_until"] = 0.0; fled = true; break
		if fled: continue
		if driving: a["follow_until"] = 0.0   # 차를 따라오지 않는다
		match a["kind"]:
			"duck":
				# 연못을 빙빙 헤엄치고, 사람이 2m 안이면 날개 치며 반대쪽으로 도망친다. 사과가 근처에 떨어져 있으면 먹으러 간다
				var bd = a["bird"]   # Bird3D 또는 Animal3D — 같은 속성
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
				_fox(a, delta)
			"dog", "cat", "marten", "squirrel", "wolf", "deer":
				# 네발 동물 습성: 집 주변을 어슬렁(걷기/뛰기), 가끔 앉기·엎드리기·기지개·(개)놀자·구르기·(고양이)그루밍·등 세우기·하품,
				# 사람이 가까우면 쳐다보고: 개는 3초 따라오고, 고양이·담비는 1.4m 안이면 달아난다. 쓰다듬으면 앉아서 꼬리
				var q = a["quad"]   # Quad3D 또는 Animal3D — 같은 상태 API
				var petted: bool = a.get("pet_until", 0.0) > a["t"]
				var shy: bool = a["kind"] != "dog"
				q.sulk = a.get("sulk_until", 0.0) > a["t"]   # 맞은 뒤 한동안 꼬리를 내리고 따라오지 않는다
				var frozen: bool = a.get("freeze_until", 0.0) > a["t"]   # 아파하는 0.5초는 제자리
				q.look = d < 4.0; q.look_at_pos = p + Vector3(0, 0.9, 0)
				var want: Vector3 = a.get("wander", a["home"])
				var spd := 0.0
				if petted:
					if q.state != "pet": q.act("pet")
					q.look = true
				elif a["kind"] == "dog" and d < 3.0 and a.get("follow_until", 0.0) < a["t"] and not q.sulk:
					a["follow_until"] = a["t"] + 3.0
				if not petted:
					if a["kind"] == "dog" and a.get("follow_until", 0.0) > a["t"]:
						if d < 3.0: a["follow_until"] = a["t"] + 3.0   # 곁에 있는 동안은 계속
						if d > 1.5:
							want = p + (n.global_position - p).normalized() * 1.1; spd = 3.2 if d > 3.5 else 1.6   # 멀면 달려오고 가까우면 걸어온다
						else:
							# 애교(운영자 2026-09-29: "달려오기만 하잖아"): 곁에서 2~4초마다 하나 — 빙글 돌기·놀자·뒹굴기·발치에 코 비비기·앉아 올려다보기·폴짝
							if a.get("aff_until", 0.0) < a["t"]:
								a["aff_until"] = a["t"] + randf_range(2.0, 4.0)
								var affs: Array = ["circle", "bow", "nuzzle", "beg", "hop", "circle", "nuzzle", "bow"]   # 뒹굴기는 아직 어색해 뺌
								a["aff"] = affs[randi() % affs.size()]
								if a["aff"] != "circle": q.act(a["aff"])
							if a["aff"] == "circle":
								var ang := atan2(n.global_position.z - p.z, n.global_position.x - p.x) + delta * 1.8
								want = p + Vector3(cos(ang), 0, sin(ang)) * 1.0; spd = 1.5
							else:
								want = n.global_position; spd = 0.0
								n.look_at(Vector3(p.x, n.global_position.y, p.z), Vector3.UP, true)   # 사람 쪽을 본다
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
								var acts: Array = ["sit", "lie", "stretch", "yawn", "scratch"] + (["bow", "roll", "sniff", "sniff", "shake"] if a["kind"] == "dog" else ["groom", "arch"])
								a["idle_act"] = acts[randi() % acts.size()]; a["wander"] = n.global_position
								q.act(a["idle_act"])
						want = a.get("wander", a["home"]); spd = 1.4
					if frozen: spd = 0.0
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
				var bd = a["bird"]   # Bird3D 또는 Animal3D — 같은 속성
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

## 던져진 것의 포물선 — 중력, 바닥(전망 언덕 위면 선반, ground_y)에 닿으면 멈추고 다시 집을 수 있는 목록으로. 바위 낯에 부딪히면 그 자리에서 곧장 떨어진다
func _fly(delta: float) -> void:
	for f in flying.duplicate():
		var n: Node3D = f["node"]
		f["vel"] += Vector3(0, -G, 0) * delta
		var prev := n.global_position
		n.global_position += f["vel"] * delta
		if f.has("axis"): n.rotate(f["axis"], f["spin"] * delta)   # 파편은 아무 축으로나 구른다
		else: n.rotation.x += f["spin"] * delta
		var gy := ground_y(n.global_position)
		if n.global_position.y < gy - 0.06 and ground_y(prev) < gy:
			n.global_position.x = prev.x; n.global_position.z = prev.z; f["vel"].x = 0.0; f["vel"].z = 0.0; gy = ground_y(prev)   # 전망 언덕 바위 낯에 부딪히면 그 자리에서 떨어진다(CI run 73)
		if n.global_position.y <= gy + 0.06:
			n.global_position.y = gy + 0.06
			if int(f.get("bounce", 0)) > 0 and f["vel"].y < -2.0:
				f["bounce"] = int(f["bounce"]) - 1; f["vel"] = Vector3(f["vel"].x * 0.5, -f["vel"].y * 0.35, f["vel"].z * 0.5); f["spin"] *= 0.5; continue   # 한 번 튄다
			flying.erase(f)
			if n.has_meta("fade"):
				var tw := n.create_tween(); tw.tween_interval(2.0); tw.tween_property(n, "scale", Vector3.ZERO, 0.6); tw.tween_callback(n.queue_free)
				continue
			if n.has_meta("debris"): continue   # 부서진 조각은 누운 채 남는다(주울 수 없고, 수리공이 치운다)
			n.rotation = Vector3.ZERO
			items.append(n)

## 물에 떨어진 물건은 떠서 강물과 흘러가다 세계 끝에서 사라진다(강가에서 건지지 않으면 잃는다); 연못에선 제자리에 떠 있다
func _water(delta: float) -> void:
	for it in items.duplicate():
		if in_water(it.global_position):
			var river: bool = absf(it.global_position.z - RIVER_Z) < RIVER_HW
			if river: it.global_position += Vector3(0.35 * delta, 0, 0)
			it.global_position.y = 0.06 + sin(wind_t * 3.0 + it.global_position.x) * 0.01
			if it.global_position.x > WORLD_X + 6.0: items.erase(it); it.queue_free()

func is_night() -> bool:
	return sin(clock * TAU) * 1.6 + 0.2 < 0.35

func _hud(now: float) -> void:
	if now - _hud_at < 0.5: return
	_hud_at = now
	var c := { "routine": 0, "walk": 0, "busy": 0, "chase": 0, "down": 0, "getup": 0 }
	for r in residents: c[r.state] = c.get(r.state, 0) + 1
	var hour := int(fmod(clock * 24.0 + 6.0, 24.0))
	var leg := get_node_or_null("UI/Legend") as Label
	if leg: leg.text = "← → ↑ ↓ move · SPACE jump (hold: higher) · X punch · Z kick · C use   |   %02d:00 · %s · residents walk %d busy %d chase %d down %d" % [hour, weather, c["walk"], c["busy"], c["chase"], c["down"]]

