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
	if job != "builder" or town.is_night() or weather == "rain" or fig.carrying or randf() < 0.2: return false   # 다섯에 하나는 쉰다(주민은 자유다)
	var sp: Dictionary = town.call("build_spot", self)
	if sp.is_empty(): return false
	var i := _free_slot(sp)
	if i < 0: return false
	spot = sp; slot = i; _claim(sp, i)
	route = town.via_bridge(global_position, [{ "pos": sp["pos"] + Vector3(-0.8 + 1.6 * i, 0, 0), "act": "" }])
	target = route[0]["pos"]; state = "walk"; busy_until = now
	return true

func _build_arrive(now: float) -> bool:
	if spot.get("kind", "") != "build": return false
	var sp := spot
	fig.face(sp.get("yaw", PI)); fig.pose_request = "hammer"; busy_until = now + town.WORK_T
	say(["Morning.", "Another wall.", "Mind the planks.", "Nearly there."][randi() % 4], 1.6)
	get_tree().create_timer(town.WORK_T - 0.2).timeout.connect(func() -> void:
		if state == "busy" and spot == sp: town.call("build_work", sp))
	return true
