class_name TownWages
extends TownSocial
## 품삯(운영자 2026-10-06 "진짜 화폐로 키우자", money 1): 일은 돈이 된다 — 값은 data/prices.json 의 "wage"(빵 하나 1 · 공사 한 단위 1 · 손님 하나 1).
## 빵집 주인은 화덕에서 창구에 오른 빵 하나마다(town_places _bakery), 건축가는 일 한 단위(25초 망치질)마다(town_growth build_work), 구두장이·칼갈이·재봉사는 손님 하나마다
## (town_trades 는 사람 손님, resident_life 는 주민 손님), 악사의 모자는 제 것(run 111). 사람도 같은 일엔 같은 값: 화덕에서 반죽해 창구에 오른 빵 하나, 공사장 망치질 한 단위 — 제 집 공사는 품삯이 없다(town_plots).
## 주민의 품삯은 제 주머니(coins)로 가서 창구에서 쓴다(pay_counter) — 넘어지면 셋 중 하나는 떨구니(drop_coin) 번 사람 곁이 사람의 벌이 길이기도 하다. 사람의 품삯은 지갑(_set_coins → records 저장).
## 아래층은 call("wage", who, kind, delay) 로 부른다 — delay ≥ 0 이면 그만큼 뒤에 주민이 한마디(mind.line "paid"; 장인은 "Resoled." 뒤에), 음수면 말없이(빵은 덩이마다 받고 줄이 끝날 때 한 번 말한다).
## 사슬: … → cabin → social → **wages** → player → town3d

const WAGE_FALLBACK := { "bread": 1, "build": 1, "cobbler": 1, "cutler": 1, "tailor": 1 }   # prices.json 에 "wage" 가 없을 때
const WAGE_WORD := { "bread": "the loaf", "build": "the work" }   # 사람이 받는 두 가지 — 토스트의 말

var earned := 0                # 이 판에서 사람이 일해 번 동전(점검·HUD 없음 — 토스트만)

## 품삯 — who 는 ResidentBase 또는 "player". 값이 0 이면 아무 일도(데이터로 끌 수 있다)
func wage(who: Variant, kind: String, delay := 0.0) -> void:
	var n := int((prices.get("wage", {}) as Dictionary).get(kind, WAGE_FALLBACK.get(kind, 1)))
	if n <= 0: return
	if who is ResidentBase:
		var r: ResidentBase = who
		r.coins += n
		if delay < 0.0: return
		if delay == 0.0: r.say(r.mind.line("paid"), 1.4)
		else: get_tree().create_timer(delay).timeout.connect(func() -> void: if is_instance_valid(r) and not (r.state in ["down", "getup"]): r.say(r.mind.line("paid"), 1.4))   # "Resoled." 가 먼저 — 말이 겹치지 않게
	elif who is String:
		earned += n
		_set_coins(coins + n)
		if delay >= 0.0: say_toast("Paid %d coin%s for %s." % [n, "" if n == 1 else "s", WAGE_WORD.get(kind, kind)])
