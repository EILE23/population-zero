class_name TownBusk
extends TownCoins
## 길거리 악사("Money in hands" 3조각, run 111 — 다른 주민이 돈을 내는 첫 일자리): 광장 게시판 동쪽 4m 의 낮은 나무 상자 무대, 그 앞에 뒤집힌 모자, 상자 옆에 기대 둔 상자 기타.
## 악사는 일 없는 어른 중 어울림(social)이 가장 높은 이(_hire_busker — 이야기방 주인 뒤, 운전사 앞). 등에 상자 기타를 메고 12:00–13:30·17:00–18:00 상자 위에서 strum(stick3d_busk.gd).
## 한 칸에 한 세트, 연달아 두 번은 없다(played — 맞아서 끊겨도 그 칸은 쓴 것). 치는 동안 4m 안을 지나는 주민은 3초 서서 듣고(wait, heard 표), 어울림 > 0.5 이고 동전이 있으면 셋에 둘이
## 모자로 와 stoop 으로 한 닢(tip 표 → resident_busk) — 어울림 반 × 0.66 ≈ 셋 중 하나. 평범한 결과: 셋에 둘은 그냥 지나가고, 세트는 아무도 안 내도 끝까지 간다.
## 사람도 모자 앞에서 C — 동전이 있으면 같은 stoop 으로 한 닢(0.12 에 주머니에서 손으로, STOOP_IN 에 손에서 모자로), 없으면 악사가 끄덕이고 busk_thanks 한 줄. 세트가 끝나면 악사가 모자의
## 동전을 stoop 으로 제 주머니에(palm_till 의 사슬, 자세만 stoop). 악사가 없을 때 사람이 상자 앞에서 C — 옆의 기타를 들고 올라서서 한 시간(30초) 세트: 주민은 똑같이 서고 똑같이 낸다.
## 다음 조각(심부름판·묵은 빵·전당포)은 백로그 "Money in hands". 사슬: … → nap → coins → **busk** → ledger(town_ledger.gd, 외상 장부 — run 112) → player → town3d

const BUSK_SLOTS := [[12.0, 13.5], [17.0, 18.0]]   # 세트 칸(0..24 시계)
const PLAYER_SET := 30.0                           # 사람의 세트 — 마을 시계 한 시간

var busk: Dictionary = {}   # {at, stage(자리), hat(자리: till/till_shown/cap), guitar(상자 옆 기타), busker, on: null | ResidentBase | "player", played(칸), slot(치는 칸), n(세트 번호), end(세트 끝), pg(사람 기타)}
var tipping: Array = []     # 모자에 넣는 손 [{fig, who, t0, coin, phase}] — phase 0 뻗음 · 1 손에 · 2 모자에

## 무대(town3d _ready — 구역 밖, 게시판처럼 늘 서 있다): 단단한 상자(올라선다)·윗면 널빤지·뒤집힌 모자(원판 다섯은 숨겨 두고 동전 수만큼 보인다)·기대 둔 기타·자리 둘
func _busk_stage(at: Vector3) -> void:
	_box(Vector3(0.9, 0.25, 0.9), at, _mat(Color("8a6a4a")))
	for sx: float in [-0.3, 0.0, 0.3]: _box(Vector3(0.26, 0.012, 0.9), at + Vector3(sx, 0.25, 0), _mat(Color("6b4a35")), false)   # 널빤지 셋 — 틈이 보인다
	var hp := at + Vector3(0, 0, 0.8)
	var cm := MeshInstance3D.new(); var cy := CylinderMesh.new(); cy.top_radius = 0.17; cy.bottom_radius = 0.13; cy.height = 0.06; cy.radial_segments = 20
	cm.mesh = cy; cm.material_override = _mat(Color("3a2a30")); cm.position = hp + Vector3(0, 0.03, 0); _add(cm)
	_box(Vector3(0.14, 0.012, 0.1), hp + Vector3(0.2, 0.012, 0.0), _mat(Color("2a1c22")), false)   # 챙 — 옆으로 뻗어 '모자'로 읽힌다
	var shown: Array = []
	for i in TILL_MAX:
		var c := make_item("coin", hp + Vector3(0, 0.05 + i * 0.013, 0)); c.visible = false; shown.append(c)
	busk = { "at": at, "on": null, "played": -1, "n": 0, "end": 0.0 }
	busk["stage"] = { "pos": at + Vector3(0, 0.25, 0), "kind": "stage", "yaw": 0.0 }
	busk["hat"] = { "pos": at + Vector3(0, 0, 1.4), "kind": "hat", "yaw": PI, "till": 0, "till_shown": shown, "cap": hp }
	spots.append(busk["stage"]); spots.append(busk["hat"])
	var g := _guitar(self); g.position = at + Vector3(0.62, 0.22, 0.05); g.rotation = Vector3(0.0, PI / 2.0, -PI / 2.0 + 0.25)   # 상자 동쪽 옆에 세워 기대 둔다
	busk["guitar"] = g

## 상자 기타 — 몸통(나무 상자)·목·머리·울림구멍·줄 둘. 원점은 몸통 가운데, 목은 −x. 악사의 가슴(chest)과 상자 옆에 같은 것
func _guitar(parent: Node3D) -> Node3D:
	var g := Node3D.new(); parent.add_child(g)
	var wood := _mat(Color("b48a5a")); var dark := _mat(Color("5a4030"))
	_box(Vector3(0.3, 0.22, 0.07), Vector3(0.04, -0.11, 0), wood, false, g)   # 몸통 — _box 는 at 을 바닥 중심으로 받으니 y 를 반 내린다
	_box(Vector3(0.3, 0.035, 0.03), Vector3(-0.3, -0.0175, 0.02), dark, false, g)   # 목
	_box(Vector3(0.08, 0.06, 0.03), Vector3(-0.49, -0.03, 0.02), dark, false, g)    # 머리
	var hole := MeshInstance3D.new(); var cy := CylinderMesh.new(); cy.top_radius = 0.04; cy.bottom_radius = 0.04; cy.height = 0.01; cy.radial_segments = 16
	hole.mesh = cy; hole.material_override = _mat(Color("1b0c15")); hole.position = Vector3(0.06, 0, 0.038); hole.rotation.x = PI / 2.0; g.add_child(hole)
	for dy: float in [-0.012, 0.012]: _box(Vector3(0.62, 0.004, 0.004), Vector3(-0.14, dy - 0.002, 0.042), _mat(Color("efe9e2")), false, g)   # 줄 둘
	return g

## 악사 — 일 없는 어른(수리공 빼고) 가운데 어울림이 가장 높은 이. 이야기방 주인 뒤, 운전사 앞에 뽑는다(town3d _ready). 등에 상자 기타
func _hire_busker() -> void:
	if busk.is_empty(): return
	var best: Resident = null; var bk := -1.0
	for r: Resident in residents:
		if r.job != "" or r.uid % 6 == 0: continue
		if r.mind.social > bk: bk = r.mind.social; best = r
	if best == null: return
	best.job = "busker"; busk["busker"] = best
	best.fig.set_meta("guitar", _guitar(best.fig.chest)); BuskPoses.sling(best.fig, 0.0)

## 지금 열린 칸 — 없으면 −1
func busk_slot() -> int:
	var h := fmod(clock * 24.0 + 6.0, 24.0)
	for i in BUSK_SLOTS.size():
		if h >= float(BUSK_SLOTS[i][0]) and h < float(BUSK_SLOTS[i][1]): return i
	return -1

## 악사가 올라설 수 있나 — 열린 칸, 아직 안 친 칸, 빈 무대, 비가 아닐 때
func busk_open() -> bool:
	if busk.is_empty() or busk["on"] != null or weather == "rain": return false
	var s := busk_slot()
	return s >= 0 and s != int(busk["played"])

## 세트 시작(악사 _busk_arrive · 사람 busk_use) — 끝나는 시각을 돌려준다: 악사는 칸이 닫힐 때까지(적어도 두 바퀴), 사람은 한 시간. 사람은 상자 옆 기타를 든다
func busk_start(who: Variant, now: float) -> float:
	var s := busk_slot(); var h := fmod(clock * 24.0 + 6.0, 24.0)
	var end: float = (now + PLAYER_SET) if (who is String or s < 0) else (now + (float(BUSK_SLOTS[s][1]) - h) * DAY_LEN / 24.0)
	end = maxf(end, now + BuskPoses.STRUM_IN + BuskPoses.LOOP_T * 2.0)
	busk["on"] = who; busk["end"] = end; busk["slot"] = s; busk["n"] = int(busk["n"]) + 1
	if s >= 0: busk["played"] = s   # 사람이 그 칸에 치면 악사는 쉰다 — 연달아 두 세트는 없다
	var fig: Stick3D = player if who is String else (who as ResidentBase).fig
	if fig.has_meta("strum_end"): fig.remove_meta("strum_end")
	if who is String:
		var g := _guitar(fig.chest); fig.set_meta("guitar", g); busk["pg"] = g; (busk["guitar"] as Node3D).visible = false
	BuskPoses.sling(fig, 0.0)
	return end

## 세트 끝(회수가 끝났을 때, 또는 맞았다·걸어갔다) — 기타는 등으로(사람 것은 상자 옆으로), 악사는 자리를 떠나 모자를 거두러 간다(resident_busk)
func busk_stop() -> void:
	var who: Variant = busk["on"]
	if who == null: return
	var fig: Stick3D = player if who is String else (who as ResidentBase).fig
	if fig.has_meta("strum_end"): fig.remove_meta("strum_end")
	if fig.pose_request == "strum": fig.pose_request = ""
	if who is String:
		var g: Variant = busk.get("pg")
		if g is Node3D and is_instance_valid(g): (g as Node3D).queue_free()
		busk.erase("pg")
		if fig.has_meta("guitar"): fig.remove_meta("guitar")
		(busk["guitar"] as Node3D).visible = true
	else:
		BuskPoses.sling(fig, 0.0)
		if (who as ResidentBase).state == "busy": (who as ResidentBase).busy_until = Time.get_ticks_msec() / 1000.0
	busk["on"] = null

## 매 프레임(town_systems _tick): 새 날엔 칸이 다시 열리고, 세트는 끝 시각에 회수(strum_end)로 들어가 0.4 뒤 끝난다; 치는 동안 지나는 주민이 선다; 모자에 넣는 손들의 진행
func _busk_tick(now: float) -> void:
	if busk.is_empty(): return
	var h := fmod(clock * 24.0 + 6.0, 24.0)
	if h < 11.0: busk["played"] = -1
	var who: Variant = busk["on"]
	if who != null:
		var fig: Stick3D = player if who is String else (who as ResidentBase).fig
		var live: bool = fig.pose_request == "strum" and (who is String or (who as ResidentBase).state == "busy")
		if not live: busk_stop()   # 맞았다·걸어갔다 — 세트는 거기서 끝(칸은 쓴 것으로 남는다)
		elif (now >= float(busk["end"]) or (who is ResidentBase and busk_slot() != int(busk["slot"]))) and not fig.has_meta("strum_end"): fig.set_meta("strum_end", fig._t)   # 악사는 칸이 닫히면(마을 시계), 사람은 한 시간 뒤
		elif fig.has_meta("strum_end") and BuskPoses.end_k(fig) >= 1.0: busk_stop()
		else: _busk_listen(now)
	_tips_tick(now)
	var b: Variant = busk.get("busker")
	if b is ResidentBase and (b as ResidentBase).fig.pose_request != "strum": BuskPoses.sling((b as ResidentBase).fig, 0.0)   # 자세가 끊겼으면 기타는 등으로

## 치는 동안 4m 안을 걷는 주민(짝 걷기·배·악사 자신·이 세트를 이미 들은 이는 지나간다) — 3초 서서 듣고, 어울림 > 0.5 이고 동전이 있으면 셋에 둘이 내기로 한다(tip 표 → _busk_pick)
func _busk_listen(now: float) -> void:
	var at: Vector3 = busk["at"]; var n: int = busk["n"]
	for r: Resident in residents:
		if r.state != "walk" or r.in_boat or r.pair != null or r.fig.pose_request != "" or r.job == "busker" or int(r.get_meta("heard", -1)) == n: continue
		if Vector2(r.global_position.x - at.x, r.global_position.z - at.z).length() > 4.0: continue
		r.set_meta("heard", n)
		r._release(); r.spot = { "kind": "listen" }; r.route = []
		r.state = "busy"; r.busy_until = now + 3.0
		r.fig.face(atan2(at.x - r.global_position.x, at.z - r.global_position.z)); r.fig.pose_request = "wait"
		if r.job != "child" and r.mind.social > 0.5 and r.coins > 0 and randf() < 0.66: r.set_meta("tip", n)   # 평범한 결과 = 그냥 간다(어울림 반 × 0.66 → 셋 중 하나쯤 낸다)

## 모자에 한 닢(주민 _busk_arrive · 사람 busk_tip) — 호출자가 stoop 자세를 올린 뒤 부른다. 진행은 _tips_tick. dish 를 주면 모자 대신 그 그릇에(장부의 그릇, run 112 town_ledger — 같은 till/till_shown 꼴)
func tip(fig: Stick3D, who: Variant, dish: Dictionary = {}) -> void:
	var e := { "fig": fig, "who": who, "t0": Time.get_ticks_msec() / 1000.0, "coin": null, "phase": 0 }
	if not dish.is_empty(): e["dish"] = dish
	tipping.append(e)

## stoop 의 시계로: 0.12 에 주머니에서 손으로(수가 준다), STOOP_IN 에 손에서 모자로(원판이 하나 더 보인다, 악사가 고마워한다). 손에 든 채 끊기면 주머니로 돌아간다
func _tips_tick(now: float) -> void:
	for e in tipping.duplicate():
		var hat: Dictionary = e.get("dish", busk["hat"])
		var fig: Stick3D = e["fig"]; var who: Variant = e["who"]; var t: float = now - float(e["t0"]); var ph: int = e["phase"]
		var broke: bool = fig.pose_request != "stoop" or (who is String and player.move_dir != Vector3.ZERO) or (who is ResidentBase and (who as ResidentBase).state != "busy")
		if broke and ph < 2:
			if ph == 1:
				(e["coin"] as Node3D).queue_free()
				if who is ResidentBase: (who as ResidentBase).coins += 1
				else: _set_coins(coins + 1)
			tipping.erase(e); continue
		if ph == 0 and t >= 0.12:
			if who is ResidentBase:
				var r: ResidentBase = who
				if r.coins <= 0: tipping.erase(e); continue
				r.coins -= 1
			elif coins <= 0: tipping.erase(e); continue
			else: _set_coins(coins - 1)
			var c := make_item("coin", Vector3.ZERO)
			c.get_parent().remove_child(c); fig.hand_r.add_child(c); c.position = Vector3(0, -0.04, 0.03); c.rotation = Vector3(PI / 2.0, 0, 0)   # 손가락 사이에 세워 쥔다
			e["coin"] = c; e["phase"] = 1
		elif ph == 1 and t >= CoinPoses.STOOP_IN:
			(e["coin"] as Node3D).queue_free(); e["coin"] = null; e["phase"] = 2
			hat["till"] = int(hat["till"]) + 1
			for i in TILL_MAX: ((hat["till_shown"] as Array)[i] as Node3D).visible = i < int(hat["till"])
			if e.has("dish"): call("tab_paid", who)   # 장부의 그릇(run 112, town_ledger) — 외상이 하나 준다
			else: _thanks(who)
		elif ph == 2 and t >= CoinPoses.STOOP_T:
			tipping.erase(e)
			if fig.pose_request == "stoop": fig.pose_request = ""

## 고마움 — 악사가 주민이면 끄덕이며 한 줄(busk_thanks), 사람이 치는 중이면 토스트 한 줄
func _thanks(who: Variant) -> void:
	var on: Variant = busk["on"]
	if on is ResidentBase:
		var bz: ResidentBase = on
		bz.fig.set_meta("nod_at", bz.fig._t); bz.say(bz.mind.line("busk_thanks"), 1.8)
	elif on is String and who is ResidentBase: say_toast("%s dropped a coin in the cap." % (who as ResidentBase).handle)

## 사람: 모자 앞(1.1m)에서 C — 동전이 있으면 stoop 으로 한 닢(주민과 같은 시계), 없으면 악사가 끄덕이고 한마디. 세트가 없고 모자에 동전이 남았으면 stoop 으로 거둔다(악사와 같은 사슬)
func busk_tip(now: float) -> bool:
	if busk.is_empty() or not seat.is_empty() or resting or rowing: return false
	var hat: Dictionary = busk["hat"]; var cap: Vector3 = hat["cap"]
	if Vector2(body.global_position.x - cap.x, body.global_position.z - cap.z).length() > 1.1: return false
	var who: Variant = busk["on"]
	if who is String: return false
	if who == null:
		if int(hat["till"]) <= 0: return false
		player.face(atan2(cap.x - body.global_position.x, cap.z - body.global_position.z))
		player.pose_request = "stoop"; use_until = now + CoinPoses.STOOP_T; action_until = use_until
		palm_till(player, hat, "player", "stoop"); return true
	player.face(atan2(cap.x - body.global_position.x, cap.z - body.global_position.z))
	if coins <= 0:
		var bz: ResidentBase = who
		bz.fig.set_meta("nod_at", bz.fig._t); bz.say(bz.mind.line("busk_thanks"), 1.8)
		action_until = now + 0.5; return true
	player.pose_request = "stoop"; use_until = now + CoinPoses.STOOP_T; action_until = use_until
	tip(player, "player"); return true

## 사람: 상자 앞에서 C — 악사가 없으면 옆의 기타를 들고 올라서서 한 시간 세트(strum). 걸어 나가면 끝(town_player 가 자세를 푼다 → _busk_tick 이 기타를 돌려놓는다)
func busk_use(now: float) -> bool:
	if busk.is_empty() or busk["on"] != null or player.carrying or not carrying_big.is_empty(): return false
	var at: Vector3 = busk["at"]
	body.global_position = at + Vector3(0, 0.27, 0); player.face(0.0)
	player.pose_request = "strum"; action_until = now + 0.5
	use_until = busk_start("player", now) + BuskPoses.STRUM_OUT
	if not busk.has("told"):
		say_toast("A set. Walk off to stop."); busk["told"] = true   # 첫 세트에만 한 줄 — 쓰는 법은 놀면서(범례엔 안 붙인다)
	return true
