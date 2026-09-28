class_name TownPlayer
extends TownSystems
## 플레이어 — 이동·점프·대시·연속기·제트킥·던지기·턱 오르기, 타격 판정과 피격, C 상호작용(집기·문·앉기·눕기·가구·동물·그네·인사).

# ── 조작 ──
func _physics_process(delta: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var grounded := body.is_on_floor()
	var dir := Vector3(Input.get_axis("move_left", "move_right"), 0, Input.get_axis("move_up", "move_down"))
	if dir.length() > 1.0:
		dir = dir.normalized()
	# 그네 타는 중: 몸은 그네가 움직인다(_swings) — 여기서 먼저 돌리고 C 만 본다(뒤의 _swings 호출 전에 return 되어 안 돌던 버그)
	if not riding.is_empty():
		_swings(delta)
		_interact_check(now)
		return
	# 넘어짐: 1.6초 누웠다가 0.6초에 걸쳐 일어난다. 그동안 입력은 없다
	if down_until > now:
		body.velocity = Vector3(lerpf(body.velocity.x, 0.0, 0.2), body.velocity.y - G * delta, lerpf(body.velocity.z, 0.0, 0.2))
		body.move_and_slide(); player.lying = true; player.move_dir = Vector3.ZERO; player.speed = 0.0
		return
	if down_until > 0.0 and down_until <= now and getup_until < 0.0:
		down_until = -1.0; getup_until = now + 0.6; player.lying = false; player.action = "getup"; player.action_t = 0.0
	if getup_until > now:
		player.action_t = 1.0 - (getup_until - now) / 0.6; body.velocity = Vector3.ZERO
		return
	if getup_until > 0.0 and getup_until <= now:
		getup_until = -1.0; player.action = ""; player.action_t = 0.0
	# 앉아 있으면 아무 방향키로 일어난다
	if not seat.is_empty():
		body.collision_layer = 0; body.collision_mask = 0   # 앉는 동안 충돌 끔 — 의자 상자에 밀려 엉덩이가 박히던 것
		if dir != Vector3.ZERO or Input.is_action_just_pressed("jump"):
			seat = {}; player.seated = false
			body.collision_layer = 1; body.collision_mask = 1
			var tw := create_tween(); tw.set_ease(Tween.EASE_OUT); tw.set_trans(Tween.TRANS_QUAD)
			tw.tween_property(body, "position", Vector3(body.position.x, 0.02, body.position.z + 0.45), 0.25)
		else:
			_interact_check(now)
			return
	for a in ["move_left", "move_right", "move_up", "move_down"]:
		if Input.is_action_just_pressed(a):
			if a == last_tap and now - last_tap_at < 0.25 and grounded:
				dash_until = now + 0.18
			last_tap = a; last_tap_at = now
	# 더블탭 순간은 대시(2.4배 0.18초), 그 뒤 방향키를 놓지 않는 한 달리기(1.9배) 유지. 0.12초 이상 놓으면 걷기로
	if dir == Vector3.ZERO:
		if idle_since < 0.0: idle_since = now
		if now - idle_since > 0.12: running = false
	else:
		idle_since = -1.0
	if now < dash_until: running = true
	var speed := WALK * (2.4 if now < dash_until else (1.9 if running else 1.0))
	var can_move := not (player.action == "throw" and (action_until >= now or throw_charge >= 0.0)) and not jet and not resting
	var v := body.velocity
	var hv := Vector3(v.x, 0, v.z)
	if jet:
		pass  # 제트킥: 쏘아진 속도 그대로
	elif can_move and dir != Vector3.ZERO:
		# 부드럽지만 빠른 반응: 땅에선 0.12초쯤에 목표 속도, 공중에선 더 느리게
		var accel := 26.0 if grounded else 9.0
		hv = hv.move_toward(dir * speed, accel * delta)
		player.move_dir = dir; player.speed = hv.length()
	else:
		hv = hv.move_toward(Vector3.ZERO, (30.0 if grounded else 3.0) * delta)
		player.move_dir = Vector3.ZERO; player.speed = 0.0
	v.x = hv.x; v.z = hv.z
	if grounded and hv.length() > 0.1:
		_step_up(hv * delta)
	if not grounded:
		v.y -= G * delta
	elif Input.is_action_just_pressed("jump"):
		# 마리오식: 누르면 꽉 찬 점프로 뜨고, 일찍 떼면 상승을 끊어 짧은 홉이 된다(위로 밀어 올리는 방식은 붕 떴다 — 운영자 2026-09-28)
		v.y = JUMP_FULL + hv.length() * 0.12
		if hv.length() > 0.5:
			var f := hv.normalized(); v.x += f.x * 1.2; v.z += f.z * 1.2
		jump_cut_ok = true
		jump_from_speed = hv.length(); dash_jump = running or now < dash_until
		jump_at = -1.0
	if jump_cut_ok and not grounded and Input.is_action_just_released("jump") and v.y > 2.0:
		v.y = 2.0; jump_cut_ok = false
	if push_at >= 0.0 and now >= push_at:
		var f := fwd_dir()
		v += f * push_amount; v.y = maxf(v.y, push_lift) if push_lift > 0.0 else v.y
		push_at = -1.0
		_strike(hit_kind)
	if jet:
		_strike("jet")
	body.velocity = v
	body.move_and_slide()
	body.position.x = clampf(body.position.x, -WORLD_X + 1.0, WORLD_X - 1.0)
	body.position.z = clampf(body.position.z, -WORLD_Z + 1.0, WORLD_Z - 1.0)
	# 착지: 빠르게 떨어졌으면 0.12초 무릎 반동, 달려서 착지하면 속도는 그대로 이어진다
	if jet and body.is_on_floor() and body.velocity.y <= 0.0 and not was_airborne:
		was_airborne = true  # 뜨지 못한 제트킥은 이번 프레임에 착지로 처리(안전장치)
	if was_airborne and body.is_on_floor():
		dash_jump = false
		if player.vertical < -4.5 or jet:
			land_until = now + (0.2 if jet else 0.12)
		if jet:
			jet = false; action_until = now + 0.2  # 착지 마무리(발을 거두는 뒤 절반)
			body.velocity = Vector3(body.velocity.x * 0.35, 0, body.velocity.z * 0.35)
	was_airborne = not body.is_on_floor()
	var land_k := clampf((land_until - now) / 0.12, 0.0, 1.0) * 0.6 if land_until > now else 0.0
	player.crouch = land_k
	player.airborne = not body.is_on_floor()
	player.jet = jet
	player.vertical = body.velocity.y
	# X·Z 는 공중에서도 된다(점프킥·점프 주먹). 들고 있을 때 X 는 던지기(웹 규칙)
	# 던지기: 들고 있을 때 X 를 누르는 동안 팔을 뒤로 감고(action_t 가 0.44 에서 멈춤), 떼면 앞으로 던진다. 오래 누를수록 멀리
	if player.carrying and throw_charge < 0.0 and action_until < now and Input.is_action_just_pressed("hit"):
		throw_charge = now; player.action = "throw"
	if throw_charge >= 0.0:
		var held := minf(THROW_MAX, now - throw_charge)
		player.action_t = minf(0.44, held / 0.25 * 0.44)
		if Input.is_action_just_released("hit") or not player.carrying:
			var power := held / THROW_MAX
			throw_charge = -1.0
			action_until = now + 0.28; throw_at = now + 0.06
			throw_power = power
	if action_until < now and throw_charge < 0.0:
		if Input.is_action_just_pressed("hit"):
			if grounded and not running:
				# 연속기: 왼 잽 → 오른 스트레이트 → 왼 훅. 0.45초 안에 이어 누르면 다음 타, 늦으면 처음부터
				if now > combo_open_until: combo = 0
				player.punch_side = [-1.0, 1.0, -1.0][combo]; player.punch_kind = ["jab", "cross", "hook"][combo]
				var dur: float = [0.22, 0.28, 0.32][combo]
				action_until = now + dur; push_at = now + dur * 0.15; push_amount = [0.35, 0.6, 0.5][combo]; push_lift = 0.0
				hit_kind = "punch"
				combo_open_until = action_until + 0.45; combo = (combo + 1) % 3
			else:
				player.punch_side = 1.0; player.punch_kind = "cross"
				action_until = now + 0.28
				push_at = now + 0.28 * 0.15; push_amount = 2.2 if not grounded else 1.8; push_lift = 1.0 if not grounded else 0.0
				hit_kind = "air" if not grounded else "punch"
			player.action = "punch"
		elif Input.is_action_just_pressed("kick"):
			if not grounded and dash_jump:  # 제트킥은 대시 중 점프 → 공중에서 Z 일 때만(운영자 2026-09-28)
				# 제트킥(운영자 2026-09-28): 앞으로 쏘아지며 비행 킥 자세를 착지까지 유지한다
				jet = true; player.action = "kick"; action_until = now + 9.0; hit_kind = "jet"
				var f := fwd_dir()
				body.velocity = Vector3(f.x * 7.5, maxf(body.velocity.y, 1.6), f.z * 7.5)  # 비거리 7.5
				was_airborne = true
			else:
				player.action = "kick"; action_until = now + 0.34
				# 달리는 중 Z 는 강한 러닝 킥(넘어뜨림, 앞으로 크게 밀림); 공중은 점프킥; 서서는 보통 발차기
				hit_kind = "runkick" if (grounded and running) else "kick"
				push_at = now + 0.34 * 0.15; push_amount = 2.6 if hit_kind == "runkick" else (1.6 if not grounded else 1.0); push_lift = 0.0
	if throw_at >= 0.0 and now >= throw_at and player.carrying:
		throw_at = -1.0
		var it := player.release(self, body.global_position + Vector3(0, 0.95, 0) + fwd_dir() * 0.35)
		flying.append({ "node": it, "vel": fwd_dir() * lerpf(4.0, 11.0, throw_power) + Vector3(0, lerpf(2.2, 4.2, throw_power), 0) + Vector3(body.velocity.x, 0, body.velocity.z) * 0.5, "spin": randf_range(4.0, 9.0) })
	if throw_charge >= 0.0:
		pass  # 감는 중 — action_t 는 위에서
	elif action_until >= now:
		if player.action == "throw":
			player.action_t = 0.45 + (1.0 - (action_until - now) / 0.28) * 0.55  # 놓는 절반만
		elif jet:
			player.action_t = 0.35
		else:
			var dur := 0.28 if player.action == "punch" else (0.34 if player.action == "kick" else 0.4)
			player.action_t = 1.0 - (action_until - now) / dur
			if player.action == "kick" and player.action_t < 0.35 and action_until - now > 0.3:
				player.action_t = 0.35 + (1.0 - (action_until - now) / 0.2) * 0.65  # 제트킥 착지 마무리: 뻗은 상태에서 거둔다
	else:
		player.action = ""; player.action_t = 0.0
	if shake_until > 0.0 and now >= shake_until:
		shake_until = -1.0; player.pose_request = ""
	if use_until > 0.0 and now >= use_until:
		use_until = -1.0
		if player.pose_request in ["eat", "drink", "wave"]: player.pose_request = ""
	if (reading or leaning or resting) and dir != Vector3.ZERO:
		reading = false; leaning = false; resting = false; player.pose_request = ""
	if not pushing.is_empty() and dir != Vector3.ZERO:
		if pushing["pusher"] == "player": pushing["pusher"] = null
		pushing = {}; player.pose_request = ""
	if not carrying_big.is_empty() and player.pose_request == "": player.pose_request = "carry"
	_interact_check(now)
	_fly(delta)
	_cutaway()
	_daylight(delta)
	_stream()
	_weather(delta)
	_animals(delta)
	_swings(delta)
	_wind(delta)

## 가구 들기(C 길게) — 두 손에 들고 옮긴다(carry 자세). 든 동안 충돌은 끈다
func _pick_furniture(now: float) -> void:
	if not carrying_big.is_empty() or player.carrying: return
	var p := body.global_position
	var best: Dictionary = {}; var bd := 9.0
	for m in movables:
		var d: float = p.distance_to(m["node"].global_position)
		if d < 0.9 and d < bd: best = m; bd = d
	if best.is_empty(): return
	var n: Node3D = best["node"]
	_set_solid(n, false)
	n.get_parent().remove_child(n); player.socket_belt.add_child(n)
	n.position = Vector3(0, 0.45, 0.42); n.rotation = Vector3.ZERO
	carrying_big = best; player.pose_request = "carry"
	player.action = "grab"; action_until = now + 0.4

## 앞 부채꼴(70°) 안, 사거리 안의 주민을 맞힌다. 무거운 한 방(제트킥·점프 주먹·훅)은 바로 넘어진다
func _strike(kind: String) -> void:
	var reach := 1.3 if kind == "jet" else (1.15 if kind == "kick" or kind == "runkick" else 0.95)
	var heavy := kind == "jet" or kind == "air" or kind == "runkick" or (kind == "punch" and player.punch_kind == "hook")
	var f := fwd_dir(); var p := body.global_position
	var now := Time.get_ticks_msec() / 1000.0
	for r in residents:
		if r.state == "down" or (kind == "jet" and float(r.get_meta("jet_hit_at", -9.0)) > now - 1.0):
			continue
		var to: Vector3 = r.global_position - p; to.y = 0.0
		var d := to.length()
		if d < reach and d > 0.05 and f.dot(to.normalized()) > 0.34:
			r.hit(f, body, heavy)
			if kind == "jet": r.set_meta("jet_hit_at", now)
			cam_kick = 0.06 if heavy else 0.03

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

## 낮은 턱 오르기: 앞으로 가려는 만큼 움직여 보고 막히면, STEP 위에서 같은 이동이 되는지 본 뒤 올라선다(그 자리엔 바닥이 있어야 한다)
func _step_up(motion: Vector3) -> void:
	step_up(body, motion)

## 공용: 사람도 주민도 같은 턱 오르기(운영자 2026-09-28: 주민이 문 앞 계단에서 막혀 집에 못 들어갔다)
static func step_up(b: CharacterBody3D, motion: Vector3) -> void:
	if motion.length() < 0.0005: return
	var xf := b.global_transform
	if not b.test_move(xf, motion):
		return
	var up := xf.translated(Vector3(0, STEP, 0))
	if b.test_move(up, motion):
		return
	var ahead := up.translated(motion + motion.normalized() * 0.06)
	var probe := PhysicsTestMotionParameters3D.new()
	probe.from = ahead; probe.motion = Vector3(0, -STEP, 0)
	var res := PhysicsTestMotionResult3D.new()
	if b.test_move(ahead, Vector3(0, -STEP, 0)) and PhysicsServer3D.body_test_motion(b.get_rid(), probe, res):
		var rise := STEP - res.get_travel().length()
		if rise > 0.02 and rise <= STEP:
			b.global_position += Vector3(0, rise + 0.01, 0)

func fwd_dir() -> Vector3:
	return Vector3(sin(player.rotation.y), 0, cos(player.rotation.y))

## C — 들고 있으면 앞에 내려놓기; 아니면 가장 가까운 것: 물건(0.8m) · 문(1.3m) · 벤치(1.0m)
func _interact_check(now: float) -> void:
	# 짧게 누르면 상호작용, 0.45초 길게 누르면 가구 들기(의자는 앉는 것과 겹쳐서)
	if Input.is_action_just_pressed("act") and action_until < now:
		act_down_at = now
	var long_press := act_down_at >= 0.0 and Input.is_action_pressed("act") and now - act_down_at >= 0.45
	var tap := act_down_at >= 0.0 and Input.is_action_just_released("act") and now - act_down_at < 0.45
	if long_press: act_down_at = -1.0
	elif tap: act_down_at = -1.0
	elif not Input.is_action_pressed("act"): act_down_at = -1.0
	if not (long_press or tap) or action_until >= now:
		return
	if long_press:
		_pick_furniture(now)
		return
	var p := body.global_position
	var fwd := Vector3(sin(player.rotation.y), 0, cos(player.rotation.y))
	if not carrying_big.is_empty():
		# 내려놓기: 앞 0.7m, 바닥에. 주민 자리도 같이 옮긴다
		var n: Node3D = carrying_big["node"]
		n.get_parent().remove_child(n); add_child(n)
		n.global_position = Vector3(p.x, 0.0, p.z) + fwd * 0.7; n.rotation = Vector3(0, player.rotation.y, 0)
		_set_solid(n, true)
		if carrying_big["spot"]: carrying_big["spot"]["pos"] = n.global_position; carrying_big["spot"]["yaw"] = player.rotation.y
		carrying_big = {}; player.pose_request = ""
		player.action = "grab"; action_until = now + 0.4
		return
	if player.carrying:
		var kind := String(player.carrying.get_meta("kind", ""))
		if kind == "apple" or kind == "bread":
			# 먹기: 한 번에 한입, 세 입이면 사라진다(운영자: 상호작용은 끝까지)
			bites += 1; player.pose_request = "eat"; use_until = now + 0.9; action_until = now + 0.9
			if bites >= 3:
				bites = 0; var core := player.carrying; player.release(self, Vector3.ZERO); core.queue_free()
			return
		if kind == "cup":
			player.pose_request = "drink"; use_until = now + 1.2; action_until = now + 1.2
			return
		if kind == "paper":
			reading = not reading; player.pose_request = "read" if reading else ""
			return
		var item := player.release(self, p + fwd * 0.5 + Vector3(0, 0.08, 0))
		items.append(item)
		player.action = "grab"; action_until = now + 0.4
		return
	var best: Dictionary = {}; var best_d := 9.0
	for it in items:
		var d := p.distance_to(it.global_position)
		if d < 0.8 and d < best_d: best = { "kind": "item", "node": it }; best_d = d
	for dr in doors:
		var d := p.distance_to(dr["pos"])
		if d < 1.3 and d < best_d: best = { "kind": "door", "door": dr }; best_d = d
	for b in benches:
		var d := p.distance_to(b["pos"])
		if d < 1.0 and d < best_d: best = { "kind": "bench", "bench": b }; best_d = d
	for sp in spots:
		if sp["kind"] != "tree" and sp["kind"] != "lamp": continue
		var d2: float = p.distance_to(sp["pos"])
		if d2 < 1.0 and d2 < best_d: best = { "kind": sp["kind"], "spot": sp }; best_d = d2
	for r in residents:
		var d3: float = p.distance_to(r.global_position)
		if d3 < 1.3 and d3 < best_d and r.state != "down": best = { "kind": "resident", "node": r }; best_d = d3
	for m in movables:
		var d4: float = p.distance_to(m["node"].global_position)
		if d4 < 0.9 and d4 < best_d: best = { "kind": "furniture", "entry": m }; best_d = d4
	for a in animals:
		if not (a["kind"] in ["dog", "cat", "marten"]): continue
		var d7: float = p.distance_to((a["node"] as Node3D).global_position)
		if d7 < 1.1 and d7 < best_d: best = { "kind": "dog", "animal": a }; best_d = d7
	for sp in spots:
		if sp["kind"] != "counter": continue
		var d8: float = p.distance_to(sp["pos"])
		if d8 < 1.1 and d8 < best_d and not player.carrying and carrying_big.is_empty(): best = { "kind": "counter", "spot": sp }; best_d = d8
	for sw in swings:
		var d6: float = p.distance_to(sw["at"])
		if d6 < 1.2 and d6 < best_d: best = { "kind": "swing", "swing": sw }; best_d = d6
	for sp in spots:
		if sp["kind"] != "bed" and sp["kind"] != "shelf": continue
		var d5: float = Vector2(p.x - sp["pos"].x, p.z - sp["pos"].z).length()
		if d5 < 1.1 and d5 < best_d: best = { "kind": sp["kind"], "spot": sp }; best_d = d5
	if best.is_empty():
		return
	match best["kind"]:
		"counter":
			# 창구: 커피(카페) 또는 빵(빵집)을 받는다 — 지금은 공짜, 코인 결제는 다음 조각
			var sp: Dictionary = best["spot"]
			player.face(sp["yaw"])
			var it := make_item(sp["item"], body.global_position + Vector3(0, 0.9, 0))
			player.hold(it); player.action = "grab"; action_until = now + 0.4
		"swing":
			var sw: Dictionary = best["swing"]
			if not riding.is_empty():
				riding = {}; player.pose_request = ""; body.velocity = Vector3(0, 1.5, 0.8)
			elif sw["rider"] is Node:
				# 주민이 타고 있다 → 뒤에 서서 밀어 준다
				pushing = sw; sw["pusher"] = "player"
				var tw := create_tween(); tw.tween_property(body, "position", sw["at"] + Vector3(0, 0.02, -1.1), 0.3)
				player.face(0.0); player.pose_request = "push"
			else:
				riding = sw; body.velocity = Vector3.ZERO
				player.move_dir = Vector3.ZERO; player.speed = 0.0
		"dog":
			# 쓰다듬기: 개는 앉아 꼬리를 흔들고, 나는 허리 숙여 손을 내민다(grab 자세)
			var a: Dictionary = best["animal"]
			a["pet_until"] = a["t"] + 2.5; a["follow_until"] = a["t"] + 6.0
			player.face(atan2((a["node"] as Node3D).global_position.x - p.x, (a["node"] as Node3D).global_position.z - p.z))
			player.action = "grab"; action_until = now + 1.2
		"furniture":
			var e: Dictionary = best["entry"]
			var n: Node3D = e["node"]
			if e["kind"] == "chair":
				# 의자에 앉기(벤치와 같은 규칙)
				seat = { "pos": n.global_position, "yaw": n.rotation.y, "chair": true }
				player.seated = true; player.move_dir = Vector3.ZERO; player.speed = 0.0; body.velocity = Vector3.ZERO
				var tw := create_tween(); tw.set_ease(Tween.EASE_IN_OUT); tw.set_trans(Tween.TRANS_QUAD)
				tw.tween_property(body, "position", n.global_position + Vector3(0, 0.05, 0.02), 0.3)
				player.face(n.rotation.y)
			elif e["kind"] == "lamp":
				var l: OmniLight3D = n.get_meta("light"); l.visible = not l.visible
				player.action = "grab"; action_until = now + 0.3
		"bed":
			# 눕기: 침대 위에서 쉬는 자세. 방향키로 일어난다
			var sp: Dictionary = best["spot"]
			resting = true; player.pose_request = "rest"; player.face(sp["yaw"])
			body.velocity = Vector3.ZERO
			var tw := create_tween(); tw.set_ease(Tween.EASE_IN_OUT); tw.set_trans(Tween.TRANS_QUAD)
			tw.tween_property(body, "position", sp["pos"] + Vector3(0, 0.02, 0), 0.35)
		"shelf":
			# 선반에서 책을 꺼내 읽는다(움직이면 끝)
			var sp: Dictionary = best["spot"]
			reading = true; player.pose_request = "read"; player.face(sp["yaw"])
		"lamp":
			# 가로등에 기대기(2D lean) — 움직이면 풀린다
			var sp: Dictionary = best["spot"]
			leaning = true; player.pose_request = "lean"; player.face(sp["yaw"])
		"resident":
			# 인사: 손을 흔들면 주민이 돌아보고 답한다
			var r: Node3D = best["node"]
			player.pose_request = "wave"; use_until = now + 1.2; action_until = now + 0.3
			player.face(atan2(r.global_position.x - p.x, r.global_position.z - p.z))
			r.greet(body)
		"tree":
			var sp: Dictionary = best["spot"]
			player.face(atan2(sp["pos"].x - p.x, sp["pos"].z - p.z))
			player.pose_request = "shake"; shake_until = now + 1.2; action_until = now + 1.2
			for c in crowns:
				if c["at"] != sp["pos"] or (c["fruit"] as Array).is_empty(): continue
				var f: Node3D = (c["fruit"] as Array).pop_back(); var fp := f.global_position; f.queue_free()
				var apple := make_item("apple", fp)
				flying.append({ "node": apple, "vel": Vector3(randf_range(-0.6, 0.6), 0.3, randf_range(0.2, 0.8)), "spin": 3.0 })  # 열린 사과가 떨어진다
				break
		"item":
			var it: Node3D = best["node"]
			items.erase(it)
			player.hold(it)
			player.action = "grab"; action_until = now + 0.4
		"door":
			set_door(best["door"], not best["door"]["open"])
		"bench":
			var b: Dictionary = best["bench"]
			seat = b
			player.seated = true
			player.move_dir = Vector3.ZERO; player.speed = 0.0
			body.velocity = Vector3.ZERO
			# 세 자리(왼·가운데·오른쪽) 중 지금 선 곳에서 가장 가까운 자리에 앉는다 — 가운데만 고집하지 않는다
			var best_slot: Vector3 = b["pos"]; var bd := 99.0
			for off in [-0.45, 0.0, 0.45]:
				var slot: Vector3 = b["pos"] + Vector3(cos(b["yaw"]) * off, 0, -sin(b["yaw"]) * off)
				var d := body.global_position.distance_to(slot)
				if d < bd: bd = d; best_slot = slot
			var tw := create_tween(); tw.set_ease(Tween.EASE_IN_OUT); tw.set_trans(Tween.TRANS_QUAD)
			tw.tween_property(body, "position", best_slot + Vector3(0, 0.05, 0.02), 0.35)  # 순간이동 대신 미끄러져 앉는다
			player.face(b["yaw"])
