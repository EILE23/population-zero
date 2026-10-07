class_name ResidentPawn
extends ResidentJobs
## 전당포의 주민(money 3b, run 116 — town_pawn.gd): 주인(job "pawnbroker")은 10시가 되면 부스 뒤 자리로 가 선반 뒤에 서서 16시까지 지킨다(그동안만 셔터가 열린다; 맞아서 나가면 다시 돌아온다).
## 손님: 빈 주머니에 배고픈(mind.full < 0.3) 어른이 모자를 쓰고 있으면 하루 한 번 부스로 가 모자를 벗어(doff) 건넨다(pass) — 사람이 든 것을 맡기는 것과 같은 자세·같은 값; 받은 동전으로 창구에 간다.
## 맡긴 것(meta "pawned")은 값이 모이면 돌아와 put 으로 내고 되찾아 쓴다(don); 모자 없는 이는 재고 모자를 같은 값·같은 자세로 산다. 사슬: … → store → jobs → **pawn** → resident

func _post_pick(now: float) -> bool:
	return _pawn_pick(now) or super._post_pick(now)

func _post_arrive(now: float) -> bool:
	return _pawn_arrive(now) or super._post_arrive(now)

## 부스로 갈 이유 — 주인은 근무 시간에 자리로; 손님은 찾으러(값이 모였다), 맡기러(빈 주머니·배고픔·모자), 사러(모자 없음·재고 모자·값). 못 가면 false(_pick_spot 이 다음 규칙으로)
func _pawn_pick(now: float) -> bool:
	var pw: Dictionary = town.pawn
	if pw.is_empty() or self is ResidentKid or town.is_night() or fig.carrying != null: return false
	var act := ""
	if job == "pawnbroker":
		if not town.pawn_hours() or is_same(spot, pw["keep"]): return false
		act = "keep"
	elif not pw["open"] or weather == "rain" or has_umb or global_position.distance_to((pw["spot"] as Dictionary)["pos"]) > 40.0: return false
	elif has_meta("pawned"):
		var e: Dictionary = get_meta("pawned")
		if e.get("gone", false): remove_meta("pawned"); return false
		if coins < town.pawn_cost(e) or randf() > 0.5: return false
		act = "back"
	elif coins == 0 and mind.full < 0.3 and fig.worn.has("hat") and now - float(get_meta("pawn_day", -1e9)) > town.DAY_LEN * 0.9 and town.pawn_slot_free() >= 0: act = "hock"
	elif not fig.worn.has("hat") and coins >= 4 and randf() < 0.15 and not (town.pawn_stock(true) as Dictionary).is_empty(): act = "buy"
	else: return false
	var sp: Dictionary = pw["keep"] if act == "keep" else pw["spot"]
	if _free_slot(sp) < 0: return false
	set_meta("pawn_act", act); slot = 0; spot = sp; _claim(sp, 0)
	route = town.via_bridge(global_position, [{ "pos": sp["pos"], "act": "" }])
	target = route[0]["pos"]; state = "walk"; busy_until = now
	return true

## 닿음(resident.gd _arrive 의 기본 가지): 주인은 선반 뒤로 들어가 근무 끝까지; 손님은 셔터가 열려 있으면 맡기거나(doff → pass) 값을 낸다(put ×n → 손으로). 이 부스가 아니면 false
func _pawn_arrive(now: float) -> bool:
	var pw: Dictionary = town.pawn
	if pw.is_empty(): return false
	var act := String(get_meta("pawn_act", ""))
	if is_same(spot, pw["keep"]):
		global_position = pw["inner"]   # 뒤에서 선반 뒤로 — 가게 주인이 계산대 뒤로 들어가듯(resident_shop)
		fig.face(0.0); busy_until = now + float(town.pawn_shift_left())
		say(mind.line("pawn_open"), 1.6)
		return true
	if not is_same(spot, pw["spot"]): return false
	fig.face(PI)
	if not pw["open"]:
		busy_until = now + 1.0; return true   # 오는 사이 닫혔다
	if act == "hock":
		set_meta("pawn_day", now)
		town.doff(fig, "hat"); busy_until = now + WearPoses.DOFF_T + StickPoses.PASS_T * 2.0 + 0.6
		get_tree().create_timer(WearPoses.DOFF_T + 0.05).timeout.connect(_pawn_hand)
		return true
	var e: Dictionary = get_meta("pawned", {}) if act == "back" else town.pawn_stock(true)
	var cost := int(town.pawn_cost(e)) if not e.is_empty() else 0
	if e.is_empty() or e.get("gone", false) or coins < cost:
		busy_until = now + 1.0; return true   # 그새 팔렸거나 값이 모자라다
	fig.pose_request = "put"; busy_until = now + CoinPoses.PUT_T * maxi(1, cost) + WearPoses.DON_T + 0.6
	town.pay_out(fig, self, e, cost, now)
	return true

## 모자가 손에 왔다 — pass 로 건넨다. 그새 맞았거나 떠났으면 없던 일(모자는 손에 남아 여느 든 것처럼 간다)
func _pawn_hand() -> void:
	if state != "busy" or fig.carrying == null or not is_same(spot, town.pawn["spot"]): return
	fig.set_meta("share_side", 1.0); fig.pose_request = "pass"
	town.hand_in(fig, self, fig.carrying, Time.get_ticks_msec() / 1000.0)
