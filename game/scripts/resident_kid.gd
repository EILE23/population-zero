class_name ResidentKid
extends Resident
## 아이("Elders and children" 1조각, run 102) — 3D 마을의 첫 아이 둘. 몸은 어른과 같은 리그·같은 자세를 0.62 배로(fig.base_scale, scale 은 Stick3D 가 매 프레임 덮어쓴다).
## 낮엔 부모 하나를 1.5m 안에서 따라다닌다: 부모가 벤치에 앉으면 옆 칸에, 집 안으로 들어가면 문 앞에서 기다린다. 걸을 땐 skip(stick3d_kid.gd).
## 밤·비엔 어른과 같은 일과(super) — 집 침대·실내로. 부모가 12m 넘게 놓치면 부모가 찾으러 온다(where_kid). 사슬: … → Resident → ResidentKid

const SIZE := 0.62
const NEAR := 1.5      # 이보다 멀어지면 다시 붙는다
const LOST := 12.0     # 이보다 멀면 부모가 찾으러 온다
var parent: Resident = null
var _fetch_at := 0.0

## 아이 둘을 들인다(town3d _ready, 운전사 뒤) — 같은 집에 사는 어른 둘 중 서로 가장 좋아하는 쌍(명부 friend 또는 정 > 0.6)의 집. 그런 쌍이 없으면 어른이 딱 둘인 집
static func settle(t: Node3D) -> void:
	var homes := {}
	for r: Resident in t.residents:
		if r.home_door.is_empty() or r.state == "drive": continue
		var key := str(r.home_door["pos"])
		if not homes.has(key): homes[key] = []
		(homes[key] as Array).append(r)
	var best: Array = []; var bk := 0.6
	var pair2: Array = []
	for key: String in homes:
		var hs: Array = homes[key]
		if hs.size() == 2 and pair2.is_empty(): pair2 = hs
		for i in hs.size():
			for j in range(i + 1, hs.size()):
				var a: Resident = hs[i]; var b: Resident = hs[j]
				var k := maxf(a.mind.relation_k(b), b.mind.relation_k(a))
				if k > bk: bk = k; best = [a, b]
	if best.is_empty(): best = pair2
	if best.size() < 2: return
	var names: Array = (ResidentMind._data.get("child", {}) as Dictionary).get("handles", ["small_print", "footnote"])
	for i in 2:
		var p: Resident = best[i]
		var kid := ResidentKid.new()
		t.add_child(kid)
		kid.setup(t, 9001 + i, String(names[i % names.size()]))
		kid.home_door = p.home_door; kid.job = "child"; kid.parent = p
		kid.fig.base_scale = Vector3.ONE * SIZE; kid.fig.set_meta("size", kid.fig.base_scale)   # 차에 깔렸다 펴질 때도 제 키로(car3d _flatten)
		kid.name_label.position.y = 0.95; kid.say_label.position.y = 1.1
		kid.position = p.position + Vector3(0.7, 0.0, 0.3)
		t.residents.append(kid)
		p.mind.befriend(kid, 0.8); kid.mind.befriend(p, 0.8)

## 지금 부모를 따라갈 수 있나 — 밤(잘 시간)·비(실내로)·부모가 운전·배·싸움 중이면 아이도 제 일과
func _with() -> bool:
	if parent == null or not is_instance_valid(parent) or town.is_night() or weather == "rain": return false
	return not (parent.state in ["drive", "chase", "down", "getup"] or parent.in_boat)

## 부모 옆 자리 — 아이마다 정해진 쪽(uid), 반 발짝 뒤
func _beside() -> Vector3:
	var y := parent.fig.rotation.y
	var side := 0.7 if uid % 2 == 0 else -0.7
	return parent.global_position + Vector3(cos(y), 0, -sin(y)) * side - Vector3(sin(y), 0, cos(y)) * 0.25

func _pick_spot() -> void:
	if not _with():
		super._pick_spot(); return
	var ps: Dictionary = parent.spot
	route = []
	if parent.state == "busy" and ps.get("kind", "") == "bench" and _free_slot(ps) >= 0:
		# 부모가 벤치에 앉아 있으면 옆 칸 — 어른과 같은 앉기(_arrive 의 bench)
		spot = ps; slot = _free_slot(ps); _claim(ps, slot)
		route = [{ "pos": ps["pos"] + Vector3([-0.45, 0.0, 0.45][slot], 0, 0.45), "act": "" }]
	elif ps.has("door") and (ps["door"] as Dictionary).has("pos"):
		# 부모가 집 안(의자·침대·선반·편지방)이면 문 앞에서 기다린다 — 문을 따라 들어가 벽에 갇히던 길을 피한다
		spot = { "kind": "follow", "wait": true }
		route = [{ "pos": (ps["door"]["pos"] as Vector3) + Vector3(0.6 if uid % 2 == 0 else -0.6, 0, 1.1), "act": "" }]
	else:
		spot = { "kind": "follow" }
		route = [{ "pos": _beside(), "act": "" }]
	route = town.via_bridge(global_position, route)
	target = route[0]["pos"]; state = "walk"

func _arrive(now: float) -> void:
	if spot.get("kind", "") != "follow":
		super._arrive(now); return
	state = "busy"; fig.pose_request = ""
	fig.face(atan2(parent.global_position.x - global_position.x, parent.global_position.z - global_position.z))
	busy_until = now + randf_range(0.6, 1.4)   # 짧게 서서 보다가 다시 붙는다(부모가 서 있으면 그 자리에서 또 선다)

func _physics_process(delta: float) -> void:
	_follow(Time.get_ticks_msec() / 1000.0)
	super._physics_process(delta)

func _follow(now: float) -> void:
	# 걸음: 걸을 땐 skip, 서면 푼다(다른 자세 — 우산·먹기 — 가 있으면 그대로)
	if state == "walk" and fig.pose_request == "": fig.pose_request = "skip"
	elif state != "walk" and fig.pose_request == "skip": fig.pose_request = ""
	var ps: Dictionary = parent.spot if parent and is_instance_valid(parent) else {}
	if parent and parent.state == "busy" and ps.get("kind", "") == "fetch" and ps.get("kid") == self and not ps.has("found"):
		ps["found"] = true; parent.say(parent.mind.line("kid_found"), 1.6)   # 찾으러 온 부모가 닿았다 — 아이를 보고 한마디
		parent.fig.face(atan2(global_position.x - parent.global_position.x, global_position.z - parent.global_position.z))
	if not _with():
		if pair == null: pace = 1.0   # 제 일과로 갈 땐 어른 걸음
		return
	var gap := global_position.distance_to(parent.global_position)
	var k: String = spot.get("kind", "")
	if state == "walk" and k == "follow" and not spot.has("wait") and route.size() <= 1:
		target = _beside()   # 부모가 움직이면 과녁도 움직인다(우회 경유지가 끼어 있으면 그대로 둔다)
		if pair == null: pace = 1.5 if gap > 2.5 else 1.0   # 뒤처지면 깡충깡충 서두른다 — 어른 걸음과 같은 1.0 이면 늘 반 걸음 뒤였다
	elif state == "busy" and gap > NEAR and parent.state == "walk" and (k == "follow" or (k == "bench" and not is_same(spot, parent.spot))):
		call("_leave"); busy_until = now   # 부모가 일어나 걸어가면 따라 일어난다 — 쉬지 않고 곧장
	elif state == "busy" and k == "follow" and spot.has("wait") and not parent.spot.has("door"):
		call("_leave"); busy_until = now   # 부모가 나왔다
	if gap > LOST and now > _fetch_at: _fetch(now)

## 부모가 아이를 놓쳤다 — 하던 걸 접고(가벼운 일일 때만) 아이에게 걸어간다. 닿으면 한마디. 앉아 있거나 실내·탈것이면 다음 기회에
func _fetch(now: float) -> void:
	var p := parent
	var light := p.state == "routine" or (p.state == "busy" and not p.fig.seated and p.riding_swing.is_empty() and p.riding_seesaw == null and p.bites == 0 and p.fig.pose_request in ["", "umbr"] and not p.spot.has("door"))
	if not light: return
	_fetch_at = now + 20.0
	if p.state == "busy": p._release()
	p.say(p.mind.line("where_kid"), 1.8)
	p.spot = { "kind": "fetch", "kid": self }
	p.route = town.via_bridge(p.global_position, [{ "pos": global_position + Vector3(0.6, 0, 0.4), "act": "" }])
	p.target = p.route[0]["pos"]; p.state = "walk"; p.fig.pose_request = ""

## 맞음 — 어른 어깨 높이로 오는 주먹·발은 아이 머리 위로 지나간다: 넘어지지 않고 반 발짝 물러선다(세상의 규칙 — 아무도 아이를 넘어뜨리지 않는다; 차는 그대로)
func hit(from_dir: Vector3, by: Node3D, heavy: bool, push := -1.0, lift := -1.0) -> void:
	if by is Car3D or state in ["down", "getup", "drive"]:
		super.hit(from_dir, by, heavy, push, lift); return
	say(mind.line("kid_duck"), 1.2)
	if parent and is_instance_valid(parent) and parent.global_position.distance_to(global_position) < 10.0 and by == town.body:
		parent.mind.witnessed(); parent.say(parent.mind.line("kid_hit_watch"), 1.6)
	if fig.seated or riding_seesaw or not riding_swing.is_empty() or in_boat: return   # 앉은 채 고개만 숙인다 — 자리는 그대로
	_release(); collision_layer = 4; collision_mask = 7
	var now := Time.get_ticks_msec() / 1000.0
	quarry = null; spot = { "kind": "hit" }; fig.pose_request = ""
	fig.action = "flinch"; fig.action_t = 0.0
	state = "busy"; busy_until = now + FightPoses.FLINCH_T
	var back := from_dir * 0.35; back.y = 0.0
	if not test_move(global_transform, back):   # 반 발짝 뒤로(벽이면 제자리) — busy 는 속도를 지우니 몸을 직접 옮긴다
		create_tween().tween_property(self, "global_position", global_position + back, FightPoses.FLINCH_T * 0.5)
