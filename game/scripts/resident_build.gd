class_name ResidentBuild
extends ResidentLedger
## 건축가(운영자 2026-10-06: "빌딩을 실제로 짓는 건축가들", town_growth.gd) — job "builder" 는 낮에 비가 안 오면 가장 가까운 공사장으로 출근해
## 25초 망치질(hammer 자세 — 구두장이와 같은 자세)을 하고, 그게 끝나면(그동안 맞거나 떠나지 않았으면) 공사장에 일 한 단위가 쌓인다. 일과 사이엔 다른 주민처럼 쉰다.
## 사슬: … → ledger → **build** → resident

func _post_pick(now: float) -> bool:
	return _build_pick(now) or super._post_pick(now)

## 건축가는 출근부터 고른다 — 고르기 사슬의 맨 앞(_pair_pick)에 끼운다(전엔 짝 걷기·책·편지에 밀려 90초에 일 한 단위였다)
func _pair_pick(now: float, chance := ResidentPair.PAIR_CHANCE) -> bool:
	return _build_pick(now) or super._pair_pick(now, chance)

func _post_arrive(now: float) -> bool:
	return _build_arrive(now) or super._post_arrive(now)

func _build_pick(now: float) -> bool:
	if job != "builder" or town.is_night() or weather == "rain" or (fig.carrying and not has_meta("plank")) or randf() < 0.2: return false   # 다섯에 하나는 쉰다(주민은 자유다)
	var sp: Dictionary = town.call("build_spot", self)
	if sp.is_empty(): return false
	if not has_meta("plank") and town.has_method("lumber_spot"):   # 빈손이면 목재소부터 — 판자를 지고 간다(운영자 2026-10-06: 진짜로 짓는 것)
		var y: Dictionary = town.call("lumber_spot", self)
		if not y.is_empty():
			spot = y; slot = 0; _claim(y, 0)
			route = town.via_bridge(global_position, [{ "pos": y["pos"], "act": "" }])
			target = route[0]["pos"]; state = "walk"; busy_until = now
			return true
	var i := _free_slot(sp)
	if i < 0: return false
	spot = sp; slot = i; _claim(sp, i)
	route = town.via_bridge(global_position, [{ "pos": sp["pos"] + Vector3(-0.8 + 1.6 * i, 0, 0), "act": "" }])
	target = route[0]["pos"]; state = "walk"; busy_until = now
	return true

func _build_arrive(now: float) -> bool:
	if spot.get("kind", "") == "lumber":   # 판자 한 묶음을 든다 — 다음 고르기에서 공사장으로
		fig.hold(town.make_item("log", global_position + Vector3(0, 0.9, 0))); set_meta("plank", true)
		fig.face(float(spot.get("yaw", PI))); busy_until = now + 1.2; say(["Planks.", "Right.", "Heavy."][randi() % 3], 1.2)
		return true
	if spot.get("kind", "") != "build": return false
	var sp := spot
	if has_meta("plank"):   # 지고 온 판자를 내려놓는다(공사장 판자 더미로)
		remove_meta("plank")
		var it: Node3D = fig.release(town, global_position)
		if it: it.queue_free()
	fig.face(sp.get("yaw", PI)); fig.pose_request = "hammer"; busy_until = now + town.WORK_T
	say(["Morning.", "Another wall.", "Mind the planks.", "Nearly there."][randi() % 4], 1.6)
	get_tree().create_timer(town.WORK_T - 0.2).timeout.connect(func() -> void:
		if state == "busy" and spot == sp: town.call("build_work", sp))
	return true
