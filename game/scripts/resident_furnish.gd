class_name ResidentFurnish
extends ResidentPawn
## 가구를 사 들이는 주민(money 4, run 117 — town_furnish.gd): 낮에 주머니에 값이 모인 어른이(부지런할수록 자주 — 집을 가꾸는 건 게으른 이의 일이 아니다, mind.lazy) 열린 잡화점 문 앞에서
## 납작 상자를 하나 사서(주인 주머니로) 제 집 문 앞까지 들고 가 사람과 같은 plonk 으로 들인다 — 그 집 방에 가구가 는다(FURN_MAX 까지, 하루 하나). 비 오면·밤이면·든 게 있으면 안 간다.
## 오다가 맞아 떨어뜨리면 상자는 바닥의 물건(누구든 집는다). 사슬: … → jobs → pawn → **furnish** → resident

func _post_pick(now: float) -> bool:
	return _furnish_pick(now) or super._post_pick(now)

func _post_arrive(now: float) -> bool:
	return _furnish_arrive(now) or super._post_arrive(now)

func _furnish_pick(now: float) -> bool:
	if self is ResidentKid or town.is_night() or weather == "rain" or fig.carrying or has_umb or home_door.is_empty() or coins < 6: return false
	if now - float(get_meta("furn_day", -1e9)) < town.DAY_LEN * 0.9 or randf() > 0.03 + 0.08 * (1.0 - mind.lazy): return false
	if town.furn_count(home_door) >= town.FURN_MAX: return false
	var sh: Dictionary = town.store_near(global_position)
	if sh.is_empty() or global_position.distance_to(sh["pos"]) > 60.0: return false
	var sp: Dictionary = town.store_front(sh)
	var i := _free_slot(sp)
	if i < 0: return false
	set_meta("furn_act", "buy"); spot = sp; slot = i; _claim(sp, i)
	route = town.via_bridge(global_position, [{ "pos": sp["pos"], "act": "" }])
	target = route[0]["pos"]; state = "walk"; busy_until = now
	return true

## 가게 문 앞: 사서 집으로 걷는다 — 집 문 앞: plonk 으로 들인다. 이 길이 아니면 false
func _furnish_arrive(now: float) -> bool:
	var act := String(get_meta("furn_act", ""))
	if act == "": return false
	if act == "buy" and String(spot.get("kind", "")) == "store":
		remove_meta("furn_act")
		fig.face(float(spot.get("yaw", 0.0)))
		var shops: Array = town.get("shops")
		if not town.furn_buy(self, shops[int(spot["shop_id"])]):
			say(mind.line("store_closed"), 1.4); busy_until = now + 1.5; return true
		set_meta("furn_day", now); set_meta("furn_act", "home")
		_release()
		spot = { "kind": "furn_home", "pos": (home_door["pos"] as Vector3) + Vector3(0.9, 0, 1.1), "yaw": PI }; slot = 0
		route = town.via_bridge(global_position, [{ "pos": spot["pos"], "act": "" }])
		target = route[0]["pos"]; state = "walk"; busy_until = now + 0.3
		return true
	if act == "home" and String(spot.get("kind", "")) == "furn_home":
		remove_meta("furn_act")
		fig.face(PI)
		var it: Node3D = fig.carrying
		if it == null or not it.get_meta("flatpack", false): busy_until = now + 1.0; return true   # 오다가 떨어뜨렸다
		fig.pose_request = "plonk"; busy_until = now + FurnishPoses.PLONK_T + 1.2
		get_tree().create_timer(FurnishPoses.PLONK_DOWN).timeout.connect(func() -> void:
			if not is_instance_valid(self) or fig.pose_request != "plonk" or fig.carrying != it: return
			var kind := String(it.get_meta("kind", ""))
			fig.release(town, Vector3.ZERO).queue_free()
			town.furn_add(self, kind); say(mind.line("furnished"), 1.8))
		get_tree().create_timer(FurnishPoses.PLONK_T).timeout.connect(func() -> void:
			if is_instance_valid(self) and fig.pose_request == "plonk": fig.pose_request = "")
		return true
	return false
