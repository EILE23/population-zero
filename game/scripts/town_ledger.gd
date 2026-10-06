class_name TownLedger
extends TownBusk
## 외상 장부("Money in hands" 4조각, run 112 — 빈 주머니로 받아 간 빵은 적힌다): 빵집 서쪽 벽 옆의 작은 글씨 탁자, 펼친 장부, 탁자 발치의 구리 그릇.
## 창구에서 동전 없이 빵을 받으면(pay_counter 의 "On the house." 가지) 적힌다 — 주민은 mind.tab(기억과 함께 저장), 사람은 tab(HUD 토스트 "On the house. That is n on the tab.").
## 거절은 없다: 장부는 기억만 하지 창구를 막지 않는다(평범한 결과 100%). 외상이 있고 동전이 있는 주민은 하루 한 번 장부로(mind.score 의 +3 × tab 항, resident_ledger) —
## 제 줄을 읽고(scan, run 100) 한숨 쉬고(sigh, stick3d_ledger.gd) 그릇에 한 닢 stoop(악사 모자의 tip 사슬, town_busk — 0.12 에 주머니에서 손으로, STOOP_IN 에 그릇으로) → tab −1.
## 사람도 장부 앞에서 C — 같은 세 박자로 제 줄을 읽고 동전이 있으면 한 닢(C 한 번에 하나). 외상이 없으면 읽기만. 빵집 주인은 17시(closing)에 그릇의 동전을 stoop 으로 거둔다(resident_ledger, palm_till 의 사슬).
## 상한(운영자 2026-10-06 money 3): 외상은 여섯까지 — 여섯이 적힌 빈 주머니는 창구가 더는 긋지 않는다(tab_full, counter_take 가 먼저 묻는다; 주인이 곁이면 한마디). 동전이 있으면 여느 때처럼 산다
## 사슬: … → coins → busk → **ledger** → growth → city → plots → interior → cabin → social → wages(town_wages.gd, 품삯 — run 113) → player → town3d

const TURN_T := PostPoses.SCAN_T + LedgerPoses.SIGH_T + CoinPoses.STOOP_T   # 한 차례: 읽기 → 한숨 → 한 닢
const TAB_MAX := 6   # 외상 상한 — 그 위로는 창구가 긋지 않는다(money 3)

var ledger: Dictionary = {}   # 자리 {pos, kind "ledger", yaw, till, till_shown, bowl, at} — 그릇은 악사의 모자와 같은 꼴(till/till_shown)이라 tip·palm_till 이 그대로 섬긴다
var tab := 0                  # 내 외상(이 판에서만 — 동전처럼 저장은 다음 조각)
var turns: Array = []         # 읽는 중 [{fig, who, t0, step}] — step 0 scan · 1 sigh · 2 stoop

## 탁자(town3d _shops — 시장과 같이 켜고 꺼진다): 다리 둘 위 상판(0.72), 펼친 장부 두 쪽(잉크 줄 셋씩), 깃펜 하나, 발치 앞의 구리 그릇에 숨긴 원판 다섯
func _ledger(at: Vector3) -> void:
	var wood := _mat(Color("6b4a35"))
	for sx: float in [-0.28, 0.28]: _box(Vector3(0.06, 0.7, 0.4), at + Vector3(sx, 0, 0), wood)
	_box(Vector3(0.7, 0.03, 0.46), at + Vector3(0, 0.7, 0), _mat(Color("8a6a4a")))   # 상판 — 손을 짚는다
	for px: float in [-0.13, 0.13]:   # 펼친 두 쪽 — 안쪽이 조금 낮아 등이 접힌 것으로 읽힌다
		var pg := _box(Vector3(0.24, 0.016, 0.3), at + Vector3(px, 0.73, -0.02), _mat(Color("f7f4ef")), false)
		pg.rotation.z = -signf(px) * 0.06
		for i in 3: _box(Vector3(0.16, 0.003, 0.012), at + Vector3(px, 0.746 + i * 0.001, -0.1 + i * 0.07), _mat(Color("4a4a52")), false)   # 잉크 줄 — 줄마다 한 사람
	_box(Vector3(0.012, 0.012, 0.18), at + Vector3(0.3, 0.73, 0.08), _mat(Color("1b0c15")), false).rotation.y = 0.5   # 깃펜
	var bp := at + Vector3(0, 0, 0.42)
	var bm := MeshInstance3D.new(); var cy := CylinderMesh.new(); cy.top_radius = 0.16; cy.bottom_radius = 0.11; cy.height = 0.05; cy.radial_segments = 18
	bm.mesh = cy; bm.material_override = _mat(Color("b56a5a")); bm.position = bp + Vector3(0, 0.025, 0); _add(bm)   # 구리 그릇 — 바닥에, 악사의 모자처럼 stoop 이 닿는 높이
	var shown: Array = []
	for i in TILL_MAX:
		var c := make_item("coin", bp + Vector3(0, 0.05 + i * 0.013, 0)); c.visible = false; shown.append(c)
	ledger = { "pos": at + Vector3(0, 0, 1.0), "kind": "ledger", "yaw": PI, "till": 0, "till_shown": shown, "bowl": bp, "at": at }
	spots.append(ledger)

## 창구에서 동전 없이 받아 갔다(town_coins pay_counter — 빵집 창구만): 적는다. 빵집 주인은 제 빵이라 안 적는다
func tab_note(by: Variant) -> void:
	if by is ResidentBase:
		var r: ResidentBase = by
		if r.job != "baker": r.mind.tab = mini(TAB_MAX, r.mind.tab + 1)
		return
	tab = mini(TAB_MAX, tab + 1)
	say_toast("On the house. That is %d on the tab." % tab + (" The limit." if tab >= TAB_MAX else ""))

## 창구가 긋기를 거절하나(town_places counter_take 가 재고를 내기 전에 묻는다) — 빈 주머니에 여섯이 적혀 있으면. 빵집 주인이 14m 안이면 한마디. 동전이 있으면 거절은 없다
func tab_full(by: Variant) -> bool:
	if coins_of(by) > 0 or tab_of(by) < TAB_MAX: return false
	var p: Vector3 = (by as ResidentBase).global_position if by is ResidentBase else body.global_position
	for r in residents:
		if r.job == "baker" and not (r.state in ["down", "getup", "drive", "chase"]) and r.global_position.distance_to(p) < 14.0:
			r.say(["Settle up first.", "Six on the tab. No.", "Not till you pay something."][randi() % 3], 1.8); break
	if by is String: say_toast("Six on the tab. Settle something first.")
	return true

## 그릇에 한 닢이 들어갔다(town_busk _tips_tick, dish 가 장부일 때): 외상이 하나 준다 — 주민은 한 줄(tab_pay)과 오늘 다녀간 표, 사람은 토스트
func tab_paid(who: Variant) -> void:
	if who is ResidentBase:
		var r: ResidentBase = who
		r.mind.tab = maxi(0, r.mind.tab - 1); r.set_meta("tabbed", Time.get_ticks_msec() / 1000.0)
		r.say(r.mind.line("tab_pay"), 1.8); return
	tab = maxi(0, tab - 1)
	say_toast("Settled." if tab == 0 else "One off. %d on the tab." % tab)

func tab_of(who: Variant) -> int:
	return (who as ResidentBase).mind.tab if who is ResidentBase else tab

func coins_of(who: Variant) -> int:
	return (who as ResidentBase).coins if who is ResidentBase else coins

## 한 차례 시작(주민 _ledger_arrive · 사람 ledger_use) — 호출자가 얼굴을 돌리고 busy/use 시간을 잡는다. 읽기부터; 진행은 _ledger_tick
func ledger_turn(fig: Stick3D, who: Variant, now: float) -> void:
	fig.pose_request = "scan"
	turns.append({ "fig": fig, "who": who, "t0": now, "step": 0 })

## 사람: 장부 앞(빈손, town_player 의 자리 목록)에서 C — 제 줄을 읽고(토스트가 수를 말한다), 외상이 있고 동전이 있으면 한숨 뒤 한 닢. 걸어 나가면 끊긴다
func ledger_use(now: float) -> void:
	if ledger.is_empty() or not seat.is_empty() or resting or rowing: return
	var at: Vector3 = ledger["at"]
	player.face(atan2(at.x - body.global_position.x, at.z - body.global_position.z))
	ledger_turn(player, "player", now)
	use_until = now + TURN_T + 0.1; action_until = use_until
	say_toast("Nothing on the tab." if tab == 0 else ("%d on the tab." % tab))

## 매 프레임(town_systems _tick): 읽기가 끝나면 한숨, 한숨이 끝나면 한 닢(tip 사슬이 주머니·그릇·자세를 맡는다). 맞았다·걸어갔다·외상이 없다·동전이 없다 — 거기서 끝
func _ledger_tick(now: float) -> void:
	if ledger.is_empty(): return
	for e in turns.duplicate():
		var fig: Stick3D = e["fig"]; var who: Variant = e["who"]; var t: float = now - float(e["t0"]); var step: int = e["step"]
		var want: String = ["scan", "sigh", "stoop"][step]
		if fig.pose_request != want or (who is String and player.move_dir != Vector3.ZERO) or (who is ResidentBase and (who as ResidentBase).state != "busy"):
			turns.erase(e); continue
		if step == 0 and t >= PostPoses.SCAN_T:
			if tab_of(who) <= 0 or coins_of(who) <= 0:
				_turn_end(e, now); continue   # 읽기만 — 적힌 게 없거나 낼 게 없다
			fig.pose_request = "sigh"; e["step"] = 1; e["t0"] = now
		elif step == 1 and t >= LedgerPoses.SIGH_T:
			fig.pose_request = "stoop"; e["step"] = 2; e["t0"] = now
			tip(fig, who, ledger)
		elif step == 2 and t >= CoinPoses.STOOP_T:
			turns.erase(e)   # 자세는 tip 사슬이 푼다

## 차례를 일찍 접는다 — 자세를 풀고, 사람이면 C 가 바로 다시 듣게, 주민이면 곧 떠나게
func _turn_end(e: Dictionary, now: float) -> void:
	var fig: Stick3D = e["fig"]; var who: Variant = e["who"]
	turns.erase(e); fig.pose_request = ""
	if who is String: use_until = now; action_until = now
	else: (who as ResidentBase).busy_until = now + 0.3
