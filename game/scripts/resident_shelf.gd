class_name ResidentShelf
extends ResidentPair
## 책 상자(run 98, "Leave one, take one" 1조각) — 사람이 C 로 하는 것과 같은 shelve 자세, 같은 shelve_book/unshelve_book(town_swap).
## 관리인(골목 첫 집 문에 "librarian")은 낮(09–17) 넷 중 셋은 상자 곁에 서 있고, 9시대와 16시대 첫 방문엔 책등을 세 번 고른다(재고는 그대로).
## 지나가는 사람(12m 안): 책을 든 이는 여섯에 하나 들러 꽂고 둘에 하나는 다른 책을 꺼내 가고, 빈손인 이는 여섯에 하나 하나 꺼내 그 자리에서 몇 초 읽는다 —
## 마지막 한 권은 남겨 둔다(사람은 다 꺼내도 된다). 평범한 결과(지나쳐 걷기)가 가장 흔하다. 사슬: base → life → pair → **shelf** → resident

var _tidied := -1   # 마지막으로 책등을 고른 시각대(9 | 16) — 한 시각대에 한 번

## 상자로 갈 이유 — 못 가면 false(_pick_spot 이 다음 규칙으로)
func _swap_pick(now: float) -> bool:
	var bx: Dictionary = town.bookbox
	if bx.is_empty() or town.is_night() or weather == "rain" or has_umb or _free_slot(bx) < 0: return false
	var h := _hour(); var go := false
	if job == "librarian": go = h >= 9.0 and h < 17.0 and randf() < 0.75
	elif carrying_kind == "book" and fig.carrying != null and fig.carrying.has_meta("lent"): go = int(bx["stock"]) < town.BOOK_MAX   # 이야기방 선반에서 집어 온 책(run 106)은 멀어도 꼭 돌려놓는다 — 칸이 다 찼으면 들고 다니다 다음에
	elif global_position.distance_to(bx["pos"]) < 12.0 and randf() < 1.0 / 6.0:
		go = carrying_kind == "book" or (fig.carrying == null and int(bx["stock"]) > 1)
	if not go: return false
	slot = _free_slot(bx); spot = bx; _claim(bx, slot)
	route = town.via_bridge(global_position, [{ "pos": bx["pos"] + Vector3(-0.3 + 0.6 * slot, 0, 0.05), "act": "" }])
	target = route[0]["pos"]; state = "walk"; busy_until = now
	return true

## 상자에 닿음(resident.gd _arrive) — 이 상자가 아니면 false. 손이 칸에 닿는 순간마다 _swap_step 이 책을 바꾼다
func _swap_arrive(now: float) -> bool:
	if not is_same(spot, town.bookbox): return false
	fig.face(spot.get("yaw", PI))
	var T := ShelfPoses.SHELVE_T; var h := int(_hour())
	if job == "librarian":
		if (h == 9 or h == 16) and _tidied != h:
			_tidied = h; fig.pose_request = "shelve"; busy_until = now + T * 3.0 + randf_range(10.0, 20.0)
			_after(T * 3.0, "stand"); say(mind.line("book_swap"), 1.6)
		else:
			busy_until = now + randf_range(20.0, 40.0)
		return true
	if carrying_kind == "book":
		fig.pose_request = "shelve"; busy_until = now + T * 2.0 + 0.2
		_after(ShelfPoses.SHELVE_IN, "put")
		if randf() < 0.5: _after(T + ShelfPoses.SHELVE_IN, "take"); _after(T * 2.0, "read")
		else: _after(T, "stand")
	elif fig.carrying == null:
		fig.pose_request = "shelve"; busy_until = now + T + 0.2
		_after(ShelfPoses.SHELVE_IN, "take"); _after(T, "read")
	else:
		busy_until = now + randf_range(2.0, 4.0)   # 그새 손이 찼다(주운 것) — 구경만
	return true

func _after(secs: float, step: String) -> void:
	get_tree().create_timer(secs).timeout.connect(_swap_step.bind(step))

## 한 박자 — 그새 맞았거나 자리를 떠났으면(상태·자리·자세가 바뀌었으면) 없던 일
func _swap_step(step: String) -> void:
	if state != "busy" or not is_same(spot, town.bookbox) or not (fig.pose_request in ["shelve", "read"]): return
	match step:
		"put":
			if town.shelve_book(fig, fig.carrying): carrying_kind = ""
		"take":
			if town.unshelve_book(fig): carrying_kind = "book"; say(mind.line("book_swap"), 1.6)
		"read":
			if carrying_kind == "book":
				fig.pose_request = "read"; busy_until = Time.get_ticks_msec() / 1000.0 + randf_range(4.0, 7.0)   # 꺼낸 자리에서 몇 장 — 사람이 C 로 펼치는 것과 같은 read
			else: fig.pose_request = ""
		"stand":
			fig.pose_request = ""
