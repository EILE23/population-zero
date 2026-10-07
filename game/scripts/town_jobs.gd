class_name TownJobs
extends TownStore
## 심부름판(운영자 2026-10-06 "진짜 화폐로 키우자" money 3 = "Money in hands" 5조각, run 115 — 마을의 첫 과제 체계): 광장 게시판 서쪽 3m 의 둘째 판(모브 틀, 칸 셋).
## 동전이 있고 진짜 모자란 게 있는 어른이 pin 으로 카드를 꽂는다 — 카드엔 제 주머니에서 나온 동전이 원판으로 붙어 있다(그게 품삯): "Two logs to the stove"(오두막 더미 < 3),
## "Knead one"(빵집 창구 0 이고 배고프다). 한 사람 하루 한 장, 같은 일은 한 장만. 지나던 빈손 어른은 읽고(scan) 맨 위 카드를 떼어(pin) 그 일의 자리로 간다(resident_jobs.gd) —
## 장작은 나무꾼과 같은 _wood_pick 길, 반죽은 화덕(resident.gd 의 "oven" 가지는 누구든 반죽한다). 일이 된 것은 세상으로 센다: 카드를 든 이가 자리 곁(2.2m)에 있는 동안
## 더미+화실이 둘 늘거나(쌓거나 넣거나) 창구가 하나 늘면 — 그때 동전이 그 주머니로(mind.line "job_done"). 사람도 같다: 판 앞 빈손 C 로 맨 위 카드를 떼면 종이(meta job)가 손에,
## 같은 자리에서 같은 일을 하면 같은 동전(토스트). 종이를 든 채 판 앞 C 면 도로 꽂는다. 아무도 안 뗀 카드는 17시에 쓴 이가 와서 떼고 동전을 도로 주머니에(pin).
## 뗀 채 반나절이 가거나 남이 먼저 해 버리면 동전은 쓴 이에게 조용히 돌아간다(아침 8시 안전망도 같다). 평범한 결과: 모든 일은 전부터 공짜로 할 수 있었다 — 판은 부탁과 동전만 얹는다.
## 사슬: … → wages → store → **jobs** → pawn(town_pawn.gd, 전당포 — run 116) → player → town3d

const JOBS_AT := Vector3(-8.5, 0, -9.4)   # 게시판(NOTICE_AT −5.5) 서쪽 3m — 넷째 집(x ≤ −10.2) 동쪽 벽에서 1m, 큰길 띠에서 9m
const CARD_MAX := 3
const TAKEN_MAX_S := 360.0     # 뗀 뒤 이만큼(반나절) 안에 못 하면 동전은 쓴 이에게
const TASKS := { "logs": { "text": "Two logs to the stove", "n": 2 }, "knead": { "text": "Knead one", "n": 1 } }

var jobs: Dictionary = {}      # 자리 {pos, kind "jobs", yaw, at, cards: [{node, slot, task, by, taker: null|ResidentBase|"player", t0, base, done, paper?, gone?}]}
var _jobs_h := -1.0

## 둘째 판 — 게시판과 같은 틀(town_letters _board_frame), 틀은 모브(accent-deep), 머리 판자에 글씨
func _jobsboard(at: Vector3) -> void:
	_board_frame(at, _mat(Color("7b526c")))
	var sign := Label3D.new(); sign.text = "ODD JOBS"; sign.font_size = 18; sign.pixel_size = 0.004; sign.modulate = Color("f7f4ef")
	sign.position = at + Vector3(0, 1.45, 0.11); _add(sign)
	jobs = { "pos": at + Vector3(0, 0, 0.75), "kind": "jobs", "yaw": PI, "at": at, "cards": [] }
	spots.append(jobs)

## 카드 한 장 — 종이, 핀, 잉크 두 줄(부탁), 아래에 붙은 동전 원판(품삯이 보인다). 칸마다 조금씩 비뚤게
func _card_node(slot: int) -> Node3D:
	var at: Vector3 = jobs["at"]
	var n := _box(Vector3(0.2, 0.24, 0.006), at + Vector3(-0.4 + 0.4 * slot + randf_range(-0.04, 0.04), 0.78, 0.03), _mat(Color("f7f4ef")), false)
	n.rotation.z = randf_range(-0.1, 0.1)
	_box(Vector3(0.024, 0.024, 0.02), Vector3(0, 0.1, 0.006), _mat(Color("ad7096")), false, n)
	for i in 2: _box(Vector3(0.13, 0.004, 0.004), Vector3(-0.01 + 0.02 * i, 0.04 - i * 0.03, 0.005), _mat(Color("4a4a52")), false, n)
	var d := MeshInstance3D.new(); var cy := CylinderMesh.new(); cy.top_radius = 0.03; cy.bottom_radius = 0.03; cy.height = 0.006; cy.radial_segments = 14
	d.mesh = cy; d.material_override = _mat(Color("e8c766")); d.position = Vector3(0.03, -0.07, 0.006); d.rotation.x = PI / 2.0; n.add_child(d)
	return n

func _card_slot() -> int:
	var used: Array = (jobs["cards"] as Array).map(func(c: Dictionary) -> int: return int(c["slot"]))
	for i in CARD_MAX:
		if not (i in used): return i
	return -1

## 이 일의 카드가 판에(또는 누군가의 손에) 있나
func job_posted(task: String) -> bool:
	return (jobs["cards"] as Array).any(func(c: Dictionary) -> bool: return String(c["task"]) == task)

## 이 사람이 지금 부탁할 만한 일 — 진짜 모자란 것만, 아직 카드가 없는 일만. 없으면 ""
func job_wanted(r: ResidentBase) -> String:
	if not woodcut.is_empty() and (woodcut["stack"] as Array).size() < 3 and not job_posted("logs"): return "logs"
	if not oven.is_empty() and int((oven["counter"] as Dictionary).get("stock", 0)) <= 0 and r.mind.full < 0.6 and not job_posted("knead"): return "knead"
	return ""

## 아직 할 만한가 — 더미가 꽉 찼거나 창구가 셋이면 끝(남이 먼저 했다)
func job_open(task: String) -> bool:
	if task == "logs": return not woodcut.is_empty() and (woodcut["stack"] as Array).size() < STACK_MAX
	return not oven.is_empty() and int((oven["counter"] as Dictionary).get("stock", 0)) < 3

## 세상의 수 — 이게 곁에서 늘면 한 몫
func job_count(task: String) -> int:
	if task == "logs": return (woodcut["stack"] as Array).size() + int(woodcut["fire"])
	return int((oven["counter"] as Dictionary).get("stock", 0))

## 일하는 자리들 — 곁(2.2m)에 있어야 센다
func job_sites(task: String) -> Array:
	if task == "logs": return [(woodcut["pile"] as Dictionary)["pos"], (woodcut["stove"] as Dictionary)["pos"]]
	return [(oven["spot"] as Dictionary)["pos"]]

## 꽂기(resident_jobs — 동전은 호출자가 뺀다). 칸이 없으면 {}
func job_post(task: String, by: ResidentBase, now: float) -> Dictionary:
	var slot := _card_slot()
	if slot < 0 or jobs.is_empty(): return {}
	var card := { "node": _card_node(slot), "slot": slot, "task": task, "by": by, "taker": null, "t0": now, "base": 0, "done": 0 }
	(jobs["cards"] as Array).append(card)
	return card

## 맨 위(가장 새) 안 뗀 카드 — 없으면 {}
func job_top() -> Dictionary:
	var cards: Array = jobs["cards"]
	for i in range(cards.size() - 1, -1, -1):
		if (cards[i] as Dictionary)["taker"] == null: return cards[i]
	return {}

## 이 사람이 꽂았고 아직 아무도 안 뗀 카드 — 17시에 떼러 온다
func job_mine(r: ResidentBase) -> Dictionary:
	for c: Dictionary in jobs["cards"]:
		if c["taker"] == null and is_same(c["by"], r): return c
	return {}

## 떼기 — 판에서 내려와 든 이의 일이 된다. base 는 지금 세상의 수: 곁에서 거기서 n 만큼 늘면 된 것
func job_take(card: Dictionary, who: Variant) -> void:
	if card["node"] != null: (card["node"] as Node3D).queue_free(); card["node"] = null
	card["taker"] = who; card["t0"] = Time.get_ticks_msec() / 1000.0; card["base"] = job_count(card["task"]); card["done"] = 0
	if who is ResidentBase: (who as ResidentBase).set_meta("card", card)

## 도로 꽂기(사람이 종이를 들고 판 앞 C) — 같은 칸에 다시
func job_putback(card: Dictionary) -> void:
	card["taker"] = null; card["node"] = _card_node(int(card["slot"])); card.erase("paper")

## 치우기 — refund 면 동전은 쓴 이의 주머니로(안 뗀 채 저녁, 반나절 지남, 남이 먼저). 든 이의 손에서 카드 표를 뗀다
func job_remove(card: Dictionary, refund: bool) -> void:
	if card["node"] != null: (card["node"] as Node3D).queue_free(); card["node"] = null
	var who: Variant = card["taker"]
	if who is ResidentBase and is_instance_valid(who) and (who as ResidentBase).has_meta("card"): (who as ResidentBase).remove_meta("card")
	if card.has("paper") and is_instance_valid(card["paper"]): (card["paper"] as Node3D).remove_meta("job")
	var by: Variant = card["by"]   # 타입을 박으면 그새 지워진 노드를 넣을 때 멈춘다
	if refund and is_instance_valid(by): (by as ResidentBase).coins += 1
	card["gone"] = true
	(jobs["cards"] as Array).erase(card)

## 됐다 — 카드의 동전이 한 이의 주머니로. 쓴 이는 고마워한다(주민끼리는 사이가, 사람이면 호감이 는다)
func _job_pay(card: Dictionary) -> void:
	var who: Variant = card["taker"]; var by: Variant = card["by"]
	if who is ResidentBase:
		var r: ResidentBase = who; r.coins += 1; r.say(r.mind.line("job_done"), 1.8)
		if is_instance_valid(by): (by as ResidentBase).mind.befriend(r, 0.15)
	else:
		_set_coins(coins + 1); say_toast("%s. Done. Paid 1 coin." % TASKS[card["task"]]["text"])
		if is_instance_valid(by): (by as ResidentBase).mind.gifted()

## 매 프레임(town_systems _tick): 든 카드마다 — 곁에서 세상의 수가 늘면 한 몫, 다 되면 품삯; 반나절이 갔거나 남이 먼저면 돌려준다. 곁에 없을 때 는 수는 기준만 올린다
func _jobs_tick(now: float) -> void:
	if jobs.is_empty(): return
	_jobs_hours()
	for card: Dictionary in (jobs["cards"] as Array).duplicate():
		var who: Variant = card["taker"]
		if who == null: continue
		if who is ResidentBase and not is_instance_valid(who): job_remove(card, true); continue
		var task: String = card["task"]
		var p: Vector3 = (who as ResidentBase).global_position if who is ResidentBase else body.global_position
		var near := false
		for s: Vector3 in job_sites(task):
			if p.distance_to(s) < 2.2: near = true
		var cnt := job_count(task)
		if near and cnt > int(card["base"]): card["done"] = int(card["done"]) + cnt - int(card["base"])
		card["base"] = cnt
		if int(card["done"]) >= int(TASKS[task]["n"]): _job_pay(card); job_remove(card, false); continue
		if now - float(card["t0"]) > TAKEN_MAX_S or not job_open(task): job_remove(card, true)

## 아침 8시 — 밤을 넘긴 카드는 안전망으로 치운다(쓴 이가 어제 저녁에 못 왔다): 동전은 돌아간다
func _jobs_hours() -> void:
	var h := fmod(clock * 24.0 + 6.0, 24.0)
	if _jobs_h >= 0.0 and _jobs_h < 8.0 and h >= 8.0 and h < 12.0:
		for card: Dictionary in (jobs["cards"] as Array).duplicate(): job_remove(card, true)
	_jobs_h = h

## 사람이 판 앞(1.1m)에서 C(town_player): 빈손이면 맨 위 카드를 떼어 종이(meta job)로 손에(pin, PIN_IN 에); 심부름 종이를 들었으면 도로 꽂는다. 둘 다 아니면 false — 호출자가 다음 규칙으로
func jobs_use(now: float) -> bool:
	if jobs.is_empty() or body.global_position.distance_to(jobs["pos"]) > 1.1: return false
	var it := player.carrying
	var put := it != null and it.has_meta("job")
	if not put and (it != null or job_top().is_empty()): return false
	player.face(jobs["yaw"]); reading = false
	player.pose_request = "pin"; use_until = now + PostPoses.PIN_T; action_until = use_until
	get_tree().create_timer(PostPoses.PIN_IN).timeout.connect(_job_hand.bind(put, it))
	return true

func _job_hand(put: bool, it: Node3D) -> void:
	if player.pose_request != "pin": return   # 그새 움직였거나 맞았다 — 없던 일
	if put:
		var card: Dictionary = it.get_meta("job")
		player.release(self, Vector3.ZERO).queue_free()
		if not card.get("gone", false): job_putback(card)   # 제 칸은 비워 둔 채였다; 그새 치워진 카드면 종이만 버린다
		return
	var card := job_top()
	if card.is_empty(): return
	var paper := make_item("paper", Vector3.ZERO); paper.set_meta("job", card)
	player.hold(paper); job_take(card, "player"); card["paper"] = paper
	say_toast("%s. A coin on it." % TASKS[card["task"]]["text"])
