class_name Resident
extends ResidentSunroom
## 주민의 일과 — 자리를 골라 걸어가 벤치에 앉고, 가로등에 기대고, 나무를 흔들고, 텃밭에 물을 주고, 빵집에서 빵을 사 먹고, 다음 자리로 간다.
## 넘어지면 일어나서 때린 사람을 쫓다가 포기한다. 몸·상태·맞음·인사는 resident_base.gd.

const FAR_SQ := 3600.0   # 60m — 이보다 먼 주민은 물리를 FAR_EVERY 틱에 한 번(2026-10-01 성능 패스). 걸음 그림은 _process 가 계속 그리니 60m 밖에선 티가 안 난다
const FAR_EVERY := 4
var _far_tick := 0

func _physics_process(delta: float) -> void:
	var far := state != "drive" and global_position.distance_squared_to(town.body.global_position) > FAR_SQ
	if far:
		if not town.gen.has_ground(global_position): return   # 밑의 칸이 지워졌다 — 떨어지지 않게 그 자리에서 기다린다
		_far_tick = (_far_tick + 1) % FAR_EVERY
		if _far_tick != 0: return
		delta *= FAR_EVERY   # 한 번에 네 틱만큼(중력·감속·턱 오르기) — 아래 move_and_slide 도 속도를 네 배로 해 같은 거리를 간다
	var now := Time.get_ticks_msec() / 1000.0
	if say_label.visible and now > say_until:
		say_label.visible = false
	var v := velocity
	if not is_on_floor():
		v.y -= 22.0 * delta
	elif v.y <= 0.5:
		v.y = 0.0   # 위로 튕겨진 속도(시소·차)는 살린다 — 땅에 있다고 0 으로 지워 안 날아갔다
	fig.airborne = not is_on_floor(); fig.vertical = v.y
	# 동작(주먹·집기)은 상태와 무관하게 끝나면 지운다 — 쫓다가 포기하면 주먹 자세가 남던 버그
	if fig.action == "punch" or fig.action == "grab":
		if now >= busy_until:
			fig.action = ""; fig.action_t = 0.0
		else:
			fig.action_t = 1.0 - (busy_until - now) / FightPoses.PUNCH_T
	if state == "drive":
		# 운전 중: 몸은 차가 옮기고(운전석), 두 손은 핸들 — 물리·일과는 쉰다
		global_position = car_seat.seat_pos(); fig.seated = true; fig.pose_request = "drive"; fig.face(car_seat.rotation.y + PI)
		fig.base_scale = Vector3.ONE * 0.8   # 차 안 — 머리·모자가 지붕을 뚫지 않게(scale 은 Stick3D 가 프레임마다 찌그러짐으로 덮어쓴다 — base_scale 이어야 남는다, polish 79)
		velocity = Vector3.ZERO
		return
	match state:
		"routine":
			v.x = 0.0; v.z = 0.0; fig.move_dir = Vector3.ZERO; fig.speed = 0.0   # 쫓다 포기한 뒤 달리던 속도가 남아 1초 더 미끄러지던 것
			if now >= busy_until:
				_pick_spot()
		"walk":
			if in_boat:   # 나루(run 94): 배가 건너편 부두로 옮긴다 — 다 오면 town_boat 가 내려 주고 걷던 길(다음은 "land")을 잇는다
				global_position = town.boat_seat(); fig.swing_k = town.boat_k(); fig.move_dir = Vector3.ZERO; fig.speed = 0.0; stuck_since = -1.0; velocity = Vector3.ZERO; return
			if now < _door_wait:
				v.x = 0.0; v.z = 0.0; fig.move_dir = Vector3.ZERO; fig.speed = 0.0; stuck_since = -1.0
				velocity = v; move_and_slide(); return
			if fig.pose_request == "moor": fig.pose_request = ""   # 밧줄을 다 맸다(_door_wait 가 MOOR_T 만큼 세워 뒀다)
			var to := target - global_position; to.y = 0.0
			if to.length() < 0.35:
				var step: Dictionary = route.pop_front() if not route.is_empty() else {}
				if step.get("act", "") == "open": town.set_door(door_ref, true); _door_wait = now + 0.5   # 문짝이 다 열릴 때까지 기다린다 — 안 그러면 도는 문짝에 막혀 우회하다 벽에 갇혔다
				elif step.get("act", "") == "close": town.set_door(door_ref, false)
				elif step.get("act", "") == "board": _ferry_board()   # 나루(run 94) — resident_life
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
				var spd := WALK * pace * (1.7 if weather == "rain" and not has_umb else 1.0) * (1.9 if spot.get("kind", "") == "flee" else 1.0)  # 비 오면 서두른다 — 우산을 폈으면 그냥 걷는다(run 76)
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
			if riding_seesaw:
				var sd := riding_seesaw.side_of(self)
				if sd >= 0: global_position = riding_seesaw.seat_pos(sd) + Vector3(0, -0.42, 0); fig.face(PI / 2.0 if sd == 0 else -PI / 2.0); v.y = 0.0
			elif not riding_swing.is_empty():
				global_position = town.swing_seat(riding_swing) + Vector3(0, -0.39, 0)
				fig.swing_k = clampf(riding_swing["vel"] / 3.0, -1.0, 1.0); fig.rotation.x = riding_swing["angle"]
				v.y = 0.0
			elif in_boat:
				global_position = town.boat_seat(); fig.swing_k = town.boat_k(); v.y = 0.0   # 거룻배(run 78): 배가 나를 옮긴다 — 노 박자는 배 속도(town_boat)
			else:
				fig.rotation.x = 0.0
			if bites > 0 and now >= bite_at: _bite(now)
			if now >= busy_until:
				_leave()
		"down":
			if is_on_floor():
				if not get_meta("bounced", false) and absf(velocity.y) < 0.1 and Vector2(v.x, v.z).length() > 1.0:
					set_meta("bounced", true); v.y = 1.6   # 땅에 닿으면 한 번 튄다
				v.x = lerpf(v.x, 0.0, 6.0 * delta); v.z = lerpf(v.z, 0.0, 6.0 * delta)   # 그다음 미끄러지며 선다
			fig.rotation.x = 0.0
			fig.move_dir = Vector3.ZERO; fig.speed = 0.0
			if now >= down_until:
				fig.lying = false; fig.action = "getup"; fig.action_t = 0.0; collision_layer = 4; collision_mask = 7; remove_meta("bounced")
				state = "getup"; busy_until = now + FightPoses.GETUP_T
		"getup":
			v.x = 0.0; v.z = 0.0
			fig.action_t = 1.0 - (busy_until - now) / FightPoses.GETUP_T
			if now >= busy_until:
				fig.action = ""; fig.action_t = 0.0
				if quarry and mind.retaliates():
					state = "chase"; chase_until = now + 4.5; say(mind.line("grudge" if mind.hurt > 1 else "hurt"))
				elif quarry and mind.flees(): _flee(quarry.global_position)   # 겁 많은 사람은 되갚지 않고 피한다
				else:
					state = "routine"; busy_until = now + 0.5; shaken_at = now   # 쫓지도 피하지도 않은 사람 — 이야기 시간이면 가까운 방석으로(resident_sunroom, run 104)
		"chase":
			var cv := _chase(now)   # 싸움 — 기술표·실력·연계(resident_life)
			v.x = cv.x; v.z = cv.y
	# 강물: 걷거나 쫓다 빠지면 사람과 같은 규칙으로 헤엄친다(느리게, 수면 높이로). 길은 다리로 짜니 보통은 빠진 경우뿐
	var wet: bool = town.in_water(global_position)
	if wet and (state == "walk" or state == "chase"):
		v.x *= 0.55; v.z *= 0.55
		if fig.pose_request != "swim": fig.pose_request = "swim"; fig.position.y = -0.1; town.water.splash(global_position, true)
		town.water.wake(self, true, delta)
	elif fig.pose_request == "swim":
		fig.pose_request = ""; fig.position.y = 0.0; town.water.drip(self)
	town.teeter(fig, global_position, state == "walk" or state == "chase")   # 디딤돌 위 균형(run 84) — 사람과 같은 자리·같은 자세
	if state == "walk" or state == "chase":
		for o in town.residents:
			if o == self: continue
			var dv: Vector3 = global_position - o.global_position; dv.y = 0.0
			var dl := dv.length()
			if dl < 0.5 and dl > 0.001:
				v += dv.normalized() * (0.5 - dl) * 6.0   # 가까울수록 세게 비킨다
	velocity = v
	if fig.seated or not riding_swing.is_empty() or in_boat:
		return   # 앉거나 그네·배를 탈 땐 물리로 밀리지 않는다
	if is_on_floor() and Vector2(v.x, v.z).length() > 0.1:
		town.step_up(self, Vector3(v.x, 0, v.z) * delta)   # 턱·문지방·계단 오르기(사람과 같은 규칙)
	if far: velocity *= FAR_EVERY
	move_and_slide()
	if far: velocity /= FAR_EVERY

## 날씨 바뀜 — 비면 지금 하던 걸 접고 실내로 서두른다(밖 자리에 있었으면 바로 다시 고른다)
func on_weather(w: String) -> void:
	weather = w
	var now := Time.get_ticks_msec() / 1000.0
	if w != "rain":
		# 비가 그치면 처마 밑에서 구경하던 주민은 1~3초 더 보다 간다(run 74) — 90초 상한까지 서 있지 않는다
		if state == "busy" and fig.pose_request == "storm": busy_until = minf(busy_until, now + randf_range(1.0, 3.0))
		if has_umb and state in ["busy", "walk", "routine"] and _to_rack(now): say(["Dry again.", "Back it goes.", "That was brief."][uid % 3], 1.6)   # 우산을 접고 돌려놓으러(run 76)
		return
	if not (state in ["busy", "walk", "routine"]) or spot.get("kind", "") in ["chair", "bed", "shelf"]:
		return
	if not has_umb and fig.carrying == null and _to_rack(now):
		say(["An umbrella.", "One left, I hope.", "Borrowing."][uid % 3], 1.5); return   # 10m 안의 꽂이에 우산이 남았으면 빌리러(run 76) — 셋뿐이라 나머지는 아래처럼 처마로
	if state == "busy" and spot.get("kind", "") == "door" and not has_umb:
		_storm(now); return   # 이미 문 앞이면 그 자리에서 비 구경으로 — 자리를 비우고 같은 문을 다시 고르던 헛걸음
	# _leave 로 자리를 제대로 비운다 — 전엔 seated 만 풀어서 그네 rider 가 남아 비 온 뒤 그네가 영영 차 있었고, 걸어가던 목표 칸도 새어 나갔다
	if state == "busy": _leave()
	else: _release()
	state = "routine"; busy_until = now + randf_range(0.0, 1.5)
	say(["Rain.", "Of course.", "Inside, then."][uid % 3], 1.5)

## 처마 밑에서 비 구경(run 74, "Weather people feel" 1조각): 문 앞 자리에 비를 만나면 storm 자세로 비가 그칠 때까지(상한 90초) 선다 — 전엔 2~5초 기본 자세로 섰다 갔다.
## 사람이 비 오는 날 밖에서 문을 닫으면 같은 자세(town_player). 그치면 on_weather 가 busy_until 을 줄인다
func _storm(now: float) -> void:
	fig.pose_request = "storm"; fig.face(0.0)   # 문을 등지고 거리 쪽을 본다
	busy_until = now + 90.0
	say(["It will pass.", "Of course.", "Heavier than it looks."][uid % 3], 1.8)

## 우산꽂이로(run 76): 빈손이면 빌리러(비 시작, 꽂이 10m 안·우산이 남았을 때), 우산을 들었으면 돌려놓으러(비 그침·밤). 칸은 셋(우산 수) — 걸어오는 동안 잡아 두니 넷이 하나를 노리진 않는다.
## 사람이 C 로 하는 것과 같은 take_umbrella/rack_put 이 도착(_arrive "rack")에서 돈다. 못 가면 false(호출자는 처마로 간다)
func _to_rack(now: float) -> bool:
	var rk: Dictionary = town.rack
	if rk.is_empty(): return false
	if not has_umb and (int(rk["stock"]) <= 0 or global_position.distance_to(rk["pos"]) > 10.0): return false
	var i := _free_slot(rk)
	if i < 0: return false
	if state == "busy": _leave()
	else: _release()
	spot = rk; slot = i; _claim(rk, i)
	route = town.crossings(global_position, rk["pos"]) + [{ "pos": rk["pos"] + Vector3(-0.25 + 0.25 * i, 0, 0.3), "act": "" }]
	target = route[0]["pos"]; state = "walk"; busy_until = now
	if has_umb: fig.pose_request = ""   # 접는다(0.3초 회수) — 돌려놓으러 가는 길은 접은 채
	return true

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
	if _back_to_car(): return   # 끌려 내렸던 운전사는 제 차로(resident_life)
	if has_umb and (weather != "rain" or town.is_night()) and _to_rack(Time.get_ticks_msec() / 1000.0): return   # 비가 그쳤거나 잘 시간이면 우산부터 돌려놓는다(쫓다가·넘어져서 on_weather 를 놓친 경우)
	# 수리공(uid 6명 중 1명): 벽에 금이 있으면 가서 고친다(운영자 2026-09-29: 주민이 알아서 복구)
	if uid % 6 == 0 and not town.is_night():
		var best: Dictionary = {}; var bd := 1e9
		for c in town.cracks:
			if c.get("by") != null: continue
			var dd: float = global_position.distance_to(c["at"])
			if dd < bd: bd = dd; best = c
		if not best.is_empty():
			best["by"] = self
			spot = { "kind": "repair", "pos": best["at"] + best["out"] * 0.55, "crack": best }
			route = town.via_bridge(global_position, [{ "pos": Vector3(spot["pos"].x, 0, spot["pos"].z), "act": "" }])
			target = route[0]["pos"]; state = "walk"; say("I'll see to that.", 1.6)
			return
	if town.is_night() and not home_door.is_empty() and carrying_kind != "log":   # 장작을 든 나무꾼은 난로부터(run 92, _wood_pick)
		# 밤: 집으로 가서 침대에 눕는다(집에 침대가 있으면), 아니면 의자
		var mine: Array = town.spots.filter(func(sp): return sp.has("door") and sp["door"] == home_door and sp["kind"] == "bed")
		if mine.is_empty(): mine = town.spots.filter(func(sp): return sp.has("door") and sp["door"] == home_door)
		mine = mine.filter(func(sp): return _free_slot(sp) >= 0)
		if not mine.is_empty():
			spot = mine[0]; slot = 0; _claim(spot, 0)
			door_ref = home_door
			var dp: Vector3 = door_ref["pos"]
			route = town.via_bridge(global_position, _approach(door_ref) + [{ "pos": dp + Vector3(0, 0, 0.8), "act": "open" }, { "pos": dp + Vector3(0, 0, -1.3), "act": "close" }, { "pos": spot["pos"] + Vector3(0, 0, 0.35), "act": "" }])
			target = route[0]["pos"]; state = "walk"; return
	if job == "baker" and not town.is_night() and weather != "rain":
		# 빵집 주인(run 72): 창구가 덜 찼으면 화덕으로 — 일은 장소에 매인다. 비엔 화덕(바깥)을 쉰다
		var ov: Dictionary = town.bake_spot(self)
		if not ov.is_empty():
			spot = ov; slot = 0; _claim(spot, 0)
			route = town.crossings(global_position, spot["pos"]) + [{ "pos": spot["pos"] + Vector3(0, 0, 0.4), "act": "" }]
			target = route[0]["pos"]; state = "walk"; return
	if _trade_pick(Time.get_ticks_msec() / 1000.0): return   # 구두장이의 낮 일, 닳은 밑창(run 80, resident_life)
	if _pair_pick(Time.get_ticks_msec() / 1000.0) or _swap_pick(Time.get_ticks_msec() / 1000.0) or _post_pick(Time.get_ticks_msec() / 1000.0): return   # 막 나선 친구와 나란히(run 95, resident_pair), 책 상자(run 98, resident_shelf), 편지방(run 99, resident_letters)
	var pool: Array = town.spots.filter(func(sp): return not (sp["kind"] in ["oven", "rack", "cobbler", "stool", "wheel", "whet", "stitch", "fitting", "chop", "pile", "stove", "swap", "letters", "notice", "story", "cushion"]))
	# 하루 일과(운영자 2026-09-30: 주민 활동을 디테일하게): 시간대와 직업이 고르는 자리 — 열에 일곱은 지금 할 일, 셋은 아무 데나(주민은 자유다)
	var want: Array = _schedule_kinds()   # 일과는 점수의 한 항(mind.score) — 배고프면 일하다가도 빵집으로, 게으르면 가까운 벤치로
	if weather == "rain" and has_umb:
		# 우산을 폈으면 밖 자리로 — 비를 맞으며 일과를 잇는 첫 존재(run 76). 팔을 쓰는 자세(기대기·흔들기·손차양·그네·먹기)는 우산 든 손과 겹치니 뺀다
		pool = town.spots.filter(func(sp): return sp["kind"] in ["bench", "bank", "door"])
	elif weather == "rain":
		# 비: 실내(의자·침대·선반) 아니면 차양 아래(문 앞)만 고른다
		pool = town.spots.filter(func(sp): return sp["kind"] in ["chair", "bed", "shelf", "door"])
		if pool.is_empty(): pool = town.spots
	# 찬 자리는 빼고 고른다(운영자: 주민끼리 겹쳐 있으면 안 된다)
	var free: Array = pool.filter(func(sp): return _free_slot(sp) >= 0)
	if free.is_empty():
		busy_until = Time.get_ticks_msec() / 1000.0 + 2.0; return
	spot = mind.pick(free, want)   # 자아가 고른다: 좋아하는 곳·모자란 욕구·친구·새로움·거리(resident_mind.gd)
	if mind.reason != "" and randf() < 0.35: say(mind.line(mind.reason), 1.6)
	slot = _free_slot(spot)
	_claim(spot, slot)
	route = []
	if (spot["kind"] == "chair" or spot["kind"] == "bed" or spot["kind"] == "shelf") and spot.has("door"):
		# 집 안 의자: (집 앞이 아니면 모서리를 돌아) 문 앞 → 문 열기 → 의자. 나올 땐 _leave 가 반대로
		door_ref = spot["door"]
		var dp: Vector3 = door_ref["pos"]
		route = _approach(door_ref) + [{ "pos": dp + Vector3(0, 0, 0.8), "act": "open" }, { "pos": dp + Vector3(0, 0, -1.3), "act": "close" }, { "pos": spot["pos"] + Vector3(0, 0, 0.35), "act": "" }]
	elif spot["kind"] == "bench":
		route = [{ "pos": spot["pos"] + Vector3([-0.45, 0.0, 0.45][slot], 0, 0.45), "act": "" }]
	elif spot["kind"] == "grass":
		var gr: float = spot.get("r", 1.0); var ga := randf_range(0.0, TAU); var gd := sqrt(randf()) * (gr - 0.3)
		route = [{ "pos": spot["pos"] + Vector3(cos(ga) * gd, 0, sin(ga) * gd), "act": "" }]
	elif spot["kind"] == "door":
		var near_door: Dictionary = {}
		for dr in town.doors:
			if (dr["pos"] as Vector3).distance_to(spot["pos"]) < 1.2: near_door = dr; break
		route = (_approach(near_door) if not near_door.is_empty() else []) + [{ "pos": spot["pos"] + Vector3(randf_range(-0.2, 0.2), 0, 0.2), "act": "" }]
	else:
		route = [{ "pos": spot["pos"] + Vector3(randf_range(-0.2, 0.2), 0, 0.5), "act": "" }]
	route = town.via_bridge(global_position, route)   # 다리·텃밭 문·전망 언덕 계단·연못 우회(town_base.via_bridge)
	target = route[0]["pos"]
	state = "walk"
	_umb_pose()

## 우산을 들고 비 속에 있으면 자세는 umbr — 자리를 떠나고 고르고 닿을 때마다 pose_request 가 비워지니 그때마다 다시(run 76). 팔을 쓰는 자세가 이미 있으면 그대로
func _umb_pose() -> void:
	if has_umb and weather == "rain" and fig.pose_request == "": fig.pose_request = "umbr"

func _arrive(now: float) -> void:
	state = "busy"
	if _chat(now): return
	fig.pose_request = ""
	match spot["kind"]:
		"seesaw":
			var ss: Seesaw3D = spot["ss"]
			var side := ss.side_near(global_position)
			if not ss.sit(self, side): side = 1 - side
			if ss.riders[side] == self or ss.sit(self, side):
				riding_seesaw = ss; fig.seated = true; collision_layer = 0; collision_mask = 0
				busy_until = now + randf_range(10.0, 20.0)
			else:
				busy_until = now + 1.0
		"car":
			if own_car and own_car.driver == null and town.driving != own_car and global_position.distance_to(own_car.exit_pos()) < 1.5: drive(own_car)
			else: busy_until = now + 1.0
		"repair":
			var c: Dictionary = spot["crack"]
			fig.pose_request = "fix"; fig.face(atan2(-c["out"].x, -c["out"].z))
			busy_until = now + 3.0
		"bench":
			fig.seated = true; collision_layer = 0; collision_mask = 0
			global_position = spot["pos"] + Vector3([-0.45, 0.0, 0.45][slot], 0.05, 0.02)
			fig.face(spot.get("yaw", 0.0))
			busy_until = now + randf_range(6.0, 14.0); _share(now)   # 먹을 걸 들고 왔으면 옆 칸과 반씩(run 85, resident_life)
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
		"grass":
			# 초원 풀밭 구역 안 아무 데나 — 도착한 그 자리에서 눕는다(사람이 C 로 하는 것과 같은 자세 sky)
			fig.pose_request = "sky"; fig.face(randf_range(0.0, TAU))
			busy_until = now + randf_range(10.0, 22.0)
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
		"lookout":
			# 전망 자리(run 73, 전망 언덕): 난간 앞에서 손차양을 하고 마을을 둘러본다 — 사람이 C 로 하는 것과 같은 shade 자세, 한두 바퀴
			fig.pose_request = "shade"; fig.face(spot.get("yaw", PI))
			busy_until = now + StickPoses.SHADE_T * (1 + randi() % 2) + 0.3
			say(["Quite a view.", "There is the bridge.", "You can see the lane."][uid % 3], 1.8)
		"door":
			# 문 앞(차양 아래): 비면 비 구경(_storm), 아니면(또는 우산을 폈으면) 잠깐 섰다 간다
			if weather == "rain" and not has_umb: _storm(now)
			else:
				fig.face(spot.get("yaw", PI)); busy_until = now + randf_range(2.0, 5.0)
		"boat":
			# 부두(run 78): 배가 부두에 비어 있으면 타고 12m 나갔다 돌아온다(town_boat _boats 가 돌아오면 busy_until 을 당긴다) — 사람이 C 로 하는 것과 같은 board. 누가 타고 나갔으면 서서 본다
			fig.face(spot.get("yaw", PI))
			if not fig.carrying and town.board(self):
				busy_until = now + 90.0; say(["Out and back.", "Mind the wake.", "Just to the bend."][uid % 3], 1.8)
			else:
				busy_until = now + randf_range(2.0, 4.0); say(["Taken.", "It will come back.", "Someone is out."][uid % 3], 1.6)
		"rack":
			# 우산꽂이(run 76): 우산을 들고 왔으면 돌려놓고, 빈손이면 하나 빌려 편다 — 사람이 C 로 하는 것과 같은 take_umbrella/rack_put. 오는 사이 비었으면(사람이 가져갔다) 빈손으로 처마로
			fig.face(spot.get("yaw", PI)); fig.action = "grab"; fig.action_t = 0.0; busy_until = now + 0.5
			if has_umb:
				if town.rack_put(): fig.release(town, Vector3.ZERO).queue_free()
				else: town.items.append(fig.release(town, global_position + Vector3(0, 0.06, 0.4)))   # 꽂이가 꽉 찼다(떨어진 걸 누가 주워 왔다) — 옆에 놓는다
				has_umb = false; carrying_kind = ""; say(["Returned.", "There.", "Dry enough."][uid % 3], 1.4)
			else:
				var u: Node3D = town.take_umbrella()
				if u == null: say(["None left.", "Of course.", "Too late."][uid % 3], 1.6)
				else: fig.hold(u); has_umb = true; carrying_kind = "umbrella"; fig.pose_request = "umbr"; say(["Borrowed.", "Just for now.", "Back by tonight."][uid % 3], 1.6)
		"cobbler", "stool", "wheel", "whet", "stitch", "fitting", "chop", "pile", "logs", "stove":
			_trade_arrive(now)   # 구두장이 작업대(run 80)·칼갈이 숫돌(run 81)·바느질 탁자(run 82, resident_life)
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
			elif town.counter_take(spot, self):   # 주머니에 동전이 있으면 하나 낸다(run 107, town_coins)
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
			if (spot.has("fish") and _fish_arrive(now)) or _swap_arrive(now) or _post_arrive(now): return   # 편지방 우편함(run 99, resident_letters); 부두 끝(run 91): 셋에 하나는 걸터앉아 낚는다(resident_life); 책 상자(run 98, resident_shelf)
			fig.face(spot.get("yaw", PI))
			busy_until = now + randf_range(2.0, 5.0)
			# 개가 곁에 있으면 쪼그려 앉아 쓰다듬는다(사람이 C 로 하는 것과 같은 자세·같은 개 반응)
			for a in town.animals:
				if a["kind"] == "dog" and a.get("sulk_until", 0.0) < a["t"] and (a["node"] as Node3D).global_position.distance_to(global_position) < 1.5:
					a["pet_until"] = a["t"] + 2.5
					fig.pose_request = "pet"; fig.face(atan2((a["node"] as Node3D).global_position.x - global_position.x, (a["node"] as Node3D).global_position.z - global_position.z))
					busy_until = now + 2.5
					break
	_umb_pose()

## 한입(run 72) — 사람의 먹기와 같은 규칙: eat 자세, 한입마다 0.27 씩 작아지고 세 입이면 사라진다. 맞아서 떨어뜨리면(hit) 남은 입은 없다
func _bite(now: float) -> void:
	bites -= 1; bite_at = now + 0.9
	if fig.carrying == null:
		bites = 0; return
	fig.pose_request = "eat"
	fig.carrying.scale = Vector3.ONE * (1.0 - (3 - bites) * 0.27); fig.carrying.set_meta("bites", 3 - bites)   # 한입 수는 물건에 — 떨어뜨린 반쪽을 누가 주워도 이어진다(run 85)
	if bites <= 0:
		fig.release(town, Vector3.ZERO).queue_free(); carrying_kind = ""; fig.pose_request = ""; mind.ate()

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


## 시소에서 튀어 오름 — 날아올랐다 발로 착지하고, 한마디
func seesaw_launch(vy: float) -> void:
	riding_seesaw = null; fig.seated = false; _release()
	collision_layer = 4; collision_mask = 7
	velocity = Vector3(randf_range(-0.4, 0.4), vy, randf_range(0.3, 0.8)); fig.squash = 1.0
	state = "busy"; busy_until = Time.get_ticks_msec() / 1000.0 + 1.2; spot = { "kind": "greet" }
	say(["Whoa.", "That was high.", "Again."][uid % 3], 1.4)

func _leave() -> void:
	if riding_seesaw: riding_seesaw.leave(self); riding_seesaw = null
	_release()
	if spot.get("kind", "") == "repair": town.repair_crack(spot["crack"])   # 3초 두드리면 금이 사라진다
	if _role() == "keeper" and spot.get("kind", "") in ["counter", "door"] and Time.get_ticks_msec() / 1000.0 >= busy_until: dull += 1   # 창구·노점 교대 하나 = 가위가 한 번 무뎌진다(run 81, 칼갈이)
	collision_layer = 4; collision_mask = 7
	bites = 0   # 먹다 말고 떠나면(인사·비) 남은 빵은 든 채로 — 다음 자리에서 이어 먹진 않는다(앉은 채 먹는 자세는 run 85 부터 있다 — 이어 먹기는 아직)
	if can_mine and fig.carrying:
		fig.release(town, Vector3.ZERO).queue_free(); can_mine = false   # 물뿌리개는 밭의 것 — 들고 돌아다니지 않는다
	if not riding_swing.is_empty():
		riding_swing["rider"] = null
		global_position = riding_swing["at"] + Vector3(0, 0.02, 0.9); fig.pose_request = ""; fig.rotation.x = 0.0
		riding_swing = {}
	if not pushing_swing.is_empty():
		if pushing_swing["pusher"] == self: pushing_swing["pusher"] = null
		pushing_swing = {}; fig.pose_request = ""
	if in_boat: town.unboard(self)   # 거룻배(run 78): 가까운 부두 쪽 둑에 내린다(run 94) — 비가 와서 일찍 내려도 같은 길
	fig.seated = false; fig.pose_request = ""
	_umb_pose()
	if spot.get("kind", "") == "bench":
		global_position += Vector3(0, 0, 0.45)
	if spot.get("kind", "") in ["chair", "bed", "shelf", "stove", "letters"] and not door_ref.is_empty():
		global_position += Vector3(0, 0, 0.35)
		var dp: Vector3 = door_ref["pos"]
		route = [{ "pos": dp + Vector3(0, 0, -0.9), "act": "open" }, { "pos": dp + Vector3(0, 0, 0.9), "act": "close" }]   # 들어가면 등 뒤로 닫고, 나올 땐 열고 나와 닫는다(운영자 2026-09-29: 문을 안 닫고 다님)
		target = route[0]["pos"]; state = "walk"
		return
	state = "routine"; busy_until = Time.get_ticks_msec() / 1000.0 + randf_range(0.5, 2.0)
