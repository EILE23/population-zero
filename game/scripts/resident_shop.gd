class_name ResidentShop
extends ResidentBuild
## 가게 주인(town_city.gd, 지도의 번화가) — job "shopkeep" 은 낮이면 제 가게 창구 뒤에 가서 서 있는다(wait 팔짱, 90초씩). 서 있는 동안만 가게가 연다.
## 밤엔 다른 주민처럼 집으로 간다(가게도 닫는다). 다섯에 하나는 쉰다(주민은 자유다 — 그동안은 닫혀 있다)
## 사슬: … → build → **shop** → store(resident_store.gd, 잡화점 손님 — run 114) → resident

func _post_pick(now: float) -> bool:
	return _shop_pick(now) or super._post_pick(now)

func _pair_pick(now: float, chance := ResidentPair.PAIR_CHANCE) -> bool:
	return _shop_pick(now) or super._pair_pick(now, chance)

func _post_arrive(now: float) -> bool:
	return _shop_arrive(now) or super._post_arrive(now)

func _shop_pick(now: float) -> bool:
	if job != "shopkeep" or town.is_night() or fig.carrying or randf() < 0.2: return false
	var id := int(get_meta("shop_id", -1))
	var shops: Array = town.get("shops")
	if id < 0 or id >= shops.size(): return false
	var ks: Dictionary = shops[id]["keeper"]
	var i := _free_slot(ks)
	if i < 0: return false
	spot = ks; slot = i; _claim(ks, i)
	route = town.via_bridge(global_position, [{ "pos": ks["pos"], "act": "" }])
	target = route[0]["pos"]; state = "walk"; busy_until = now
	return true

func _shop_arrive(now: float) -> bool:
	if spot.get("kind", "") != "keeper": return false
	if not spot.has("inner"): return false   # 가게 방이 아직 없다(지어지기 전) — 그냥 다음 일과
	var ks := spot
	global_position = ks["inner"]   # 문 앞에서 가게 방 계산대 뒤로(town_interior — 로딩 없는 방)
	fig.face(float(ks.get("yaw", 0.0))); fig.pose_request = "wait"; busy_until = now + 90.0
	say(["Open.", "Morning.", "Right then.", "Shop's open."][randi() % 4], 1.4)
	get_tree().create_timer(89.5).timeout.connect(func() -> void:   # 일이 끝나면 문 앞으로 나온다
		if is_instance_valid(self) and spot == ks: global_position = ks["pos"])
	return true
