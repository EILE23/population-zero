class_name TownCoins
extends TownNap
## 동전("Money in hands" — 마을이 설계한 스무째 시스템, 1조각 run 107): 마을의 첫 돈. `coin` 은 바닥의 물건(make_item)이지만 손에 들지 않고 주머니로 간다 —
## 바닥의 동전 앞에서 C = stoop(숙여 쥐고 허리 주머니에, stick3d_coin.gd): STOOP_IN 에 손으로, STOOP_AWAY 에 주머니로. 주머니는 HUD 오른쪽 위 잉크 글자 하나(막대·아이콘 줄 없음).
## 주민도 걷다 0.8m 안의 동전을 보면 멈춰 같은 자세로 집고(mind.line "finders") 제 주머니(coins)에 넣는다. 넘어지면 셋 중 하나는 동전을 떨군다 — 주머니에 있으면 그것, 주민은 없어도 하나(마을에 돈이 생기는 길),
## 사람은 주머니가 비면 아무것도. 평범한 결과(든 것만 떨어진다)가 70%. 창구는 주머니에 동전이 있으면 하나 받고(상판 끝 접시에 셋까지 보인다), 없으면 그냥 준다("On the house.") — 돈이 없어도 핵심 동작은 그대로.
## 다음 조각(주민의 아침 동전·주인의 수입과 훔치기·시장 노점에 작물 팔기)은 백로그 "Money in hands". 사슬: … → sunroom → nap → **coins** → player → town3d

var coins := 0                  # 내 주머니(이 판에서만 — 저장은 다음 조각)
var stooping: Array = []        # 집는 중 [{fig, coin, t0, who, at, phase}] — who: ResidentBase 또는 "player"; phase 0 숙임 · 1 손에 · 2 주머니에

## 바닥 r 안의 동전(집는 중인 건 items 에 없다) — 없으면 null
func coin_near(p: Vector3, r := 0.8) -> Node3D:
	var best: Node3D = null
	for it in items:
		if String(it.get_meta("kind", "")) != "coin": continue
		var d := it.global_position.distance_to(p)
		if d < r: r = d; best = it
	return best

## 사람: C 로 가까운 동전을 집는다(town_player — 든 것이 있어도: 동전은 손이 아니라 주머니로). 없으면 false
func stoop_near(now: float) -> bool:
	if not seat.is_empty() or resting or rowing: return false
	var c := coin_near(body.global_position)
	if c == null: return false
	player.face(atan2(c.global_position.x - body.global_position.x, c.global_position.z - body.global_position.z))
	player.pose_request = "stoop"; use_until = now + CoinPoses.STOOP_T; action_until = now + CoinPoses.STOOP_T
	_stoop(player, c, "player")
	return true

func _stoop(fig: Stick3D, c: Node3D, who: Variant) -> void:
	items.erase(c)   # 집는 동안은 아무도(여우도) 못 집는다
	stooping.append({ "fig": fig, "coin": c, "t0": Time.get_ticks_msec() / 1000.0, "who": who, "at": c.global_position, "phase": 0 })

## 매 프레임(town_systems _tick): 걷는 주민이 동전을 보면 멈춰 집는다(자리는 놓는다 — 일어나면 다시 고른다; 짝 걷기·배·아이는 지나간다), 그리고 집는 손들의 진행
func _coins_tick(now: float) -> void:
	for r in residents:
		if r.state != "walk" or r.in_boat or r.pair != null or r.job == "child" or r.fig.pose_request != "": continue
		var c := coin_near(r.global_position)
		if c == null or (c.global_position.z > -0.1 and c.global_position.z < 4.1): continue   # 큰길 띠(z −0.1..4.1)의 동전은 두고 간다 — 차선에 멈춰 숙이면 차가 친다(사람은 집어도 된다)
		r._release(); r.spot = { "kind": "coin" }; r.route = []   # 침대·의자로 가던 길이면 _leave 가 문으로 돌려보내려 한다 — 동전 자리로 바꿔 둔다
		r.state = "busy"; r.busy_until = now + CoinPoses.STOOP_T + 0.1
		r.fig.face(atan2(c.global_position.x - r.global_position.x, c.global_position.z - r.global_position.z)); r.fig.pose_request = "stoop"
		_stoop(r.fig, c, r)
	for e in stooping.duplicate():
		var fig: Stick3D = e["fig"]; var c: Node3D = e["coin"]; var t: float = now - float(e["t0"]); var who: Variant = e["who"]
		var broke: bool = fig.pose_request != "stoop" or (who is String and player.move_dir != Vector3.ZERO) or (who is ResidentBase and (who as ResidentBase).state != "busy")
		if broke and int(e["phase"]) < 2:
			_put_back(e); continue   # 맞았다·걸어갔다 — 동전은 있던 자리로
		if int(e["phase"]) == 0 and t >= CoinPoses.STOOP_IN:
			c.get_parent().remove_child(c); fig.hand_r.add_child(c); c.position = Vector3(0, -0.04, 0.03); c.rotation = Vector3(PI / 2.0, 0, 0); e["phase"] = 1   # 손가락 사이에 세워 쥔다
		elif int(e["phase"]) == 1 and t >= CoinPoses.STOOP_AWAY:
			c.queue_free(); e["coin"] = null; e["phase"] = 2   # 지워진 노드를 다음 프레임에 타입 변수에 담으면 오류 — 비워 둔다
			if who is ResidentBase:
				var r: ResidentBase = who; r.coins += 1; r.say(r.mind.line("finders"), 1.4)
			else: _set_coins(coins + 1)
		elif int(e["phase"]) == 2 and t >= CoinPoses.STOOP_T:
			stooping.erase(e)
			if fig.pose_request == "stoop": fig.pose_request = ""

func _put_back(e: Dictionary) -> void:
	var c: Node3D = e["coin"]
	if c.get_parent() != self: c.get_parent().remove_child(c); add_child(c)
	c.global_position = e["at"]; c.rotation = Vector3.ZERO
	items.append(c); stooping.erase(e)

## 넘어진 이의 동전(resident_base.hit · town_critters.resident_hits_player): 셋 중 하나 — 주머니에 있으면 그것, 주민은 비어도 하나, 사람은 비면 없다. 날아가 바닥에 한 번 튀고 눕는다(_fly)
func drop_coin(at: Vector3, dir: Vector3, from: Variant) -> void:
	if randf() >= 0.3: return
	if from is ResidentBase:
		var r: ResidentBase = from
		if r.coins > 0: r.coins -= 1
	elif coins <= 0: return
	else: _set_coins(coins - 1)
	var c := make_item("coin", at)
	flying.append({ "node": c, "vel": dir * randf_range(1.2, 2.0) + Vector3(randf_range(-0.5, 0.5), 2.6, 0), "spin": 6.0, "bounce": 1 })

## 창구 값(town_places counter_use · counter_take): 주머니에 있으면 하나 — 상판 왼쪽 끝의 접시에 쌓인다(셋까지 보인다; 주인의 수입으로 가져가는 건 다음 조각). 없으면 그냥
func pay_counter(sp: Dictionary, by: Variant) -> void:
	if by is ResidentBase:
		var r: ResidentBase = by
		if r.coins <= 0: return
		r.coins -= 1
	elif coins <= 0:
		say_toast("On the house."); return
	else: _set_coins(coins - 1)
	sp["till"] = int(sp.get("till", 0)) + 1
	if not sp.has("till_shown"):
		var shown: Array = []
		for i in 3: shown.append(make_item("coin", (sp["pos"] as Vector3) + Vector3(-0.5, 0.925 + i * 0.013, -0.75)))   # 상판은 pos 의 0.8 뒤, 윗면 0.925
		sp["till_shown"] = shown
	for i in 3: ((sp["till_shown"] as Array)[i] as Node3D).visible = i < int(sp["till"])

## 주머니 수 — HUD 오른쪽 위 글자(첫 동전에 생긴다). 첫 동전엔 한 줄 토스트: 쓰는 법은 놀면서 배운다(범례엔 안 붙인다)
func _set_coins(n: int) -> void:
	if coins == 0 and n > 0: say_toast("A coin. Counters take one when you have one.")
	coins = n
	var ui := get_node_or_null("UI") as CanvasLayer
	if ui == null: return
	var l := ui.get_node_or_null("Coins") as Label
	if l == null:
		l = Label.new(); l.name = "Coins"
		l.offset_left = 760.0; l.offset_top = 10.0; l.offset_right = 948.0; l.offset_bottom = 32.0
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		var leg := ui.get_node_or_null("Legend") as Label
		if leg and leg.label_settings:
			var ls: LabelSettings = leg.label_settings.duplicate(); ls.font_size = 16; l.label_settings = ls
		ui.add_child(l)
	l.text = "%d coin%s" % [coins, "" if coins == 1 else "s"]
