class_name ResidentLetters
extends ResidentShelf
## 편지방 우편함(run 99, "Letters and notes" 1조각) — 사람이 C 로 하는 것과 같은 sort 자세, 같은 post_letter/unpost_letter(town_letters). 문을 열고 들어가 우편함 앞에 선다.
## 서기(편지방 문에 "scribe")는 낮(09–17) 넷 중 셋은 우편함 곁에 있고, 9–10시대 첫 방문엔 그날 편지를 세 바퀴(아래·가운데·위 단) 칸에 넣는다(+1씩, 열둘까지).
## 지나가는 사람(16m 안, 다섯에 하나): 종이나 편지를 든 이는 들러 꽂고, 빈손인 이는 하나 꺼내 그 자리에서 몇 초 읽고 들고 간다 —
## 마지막 한 통은 남겨 둔다(사람은 다 꺼내도 된다). 평범한 결과(지나쳐 걷기)가 가장 흔하다. 사슬: base → life → pair → shelf → **letters** → resident
## 광장 게시판(run 100): 10m 안을 지나는 이는 다섯에 하나 들른다 — 종이·편지를 들었으면 핀으로 꽂고(pin), 아니면 뒷짐 지고 3–5초 읽는다(scan);
## 빈손으로 읽은 이는 넷에 하나 가장 새 쪽지를 떼어 간다(사람의 빈손 C 와 같다). 서기는 16시대에 하루 넘은 쪽지를 떼어 다발로 들고 우편함에 넣는다

var _bundle := 0   # 서기가 게시판에서 이번에 뗀 쪽지 수(run 100)
var _posted := -1e9   # 서기가 마지막으로 아침 편지를 넣은 시각 — 하루(반나절 넘게 지나야) 한 번. 마을엔 날짜 셈이 없다

## 편지 일로 갈 곳 — 게시판, 아니면 우편함. 못 가면 false(_pick_spot 이 다음 규칙으로)
func _post_pick(now: float) -> bool:
	return _notice_pick(now) or _wall_pick(now)

func _wall_pick(now: float) -> bool:
	var lw: Dictionary = town.letterwall
	if lw.is_empty() or town.is_night() or _free_slot(lw) < 0: return false
	var h := _hour(); var go := false
	if job == "scribe": go = (h >= 9.0 and h < 17.0 and randf() < 0.75) or (carrying_kind == "paper" and fig.carrying != null and fig.carrying.has_meta("count"))   # 게시판에서 뗀 다발은 곧장 넣으러
	elif global_position.distance_to(lw["pos"]) < 16.0 and randf() < 0.2:
		go = (carrying_kind in ["paper", "letter"] and int(lw["stock"]) < town.LETTER_MAX) or (fig.carrying == null and int(lw["stock"]) > 1)
	if not go: return false
	slot = _free_slot(lw); spot = lw; _claim(lw, slot)
	door_ref = lw["door"]; var dp: Vector3 = door_ref["pos"]
	route = town.via_bridge(global_position, call("_approach", door_ref) + [{ "pos": dp + Vector3(0, 0, 0.8), "act": "open" }, { "pos": dp + Vector3(0, 0, -1.3), "act": "close" }, { "pos": lw["pos"] + Vector3(-0.3 + 0.6 * slot, 0, 0.05), "act": "" }])
	target = route[0]["pos"]; state = "walk"; busy_until = now
	return true

## 우편함에 닿음(resident.gd _arrive) — 이 우편함이 아니면 false. 손이 칸에 닿는 순간마다 _post_step 이 편지를 바꾼다
func _post_arrive(now: float) -> bool:
	if not is_same(spot, town.letterwall): return _notice_arrive(now)   # 게시판도 여기서(resident.gd 가 500줄 끝이라 한 줄 더 못 단다)
	fig.face(spot.get("yaw", PI))
	var T := PostPoses.SORT_T
	if job == "scribe" and fig.carrying != null and fig.carrying.has_meta("count"):   # 게시판 다발 — 한 번 꽂으면 여러 통(post_letter)
		fig.pose_request = "sort"; busy_until = now + T + 0.3
		_post_after(PostPoses.SORT_IN, "put"); _post_after(T, "stand"); say(mind.line("letter_in"), 1.6)
	elif job == "scribe":
		if _hour() < 11.0 and now - _posted > town.DAY_LEN * 0.5:
			_posted = now; fig.pose_request = "sort"; busy_until = now + T * 3.0 + randf_range(15.0, 30.0)
			for i in 3: _post_after(T * i + PostPoses.SORT_IN, "morning")
			_post_after(T * 3.0, "stand"); say(mind.line("letter_in"), 1.6)
		else:
			fig.pose_request = "sort"; busy_until = now + randf_range(20.0, 40.0)   # 칸 정리 — 재고는 그대로, 세 단을 돌며 줄만 맞춘다
			_post_after(T * 2.0, "stand")
		return true
	elif carrying_kind in ["paper", "letter"]:
		fig.pose_request = "sort"; busy_until = now + T + 0.3
		_post_after(PostPoses.SORT_IN, "put"); _post_after(T, "stand")
	elif fig.carrying == null:
		fig.pose_request = "sort"; busy_until = now + T + 0.2
		_post_after(PostPoses.SORT_IN, "take"); _post_after(T, "read")
	else:
		busy_until = now + randf_range(2.0, 4.0)   # 그새 손이 찼다 — 구경만
	return true

func _post_after(secs: float, step: String) -> void:
	get_tree().create_timer(secs).timeout.connect(_post_step.bind(step))

## 한 박자 — 그새 맞았거나 자리를 떠났으면(상태·자리·자세가 바뀌었으면) 없던 일
func _post_step(step: String) -> void:
	if state != "busy" or not is_same(spot, town.letterwall) or not (fig.pose_request in ["sort", "read"]): return
	var lw: Dictionary = town.letterwall
	match step:
		"put":
			if town.post_letter(fig, fig.carrying): carrying_kind = ""
		"take":
			if town.unpost_letter(fig): carrying_kind = "letter"; say(mind.line("letter_out"), 1.6)
		"morning":
			if int(lw["stock"]) < town.LETTER_MAX: lw["stock"] = int(lw["stock"]) + 1; town._show_stock(lw)   # 아침 편지 — 손이 칸에 닿는 순간 한 통씩
		"read":
			if carrying_kind == "letter":
				fig.pose_request = "read"; busy_until = Time.get_ticks_msec() / 1000.0 + randf_range(4.0, 7.0)   # 꺼낸 자리에서 읽는다 — 사람이 C 로 펼치는 것과 같은 read
			else: fig.pose_request = ""
		"stand":
			fig.pose_request = ""

## 게시판으로 갈 이유 — 비·밤엔 안 간다. 서기는 16–17시에 하루 넘은 쪽지가 있을 때만
func _notice_pick(now: float) -> bool:
	var nb: Dictionary = town.notice
	if nb.is_empty() or town.is_night() or weather == "rain" or has_umb or _free_slot(nb) < 0: return false
	var go := false
	if job == "scribe": go = _hour() >= 16.0 and _hour() < 17.0 and fig.carrying == null and not town.old_notes(now).is_empty()
	elif global_position.distance_to(nb["pos"]) < 10.0 and randf() < 0.2:
		go = (carrying_kind in ["paper", "letter"] and town.note_slot() >= 0) or not (nb["notes"] as Array).is_empty()
	if not go: return false
	slot = _free_slot(nb); spot = nb; _claim(nb, slot)
	route = town.via_bridge(global_position, [{ "pos": nb["pos"] + Vector3(-0.35 + 0.7 * slot, 0, 0.05), "act": "" }])
	target = route[0]["pos"]; state = "walk"; busy_until = now
	return true

## 게시판에 닿음 — 이 판이 아니면 false
func _notice_arrive(now: float) -> bool:
	if not is_same(spot, town.notice): return false
	fig.face(spot.get("yaw", PI))
	var T := PostPoses.PIN_T
	var old: int = mini(town.old_notes(now).size(), 6) if job == "scribe" and fig.carrying == null else 0
	if old > 0:   # 서기: 한 바퀴에 한 장씩 떼어 다발로
		fig.pose_request = "pin"; busy_until = now + T * old + 0.4
		for i in old: _notice_after(T * i + PostPoses.PIN_IN, "old")
		_notice_after(T * old, "bundle")
	elif carrying_kind in ["paper", "letter"] and town.note_slot() >= 0:
		fig.pose_request = "pin"; busy_until = now + T + 0.3
		_notice_after(PostPoses.PIN_IN, "pin"); _notice_after(T, "stand")
	else:
		var stay := randf_range(3.0, 5.0)
		fig.pose_request = "scan"; busy_until = now + stay; say(mind.line("notice"), 1.8)
		if fig.carrying == null and randf() < 0.25: _notice_after(stay - T - 0.2, "pluck")   # 다 읽고 한 장 떼어 간다 — 셋은 그냥 간다
	return true

func _notice_after(secs: float, step: String) -> void:
	get_tree().create_timer(secs).timeout.connect(_notice_step.bind(step))

## 한 박자 — 그새 맞았거나 자리를 떠났으면 없던 일
func _notice_step(step: String) -> void:
	if state != "busy" or not is_same(spot, town.notice) or not (fig.pose_request in ["pin", "scan"]): return
	var now := Time.get_ticks_msec() / 1000.0
	match step:
		"pin":
			if town.pin_note(fig, fig.carrying, now): carrying_kind = ""
		"pluck":
			fig.pose_request = "pin"; busy_until = now + PostPoses.PIN_T + 0.2
			_notice_after(PostPoses.PIN_IN, "take"); _notice_after(PostPoses.PIN_T, "stand")
		"take":
			if town.unpin_note(fig): carrying_kind = String(fig.carrying.get_meta("kind", "paper"))
		"old":
			var old: Array = town.old_notes(now)
			if not old.is_empty():
				(town.notice["notes"] as Array).erase(old[0]); (old[0] as Node3D).queue_free(); _bundle += 1
		"bundle":
			if _bundle > 0 and fig.carrying == null:
				var b: Node3D = town.make_item("paper", Vector3.ZERO); b.set_meta("count", _bundle)
				fig.hold(b); carrying_kind = "paper"; say(mind.line("notice_down"), 1.8)
			_bundle = 0; fig.pose_request = ""
		"stand":
			fig.pose_request = ""
