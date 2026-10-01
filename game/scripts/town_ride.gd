class_name TownRide
extends TownCombat
## 타고 들기 — 차 타기·내리기, 개 쓰다듬기, 가구 들기. town_player 에서 떼어 냈다(500줄 상한). 사슬: combat → ride → player

## 타기 — 몸을 숨기고 차가 나를 대신한다. 들고 있던 큰 가구는 내려놓는다
func _enter_car(c: Car3D, now: float) -> void:
	if not carrying_big.is_empty() or swimming or not riding.is_empty(): return
	if c.driver is Resident:
		# 주민이 모는 차: 조수석에 탄다(운영자 2026-09-30: "옆자리에 타고 싶으면?") — 운전사는 나를 기억하는 만큼 반기거나 떨떠름해한다
		var r: Resident = c.driver
		if absf(c.v) > 1.5: return
		passenger = c; _hide_body(); _pending_out = false
		r.say(r.mind.line("greet_fond") if r.mind.fond > 0.3 else (r.mind.line("greet_cold") if r.mind.fond < -0.3 else ["Hop in.", "Where to?", "Mind the door."][randi() % 3]), 1.8)
		action_until = now + 0.4
		return
	driving = c; c.driver = body
	seat = {}; player.seated = false   # 벤치에서 곧장 타면 자리가 남아 내린 뒤 '앉은 몸'(충돌 0)으로 걸었다(polish 79)
	down_until = -1.0; getup_until = -1.0; player.lying = false; player.rotation.x = 0.0
	body.visible = false; body.collision_layer = 0; body.collision_mask = 0; body.velocity = Vector3.ZERO
	player.pose_request = ""; reading = false; leaning = false; resting = false
	action_until = now + 0.4

## 내리기 — 차 왼쪽 옆에 선다. 차가 달리는 중이면 못 내린다
func _exit_car(now: float) -> void:
	if absf(driving.v) > 1.0: return
	var c := driving
	driving = null; c.driver = null; c.input = { "throttle": 0.0, "steer": 0.0, "brake": false }
	body.global_position = c.exit_pos() + Vector3(0, 0.02, 0)
	body.visible = true; body.collision_layer = 4; body.collision_mask = 7
	# 몸 상태를 깨끗이 — 누움·기울기·찌그러짐이 남아 내린 뒤 대각선으로 누워 있던 것(운영자 2026-09-29)
	player.rotation = Vector3(0, player.rotation.y, 0); player.base_scale = Vector3.ONE; player.lying = false; player.seated = false; player.pose_request = ""
	down_until = -1.0; getup_until = -1.0; resting = false
	player.face(c.rotation.y)
	action_until = now + 0.4

## 쓰다듬기 — 개는 앉아 꼬리를 흔들고, 나는 허리 숙여 손을 내민다(grab 자세). 맞은 걸 기억하는 개는 손을 내밀면 한 발 물러난다
func _pet_dog(a: Dictionary, now: float) -> void:
	var p := body.global_position
	var an: Node3D = a["node"]
	if a.get("sulk_until", 0.0) > a["t"]:
		a["flee_until"] = a["t"] + 1.0; a["wander"] = an.global_position + (an.global_position - p).normalized() * 2.0
		player.action = "grab"; action_until = now + 0.6
		return
	a["pet_until"] = a["t"] + 2.5; a["follow_until"] = a["t"] + 6.0
	player.face(atan2(an.global_position.x - p.x, an.global_position.z - p.z))
	player.pose_request = "pet"; use_until = now + 2.2; action_until = now + 0.3   # 쪼그려 앉아 등을 쓸어 준다(전엔 허리만 숙였다)

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

var _pending_out := false

func _hide_body() -> void:
	down_until = -1.0; getup_until = -1.0; player.lying = false; player.rotation.x = 0.0
	body.visible = false; body.collision_layer = 0; body.collision_mask = 0; body.velocity = Vector3.ZERO
	player.pose_request = ""; reading = false; leaning = false; resting = false

## 조수석 — 몸은 조수석을 따라가고, C 를 누르면 운전사에게 세워 달라 한다(차가 서면 내린다). 운전사가 내리면(끌려 나가는 등) 같이 내린다
func _passenger_tick(now: float) -> void:
	var c := passenger
	body.global_position = c.passenger_pos() + Vector3(0, 0.3, 0)
	var r: Resident = c.driver if c.driver is Resident else null
	if Input.is_action_just_pressed("act") and action_until < now and not _pending_out:
		_pending_out = true; c.stop_until = now + 3.0; action_until = now + 0.4
		if r: r.say(["Here? All right.", "Stopping.", "Mind the traffic."][randi() % 3], 1.6)
	if r == null or (_pending_out and absf(c.v) < 1.0):
		passenger = null; _pending_out = false
		body.global_position = c.global_position - c.global_transform.basis.x * 1.3 + Vector3(0, 0.02, 0)   # 조수석 쪽(오른쪽)으로 내린다
		body.visible = true; body.collision_layer = 4; body.collision_mask = 7
		player.rotation = Vector3(0, player.rotation.y, 0); player.scale = Vector3.ONE; player.seated = false; player.face(c.rotation.y)
		action_until = now + 0.4

## 끌어내기(X, 선 차의 운전석 옆) — 주민을 끌어내 바닥에 넘어뜨리고 내가 탄다. 주민은 기억하고(맞은 것과 같다), 성미대로 쫓아오거나 피하고,
## 일이 끝나면 제 차로 돌아가 다시 탄다(내가 타고 있으면 기다린다 — resident_life _back_to_car)
func try_hijack(now: float) -> bool:
	if driving or passenger or player.carrying or not carrying_big.is_empty(): return false
	for c in cars:
		if not (c.driver is Resident) or absf(c.v) > 1.5: continue
		if body.global_position.distance_to(c.exit_pos()) > 1.4 and body.global_position.distance_to(c.global_position) > 1.9: continue
		var r: Resident = c.driver
		r.leave_car()
		var dir: Vector3 = r.global_position - body.global_position; dir.y = 0.0
		r.hit(dir.normalized() if dir.length() > 0.05 else Vector3(1, 0, 0), body, true)
		r.say(r.mind.line("hurt"), 1.6)
		_enter_car(c, now)
		return true
	return false
