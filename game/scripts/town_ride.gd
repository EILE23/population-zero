class_name TownRide
extends TownCombat
## 타고 들기 — 차 타기·내리기, 개 쓰다듬기, 가구 들기. town_player 에서 떼어 냈다(500줄 상한). 사슬: combat → ride → player

## 타기 — 몸을 숨기고 차가 나를 대신한다. 들고 있던 큰 가구는 내려놓는다
func _enter_car(c: Car3D, now: float) -> void:
	if not carrying_big.is_empty() or swimming or not riding.is_empty(): return
	driving = c; c.driver = body
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
