class_name ResidentStore
extends ResidentShop
## 잡화점 손님(money 2, run 114 — town_store.gd): 낮에 주머니에 값이 있고(품삯·주운 동전) 모자가 없거나 등이 비면, 열린 잡화점 문 앞에 가서 값을 내고 그 자리에서 쓴다(don) —
## 사람이 하는 것과 같은 자세·같은 돈. 어울림이 높은 사람일수록 자주 간다(mind.social — 꾸미는 건 남 보라고 하는 일); 아이는 안 산다(아이 주머니엔 동전이 안 는다). 닫혀 있으면 한마디 하고 돌아선다.
## 사슬: … → shop → **store** → resident

func _post_pick(now: float) -> bool:
	return _store_pick(now) or super._post_pick(now)

func _post_arrive(now: float) -> bool:
	return _store_arrive(now) or super._post_arrive(now)

func _store_pick(now: float) -> bool:
	if self is ResidentKid or town.is_night() or weather == "rain" or fig.carrying or coins < 4 or randf() > 0.06 + 0.12 * mind.social: return false   # 보통 모자값 넷
	if fig.worn.has("hat") and fig.worn.has("back") and randf() < 0.7: return false   # 다 갖춘 사람은 가끔만(다른 모자)
	var sh: Dictionary = town.call("store_near", global_position)
	if sh.is_empty() or global_position.distance_to(sh["pos"]) > 60.0: return false
	var sp: Dictionary = town.call("store_front", sh)
	var i := _free_slot(sp)
	if i < 0: return false
	spot = sp; slot = i; _claim(sp, i)
	route = town.via_bridge(global_position, [{ "pos": sp["pos"], "act": "" }])
	target = route[0]["pos"]; state = "walk"; busy_until = now
	return true

func _store_arrive(now: float) -> bool:
	if spot.get("kind", "") != "store": return false
	fig.face(float(spot.get("yaw", 0.0)))
	var shops: Array = town.get("shops")
	var sh: Dictionary = shops[int(spot["shop_id"])]
	if town.call("store_buy", self, sh):
		busy_until = now + WearPoses.DON_T + 1.6
	else:
		say(mind.line("store_closed"), 1.4); busy_until = now + 1.5
	return true
