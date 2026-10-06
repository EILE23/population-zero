class_name ResidentJobs
extends ResidentStore
## 심부름판(money 3, run 115 — town_jobs.gd): 동전이 있고 진짜 모자란 게 있는 어른은 하루 한 번 판에 가서 카드를 꽂는다(pin, PIN_IN 에 동전 −1). 일 없는 빈손 어른이 12m 안을 지나면 넷에 하나 들러
## 읽고(scan) 맨 위 카드를 떼어(pin) 그 일의 자리로 간다 — 장작은 나무꾼의 _wood_pick 길 그대로(패고 줍고 쌓고 저녁엔 난로에), 반죽은 화덕(bake_spot 과 같은 조건; resident.gd 의 "oven" 가지가 반죽한다).
## 일이 되면 town 이 동전을 주머니에 넣는다(_jobs_tick, job_done). 17시엔 쓴 이가 안 뗀 제 카드를 떼러 온다(동전 돌려받기). 사람이 C 로 하는 것과 같은 자세·같은 시각.
## 사슬: … → shop → store → **jobs** → resident

func _post_pick(now: float) -> bool:
	return _job_pick(now) or super._post_pick(now)

func _post_arrive(now: float) -> bool:
	return _job_arrive(now) or super._post_arrive(now)

## 판으로 갈 이유 — 뗀 카드가 있으면 그 일의 자리로; 아니면 떼러(17시, 내 카드), 들러(빈손·일 없음·가까이), 꽂으러(동전·모자란 것·오늘 처음). 못 가면 false(_pick_spot 이 다음 규칙으로)
func _job_pick(now: float) -> bool:
	var jb: Dictionary = town.jobs
	if jb.is_empty() or self is ResidentKid or town.is_night() or weather == "rain" or has_umb: return false
	var card: Dictionary = get_meta("card", {})
	if not card.is_empty(): return _wood_pick(now) if String(card["task"]) == "logs" else _oven_pick(now)
	if fig.carrying: return false
	var h := _hour(); var act := ""
	if not town.job_mine(self).is_empty():
		if h < 17.0: return false   # 내 카드가 걸려 있다 — 저녁까지 기다린다(또 꽂지도, 제 것을 떼지도 않는다)
		act = "down"
	elif job == "" and global_position.distance_to(jb["pos"]) < 12.0 and not town.job_top().is_empty() and randf() < 0.25: act = "take"
	elif coins > 0 and h >= 8.0 and h < 17.0 and now - float(get_meta("posted", -1e9)) > town.DAY_LEN * 0.9 and randf() < 0.05 + 0.1 * mind.social and town.job_wanted(self) != "": act = "post"
	if act == "" or _free_slot(jb) < 0: return false
	set_meta("job_act", act)
	slot = 0; spot = jb; _claim(jb, 0)
	route = town.via_bridge(global_position, [{ "pos": jb["pos"], "act": "" }])
	target = route[0]["pos"]; state = "walk"; busy_until = now
	return true

## 반죽하러 — 창구가 덜 찼고 판이 비었으면 화덕 자리(빵집 주인과 같은 길)
func _oven_pick(now: float) -> bool:
	var sp: Dictionary = town.bake_spot(self)
	if sp.is_empty(): return false
	spot = sp; slot = 0; _claim(sp, 0)
	route = town.via_bridge(global_position, town.crossings(global_position, sp["pos"]) + [{ "pos": sp["pos"] + Vector3(0, 0, 0.4), "act": "" }])
	target = route[0]["pos"]; state = "walk"; busy_until = now
	return true

## 판에 닿음 — 떼러 왔으면 읽고(scan) 떼고(pin), 꽂거나 내리러 왔으면 pin 한 바퀴. 이 판이 아니면 false
func _job_arrive(now: float) -> bool:
	if not is_same(spot, town.jobs): return false
	fig.face(spot.get("yaw", PI))
	var act := String(get_meta("job_act", "take")); var T := PostPoses.PIN_T
	if act == "take":
		fig.pose_request = "scan"; busy_until = now + PostPoses.SCAN_T + T + 0.3
		_job_after(PostPoses.SCAN_T, "pin"); _job_after(PostPoses.SCAN_T + PostPoses.PIN_IN, "take"); _job_after(PostPoses.SCAN_T + T, "stand")
	else:
		fig.pose_request = "pin"; busy_until = now + T + 0.3
		_job_after(PostPoses.PIN_IN, act); _job_after(T, "stand")
	return true

func _job_after(secs: float, step: String) -> void:
	get_tree().create_timer(secs).timeout.connect(_job_step.bind(step))

## 한 박자 — 그새 맞았거나 자리를 떠났으면 없던 일
func _job_step(step: String) -> void:
	if state != "busy" or not is_same(spot, town.jobs) or not (fig.pose_request in ["pin", "scan"]): return
	var now := Time.get_ticks_msec() / 1000.0
	match step:
		"pin": fig.pose_request = "pin"
		"take":
			var card: Dictionary = town.job_top()
			if card.is_empty(): return   # 읽는 새 누가 떼어 갔다 — 빈 판을 보고 간다
			town.job_take(card, self); say(mind.line("job_take"), 1.8)
		"post":
			var task: String = town.job_wanted(self)
			if task == "" or coins <= 0 or (town.job_post(task, self, now) as Dictionary).is_empty(): return
			coins -= 1; set_meta("posted", now); say(mind.line("job_post"), 1.8)
		"down":
			var mine: Dictionary = town.job_mine(self)
			if not mine.is_empty(): town.job_remove(mine, true); say(mind.line("job_down"), 1.8)
		"stand": fig.pose_request = ""
