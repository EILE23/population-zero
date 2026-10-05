class_name ResidentTill
extends ResidentSunroom
## 가게 주인의 접시("Money in hands" 2조각, run 110) — 창구 접시의 수입을 거둔다: 사람이 C 로 접시에서 집는 것과 같은 palm 자세(stick3d_coin.gd), 같은 palm_till(town_coins).
## 빵집 주인만(재고 있는 창구 = 빵집; 카페엔 아직 주인이 없다). 17시가 지났거나 접시가 다섯이면(`closing`) 일과 사이에 접시 앞으로 와 하나에 PALM_T 씩 제 주머니로 —
## 진행은 town_coins _coins_tick 이(끝나면 다음 동전을 이어 집는다). 맞아서 끊기면 셈과 원판이 접시로 돌아가고 `closing` 이 남아 다시 온다. 사슬: base → life → pair → shelf → letters → sunroom → **till** → resident

## 거둘 접시가 있으면 그리로 — 손님 쪽 끝에 선다(창구 뒤는 집 벽). 못 가면 false(_pick_spot 이 다음 규칙으로)
func _till_pick(now: float) -> bool:
	if job != "baker" or fig.carrying != null: return false
	var sp: Dictionary = town.till_closing()
	if sp.is_empty(): return false
	var at: Vector3 = town.till_pos(sp)
	spot = { "kind": "till", "pos": Vector3(at.x, 0.0, (sp["pos"] as Vector3).z), "yaw": sp.get("yaw", PI), "sp": sp }
	route = town.via_bridge(global_position, [{ "pos": spot["pos"], "act": "" }])
	target = route[0]["pos"]; state = "walk"; busy_until = now
	return true

## 접시에 닿음(resident.gd _arrive) — 동전 수만큼 palm, 하나에 PALM_T
func _till_arrive(now: float) -> void:
	var sp: Dictionary = spot["sp"]
	var n := int(sp.get("till", 0))
	fig.face(spot.get("yaw", PI))
	if n <= 0:
		busy_until = now + 1.0; return   # 오는 사이 누가 집어 갔다 — 빈 접시를 보고 간다
	fig.pose_request = "palm"; busy_until = now + CoinPoses.PALM_T * n + 0.6
	town.palm_till(fig, sp, self)
	say(mind.line("till_close"), 1.8)
