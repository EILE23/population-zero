class_name TownPlayer
extends TownSunroom
## 플레이어 — 이동·점프·대시·연속기·제트킥·던지기·턱 오르기, 타격 판정과 피격, C 상호작용(집기·문·앉기·눕기·가구·동물·그네·인사).

# ── 조작 ──
func _physics_process(delta: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var grounded := body.is_on_floor()
	var dir := Vector3(Input.get_axis("move_left", "move_right"), 0, Input.get_axis("move_up", "move_down"))
	if dir.length() > 1.0:
		dir = dir.normalized()
	if passenger:
		_passenger_tick(now); _tick(delta, now); return   # 조수석(town_ride): 주민이 몬다, C 로 세워 달라 한다
	# 운전 중: 차가 몸이다 — 방향키·SPACE 를 차에 넘기고 C 로 내린다. 세계 시스템은 계속 돈다
	if driving:
		if not "--sheet" in OS.get_cmdline_user_args():   # 시트 도구는 입력을 직접 넣는다
			driving.input = { "throttle": -dir.z, "steer": dir.x, "brake": Input.is_action_pressed("jump") }
		body.global_position = driving.global_position + Vector3(0, 0.3, 0)
		if Input.is_action_just_pressed("act") and action_until < now:
			_exit_car(now)
		_tick(delta, now)
		return
	# 시소 타는 중: 몸은 판 끝을 따라가고, SPACE = 낮은 쪽이면 박차기 / 높은 쪽이면 뛰어내리기(판이 올라가는 중이면 더 높이), C = 내리기
	if seesaw_ride:
		var ss := seesaw_ride; var side := ss.side_of("player")
		body.global_position = ss.seat_pos(side) + Vector3(0, -0.42, 0); body.velocity = Vector3.ZERO
		player.seated = true; player.face(PI / 2.0 if side == 0 else -PI / 2.0)
		if Input.is_action_just_pressed("jump"):
			var rising: float = ss.omega * (1.0 if side == 1 else -1.0)
			if rising < -0.3 or ((side == 1 and ss.angle < 0.0) or (side == 0 and ss.angle > 0.0)):
				ss.push(side)
			else:
				ss.leave("player"); seesaw_ride = null; player.seated = false; body.collision_layer = 4; body.collision_mask = 7
				body.velocity = Vector3(0, JUMP_FULL + maxf(0.0, rising) * Seesaw3D.L * 2.2, 0.4); was_airborne = true; player.squash = 1.0
		elif Input.is_action_just_pressed("act") and action_until < now:
			ss.leave("player"); seesaw_ride = null; player.seated = false; body.collision_layer = 4; body.collision_mask = 7
			body.global_position += Vector3(0, 0, 0.7); action_until = now + 0.3
		_tick(delta, now)
		return
	# 그네 타는 중: 몸은 그네가 움직인다(_swings) — 여기서 먼저 돌리고 C 만 본다(뒤의 _swings 호출 전에 return 되어 안 돌던 버그)
	if not riding.is_empty():
		_tick(delta, now)   # _swings 는 _tick 안에서 — 세계도 같이 돈다(run 78)
		_interact_check(now)
		return
	# 거룻배(run 78): 몸은 배가 옮긴다(_boats) — C 만 본다(내리기)
	if rowing:
		_tick(delta, now)
		_interact_check(now)
		return
	# 넘어짐: 1.6초 누웠다가 0.6초에 걸쳐 일어난다. 그동안 입력은 없다
	if down_until > now:
		var fk := 0.2 if body.is_on_floor() else 0.0   # 날아가는 동안은 속도 유지(차에 치이면 포물선)
		body.velocity = Vector3(lerpf(body.velocity.x, 0.0, fk), body.velocity.y - G * delta, lerpf(body.velocity.z, 0.0, fk))
		player.rotation.x = 0.0 if body.is_on_floor() else player.rotation.x + delta * 7.0
		body.collision_layer = 0; body.collision_mask = 1   # 누운 동안 차가 깔고 지나간다
		body.move_and_slide(); player.lying = true; player.move_dir = Vector3.ZERO; player.speed = 0.0
		_tick(delta, now)
		return
	if down_until > 0.0 and down_until <= now and getup_until < 0.0:
		down_until = -1.0; getup_until = now + FightPoses.GETUP_T; player.lying = false; player.action = "getup"; player.action_t = 0.0; body.collision_layer = 4; body.collision_mask = 7
		player_up_at = now   # 이야기방 방석이 30초 동안 달래 준다(town_sunroom cushion_use, run 104)
	if getup_until > now:
		player.action_t = 1.0 - (getup_until - now) / FightPoses.GETUP_T; body.velocity = Vector3.ZERO
		_tick(delta, now)
		return
	if getup_until > 0.0 and getup_until <= now:
		getup_until = -1.0; player.action = ""; player.action_t = 0.0; player.rotation.x = 0.0; player.rotation.z = 0.0
	# 앉아 있으면 아무 방향키로 일어난다
	if not seat.is_empty():
		body.collision_layer = 0; body.collision_mask = 0   # 앉는 동안 충돌 끔 — 의자 상자에 밀려 엉덩이가 박히던 것
		if dir != Vector3.ZERO or Input.is_action_just_pressed("jump"):
			seat = {}; player.seated = false
			body.collision_layer = 4; body.collision_mask = 7
			var tw := create_tween(); tw.set_ease(Tween.EASE_OUT); tw.set_trans(Tween.TRANS_QUAD)
			tw.tween_property(body, "position", Vector3(body.position.x, ground_y(body.position) + 0.02, body.position.z + 0.45), 0.25)   # 땅 높이로 — 전망 언덕 벤치(run 73)에서 0.02 로 내려서면 바위 속으로 떨어졌다(polish 75)
		else:
			_interact_check(now)
			_tick(delta, now)   # 앉아 있는 동안에도 세계는 돈다(run 78)
			return
	# 강물: 들어가면 헤엄(느리고, 점프·타격 없음, 몸이 수면 높이로 내려간다), 나오면 다시 걷는다. 주민도 같은 규칙(resident.gd)
	var wet := in_water(body.global_position)
	if wet != swimming:
		swimming = wet; player.position.y = -0.1 if wet else 0.0   # 수면(0.04) 위로 등·팔이 보이게 — -0.22 는 머리만 떠 있었다
		if wet:
			player.pose_request = "swim"; jet = false; running = false; dash_until = -1.0; reading = false; leaning = false; resting = false
			water.splash(body.global_position, true)   # 첨벙
		else:
			if player.pose_request == "swim": player.pose_request = ""
			water.drip(body)   # 나오면 물이 뚝뚝
	teeter(player, body.global_position, true)   # 디딤돌 위면 두 팔 벌려 균형(run 84) — 주민도 같은 자리에서(resident.gd)
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
	if swimming: speed = WALK * 0.55
	var can_move := not (player.action == "throw" and (action_until >= now or throw_charge >= 0.0)) and not jet and not resting
	var v := body.velocity
	var hv := Vector3(v.x, 0, v.z)
	if jet:
		pass  # 제트킥: 쏘아진 속도 그대로
	elif can_move and dir != Vector3.ZERO:
		# 부드럽지만 빠른 반응: 땅에선 0.12초쯤에 목표 속도, 공중에선 더 느리게
		var accel := 26.0 if grounded else 15.0   # air control 9 -> 15: steerable mid-air (jump maps)
		hv = hv.move_toward(dir * speed, accel * delta)
		player.move_dir = dir; player.speed = hv.length()
	else:
		hv = hv.move_toward(Vector3.ZERO, (30.0 if grounded else 3.0) * delta)
		player.move_dir = Vector3.ZERO; player.speed = 0.0
	v.x = hv.x; v.z = hv.z
	if swimming: water.wake(body, hv.length() > 0.2, delta)   # 헤엄 자국
	if grounded and hv.length() > 0.1:
		_step_up(hv * delta)
	# 점프(Jump3D: 코요테·버퍼·꼭대기 체공·묵직한 낙하·가변 높이 — Climb 도 같은 부품)
	jumpf.tick(grounded, Input.is_action_just_pressed("jump") and not swimming, now)
	if jumpf.consume(now):
		v.y = JUMP_FULL + hv.length() * 0.12
		if hv.length() > 0.5:
			var f := hv.normalized(); v.x += f.x * 1.2; v.z += f.z * 1.2
		jump_from_speed = hv.length(); dash_jump = running or now < dash_until
		jump_at = -1.0; player.squash = 1.0   # 뛰는 순간 몸이 위로 늘어난다
	elif not grounded:
		v.y = jumpf.air(v.y, Input.is_action_just_released("jump"), delta)
	if push_at >= 0.0 and now >= push_at:
		var f := fwd_dir()
		v += f * push_amount; v.y = maxf(v.y, push_lift) if push_lift > 0.0 else (push_lift if push_lift < 0.0 else v.y)
		push_at = -1.0
		_strike(hit_kind)
	if jet:
		_strike("jet")
	body.velocity = v
	body.move_and_slide()
	body.position.x = clampf(body.position.x, -OPEN + 1.0, OPEN - 1.0)   # 열린 세계 끝까지 걸어간다
	body.position.z = clampf(body.position.z, -OPEN + 1.0, OPEN - 1.0)
	# 착지: 빠르게 떨어졌으면 0.12초 무릎 반동, 달려서 착지하면 속도는 그대로 이어진다
	if jet and body.is_on_floor() and body.velocity.y <= 0.0 and not was_airborne:
		was_airborne = true  # 뜨지 못한 제트킥은 이번 프레임에 착지로 처리(안전장치)
	if was_airborne and body.is_on_floor():
		dash_jump = false
		var hard := clampf(-player.vertical / 12.0, 0.0, 1.0)
		for ss in seesaws:   # 시소 끝을 밟으면 반대쪽이 튄다
			if Vector2(body.global_position.x - ss.global_position.x, body.global_position.z - ss.global_position.z).length() < Seesaw3D.L + 0.3 and body.global_position.y > 0.15:
				ss.stomp(ss.side_near(body.global_position), -player.vertical)
		player.squash = -0.4 - 0.6 * hard; Jump3D.dust(self, body.global_position, hard)   # 닿는 순간 찌그러지고, 세게 닿으면 흙먼지
		if player.vertical < -4.5 or jet:
			land_until = now + (0.2 if jet else 0.12 + 0.1 * hard)
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
			throw_charge = -1.0
			if player.carrying:
				action_until = now + 0.28; throw_at = now + 0.06
				throw_power = held / THROW_MAX
			else:
				player.action = ""; player.action_t = 0.0   # 감는 동안 손이 비면(마지막 한입·모자 씀) 던질 게 없다 — 전엔 throw_at 이 남아 다음에 집는 것이 곧장 날아갔다
	if throw_charge < 0.0 and not swimming and not player.carrying:
		attack_input(now, grounded)   # X 주먹 · Z 발 — 연계·버퍼·공중 기술(town_combat, FightMoves)
	if throw_at >= 0.0 and now >= throw_at:
		throw_at = -1.0
		if player.carrying:
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
			var dur := FightMoves.dur(player.move) if player.action == "fight" else FightPoses.PUNCH_T if player.action == "punch" else ((FightPoses.ROUND_T if player.kick_step == 2 else FightPoses.KICK_T) if player.action == "kick" else 0.4)
			player.action_t = 1.0 - (action_until - now) / dur
	else:
		player.action = ""; player.action_t = 0.0
	if shake_until > 0.0 and now >= shake_until:
		shake_until = -1.0; player.pose_request = ""
	if use_until > 0.0 and now >= use_until:
		use_until = -1.0
		if player.pose_request == "lwave": player.pose_request = "umbr" if player.umbr_k > 0.5 else ""   # 왼손 인사(CI run 77)가 끝나면 우산은 있던 대로
		elif player.pose_request in ["eat", "drink", "wave", "pet", "water", "knead", "hammer", "grind", "wait", "sew", "share", "pass", "chop", "stoke", "moor", "shelve", "sort", "pin"]: player.pose_request = ""   # hammer 는 run 80 이 빠뜨려 사람이 망치를 영영 들고 있었다(run 81)
	if player.pose_request == "pet" and dir != Vector3.ZERO:
		player.pose_request = ""; use_until = -1.0   # 쓰다듬다 움직이면 바로 일어난다
	if (reading or leaning or resting or player.pose_request in ["water", "knead", "shade", "storm", "hammer", "grind", "wait", "sew", "chop", "cast", "reel", "stoke", "moor", "shelve", "sort", "pin"]) and dir != Vector3.ZERO:
		if resting and player.pose_request in ["sky", "rest"]:
			getup_until = now + FightPoses.GETUP_T; player.action = "getup"; player.action_t = 0.0   # 누웠다 일어나는 건 맞고 일어날 때와 같은 동작·같은 길이(0.6 이 남아 있어 진행이 0.4 에서 시작해 튀었다, polish 79)
		reading = false; leaning = false; resting = false; player.pose_request = ""
	if not pushing.is_empty() and dir != Vector3.ZERO:
		if pushing["pusher"] == "player": pushing["pusher"] = null
		pushing = {}; player.pose_request = ""
	if not carrying_big.is_empty() and player.pose_request == "": player.pose_request = "carry"
	KidPoses.player(player, now, Input.is_action_just_pressed("jump") and not swimming, grounded and not swimming and dir != Vector3.ZERO and seat.is_empty())   # SPACE 톡톡 = 아이 걸음 skip 3초(run 102, stick3d_kid.gd) — 아이들과 같은 걸음
	_interact_check(now)
	_tick(delta, now)

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
		if not pass_on_bench(now): _pick_furniture(now)   # 벤치에 앉아 컵·먹을 걸 들었으면 길게 = 옆 칸에 넘기기(run 86, town_meals)
		return
	if rowing:
		boat_leave(now); return   # 배 위(run 78): C = 가까운 부두 쪽 둑에 내린다 — 부두에 대었으면 moor(run 94, town_boat)
	if fish_c(now): return   # 부두 끝에서 낚는 중(run 91): C = 입질이면 감아 낚고, 아니면 빈 줄을 거둔다(town_sites)
	var p := body.global_position
	var fwd := Vector3(sin(player.rotation.y), 0, cos(player.rotation.y))
	if not carrying_big.is_empty():
		# 내려놓기: 앞 0.7m, 바닥에. 주민 자리도 같이 옮긴다
		var n: Node3D = carrying_big["node"]
		n.get_parent().remove_child(n); add_child(n)
		n.global_position = Vector3(p.x, ground_y(p), p.z) + fwd * 0.7; n.rotation = Vector3(0, player.rotation.y, 0)   # 언덕 위에서 내려놓으면 선반 위에(바닥 0 이면 바위 속)
		_set_solid(n, true)
		if carrying_big["spot"]: carrying_big["spot"]["pos"] = n.global_position; carrying_big["spot"]["yaw"] = player.rotation.y
		carrying_big = {}; player.pose_request = ""
		player.action = "grab"; action_until = now + 0.4
		return
	if player.carrying and player.carrying.get_meta("wearable", false):
		# 입는 것을 든 채 C → 쓴다. 같은 슬롯에 있던 건 손으로 온다
		var prev := player.wear(player.carrying)
		if prev: player.hold(prev)
		player.action = "grab"; action_until = now + 0.35
		return
	if player.carrying and (sunroom_give(now) or give_to_resident(now)): return   # 앞의 주민에게 건네기가 먹기·내려놓기보다 먼저(town_critters); 안락의자의 읽는 이는 앉아 있어 따로(run 106, town_sunroom)
	if player.carrying:
		var kind := String(player.carrying.get_meta("kind", ""))
		if kind in FOOD:
			if share_on_bench(now) or (seat.is_empty() and riding.is_empty() and sit_with_food(p)): return   # 앉았으면 옆 사람과 반씩(run 85, town_meals), 벤치 앞이면 먼저 앉는다
			# 먹기: 한 번에 한입, 한입마다 작아지고 세 입이면 사라진다(운영자: 상호작용은 끝까지). 한입 수는 물건에 붙는다 — 전엔 전역이라 사과를 바꿔 들어도 이어졌다
			var food := player.carrying
			var bites := int(food.get_meta("bites", 0)) + 1
			food.set_meta("bites", bites); food.scale = Vector3.ONE * (1.0 - bites * 0.27)
			player.pose_request = "eat"; use_until = now + 0.9; action_until = now + 0.9
			if bites >= 3:
				player.release(self, Vector3.ZERO); food.queue_free()
			return
		if kind == "cup":
			player.pose_request = "drink"; use_until = now + 1.2; action_until = now + 1.2
			return
		if kind == "umbrella":
			umbrella_use(now)   # 우산(run 76): 꽂이 앞이면 돌려놓기, 아니면 펴기/접기(town_places) — 전엔 아래 '내려놓기'가 먼저 잡았다
			return
		if kind == "can" and not near_plot(p).is_empty():
			garden_use(near_plot(p), now)   # 물뿌리개 들고 이랑 앞 C = 물 주기(전엔 아래 '내려놓기'가 먼저 잡아 물뿌리개를 바닥에 떨궜다)
			return
		if kind == "log" and (stoke_log(now) or stack_log(now)): return   # 난로 앞이면 넣고(run 92), 장작더미 앞이면 쌓는다(town_woods) — 아니면 아래 '내려놓기'
		if kind == "book" and swap_use(now): return   # 책 상자 앞이면 꽂기(run 98, town_swap) — 아니면 아래처럼 펼쳐 읽는다
		if kind in ["paper", "letter"] and (letters_use(now) or notice_use(now)): return   # 우편함 앞이면 꽂기(run 99), 게시판 앞이면 핀으로(run 100, town_letters) — 아니면 아래처럼 펼쳐 읽는다
		if kind in ["paper", "book", "letter"]:
			reading = not reading; player.pose_request = "read" if reading else ""
			return
		# 들고 있어도 손 닿는 곳에 다른 물건이 있으면 그것부터 줍는다(셋까지); 없으면 맨 위 것을 앞에 내려놓는다
		var near_it: Node3D = null; var nd := 0.8
		for it in items:
			var d0 := p.distance_to(it.global_position)
			if d0 < nd: near_it = it; nd = d0
		if near_it and player.pocket.size() < 2 and near_it != last_dropped:   # 방금 내려놓은 건 다시 안 집는다(리뷰 버그: 두 개를 한 자리에 못 놓았다)
			items.erase(near_it); player.hold(near_it)
			player.action = "grab"; action_until = now + 0.4
			return
		var item := player.release(self, p + fwd * 0.5 + Vector3(0, 0.08, 0))
		items.append(item); last_dropped = item
		player.action = "grab"; action_until = now + 0.4
		return
	var best: Dictionary = {}; var best_d := 9.0
	for it in items:
		var d := p.distance_to(it.global_position)
		if d < 0.8 and d < best_d: best = { "kind": "item", "node": it }; best_d = d
	var item_near := not best.is_empty()   # 손 닿는 곳에 물건이 있으면 줍기가 먼저 — 풀밭·벤치·침대 위 물건을 두고 눕지 않는다(운영자 2026-09-28)
	for dr in doors:
		var d := p.distance_to(dr["pos"])
		if d < 1.3 and d < best_d: best = { "kind": "door", "door": dr }; best_d = d
	for b in benches:
		var d := p.distance_to(b["pos"])
		if d < 1.0 and d < best_d and not item_near: best = { "kind": "bench", "bench": b }; best_d = d
	for sp in spots:
		if sp["kind"] != "tree" and sp["kind"] != "lamp": continue
		var d2: float = p.distance_to(sp["pos"])
		if d2 < 1.0 and d2 < best_d: best = { "kind": sp["kind"], "spot": sp }; best_d = d2
	for r in residents:
		var d3: float = p.distance_to(r.global_position)
		if d3 < 1.3 and d3 < best_d and not (r.state in ["down", "drive"]): best = { "kind": "resident", "node": r }; best_d = d3   # 운전사는 차 안 — 택시 옆에서 C 가 인사를 걸어 운전사를 차에서 끌어냈다(polish 79)
	for m in movables:
		var d4: float = p.distance_to(m["node"].global_position)
		if d4 < 0.9 and d4 < best_d: best = { "kind": "furniture", "entry": m }; best_d = d4
	for a in animals:
		if not (a["kind"] in ["dog", "cat", "marten"]): continue
		var d7: float = p.distance_to((a["node"] as Node3D).global_position)
		if d7 < 1.1 and d7 < best_d: best = { "kind": "dog", "animal": a }; best_d = d7
	for sp in spots:
		if not (sp["kind"] in ["hatstand", "counter", "oven", "lookout", "rack", "boat", "cobbler", "stool", "wheel", "whet", "stitch", "fitting", "gate", "chop", "swap", "letters", "notice"] or sp.has("fish")): continue   # 빈손으로 쓰는 것들 — 모자 집기, 창구, 화덕(반죽), 전망 자리(손차양), 우산꽂이(빌리기), 부두(거룻배 타기), 구두장이 작업대·걸상(run 80), 숫돌·손님 자리(run 81)
		var d8: float = p.distance_to(sp["pos"])
		if d8 < 1.1 and d8 < best_d and not player.carrying and carrying_big.is_empty(): best = { "kind": "fish" if sp.has("fish") else sp["kind"], "spot": sp }; best_d = d8   # 부두 끝 bank 는 빈손이면 낚시 자리(run 91)
	var pl := near_plot(p)
	if not pl.is_empty() and plot_dist(p, pl) < best_d: best = { "kind": "plot", "spot": pl }; best_d = plot_dist(p, pl)
	for c in cars:
		var dc: float = p.distance_to(c.global_position)
		if dc < 1.9 and dc < best_d and (c.driver == null or c.driver is Resident) and carrying_big.is_empty(): best = { "kind": "car", "car": c }; best_d = dc   # 주민이 모는 차면 조수석
	for ss in seesaws:
		var dss: float = Vector2(p.x - ss.global_position.x, p.z - ss.global_position.z).length()
		if dss < Seesaw3D.L + 0.6 and dss < best_d + 0.5 and seesaw_ride == null: best = { "kind": "seesaw", "ss": ss }; best_d = dss
	for sw in swings:
		var d6: float = p.distance_to(sw["at"])
		if d6 < 1.2 and d6 < best_d: best = { "kind": "swing", "swing": sw }; best_d = d6
	for sp in spots:
		if not (sp["kind"] in ["bed", "shelf", "grass"]) or item_near: continue
		var d5: float = Vector2(p.x - sp["pos"].x, p.z - sp["pos"].z).length()
		if sp["kind"] == "grass":
			if d5 < float(sp.get("r", 1.1)) and best.is_empty(): best = { "kind": "grass", "spot": sp }; best_d = 9.0   # 구역: 안에 있으면 되고, 다른 것이 더 가까우면 그것이 먼저
		elif d5 < 1.1 and d5 < best_d: best = { "kind": sp["kind"], "spot": sp }; best_d = d5
	if best.is_empty():
		# 근처에 아무것도 없고 빈손이면 모자를 벗어 손에 든다
		if not player.carrying and player.worn.has("hat"):
			var h := player.take_off("hat"); player.hold(h); player.action = "grab"; action_until = now + 0.35
		return
	match best["kind"]:
		"hatstand":
			var sp: Dictionary = best["spot"]
			player.face(sp["yaw"])
			var kinds := ["cap", "straw", "tophat", "beanie", "glasses", "sunglasses", "backpack", "scarf"]
			var h := make_wearable(kinds[randi() % kinds.size()], body.global_position, Wear.palette(randi() % 6))
			player.hold(h); player.action = "grab"; action_until = now + 0.4
		"plot":
			garden_use(best["spot"], now)   # 텃밭: 물뿌리개를 들었으면 물 주기, 빈손이면 익은 것 따기(town_places)
		"counter":
			counter_use(best["spot"], now)   # 창구: 빵(재고 셋, 비면 "Sold out.")이나 컵을 받는다 — 지금은 공짜, 코인 결제는 다음 조각(town_places)
		"oven":
			oven_use(best["spot"], now)   # 화덕: 반죽 한 바퀴(knead 자세)로 창구에 빵 하나 — 빵집 주인이 하는 것과 같은 자세·같은 효과(town_places)
		"swap":
			swap_use(now)   # 책 상자(run 98): 빈손이면 하나 꺼낸다 — 주민이 지나가다 하는 것과 같은 shelve 자세(town_swap)
		"letters":
			letters_use(now)   # 편지방 우편함(run 99): 빈손이면 하나 꺼낸다 — 서기·지나는 주민과 같은 sort 자세(town_letters)
		"cushion", "story":
			cushion_use(best["spot"], now)   # 이야기방(run 103): 빈 방석에 책상다리 — 아이들과 같은 crossleg, 의자에선 책을 들었으면 story(town_sunroom)
		"notice":
			notice_use(now)   # 광장 게시판(run 100): 빈손이면 가장 새 쪽지를 뗀다 — 주민과 같은 pin 자세(town_letters)
		"rack":
			rack_use(now)   # 우산꽂이(run 76): 하나 빌린다 — 주민이 비 올 때 하는 것과 같은 take_umbrella(town_places)
		"cobbler", "stool":
			cobbler_use(best["spot"], now)   # 구두장이(run 80): 일하는 중이면 걸상에서 밑창 수선, 아니면 망치질 한 바퀴 — 주민과 같은 자리·같은 자세(town_trades)
		"stitch", "fitting":
			stitch_use(best["spot"], now)   # 재봉사(run 82): 찢어졌으면 걸상에서 꿰매 받기, 아니면 탁자에서 바느질 한 바퀴 — 주민과 같은 자리·같은 자세(town_trades)
		"wheel", "whet":
			wheel_use(best["spot"], now)   # 칼갈이(run 81): 가는 중이면 손님 자리에서 두 바퀴 기다리기, 아니면 갈기 한 바퀴 — 주민과 같은 자리·같은 자세(town_trades)
		"chop":
			chop_use(best["spot"], now)   # 오두막 그루터기: 두 번 패기 — 나무꾼과 같은 자리·같은 자세, 장작이 튄다(town_woods)
		"fish":
			fish_use(best["spot"], now)   # 부두 끝(run 91): 걸터앉아 던진다 — 주민과 같은 자리·같은 자세(town_sites)
		"gate":
			enter_game(String(best["spot"]["game"]))   # 미니게임 입구(town_sites) — 마을은 멈춰 기다리고, 끝나면 이 문 앞으로
		"boat":
			boat_use(now)   # 부두(run 78): 거룻배에 탄다 — 주민이 같은 자리에서 하는 것과 같은 board(town_boat)
		"car":
			_enter_car(best["car"], now)
		"seesaw":
			var ss: Seesaw3D = best["ss"]
			var side := ss.side_near(p)
			if not ss.sit("player", side): side = 1 - side; if not ss.sit("player", side): return
			seesaw_ride = ss; body.collision_layer = 0; body.collision_mask = 0; player.move_dir = Vector3.ZERO; player.speed = 0.0
		"swing":
			var sw: Dictionary = best["swing"]
			if not riding.is_empty():
				dismount(); body.velocity = Vector3(0, 1.5, 0.8)
			elif sw["rider"] is Node:
				# 주민이 타고 있다 → 뒤에 서서 밀어 준다
				pushing = sw; sw["pusher"] = "player"
				var tw := create_tween(); tw.tween_property(body, "position", sw["at"] + Vector3(0, 0.02, -1.1), 0.3)
				player.face(0.0); player.pose_request = "push"
			else:
				riding = sw; body.velocity = Vector3.ZERO
				player.move_dir = Vector3.ZERO; player.speed = 0.0
		"dog":
			_pet_dog(best["animal"], now)
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
		"grass":
			# 초원 풀밭 구역 안 아무 데서나, 선 자리 그대로 눕는다(전엔 가운데로 끌려갔다). 방향키로 일어난다. 주민도 같은 자세
			resting = true; player.pose_request = "sky"
			body.velocity = Vector3.ZERO
		"shelf":
			# 선반에서 책을 꺼내 읽는다(움직이면 끝)
			var sp: Dictionary = best["spot"]
			reading = true; player.pose_request = "read"; player.face(sp["yaw"])
		"lamp":
			# 가로등에 기대기(2D lean) — 움직이면 풀린다
			var sp: Dictionary = best["spot"]
			leaning = true; player.pose_request = "lean"; player.face(sp["yaw"])
		"lookout":
			# 전망 언덕의 전망 자리(run 73): 난간 앞에서 손차양(shade) — 움직이면 풀린다. 주민도 같은 자리에서 같은 자세(resident.gd)
			var sp: Dictionary = best["spot"]
			player.pose_request = "shade"; player.face(sp["yaw"])
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
			if player.hold(it): items.erase(it)
			player.action = "grab"; action_until = now + 0.4
		"door":
			var dr: Dictionary = best["door"]
			set_door(dr, not dr["open"])   # 문 여닫기는 그대로(항상) — 아래는 덧붙는 자세일 뿐
			if weather == "rain" and not dr["open"] and p.z > (dr["pos"] as Vector3).z + 0.2:
				# 비 오는 날 밖에서 문을 닫으면 처마 밑에서 비 구경(storm, run 74) — 움직이면 풀린다. 주민도 비 오는 문 앞에서 같은 자세(resident.gd _storm)
				player.pose_request = "storm"; player.face(0.0)
		"bench":
			sit_bench(best["bench"])   # 빈 칸 고르기·미끄러져 앉기는 town_meals(run 85: 먹을 걸 들고도 앉는다)
