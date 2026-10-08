class_name TownPawn
extends TownJobs
## 전당포(운영자 2026-10-06 "진짜 화폐로 키우자" money 3b = "Money in hands" 7조각, run 116): 계단집 뒤 광장 동쪽 빈 땅의 부스 — 기둥 넷 위 지붕, 앞 계산대(상판 끝에 접시), 내려오는 모브 셔터, 뒤 선반 한 줄(꼬리표 칸 셋).
## 주인(job "pawnbroker" — uid % 24 == 5 인 어른, 없으면 일 없는 첫 어른)이 10:00–16:00 선반 뒤에 서 있는 동안만 셔터가 올라간다(문의 set_door 와 같은 tween — 셔터는 x 축으로 든다).
## 맡기기: 값이 있는 작은 것(prices.json "sell", 없으면 "buy" 의 반 — 먹을 것·동전·값 안 치른 가게 물건은 아니다)을 든 채 C → pass(run 86)로 건네면 PASS_HAND 에 물건이 선반 칸으로, 주인이 pass 로 동전을 건넨다(손의 원판, 주인의 PASS_HAND 에 주머니로).
## 찾기: 빈손 C, 주머니에 값+1 이 있으면 `put`(stick3d_coin.gd — 주머니에서 꺼내 접시에 놓는 새 자세)을 동전마다 한 번씩(시계를 되감는 palm_till 의 사슬), 마지막 동전에 물건이 손으로. 도중에 끊기면 낸 만큼은 꼬리표에 적힌다(paid) — 동전은 접시에 남고 값은 그만큼 준다.
## 아침 8시: 안 찾아간 것은 재고(꼬리표가 모브) — 지나는 누구든 "buy" 값(없으면 맡긴 값+1)에 같은 put 으로 산다. 주민도 같다(resident_pawn.gd): 빈 주머니에 배고픈 이는 쓴 모자를 벗어(doff) 맡기고, 값이 모이면 돌아와 찾아 쓴다(don); 모자 없는 이는 재고 모자를 산다.
## 접시의 동전은 16시에 주인이 palm 으로 거둔다(palm_till). 평범한 결과: 셔터는 하루의 셋 중 둘이 내려가 있고, 마을의 어느 것도 전당포 없이 돌아간다(빵은 외상으로도 먹는다).
## 사슬: … → store → jobs → **pawn** → player → town3d

const PAWN_AT := Vector3(8.6, 0, -10.0)   # 계단집(x 4.5..9.5, z −5.9..−2.1) 뒤 4m, 골목길(z −12..−14) 앞, 나무(13, −7)·골목 길(x 2.35..4.35)에서 떨어져; 큰길 띠(z −0.1..4.1)에서 10m
const PAWN_H := [10.0, 16.0]
const PAWN_SLOTS := 3
const SLOT_X := [-0.42, 0.0, 0.42]

var pawn: Dictionary = {}   # {at, node, spot(손님, kind "pawn"), keep(주인 자리), inner(주인이 서는 곳), dish(till/till_shown), shutter(경첩), open, broker, items: [{node, kind, by: ResidentBase|"player"|null, value, paid, stock, tag, slot, gone?}]}
var handing: Array = []     # 건네는 중 [{fig, who, item, t0, phase, bt0, coin}] — phase 0 손님의 pass · 1 주인의 pass(동전) · 2 끝
var paying: Array = []      # 내는 중 [{fig, who, e, cost, t0, phase, coin}] — phase 0 주머니로 · 1 손에 · 2 접시에
var _pawn_h := -1.0

## 부스(town3d _ready — 구역 밖, 게시판처럼 늘 서 있다)
func _pawn_post(at: Vector3) -> void:
	var n := Node3D.new(); n.name = "Pawn"; add_child(n)
	var wood := _mat(Color("6b4a35")); var paper := _mat(Color("f7f4ef"))
	for cx: float in [-0.68, 0.68]:
		for cz: float in [-0.42, 0.42]: _box(Vector3(0.08, 2.2, 0.08), at + Vector3(cx, 0, cz), wood, false, n)   # 기둥 넷 — 옆과 뒤는 트여 주인이 걸어 들어간다
	_box(Vector3(1.6, 0.08, 1.1), at + Vector3(0, 2.2, 0), _mat(Color("7b526c")), false, n)   # 지붕
	_box(Vector3(1.4, 0.9, 0.4), at + Vector3(0, 0, 0.25), _mat(Color("8a6a4a")), true, n)     # 계산대 — 유일하게 단단한 것
	_box(Vector3(1.5, 0.04, 0.5), at + Vector3(0, 0.9, 0.25), _mat(Color("e6d3a5")), false, n)   # 상판
	_box(Vector3(1.3, 0.04, 0.3), at + Vector3(0, 1.35, -0.3), wood, false, n)                 # 뒤 선반 — 맡긴 것이 앉는다
	var sign := Label3D.new(); sign.text = "PAWN"; sign.font_size = 20; sign.pixel_size = 0.004; sign.modulate = Color("f7f4ef")
	sign.position = at + Vector3(0, 2.1, 0.56); n.add_child(sign)
	var hinge := Node3D.new(); hinge.position = at + Vector3(0, 2.14, 0.47); n.add_child(hinge)   # 셔터 경첩 — 지붕 앞 모서리
	_box(Vector3(1.36, 1.18, 0.03), Vector3(0, -1.18, 0), _mat(Color("ad7096")), false, hinge)   # 내려온 셔터: 상판 위(y 0.96)부터 지붕까지
	var dp := at + Vector3(0.55, 0.945, 0.3)
	var shown: Array = []
	for i in TILL_MAX:
		var c := make_item("coin", dp + Vector3(0, i * 0.013, 0)); c.visible = false; shown.append(c)
	pawn = { "at": at, "node": n, "open": false, "items": [], "shutter": hinge }
	pawn["spot"] = { "pos": at + Vector3(0, 0, 1.05), "kind": "pawn", "yaw": PI }
	pawn["keep"] = { "pos": at + Vector3(0, 0, -1.0), "kind": "pawn_keep", "yaw": 0.0 }
	pawn["inner"] = at + Vector3(0, 0.02, -0.1)
	pawn["dish"] = { "pos": dp, "kind": "pawn_dish", "till": 0, "till_shown": shown }
	spots.append(pawn["spot"]); spots.append(pawn["keep"])

## 주인 — uid % 24 == 5 인 일 없는 어른, 없으면 일 없는 첫 어른(운전사 될 uid % 6 == 0 은 빼고). town3d _ready 가 악사 뒤, 운전사 앞에 부른다
func _hire_broker() -> void:
	if pawn.is_empty(): return
	var best: Resident = null
	for r: Resident in residents:
		if r.job != "" or r.uid % 6 == 0 or r is ResidentKid: continue
		if best == null or r.uid % 24 == 5: best = r
		if r.uid % 24 == 5: break
	if best == null: return
	best.job = "pawnbroker"; pawn["broker"] = best

func pawn_hours() -> bool:
	var h := fmod(clock * 24.0 + 6.0, 24.0)
	return h >= float(PAWN_H[0]) and h < float(PAWN_H[1])

## 16시까지 남은 초(주인의 근무 — resident_pawn)
func pawn_shift_left() -> float:
	return maxf(1.0, (float(PAWN_H[1]) - fmod(clock * 24.0 + 6.0, 24.0)) * DAY_LEN / 24.0)

## 맡길 값 — "sell"(어느 창구에서나 파는 값), 없으면 "buy" 의 반. 먹을 것·동전·종이는 0(안 받는다)
func pawn_value(kind: String) -> int:
	if kind in FOOD or kind in ["coin", "paper", "letter", ""]: return 0
	var sell: Dictionary = prices.get("sell", {}); var buy: Dictionary = prices.get("buy", {})
	if sell.has(kind): return int(sell[kind])
	return maxi(1, int(buy[kind]) / 2) if buy.has(kind) else 0

## 찾을(살) 값 — 제 것은 맡긴 값+1, 재고는 "buy"(없으면 맡긴 값+1); 낸 만큼은 뺀다
func pawn_cost(e: Dictionary) -> int:
	var base := int(e["value"]) + 1
	if e.get("stock", false): base = int((prices.get("buy", {}) as Dictionary).get(String(e["kind"]), base))
	return maxi(0, base - int(e.get("paid", 0)))

func pawn_slot_free() -> int:
	var used: Array = (pawn["items"] as Array).map(func(e: Dictionary) -> int: return int(e["slot"]))
	for i in PAWN_SLOTS:
		if not (i in used): return i
	return -1

## 이 사람의 것(안 팔린) — 없으면 {}
func pawn_mine(who: Variant) -> Dictionary:
	for e: Dictionary in pawn["items"]:
		if e.get("stock", false): continue
		if (who is String and e["by"] is String) or (who is Object and e["by"] is Object and is_same(e["by"], who)): return e
	return {}

## 재고 하나 — hat 이면 머리에 쓰는 종류만(주민 손님). 없으면 {}
func pawn_stock(hat := false) -> Dictionary:
	for e: Dictionary in pawn["items"]:
		if e.get("stock", false) and (not hat or String(e["kind"]) in ShopKit.MIX["cap"]): return e
	return {}

## 건네기 시작(사람 pawn_use · 주민 _pawn_arrive) — 호출자가 pass 자세를 올린다. PASS_HAND 에 물건이 선반으로, 그때 주인이 동전을 들고 pass 를 시작한다(_pawn_tick)
func hand_in(fig: Stick3D, who: Variant, item: Node3D, now: float) -> void:
	handing.append({ "fig": fig, "who": who, "item": item, "t0": now, "phase": 0, "bt0": 0.0, "coin": null })

## 내기 시작(사람 pawn_use · 주민 _pawn_arrive) — 호출자가 put 자세를 올린다. 동전마다 한 바퀴, 다 내면 물건이 손으로(_pawn_tick)
func pay_out(fig: Stick3D, who: Variant, e: Dictionary, cost: int, now: float) -> void:
	paying.append({ "fig": fig, "who": who, "e": e, "cost": cost, "t0": now, "phase": 0, "coin": null })

## 사람: 부스 앞(1.2m)에서 C(town_player — 입는 것을 쓰기보다 먼저: 모자도 맡긴다). 든 것이 값이 있으면 맡기고, 빈손이면 제 것(없으면 재고)을 찾는다. 둘 다 아니면 false — 호출자가 다음 규칙으로
func pawn_use(now: float) -> bool:
	if pawn.is_empty() or not seat.is_empty() or resting or rowing: return false
	var sp: Dictionary = pawn["spot"]
	if body.global_position.distance_to(sp["pos"]) > 1.2: return false
	var it := player.carrying
	if it != null:
		if pawn_value(String(it.get_meta("kind", ""))) <= 0 or it.has_meta("unpaid") or it.has_meta("job") or it.has_meta("free"): return false   # 공짜로 얻은 것(모자 걸이·우산꽂이·방 상자·냉장고)은 안 받는다 — 공짜 돈 구멍(리뷰 2026-10-08)
		if not pawn["open"]: say_toast("Shut. Ten till four."); action_until = now + 0.5; return true
		if pawn_slot_free() < 0: say_toast("The shelf is full."); action_until = now + 0.5; return true
		player.face(sp["yaw"]); player.set_meta("share_side", 1.0); player.pose_request = "pass"
		use_until = now + StickPoses.PASS_T; action_until = use_until
		hand_in(player, "player", it, now); return true
	var e := pawn_mine("player")
	if e.is_empty(): e = pawn_stock()
	if e.is_empty(): return false
	if not pawn["open"]: say_toast("Shut. Ten till four."); action_until = now + 0.5; return true
	var cost := pawn_cost(e)
	if coins < cost:
		say_toast(("%d coins for the %s." if e.get("stock", false) else "%d coins to take the %s back.") % [cost, e["kind"]]); action_until = now + 0.6; return true
	player.face(sp["yaw"]); player.pose_request = "put"
	use_until = now + CoinPoses.PUT_T * maxi(1, cost) + 0.1; action_until = use_until
	pay_out(player, "player", e, cost, now); return true

## 매 프레임(town_systems _tick): 셔터(주인이 선반 뒤에 서 있는 동안만 열린다), 8시·16시의 경계, 건네는 손들과 내는 손들의 진행
func _pawn_tick(now: float) -> void:
	if pawn.is_empty(): return
	var b: Variant = pawn.get("broker")
	var at: Vector3 = pawn["at"]
	var open: bool = b is ResidentBase and is_instance_valid(b) and (b as ResidentBase).state == "busy" and is_same((b as ResidentBase).spot, pawn["keep"]) and pawn_hours()
	if open != bool(pawn["open"]):
		pawn["open"] = open
		var tw := create_tween(); tw.set_ease(Tween.EASE_OUT); tw.set_trans(Tween.TRANS_CUBIC)
		tw.tween_property(pawn["shutter"], "rotation:x", -1.45 if open else 0.0, 0.45)
	if not open and b is ResidentBase and is_instance_valid(b):
		var p: Vector3 = (b as ResidentBase).global_position
		if absf(p.x - at.x) < 0.75 and absf(p.z - at.z) < 0.5 and (b as ResidentBase).state != "busy": (b as ResidentBase).global_position = (pawn["keep"] as Dictionary)["pos"]   # 근무가 끝나 나서는 주인 — 계산대에 막히지 않게 뒤로(가게 주인의 문 앞과 같다)
	_pawn_hours(b)
	_handing_tick(now, b)
	_paying_tick(now)

## 8시: 안 찾아간 것은 재고(꼬리표가 모브, 주인은 아무도 아니다). 16시: 접시에 동전이 있으면 주인이 palm 으로 거둔다
func _pawn_hours(b: Variant) -> void:
	var h := fmod(clock * 24.0 + 6.0, 24.0)
	if _pawn_h >= 0.0 and _pawn_h < 8.0 and h >= 8.0 and h < 12.0:
		for e: Dictionary in pawn["items"]:
			if e.get("stock", false): continue
			e["stock"] = true; e["by"] = null; (e["tag"] as MeshInstance3D).material_override = _mat(Color("ad7096"))
	var dish: Dictionary = pawn["dish"]
	if _pawn_h >= 0.0 and _pawn_h < float(PAWN_H[1]) and h >= float(PAWN_H[1]) and int(dish["till"]) > 0 and b is ResidentBase and is_instance_valid(b) and (b as ResidentBase).state == "busy" and is_same((b as ResidentBase).spot, pawn["keep"]):
		var r: ResidentBase = b
		r.fig.pose_request = "palm"; r.busy_until = Time.get_ticks_msec() / 1000.0 + CoinPoses.PALM_T * int(dish["till"]) + 0.6
		palm_till(r.fig, dish, r); r.say(r.mind.line("till_close"), 1.8)
	_pawn_h = h

## 손님의 pass: PASS_HAND 에 물건이 선반 칸으로(꼬리표가 붙는다) → 주인이 동전을 들고 pass → 주인의 PASS_HAND 에 손님 주머니로. 손님이 끊기면 없던 일; 주인이 끊기면 그 자리에서 값을 준다(물건은 이미 선반이다)
func _handing_tick(now: float, b: Variant) -> void:
	for e in handing.duplicate():
		var fig: Stick3D = e["fig"]; var who: Variant = e["who"]; var ph: int = e["phase"]
		if ph == 0:
			var broke: bool = fig.pose_request != "pass" or fig.carrying != e["item"] or (who is String and player.move_dir != Vector3.ZERO) or (who is ResidentBase and (who as ResidentBase).state != "busy")
			if broke: handing.erase(e); continue
			if now - float(e["t0"]) < StickPoses.PASS_HAND: continue
			var slot := pawn_slot_free()
			if slot < 0: handing.erase(e); continue
			e["entry"] = _shelve(fig.release(pawn["node"], Vector3.ZERO), who, slot)
			e["phase"] = 1; e["bt0"] = now
			if b is ResidentBase and is_instance_valid(b) and (b as ResidentBase).state == "busy" and is_same((b as ResidentBase).spot, pawn["keep"]):
				var r: ResidentBase = b
				r.fig.set_meta("share_side", 1.0); r.fig.pose_request = "pass"
				var c := make_item("coin", Vector3.ZERO)
				c.get_parent().remove_child(c); r.fig.hand_r.add_child(c); c.position = Vector3(0, -0.04, 0.03); c.rotation = Vector3(PI / 2.0, 0, 0)
				e["coin"] = c
			else: e["bt0"] = now - StickPoses.PASS_HAND   # 주인이 없다(그새 맞았다) — 값은 바로
		elif ph == 1:
			var done: bool = now - float(e["bt0"]) >= StickPoses.PASS_HAND or (b is ResidentBase and is_instance_valid(b) and (b as ResidentBase).fig.pose_request != "pass")
			if not done: continue
			if e["coin"] != null: (e["coin"] as Node3D).queue_free(); e["coin"] = null
			var v := int((e["entry"] as Dictionary)["value"])
			if who is ResidentBase: (who as ResidentBase).coins += v; (who as ResidentBase).say((who as ResidentBase).mind.line("hocked"), 1.8)
			else: _set_coins(coins + v); say_toast("Pawned. +%d, and %d to take it back." % [v, v + 1])
			if b is ResidentBase and is_instance_valid(b): (b as ResidentBase).say((b as ResidentBase).mind.line("pawn"), 1.8)
			e["phase"] = 2
		elif now - float(e["bt0"]) >= StickPoses.PASS_T:
			if b is ResidentBase and is_instance_valid(b) and (b as ResidentBase).fig.pose_request == "pass": (b as ResidentBase).fig.pose_request = ""
			handing.erase(e)

## 선반 칸에 앉힌다 — 꼬리표(종이, 재고가 되면 모브)를 앞에 달고, 바닥 목록에서 뺀다
func _shelve(item: Node3D, who: Variant, slot: int) -> Dictionary:
	var at: Vector3 = pawn["at"]
	items.erase(item)
	item.global_position = at + Vector3(SLOT_X[slot], 1.37, -0.3); item.rotation = Vector3.ZERO
	var tag := _box(Vector3(0.07, 0.09, 0.004), at + Vector3(SLOT_X[slot] + 0.12, 1.3, -0.14), _mat(Color("f7f4ef")), false, pawn["node"])
	_box(Vector3(0.04, 0.003, 0.003), Vector3(0, 0.02, 0.003), _mat(Color("4a4a52")), false, tag)   # 잉크 한 줄 — 이름
	var kind := String(item.get_meta("kind", ""))
	var e := { "node": item, "kind": kind, "by": who, "value": pawn_value(kind), "paid": 0, "stock": false, "tag": tag, "slot": slot }
	(pawn["items"] as Array).append(e)
	if who is ResidentBase: (who as ResidentBase).set_meta("pawned", e)
	return e

## put 의 시계로: PUT_IN 에 주머니에서 손으로(수가 준다), PUT_AWAY 에 손에서 접시로(원판이 하나 더 보인다, 꼬리표의 paid), PUT_T 에 다음 동전(시계를 되감는다) 또는 물건이 손으로. 손에 든 채 끊기면 주머니로 돌아간다
func _paying_tick(now: float) -> void:
	var dish: Dictionary = pawn["dish"]
	for e in paying.duplicate():
		var fig: Stick3D = e["fig"]; var who: Variant = e["who"]; var en: Dictionary = e["e"]; var t: float = now - float(e["t0"]); var ph: int = e["phase"]
		var broke: bool = fig.pose_request != "put" or (who is String and player.move_dir != Vector3.ZERO) or (who is ResidentBase and (who as ResidentBase).state != "busy") or en.get("gone", false)
		if broke:
			if ph == 1:
				(e["coin"] as Node3D).queue_free()
				if who is ResidentBase: (who as ResidentBase).coins += 1
				else: _set_coins(coins + 1)
			elif ph == 2 and int(e["cost"]) <= 0: _hand_out(fig, who, en)   # 마지막 동전은 접시에 있다 — 자세가 먼저 풀렸어도(town_player 의 use_until) 물건은 손으로
			paying.erase(e); continue
		if ph == 0 and t >= CoinPoses.PUT_IN:
			if int(e["cost"]) <= 0:
				_hand_out(fig, who, en); paying.erase(e); continue   # 낼 것이 없다(전에 다 냈다) — 바로 손으로
			if who is ResidentBase:
				if (who as ResidentBase).coins <= 0: paying.erase(e); fig.pose_request = ""; continue
				(who as ResidentBase).coins -= 1
			elif coins <= 0: paying.erase(e); fig.pose_request = ""; continue
			else: _set_coins(coins - 1)
			var c := make_item("coin", Vector3.ZERO)
			c.get_parent().remove_child(c); fig.hand_r.add_child(c); c.position = Vector3(0, -0.04, 0.03); c.rotation = Vector3(PI / 2.0, 0, 0)
			e["coin"] = c; e["phase"] = 1
		elif ph == 1 and t >= CoinPoses.PUT_AWAY:
			(e["coin"] as Node3D).queue_free(); e["coin"] = null; e["phase"] = 2
			dish["till"] = int(dish["till"]) + 1; en["paid"] = int(en["paid"]) + 1; e["cost"] = int(e["cost"]) - 1
			for i in TILL_MAX: ((dish["till_shown"] as Array)[i] as Node3D).visible = i < int(dish["till"])
		elif ph == 2 and t >= CoinPoses.PUT_T:
			if int(e["cost"]) > 0:
				fig.pose_t = 0.0; e["t0"] = now; e["phase"] = 0; continue   # 다음 동전 — 자세 이름이 같으니 시계만 되감는다
			paying.erase(e); _hand_out(fig, who, en)

## 물건이 손으로 — 꼬리표를 떼고, 입는 것이면 주민은 바로 쓴다(don). 사람은 든다(C 로 쓴다). 맡긴 이의 표도 뗀다
func _hand_out(fig: Stick3D, who: Variant, e: Dictionary) -> void:
	if fig.pose_request == "put": fig.pose_request = ""
	(e["tag"] as Node3D).queue_free(); e["gone"] = true
	(pawn["items"] as Array).erase(e)
	var by: Variant = e["by"]
	if by is ResidentBase and is_instance_valid(by) and (by as ResidentBase).has_meta("pawned"): (by as ResidentBase).remove_meta("pawned")
	var it: Node3D = e["node"]
	if who is ResidentBase:
		var r: ResidentBase = who
		if r.has_meta("pawned"): r.remove_meta("pawned")
		if String(e["kind"]) in Wear.KINDS: don(r.fig, it, false)
		else: r.fig.hold(it); r.carrying_kind = String(e["kind"])
		r.say(r.mind.line("redeemed"), 1.8)
	else:
		player.hold(it)
		say_toast("Bought the %s." % e["kind"] if e.get("stock", false) else "Yours again.")
