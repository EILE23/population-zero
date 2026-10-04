class_name ResidentSunroom
extends ResidentLetters
## 이야기방(run 103, "Elders and children" 2조각) — 사람이 C 로 하는 것과 같은 자리·같은 자세(town_sunroom).
## 주인("storysitter")은 14:45–16 시에 문을 열고 들어가 안락의자에 앉아 책을 펴고 소리 내어 읽는다(story). 아이(job "child")는 14:30 부터 빈 방석으로 —
## 나설 때 곁의 부모가 "세 시에 이야기"를 말하고, 앉으면 끝날 때까지 책상다리(crossleg), 마지막 0.3초는 바닥을 짚고 일어선다.
## 나올 땐 _leave 뒤 _exit_house 가 문으로 데리고 나간다. 사슬: … → letters → **sunroom** → resident → kid
## 2b(run 104): 넘어졌다 일어난 어른(쫓지도 피하지도 않은 — 쫓는 쪽이 이긴다)이 이야기 시간에 문에서 14m 안이면 방석에 6–10초 앉는다 —
## 맞은 기억(last_hurt)이 15초 뒤로 밀려 기분이 먼저 돌아오고, 읽는 이가 달래는 한 줄(story_calm). 사람도 같은 자리에서 같은 줄(town_sunroom)

var shaken_at := -999.0   # resident.gd 가 일어선 순간 적는다 — 30초 안에만 센다

## 이야기방으로 갈 이유가 있나 — 있으면 걸어간다(true). 아이는 resident_kid 의 _pick_spot 도 이걸 먼저 부른다
func _story_pick(now: float) -> bool:
	var sr: Dictionary = town.sunroom
	if sr.is_empty() or not town.story_time(): return false
	var sp: Dictionary = {}
	if job == "storysitter" and _hour() >= 14.75 and _free_slot(sr["chair"]) >= 0: sp = sr["chair"]
	elif job == "child" or (now - shaken_at < 30.0 and global_position.distance_to(sr["door"]["pos"] as Vector3) < 14.0):
		for c: Dictionary in sr["cushions"]:
			if _free_slot(c) >= 0: sp = c; break
	if sp.is_empty(): return false
	slot = 0; spot = sp; _claim(sp, 0)
	door_ref = sr["door"]; var dp: Vector3 = door_ref["pos"]
	var off := Vector3(0.45, 0, 0) if sp["kind"] == "story" else Vector3(0, 0, 0.3)   # 의자는 앞(+x)에서, 방석은 문 쪽에서 다가간다
	route = town.via_bridge(global_position, call("_approach", door_ref) + [{ "pos": dp + Vector3(0, 0, 0.8), "act": "open" }, { "pos": dp + Vector3(0, 0, -1.3), "act": "close" }, { "pos": Vector3(sp["pos"].x, 0, sp["pos"].z) + off, "act": "" }])
	target = route[0]["pos"]; state = "walk"; busy_until = now
	var p: Variant = get("parent")
	if p is ResidentBase and is_instance_valid(p) and (p as ResidentBase).global_position.distance_to(global_position) < 12.0:
		(p as ResidentBase).say((p as ResidentBase).mind.line("story_call"), 1.8)   # 부모가 보낸다 — 퀘스트 대신 마을의 한마디
	return true

func _post_pick(now: float) -> bool:
	return _story_pick(now) or super._post_pick(now)

## 이야기방 자리에 닿음 — 남은 이야기 시간만큼 앉는다(시계 한 시간 = DAY_LEN/24 초)
func _post_arrive(now: float) -> bool:
	var k: String = spot.get("kind", "")
	if k != "story" and k != "cushion": return super._post_arrive(now)
	var shaken: bool = k == "cushion" and job != "child"   # 어른이 방석에 왔다면 넘어졌다 온 사람(_story_pick) — 끝까지가 아니라 잠깐
	var left := randf_range(6.0, 10.0) if shaken else maxf(2.0, (town.STORY_TO - _hour()) * town.DAY_LEN / 24.0)
	fig.seated = true; collision_layer = 0; collision_mask = 0
	fig.face(spot.get("yaw", 0.0)); busy_until = now + left
	if k == "story":
		global_position = spot["pos"] + Vector3(0, 0.02, 0)
		if fig.carrying == null: fig.hold(town.make_item("book", Vector3.ZERO)); carrying_kind = "book"; fig.carrying.set_meta("story", true)
		fig.pose_request = "story"; say(mind.line("story_open"), 1.8)
		get_tree().create_timer(left - 0.1).timeout.connect(_close_book)
	else:
		global_position = spot["pos"] + Vector3(0, -0.08, 0)
		fig.pose_request = "crossleg"; fig.set_meta("cross_up", fig._t + left - SunroomPoses.UP_T)   # 끝나기 0.3초 전에 바닥을 짚고 일어서기 시작
		if shaken: shaken_at = -999.0; mind.last_hurt -= 15.0   # 한 번만, 그리고 맞은 기억이 15초 먼저 옅어진다(mind.tick 의 30초 항)
		var reader: ResidentBase = town.storysitter_here()
		if reader: reader.say(reader.mind.line("story_calm" if shaken else "story"), 2.4); mind.befriend(reader, 0.1)
	return true

## 이야기가 끝났다 — 주인의 책은 이 집 것이라 덮어 둔다(맞아서 떨어뜨렸으면 그 책은 마을에 남는다)
func _close_book() -> void:
	if fig.carrying != null and fig.carrying.has_meta("story"):
		fig.release(town, Vector3.ZERO).queue_free(); carrying_kind = ""
