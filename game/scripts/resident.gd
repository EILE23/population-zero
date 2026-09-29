class_name Resident
extends ResidentBase
## 주민의 일과 — 자리를 골라 걸어가 벤치에 앉고, 가로등에 기대고, 나무를 흔들고, 텃밭에 물을 주고, 빵집에서 빵을 사 먹고, 다음 자리로 간다.
## 넘어지면 일어나서 때린 사람을 쫓다가 포기한다. 몸·상태·맞음·인사는 resident_base.gd.

func _physics_process(delta: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if say_label.visible and now > say_until:
		say_label.visible = false
	var v := velocity
	if not is_on_floor():
		v.y -= 22.0 * delta
	else:
		v.y = 0.0
	fig.airborne = not is_on_floor(); fig.vertical = v.y
	# 동작(주먹·집기)은 상태와 무관하게 끝나면 지운다 — 쫓다가 포기하면 주먹 자세가 남던 버그
	if fig.action == "punch" or fig.action == "grab":
		if now >= busy_until:
			fig.action = ""; fig.action_t = 0.0
		else:
			fig.action_t = 1.0 - (busy_until - now) / 0.28
	match state:
		"routine":
			v.x = 0.0; v.z = 0.0; fig.move_dir = Vector3.ZERO; fig.speed = 0.0   # 쫓다 포기한 뒤 달리던 속도가 남아 1초 더 미끄러지던 것
			if now >= busy_until:
				_pick_spot()
		"walk":
			var to := target - global_position; to.y = 0.0
			if to.length() < 0.35:
				var step: Dictionary = route.pop_front() if not route.is_empty() else {}
				if step.get("act", "") == "open": town.set_door(door_ref, true)
				elif step.get("act", "") == "close": town.set_door(door_ref, false)
				detours = 0; stuck_since = -1.0   # 경유지가 바뀌면 막힘 판정도 새로 — 다음 경유지가 더 멀면 '못 다가갔다'로 읽혀 헛우회했다
				if route.is_empty():
					if step.get("act", "") == "close":
						state = "routine"; busy_until = now + randf_range(0.5, 2.0)
					else:
						_arrive(now)
				else:
					target = route[0]["pos"]
			else:
				var dir := to.normalized()
				var spd := WALK * (1.7 if weather == "rain" else 1.0)  # 비 오면 서두른다
				v.x = dir.x * spd; v.z = dir.z * spd
				fig.move_dir = dir; fig.speed = Vector2(velocity.x, velocity.z).length()   # 걸음은 실제 속도로 — 벽에 막히면 제자리 뛰기가 안 난다
				# 막힘은 진행 거리로 판단: 1.2초 동안 목표에 0.15m 도 못 다가가면 옆으로 우회 지점을 하나 두고, 두 번째면 포기
				if stuck_since < 0.0:
					stuck_since = now; stuck_dist = to.length()
				elif now - stuck_since > 1.2:
					if stuck_dist - to.length() < 0.15:
						if detours < 2:
							detours += 1
							var side := Vector3(-dir.z, 0, dir.x) * (1.6 if (uid + detours) % 2 == 0 else -1.6)
							route.push_front({ "pos": global_position + side + dir * 0.8, "act": "" })
							target = route[0]["pos"]
						else:
							detours = 0; _release(); state = "routine"; busy_until = now; route = []
					stuck_since = -1.0
		"busy":
			v.x = 0.0; v.z = 0.0
			fig.move_dir = Vector3.ZERO; fig.speed = 0.0
			if not riding_swing.is_empty():
				global_position = town.swing_seat(riding_swing) + Vector3(0, -0.39, 0)
				fig.swing_k = clampf(riding_swing["vel"] / 3.0, -1.0, 1.0); fig.rotation.x = riding_swing["angle"]
				v.y = 0.0
			else:
				fig.rotation.x = 0.0
			if bites > 0 and now >= bite_at: _bite(now)
			if now >= busy_until:
				_leave()
		"down":
			v.x = lerpf(v.x, 0.0, 0.2); v.z = lerpf(v.z, 0.0, 0.2)
			fig.move_dir = Vector3.ZERO; fig.speed = 0.0
			if now >= down_until:
				fig.lying = false; fig.action = "getup"; fig.action_t = 0.0
				state = "getup"; busy_until = now + 0.6
		"getup":
			v.x = 0.0; v.z = 0.0
			fig.action_t = 1.0 - (busy_until - now) / 0.6
			if now >= busy_until:
				fig.action = ""; fig.action_t = 0.0
				if quarry and randf() < 0.65:
					state = "chase"; chase_until = now + 4.5; say(LINES_HIT[uid % LINES_HIT.size()])
				else:
					state = "routine"; busy_until = now + 0.5
		"chase":
			if quarry == null or now >= chase_until:
				say(LINES_GIVEUP[uid % LINES_GIVEUP.size()]); quarry = null
				fig.action = ""; fig.action_t = 0.0
				state = "routine"; busy_until = now + 1.0
			else:
				var to := quarry.global_position - global_position; to.y = 0.0
				var d := to.length()
				var dir := to.normalized()
				if d > REACH:
					v.x = dir.x * RUN; v.z = dir.z * RUN
					fig.move_dir = dir; fig.speed = RUN
				else:
					v.x = 0.0; v.z = 0.0
					fig.move_dir = dir; fig.speed = 0.0
					fig.face(atan2(dir.x, dir.z))
					if now >= next_punch:
						next_punch = now + 0.55
						fig.punch_side = -fig.punch_side; fig.punch_kind = "jab" if fig.punch_side < 0.0 else "cross"
						fig.action = "punch"; fig.action_t = 0.0; busy_until = now + 0.28
						town.resident_hits_player(self, dir)
	if state == "walk" or state == "chase":
		for o in town.residents:
			if o == self: continue
			var dv: Vector3 = global_position - o.global_position; dv.y = 0.0
			var dl := dv.length()
			if dl < 0.5 and dl > 0.001:
				v += dv.normalized() * (0.5 - dl) * 6.0   # 가까울수록 세게 비킨다
	velocity = v
	if fig.seated or not riding_swing.is_empty():
		return   # 앉거나 그네를 탈 땐 물리로 밀리지 않는다
	if is_on_floor() and Vector2(v.x, v.z).length() > 0.1:
		town.step_up(self, Vector3(v.x, 0, v.z) * delta)   # 턱·문지방·계단 오르기(사람과 같은 규칙)
	move_and_slide()

## 날씨 바뀜 — 비면 지금 하던 걸 접고 실내로 서두른다(밖 자리에 있었으면 바로 다시 고른다)
func on_weather(w: String) -> void:
	weather = w
	if w != "rain" or not (state in ["busy", "walk", "routine"]) or spot.get("kind", "") in ["chair", "bed", "shelf"]:
		return
	# _leave 로 자리를 제대로 비운다 — 전엔 seated 만 풀어서 그네 rider 가 남아 비 온 뒤 그네가 영영 차 있었고, 걸어가던 목표 칸도 새어 나갔다
	if state == "busy": _leave()
	else: _release()
	state = "routine"; busy_until = Time.get_ticks_msec() / 1000.0 + randf_range(0.0, 1.5)
	say(["Rain.", "Of course.", "Inside, then."][uid % 3], 1.5)

## 집 안에서 자리를 잃었으면(안에서 인사받거나 맞아서) 다음 자리를 고르기 전에 문으로 나온다 — 전엔 벽을 향해 곧장 걷다 막혀 포기하기를 되풀이했다
func _exit_house() -> bool:
	var p := global_position
	for h in town.houses:
		var mn: Vector3 = h["min"]; var mx: Vector3 = h["max"]
		if p.x <= mn.x or p.x >= mx.x or p.z <= mn.z or p.z >= mx.z or p.y >= mx.y: continue
		for dr in town.doors:
			var dp: Vector3 = dr["pos"]
			if dp.x > mn.x and dp.x < mx.x and absf(dp.z - mx.z) < 0.5:
				door_ref = dr; spot = { "kind": "exit" }
				route = [{ "pos": dp + Vector3(0, 0, -0.6), "act": "open" }, { "pos": dp + Vector3(0, 0, 0.8), "act": "close" }]
				target = route[0]["pos"]; state = "walk"
				return true
	return false

func _pick_spot() -> void:
	if town.spots.is_empty():
		busy_until = Time.get_ticks_msec() / 1000.0 + 3.0; return
	if _exit_house(): return
	if town.is_night() and not home_door.is_empty():
		# 밤: 집으로 가서 침대에 눕는다(집에 침대가 있으면), 아니면 의자
		var mine: Array = town.spots.filter(func(sp): return sp.has("door") and sp["door"] == home_door and sp["kind"] == "bed")
		if mine.is_empty(): mine = town.spots.filter(func(sp): return sp.has("door") and sp["door"] == home_door)
		mine = mine.filter(func(sp): return _free_slot(sp) >= 0)
		if not mine.is_empty():
			spot = mine[0]; slot = 0; _claim(spot, 0)
			door_ref = home_door
			var dp: Vector3 = door_ref["pos"]
			route = town.crossings(global_position, dp) + _approach(door_ref) + [{ "pos": dp + Vector3(0, 0, 0.8), "act": "open" }, { "pos": dp + Vector3(0, 0, -0.6), "act": "" }, { "pos": spot["pos"] + Vector3(0, 0, 0.35), "act": "" }]
			target = route[0]["pos"]; state = "walk"; return
	if job == "baker" and not town.is_night() and weather != "rain":
		# 빵집 주인(run 72): 창구가 덜 찼으면 화덕으로 — 일은 장소에 매인다. 비엔 화덕(바깥)을 쉰다
		var ov: Dictionary = town.bake_spot(self)
		if not ov.is_empty():
			spot = ov; slot = 0; _claim(spot, 0)
			route = town.crossings(global_position, spot["pos"]) + [{ "pos": spot["pos"] + Vector3(0, 0, 0.4), "act": "" }]
			target = route[0]["pos"]; state = "walk"; return
	var pool: Array = town.spots.filter(func(sp): return sp["kind"] != "oven")   # 화덕은 빵집 주인이 일부러 간다(위) — 산책 자리가 아니다
	if weather == "rain":
		# 비: 실내(의자·침대·선반) 아니면 차양 아래(문 앞)만 고른다
		pool = town.spots.filter(func(sp): return sp["kind"] in ["chair", "bed", "shelf", "door"])
		if pool.is_empty(): pool = town.spots
	# 찬 자리는 빼고 고른다(운영자: 주민끼리 겹쳐 있으면 안 된다)
	var free: Array = pool.filter(func(sp): return _free_slot(sp) >= 0)
	if free.is_empty():
		busy_until = Time.get_ticks_msec() / 1000.0 + 2.0; return
	spot = free[randi() % free.size()]
	slot = _free_slot(spot)
	_claim(spot, slot)
	route = []
	if (spot["kind"] == "chair" or spot["kind"] == "bed" or spot["kind"] == "shelf") and spot.has("door"):
		# 집 안 의자: (집 앞이 아니면 모서리를 돌아) 문 앞 → 문 열기 → 의자. 나올 땐 _leave 가 반대로
		door_ref = spot["door"]
		var dp: Vector3 = door_ref["pos"]
		route = _approach(door_ref) + [{ "pos": dp + Vector3(0, 0, 0.8), "act": "open" }, { "pos": dp + Vector3(0, 0, -0.6), "act": "" }, { "pos": spot["pos"] + Vector3(0, 0, 0.35), "act": "" }]
	elif spot["kind"] == "bench":
		route = [{ "pos": spot["pos"] + Vector3([-0.45, 0.0, 0.45][slot], 0, 0.45), "act": "" }]
	elif spot["kind"] == "door":
		var near_door: Dictionary = {}
		for dr in town.doors:
			if (dr["pos"] as Vector3).distance_to(spot["pos"]) < 1.2: near_door = dr; break
		route = (_approach(near_door) if not near_door.is_empty() else []) + [{ "pos": spot["pos"] + Vector3(randf_range(-0.2, 0.2), 0, 0.2), "act": "" }]
	else:
		route = [{ "pos": spot["pos"] + Vector3(randf_range(-0.2, 0.2), 0, 0.5), "act": "" }]
	route = town.crossings(global_position, spot["pos"]) + route   # 강 건너 자리면 다리로(곧장 가면 물 위 벽에 막혀 포기했다)
	target = route[0]["pos"]
	state = "walk"

func _arrive(now: float) -> void:
	state = "busy"
	fig.pose_request = ""
	match spot["kind"]:
		"bench":
			fig.seated = true; collision_layer = 0; collision_mask = 0
			global_position = spot["pos"] + Vector3([-0.45, 0.0, 0.45][slot], 0.05, 0.02)
			fig.face(spot.get("yaw", 0.0))
			busy_until = now + randf_range(6.0, 14.0)
		"swing":
			var sw: Dictionary = spot["swing"]
			if sw["rider"] == null:
				sw["rider"] = self; riding_swing = sw
				fig.pose_request = "swing"; fig.face(0.0)
				busy_until = now + randf_range(10.0, 25.0)
			else:
				# 누가 타고 있으면 뒤에서 밀어 준다
				go_push(sw)
		"chair":
			fig.seated = true; collision_layer = 0; collision_mask = 0
			global_position = spot["pos"] + Vector3(0, 0.05, 0.02)
			fig.face(spot.get("yaw", 0.0))
			busy_until = now + randf_range(6.0, 12.0)
		"bed":
			fig.pose_request = "rest"
			global_position = spot["pos"] + Vector3(0, 0.02, 0)
			fig.face(spot.get("yaw", 0.0))
			busy_until = now + (randf_range(60.0, 120.0) if town.is_night() else randf_range(8.0, 16.0))
		"shelf":
			fig.pose_request = "read"; fig.face(spot.get("yaw", PI))
			busy_until = now + randf_range(4.0, 8.0)
		"push":
			fig.pose_request = "push"; fig.face(0.0)
			busy_until = now + randf_range(12.0, 20.0)
		"lamp":
			fig.pose_request = "lean"; fig.face(spot.get("yaw", 0.0))
			busy_until = now + randf_range(4.0, 9.0)
		"tree":
			fig.pose_request = "shake"; fig.face(atan2(spot["pos"].x - global_position.x, spot["pos"].z - global_position.z))
			busy_until = now + randf_range(1.5, 3.0)
		"oven":
			# 화덕(run 72): 창구에 모자란 만큼(최대 셋) 반죽 — 한 바퀴(KNEAD_T)에 빵 하나가 창구에 오른다(town_places _bakery). 사람이 C 로 하는 것과 같은 자세·같은 효과
			var n: int = maxi(1, 3 - int((town.oven["counter"] as Dictionary).get("stock", 0)))
			fig.pose_request = "knead"; fig.face(spot.get("yaw", PI))
			town.bake(now, n, self); busy_until = now + StickPoses.KNEAD_T * n + 0.3
			say(["Kneading.", "Give it a minute.", "Flour everywhere."][uid % 3], 1.6)
		"counter":
			# 창구(run 72): 빈손이고 재고가 있는 창구(빵집)면 빵을 받아 세 입에 먹는다(사람과 같은 eat 자세, 한입마다 작아진다 — _bite). 비었으면 "Sold out."
			# 카페 창구(재고 없음)는 아직 서서 구경만 — 컵을 비우는 조각(비전 5단계)이 오면 같은 길로 마신다
			fig.face(spot.get("yaw", PI))
			if fig.carrying or not spot.has("stock"):
				busy_until = now + randf_range(2.0, 4.0)
			elif town.counter_take(spot):
				carrying_kind = String(spot["item"]); fig.hold(town.make_item(carrying_kind, Vector3.ZERO))
				bites = 3; bite_at = now + 0.9; busy_until = now + 0.9 * 3 + 1.2
				say(["One, please.", "The usual.", "Still warm?"][uid % 3], 1.4)
			else:
				busy_until = now + 2.0
				say(["Sold out.", "Nothing left.", "Could someone knead one?"][uid % 3], 1.8)
		"plot":
			# 텃밭(run 70): 빈손이고 익었으면 딴다, 빈손이면 물뿌리개를 꺼내 들고 물을 준다(사람과 같은 water 자세·같은 효과), 뭘 들고 있으면 구경만
			var row: Dictionary = town.rows[int(spot["row"])]
			fig.face(spot.get("yaw", PI))
			if not fig.carrying and int(row["stage"]) >= 3:
				carrying_kind = town.pick_row(row); fig.hold(town.make_item(carrying_kind, Vector3.ZERO))
				fig.action = "grab"; fig.action_t = 0.0; busy_until = now + 0.28; say("Ripe.", 1.4)
			elif not fig.carrying:
				fig.hold(town.make_item("can", Vector3.ZERO)); can_mine = true
				fig.pose_request = "water"; town.water_row(row, now); busy_until = now + StickPoses.WATER_T + 0.3
				say(["Mind the rows.", "Dry week.", "There."][uid % 3], 1.6)
			else:
				busy_until = now + randf_range(2.0, 4.0)
		_:
			fig.face(spot.get("yaw", PI))
			busy_until = now + randf_range(2.0, 5.0)

## 한입(run 72) — 사람의 먹기와 같은 규칙: eat 자세, 한입마다 0.27 씩 작아지고 세 입이면 사라진다. 맞아서 떨어뜨리면(hit) 남은 입은 없다
func _bite(now: float) -> void:
	bites -= 1; bite_at = now + 0.9
	if fig.carrying == null:
		bites = 0; return
	fig.pose_request = "eat"
	fig.carrying.scale = Vector3.ONE * (1.0 - (3 - bites) * 0.27)
	if bites <= 0:
		fig.release(town, Vector3.ZERO).queue_free(); carrying_kind = ""; fig.pose_request = ""

## 집 앞이 아닌 곳(옆·뒤)에서 출발하면 집 모서리를 돌아 앞길로 나오는 경유지 — 벽 모서리에 막혀 문을 못 찾던 것(운영자 지적, 비 오는 날)
func _approach(dr: Dictionary) -> Array:
	var dp: Vector3 = dr["pos"]
	var hw: float = dr.get("hw", 2.0); var hd: float = dr.get("hd", 1.8)
	var front_z := dp.z + 0.3
	if global_position.z > front_z + 0.2 and absf(global_position.x - dp.x) < hw + 1.0:
		return []   # 이미 집 앞
	var side := 1.0 if global_position.x >= dp.x else -1.0
	var out := []
	if global_position.z <= front_z + 0.2:
		# 옆이나 뒤: 그쪽 옆면을 따라 앞으로 나온다
		out.append({ "pos": Vector3(dp.x + side * (hw + 1.1), 0, global_position.z), "act": "" })
		out.append({ "pos": Vector3(dp.x + side * (hw + 1.1), 0, front_z + 1.6), "act": "" })
	out.append({ "pos": Vector3(dp.x, 0, front_z + 1.6), "act": "" })
	return out

## 그네 뒤로 가서 밀어 주기(사람이 타는데 안 밀 때 town 이 부르거나, 주민이 그네 자리에 왔는데 차 있을 때)
func go_push(sw: Dictionary) -> void:
	_release()   # 걸어가던(또는 방금 잡은 그네) 자리를 비운다 — 안 비우면 그 칸이 영영 '찬 자리'
	pushing_swing = sw; sw["pusher"] = self
	spot = { "kind": "push", "swing": sw }
	route = town.crossings(global_position, sw["at"]) + [{ "pos": sw["at"] + Vector3(0, 0, -1.1), "act": "" }]
	target = route[0]["pos"]; state = "walk"
	say(["Hold on.", "Here.", "Higher?"][uid % 3], 1.5)

func _leave() -> void:
	_release()
	collision_layer = 1; collision_mask = 1
	bites = 0   # 먹다 말고 떠나면(인사·비) 남은 빵은 든 채로 — 다음 자리에서 이어 먹진 않는다(앉은 채 먹는 자세가 아직 없다)
	if can_mine and fig.carrying:
		fig.release(town, Vector3.ZERO).queue_free(); can_mine = false   # 물뿌리개는 밭의 것 — 들고 돌아다니지 않는다
	if not riding_swing.is_empty():
		riding_swing["rider"] = null
		global_position = riding_swing["at"] + Vector3(0, 0.02, 0.9); fig.pose_request = ""; fig.rotation.x = 0.0
		riding_swing = {}
	if not pushing_swing.is_empty():
		if pushing_swing["pusher"] == self: pushing_swing["pusher"] = null
		pushing_swing = {}; fig.pose_request = ""
	fig.seated = false; fig.pose_request = ""
	if spot.get("kind", "") == "bench":
		global_position += Vector3(0, 0, 0.45)
	if spot.get("kind", "") in ["chair", "bed", "shelf"] and not door_ref.is_empty():
		global_position += Vector3(0, 0, 0.35)
		var dp: Vector3 = door_ref["pos"]
		route = [{ "pos": dp + Vector3(0, 0, -0.6), "act": "" }, { "pos": dp + Vector3(0, 0, 0.8), "act": "close" }]
		target = route[0]["pos"]; state = "walk"
		return
	state = "routine"; busy_until = Time.get_ticks_msec() / 1000.0 + randf_range(0.5, 2.0)
