class_name ResidentLedger
extends ResidentBusk
## 장부 앞의 주민("Money in hands" 4조각, run 112 — town_ledger): 외상(mind.tab)이 있고 동전이 있는 어른은 하루 한 번 장부 자리를 고를 수 있다(_ledger_ok 가 자리 풀에 남기고, mind.score 가 +3 × tab 으로 끌어당긴다) —
## 닿으면 제 줄을 읽고(scan) 한숨 쉬고(sigh) 그릇에 한 닢 stoop(town.ledger_turn — 사람의 C 와 같은 세 박자). 빵집 주인은 그릇이 `closing`(17시) 이면 일과 사이에 와서 stoop 으로 거둔다(악사가 모자를 거두는 것과 같은 palm_till 사슬).
## 사슬: … → till → busk → **ledger** → resident

func _post_pick(now: float) -> bool:
	return _ledger_pick(now) or super._post_pick(now)

func _post_arrive(now: float) -> bool:
	return _ledger_arrive(now) or super._post_arrive(now)

## 장부 자리가 풀에 남는 조건(resident.gd _pick_spot) — 외상이 있고, 낼 동전이 있고, 오늘 아직 안 갔고, 빈손. 아이와 빵집 주인은 아니다
func _ledger_ok() -> bool:
	if job == "baker" or job == "child" or fig.carrying != null or mind.tab <= 0 or coins <= 0: return false
	return Time.get_ticks_msec() / 1000.0 - float(get_meta("tabbed", -1e9)) > town.DAY_LEN * 0.9

## 빵집 주인: 그릇이 거둘 차례면 그리로. 못 가면 false(_pick_spot 이 다음 규칙으로)
func _ledger_pick(now: float) -> bool:
	var lg: Dictionary = town.ledger
	if job != "baker" or lg.is_empty() or fig.carrying != null or not lg.get("closing", false) or int(lg["till"]) <= 0 or _free_slot(lg) < 0: return false
	slot = 0; spot = lg; _claim(lg, 0)
	route = town.via_bridge(global_position, [{ "pos": lg["pos"], "act": "" }])
	target = route[0]["pos"]; state = "walk"; busy_until = now
	return true

## 닿음(resident.gd _arrive 의 기본 가지): 주인은 거두고(하나에 STOOP_T), 손님은 한 차례(읽기 → 한숨 → 한 닢). 칸에 따라 반 발짝 좌우로 — 둘이 한 줄을 읽지 않게
func _ledger_arrive(now: float) -> bool:
	if spot.get("kind", "") != "ledger": return false
	var lg: Dictionary = town.ledger
	global_position = (spot["pos"] as Vector3) + Vector3(-0.3 if slot == 0 else 0.3, 0.02, 0)   # 자리 자체에(기본 길은 0.5 앞에 세운다) — 그릇이 0.6m 앞, 악사의 모자와 같은 거리
	fig.face(spot.get("yaw", PI))
	if job == "baker":
		var n := int(lg["till"])
		if n <= 0:
			busy_until = now + 1.0; return true   # 오는 사이 비었다
		fig.pose_request = "stoop"; busy_until = now + CoinPoses.STOOP_T * n + 0.6
		town.palm_till(fig, lg, self, "stoop"); say(mind.line("till_close"), 1.8)
		return true
	town.ledger_turn(fig, self, now)
	busy_until = now + town.TURN_T + 0.6
	say(mind.line("tab_read" if mind.tab > 0 else "tab_clear"), 2.0)
	return true
