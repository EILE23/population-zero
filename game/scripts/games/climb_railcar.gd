class_name ClimbRailcar
extends Node3D
## Climb 콘텐츠 팩 '톱니 궤도차'(운영자 2026-10-06 밤: "Climb는 컨텐츠 자체의 질과 양을 늘리는 거" — 팩은 data/climb/*.json 자료, 로더는 운영자 세션이 잇는다; climb.gd 는 CI 가 안 건드린다).
## 태엽(Clockwork) 층(바람구멍 층은 뺀다)의 잇단 두 발판(아래 a·위 b; a 는 still, b 는 부서져도 된다 — 튀는 발판은 안 된다, 내려선 몸이 튀어 오른다) 사이 틈(min_gap..max_gap, 오름 min_dy..max_dy, 경사 grade_max 까지) — a 의 틈 쪽 가장자리 dock_in 안의 아랫역에서 b 의 가장자리 dock_in 안의 윗역까지 톱니 궤도가 오르고, 아랫역에 안장·페달·톱니바퀴의 놋쇠 차가 서 있다.
## 아랫역 곁(HW + reach, a 위)에서 C 한 번: 차에 오른다(mount_s — 다리를 안장 너머로 넘긴다, busy) → 안장에 앉은 몸(궤도 위 ride_dy)이 실려 간다: C 를 쥐면 페달을 밟아 차가 spin_s 에 v_up 까지 오르고, 놓으면 자유바퀴로 roll_s 에 −v_back 까지 굴러 내린다(다리는 멎고 몸은 뒤로 버틴다); tooth 마다 톱니가 딸깍인다.
## 꼭대기에서 멈춤쇠가 건다(clack) — 탑의 하루(day_s)에 한 번 센다(쉼터 판이 note(n) 으로 읽는다: 'Rack cars, floors 15–19: 1 of 2 cars ridden to the top today, 3 rides today.') — 몸은 off_s 에 b 로 내려선다(step_out 안쪽, busy). 바닥까지 굴러 내리면 차가 멎고(bump) C 를 idle_s 놓으면 a 로 내려선다.
## 빈 차는 꼭대기에서 hold_s 기다렸다 v_back 으로 집에 굴러온다 — 그동안 빈 아랫역 곁 C 는 아무것도 아니다. 타는 동안은 내내 busy(걷기·점프 없음, ← → 는 아무것도 아니다).
## 아랫역 곁에서 C 를 누르지 않는 몸에겐 아무것도 바뀌지 않는다: a 를 달려 지나는 길, 틈을 건너는 맨 점프, 다른 데서의 C(쉼터 문·판)는 그대로(평이한 결과 100%). 안장은 탄 몸 밑에서만 발판이고 값도 없다 — 위에서 떨어져 타는 일은 없다(로더의 착지 판정은 할 일이 없다).
## 자세는 pedal(stick3d_pedal.gd — 운영자 보드의 '자전거' 가족의 첫 자세: 안장 너머로 넘기는 다리, 앉음, 크랭크 위를 도는 두 발(원 위의 두 관절 다리), 손잡이의 두 손, 밟음마다 흔들리는 상체, 자유바퀴에 뒤로 버티는 몸, 궤도 위를 보는 눈 — 정지화가 아니다). 타는 이는 dir 쪽을 본다(riding(fig) 이 dir 을 준다).
## 풀무(발로 다른 자리를 올린다)·파터노스터(멈추지 않는 칸에 들어선다)·튤립(접힌 채 실려 오른다)·집라인(제 무게로 내려간다)과 다르다: 이건 제 다리로 모는 첫 바퀴 — 다리가 멎으면 되돌아 내려온다.
## 로더가 할 일(climb.gd, 운영자 세션): `var cr := ClimbRailcar.new(); add_child(cr); signs.notes.append(cr.note)`; 층을 지을 때 `var ck := cg.plan(n, plats) + cpn.plan(n, plats) + pk.plan(n, plats); var bl := cl.plan(n, plats, ck); var ep := ew.plan(n, plats, ck + bl); cr.build(root, cr.plan(n, plats, ck + bl + ep + cw.plan(n, plats, ck + bl + ep)))`
## (톱니 띠·추·뻐꾸기 집·풀무·핀 바퀴·시계추의 계획을 taken 으로 — 그 틈은 비켜 간다); 매 틱 `cr.sync(_t)`;
## 발판에 선 가지의 맨 앞(jump_held 를 읽기 전에): `if String(on.get("kind", "")) == "railcar": dir = 0.0; jump_held = false; charge = 0.0 else: var mt := cr.mount(on, x, z, Input.is_action_just_pressed("act"), fig); if not mt.is_empty(): on = mt; vx = 0.0` (오른 틱 — 사전은 안장, 로더의 다른 발판과 같은 꼴; 빈 사전이면 닿지 않거나 차가 집에 없는 것);
## 'move' 발판 자리에서 `elif on["kind"] == "railcar": var r := cr.stand(on, Input.is_action_pressed("act"), dt, fig); x = r["x"]; y = r["y"]; vx = 0.0; fig.pose_request = "pedal"; if r["off"]: on = {}; apex = y; fig.pose_request = ""` (내려선 틱의 x·y 가 발판 위라 다음 틱 로더의 착지 판정이 밟는다 — 집라인과 같은 식);
## `_figure()` 의 face 가지 앞에 `var rd := cr.riding(fig); if rd != 0.0: fig.face(PI / 2.0 if rd > 0.0 else -PI / 2.0)`. 쉼터 판 C 는 signs.tick 이 먼저 — 아랫역은 발판에만 선다.
## mount 의 count: 비우면 플레이어(판에 세고 me_t 를 적는다 — 다음 조각의 주민 반쪽이 따라 탄다), 다른 몸은 거짓을 준다. 단위는 climb.gd 와 같은 px(36px = 1m, +y 위). 점검은 tools/probe_railcar.gd

const PACK := "res://data/climb/railcar.json"
const C = preload("res://scripts/games/climb.gd")
const BAND_LO := 20.0      # taken 조각이 이 틈·역의 것인가: y 가 상자 바닥 − BAND_LO 부터 + BAND_HI 앞까지(run 152 의 띠 규칙 — 풀무의 220 px 띠는 여섯 팩이 선 태엽 층의 틈을 하나도 안 남겼다)
const BAND_HI := 60.0
const BODY_UP := 50.0      # 윗역에 선 몸의 키(px) — 상자 위쪽 여유
const SIDE := 10.0         # 상자의 x 여유(px) — 손 하나
const STOOD_T := 0.25      # 이만큼 stand 가 안 오면 탄 몸이 사라진 것 — 차를 비운다
const MAX_TEETH := 24      # 그리는 톱니의 상한
const COG_R := 0.12        # 톱니바퀴 반지름(m)
const SEAT_H := 0.30       # 탄 몸의 발에서 안장까지(m) = 자세의 골반 내림(HIP_Y 0.42 → 0.32)
const AXLE_F := 0.26       # 크랭크 축: 골반에서 앞으로(m) — stick3d_pedal.gd 와 같은 수
const CRANK_R := 0.09      # 크랭크 반지름(m)

var pack: Dictionary = {}
var kind: Dictionary = {}       # kinds.rail
var cars: Array = []            # 지은 궤도 {id, kind "rail", n, a_id, b_id, a_y, b_y, dir, gap, dy, x0, y0, x1, y1, run, rail_len, grade, x, w, y, y_top, z, d, node, car, cog, cranks, seat, u, v, ang, sw, sw_t0, rider, pressed, idle_t0, stand_t, count, latch_t0, moved, day, rides, ride_day, day_rides, me_t, top, tooth_acc, clicks, tick, clack, bump}
var t := 0.0                    # 로더의 _t 와 같이 간다(sync)

func _ready() -> void:
	var f := FileAccess.open(PACK, FileAccess.READ)
	if f: pack = JSON.parse_string(f.get_as_text()) as Dictionary
	kind = (pack.get("kinds", {}) as Dictionary).get("rail", {})

func sync(now: float) -> void:
	t = now

func min_gap() -> float:
	return maxf(2.0 * C.HW, float(kind.get("min_gap", 60.0)))

func max_gap() -> float:
	return maxf(min_gap(), float(kind.get("max_gap", 260.0)))

func min_dy() -> float:
	return maxf(1.0, float(kind.get("min_dy", 60.0)))

func max_dy() -> float:
	return maxf(min_dy(), float(kind.get("max_dy", 160.0)))

func grade_max() -> float:
	return maxf(0.1, float(kind.get("grade_max", 1.6)))

func dock_in() -> float:
	return maxf(C.HW, float(kind.get("dock_in", 22.0)))

func reach() -> float:
	return maxf(0.0, float(kind.get("reach", 14.0)))

func ride_dy() -> float:
	return maxf(1.0, float(kind.get("ride_dy", 8.0)))

func v_up() -> float:
	return maxf(1.0, float(kind.get("v_up", 70.0)))

func spin_s() -> float:
	return maxf(0.05, float(kind.get("spin_s", 0.6)))

func v_back() -> float:
	return maxf(1.0, float(kind.get("v_back", 110.0)))

func roll_s() -> float:
	return maxf(0.05, float(kind.get("roll_s", 0.5)))

func tooth() -> float:
	return maxf(2.0, float(kind.get("tooth", 12.0)))

func mount_s() -> float:
	return maxf(0.05, float(kind.get("mount_s", 0.45)))

func off_s() -> float:
	return maxf(0.05, float(kind.get("off_s", 0.45)))

func idle_s() -> float:
	return maxf(0.05, float(kind.get("idle_s", 1.0)))

func hold_s() -> float:
	return maxf(0.0, float(kind.get("hold_s", 3.0)))

func step_out() -> float:
	return maxf(C.HW, float(kind.get("step_out", 14.0)))

func deck_d() -> float:
	return maxf(2.0, float(kind.get("deck_d", 28.0)))

func day_s() -> float:
	return maxf(1.0, float(kind.get("day_s", 600.0)))

func cad_hz() -> float:
	return maxf(0.1, float(kind.get("cad_hz", 1.4)))

## 탑의 오늘 — 로더의 시계를 day_s 로 나눈 몫
func day() -> int:
	return floori(t / day_s())

## 층 n(테마 층, 조각의 not 규칙)의 잇단 두 발판(조각의 on·to; 아래 a·위 b) 중 틈이 min_gap..max_gap 이고 b 가 min_dy..max_dy 높으며 경사가 grade_max 안이고 궤도의 상자를 다른 발판이 가르지 않고 taken 조각이 닿지 않는 짝들 중 가장 넓은 틈 하나. 같은 층·같은 taken 은 늘 같은 답
func plan(n: int, plats: Array, taken: Array = []) -> Array:
	var out: Array = []
	if not (String(C.theme(n)[0]) in (pack.get("themes", []) as Array)): return out
	for pv in (pack.get("pieces", []) as Array):
		var piece: Dictionary = pv
		var skip: Dictionary = piece.get("not", {})
		if not skip.is_empty() and _on(n, skip): continue
		var kinds: Array = piece.get("on", ["std", "ice"]); var to: Array = piece.get("to", kinds)   # on: 오르는 아래 발판(still 만), to: 내려서는 위 발판(부서져도 된다, 튀면 안 된다)
		var hops: Array = plats.filter(func(p: Dictionary) -> bool: return not (String(p["kind"]) in ["rest", "short", "ledge"]))
		var found: Array = []
		for i in range(1, hops.size()):
			var a: Dictionary = hops[i - 1]; var b: Dictionary = hops[i]   # a 가 아래 발판(band() 는 오르는 순서로 쌓는다)
			if not (String(a["kind"]) in kinds and String(b["kind"]) in to): continue
			var dy := float(b["y"]) - float(a["y"])
			if dy < min_dy() or dy > max_dy(): continue
			var ax0 := float(a["x"]); var ax1 := ax0 + float(a["w"]); var bx0 := float(b["x"]); var bx1 := bx0 + float(b["w"])
			if bx0 < ax1 and bx1 > ax0: continue   # 겹친 발판 — 틈이 없다
			var dir := 1.0 if bx0 >= ax1 else -1.0   # a 에서 b 쪽 — b 가 오른쪽이면 +x
			var gap := bx0 - ax1 if dir > 0.0 else ax0 - bx1
			if gap < min_gap() or gap > max_gap(): continue
			var a_edge := ax1 if dir > 0.0 else ax0; var b_edge := bx0 if dir > 0.0 else bx1
			var x0 := a_edge - dir * dock_in(); var x1 := b_edge + dir * dock_in()
			var run := absf(x1 - x0); var grade := dy / maxf(1.0, run)
			if grade > grade_max(): continue
			var lo := minf(x0, x1) - SIDE; var hi := maxf(x0, x1) + SIDE
			var ylo := float(a["y"]) - 10.0; var yhi := float(b["y"]) + BODY_UP
			if not _clear(plats, a, b, lo, hi, ylo, yhi): continue
			if not _free(taken, lo, hi, ylo, yhi): continue
			found.append({ "gap": gap, "dy": dy, "dir": dir, "a_id": String(a["id"]), "b_id": String(b["id"]), "a_y": float(a["y"]), "b_y": float(b["y"]),
				"x0": x0, "y0": float(a["y"]), "x1": x1, "y1": float(b["y"]), "run": run, "rail_len": sqrt(run * run + dy * dy), "grade": grade, "x": lo, "w": hi - lo })
		found.sort_custom(func(p: Dictionary, q: Dictionary) -> bool: return float(p["gap"]) > float(q["gap"]) if float(p["gap"]) != float(q["gap"]) else float(p["a_y"]) < float(q["a_y"]))
		for i in range(0, mini(int(piece.get("max", 1)), found.size())):
			var g: Dictionary = found[i]
			var s: Dictionary = g.duplicate(true)
			s["id"] = "%d.R%d" % [n, i]; s["kind"] = "rail"; s["n"] = n
			s["y"] = float(g["a_y"]); s["y_top"] = float(g["b_y"])   # 다른 팩의 _free 가 읽는 키 — 상자는 아랫역 높이에서 윗역까지
			s["z"] = C.PLAYER_Z; s["d"] = deck_d()
			out.append(s)
	return out

## 층 n 이 {from, every} 에 드나
static func _on(n: int, rule: Dictionary) -> bool:
	var from := int(rule.get("from", 0))
	return n >= from and (n - from) % maxi(1, int(rule.get("every", 1))) == 0

## 궤도의 상자(두 역의 x 폭, a 윗면 조금 밑..b 위 선 몸)에 두 발판 말고 다른 발판이 걸리지 않나 — 움직이는 발판은 진폭째
static func _clear(plats: Array, a: Dictionary, b: Dictionary, x0: float, x1: float, ylo: float, yhi: float) -> bool:
	for pv in plats:
		var p: Dictionary = pv
		if p["id"] == a["id"] or p["id"] == b["id"]: continue
		var py := float(p["y"])
		if py < ylo or py > yhi: continue
		var amp := float(p.get("amp", 0.0))
		var px0 := float(p["x"]) - amp - 10.0; var px1 := float(p["x"]) + float(p["w"]) + amp + 10.0
		if x1 > px0 and x0 < px1: return false
	return true

## 다른 팩의 조각(taken: x·w·y, 있으면 len·y_top)이 궤도의 상자에 닿지 않나 — 조각의 몸은 y − BAND_LO 부터 y + BAND_HI(제 꼭대기 len·y_top 가 더 높으면 거기 + 10)까지; 톱니 띠(kind gears)는 발판째라 세지 않는다 — 역이 띠 위에 서도 된다(띠가 몸을 역으로 나르고, 내려선 몸을 띠가 받는다; 띠를 세면 태엽 층엔 궤도가 설 틈이 없다)
static func _free(taken: Array, x0: float, x1: float, ylo: float, yhi: float) -> bool:
	for tv in taken:
		var q: Dictionary = tv
		if String(q.get("kind", "")) == "gears": continue
		var qx0 := float(q.get("x", 0.0)) - 10.0; var qx1 := float(q.get("x", 0.0)) + float(q.get("w", 0.0)) + 10.0
		var qy := float(q.get("y", 0.0)); var qy0 := qy - BAND_LO; var qy1 := qy + BAND_HI
		if q.has("len"): qy1 = maxf(qy1, qy + float(q["len"]) + 10.0)
		if q.has("y_top"): qy1 = maxf(qy1, float(q["y_top"]) + 10.0)
		if x1 > qx0 and x0 < qx1 and yhi > qy0 and ylo < qy1: return false
	return true

## 궤도 위 u(0 아랫역..1 윗역)의 자리(px) — 차의 가운데
func pos(s: Dictionary, u: float) -> Vector2:
	return Vector2(lerpf(float(s["x0"]), float(s["x1"]), u), lerpf(float(s["y0"]), float(s["y1"]), u))

## 발판에 선 틱, C 가 막 눌렸을 때 — 아랫역 곁(HW + reach, a 위, 걷는 선)에 선 몸이 집에 선 빈 차에 오른다: 안장 사전(로더의 on)을 돌려주고 mount_s 동안 다리를 넘긴다(meta pedal_m). 안 닿거나 차가 집에 없거나 남이 탔으면 빈 사전
func mount(on: Dictionary, x: float, z: float, pressed: bool, fig: Stick3D = null, count := true) -> Dictionary:
	if not pressed: return {}
	var oid := String(on.get("id", ""))
	for sv in cars:
		var s: Dictionary = sv
		if oid != String(s["a_id"]) or absf(z - C.PLAYER_Z) >= C.HZ + 4.0 or absf(x - float(s["x0"])) > C.HW + reach(): continue
		if String(s["sw"]) != "" or float(s["u"]) > 0.0 or s["rider"] != null: return {}   # 차가 집에 없거나 남이 탔다 — 아무것도 아니다
		s["sw"] = "mount"; s["sw_t0"] = t; s["rider"] = fig; s["count"] = count; s["pressed"] = false; s["idle_t0"] = -1.0; s["stand_t"] = t; s["top"] = false
		_metas(s, 0.0)
		_seat(s)
		return s["seat"]
	return {}

## 안장 위의 매 틱 — {x, y, off, busy, k, u}: 오르는 동안(mount) 다리를 넘기고, 타는 동안(ride) C 를 쥐면 밟아 오르고 놓으면 굴러 내리며, 꼭대기에 닿으면 걸고 세고 내려서기(off)로, 바닥에서 C 를 idle_s 놓으면 내려서기로; off 가 끝난 틱은 off 참이고 x·y 는 발판 위(로더의 착지 판정이 다음 틱에 밟는다). 모르는 안장이면 off
func stand(on: Dictionary, pressed: bool, dt: float, _fig: Stick3D = null) -> Dictionary:
	var s := _find_seat(String(on.get("id", "")))
	if s.is_empty() or s["rider"] == null: return { "x": float(on.get("x", 0.0)) + float(on.get("w", 0.0)) / 2.0, "y": float(on.get("y", 0.0)), "off": true, "busy": false, "k": 0.0, "u": 0.0 }
	s["pressed"] = pressed; s["stand_t"] = t
	var u_t := t - float(s["sw_t0"])
	match String(s["sw"]):
		"mount":
			_metas(s, clampf(u_t / mount_s(), 0.0, 1.0))
			if u_t >= mount_s(): s["sw"] = "ride"; s["sw_t0"] = t
		"ride":
			_drive(s, pressed, dt)
			if float(s["u"]) >= 1.0: _latch(s)
			elif float(s["u"]) <= 0.0 and float(s["v"]) <= 0.0: _bottom(s, pressed)
			_metas(s, 1.0)   # 건·멎은 뒤에 — 그 틱의 박자가 0 으로 읽히게
		"off":
			_metas(s, 1.0 - clampf(u_t / off_s(), 0.0, 1.0))
			if u_t >= off_s():
				var top := bool(s["top"]); var dir := float(s["dir"])
				var gx := float(s["x1"]) + dir * step_out() if top else float(s["x0"]) - dir * step_out()
				var gy := float(s["y1"]) if top else float(s["y0"])
				_leave(s)
				return { "x": gx, "y": gy, "off": true, "busy": false, "k": 0.0, "u": 1.0 if top else 0.0 }
	_seat(s)
	var seat: Dictionary = s["seat"]
	return { "x": float(seat["x"]) + float(seat["w"]) / 2.0, "y": float(seat["y"]), "off": false, "busy": true, "k": maxf(0.0, float(s["v"])) / v_up(), "u": float(s["u"]) }

## 밟기·자유바퀴 — C 를 쥐면 spin_s 에 v_up 까지, 놓으면 roll_s 에 −v_back 까지; 간 만큼 u 가 가고 크랭크가 돌고 톱니가 딸깍인다
func _drive(s: Dictionary, pressed: bool, dt: float) -> void:
	var v := float(s["v"])
	v = minf(v_up(), v + v_up() / spin_s() * dt) if pressed else maxf(-v_back(), v - v_back() / roll_s() * dt)
	s["v"] = v
	_travel(s, v * dt)
	s["ang"] = float(s["ang"]) + maxf(0.0, v) / v_up() * cad_hz() * TAU * dt   # 크랭크 — 밟을 때만 돈다(자유바퀴)

## 궤도를 d px 간다(+ 위) — 실제로 간 만큼만 센다(끝에 눌린 차는 안 간 것: 바닥의 bump 가 틱마다 울리지 않게); 톱니마다 딸깍
func _travel(s: Dictionary, d: float) -> void:
	var u0 := float(s["u"])
	s["u"] = clampf(u0 + d / float(s["rail_len"]), 0.0, 1.0)
	var went := absf(float(s["u"]) - u0) * float(s["rail_len"])
	if went <= 0.0: return
	s["moved"] = true
	s["tooth_acc"] = float(s["tooth_acc"]) + went
	if float(s["tooth_acc"]) >= tooth():
		s["tooth_acc"] = fmod(float(s["tooth_acc"]), tooth()); s["clicks"] = int(s["clicks"]) + 1
		_play(s["tick"] as AudioStreamPlayer3D)

## 꼭대기 — 멈춤쇠가 건다(clack), 센다(오늘·탄 횟수; 플레이어의 것만 판의 날), 내려서기로
func _latch(s: Dictionary) -> void:
	s["u"] = 1.0; s["v"] = 0.0; s["top"] = true
	s["rides"] = int(s["rides"]) + 1
	if int(s["ride_day"]) != day(): s["ride_day"] = day(); s["day_rides"] = 0
	s["day_rides"] = int(s["day_rides"]) + 1
	if bool(s["count"]): s["day"] = day(); s["me_t"] = t   # 플레이어가 올랐다 — 주민 반쪽이 따라 탄다
	_play(s["clack"] as AudioStreamPlayer3D)
	s["sw"] = "off"; s["sw_t0"] = t

## 바닥 — 굴러 내려온 차가 멎고(bump), C 를 idle_s 놓고 있으면 내려서기로
func _bottom(s: Dictionary, pressed: bool) -> void:
	s["u"] = 0.0
	if float(s["v"]) < 0.0 and bool(s["moved"]): _play(s["bump"] as AudioStreamPlayer3D)
	s["v"] = 0.0; s["moved"] = false
	if pressed: s["idle_t0"] = -1.0; return
	if float(s["idle_t0"]) < 0.0: s["idle_t0"] = t
	elif t - float(s["idle_t0"]) >= idle_s(): s["top"] = false; s["sw"] = "off"; s["sw_t0"] = t

## 안장 사전을 차의 자리로 — x·w 는 안장의 왼끝과 폭(몸 하나), y 는 탄 몸의 발(궤도 위 ride_dy)
func _seat(s: Dictionary) -> void:
	var p := pos(s, float(s["u"]))
	var seat: Dictionary = s["seat"]
	seat["x"] = p.x - C.HW - 6.0; seat["w"] = 2.0 * C.HW + 12.0; seat["y"] = p.y + ride_dy()

## 자세의 메타 — pedal_m 오른 몫 0..1, pedal_k 밟는 박자 0..1, pedal_b 자유바퀴에 버티는 몫 0..1, pedal_a 크랭크 각(rad)
func _metas(s: Dictionary, m: float) -> void:
	var fig := s["rider"] as Stick3D
	if fig == null: return
	fig.set_meta("pedal_m", m)
	fig.set_meta("pedal_k", maxf(0.0, float(s["v"])) / v_up())
	fig.set_meta("pedal_b", maxf(0.0, -float(s["v"])) / v_back())
	fig.set_meta("pedal_a", float(s["ang"]))

## 이 몸이 어느 차에든 타고 있으면(오르는·타는·내려서는 중) 그 궤도의 dir(±1), 아니면 0 — 로더가 그쪽을 보게 한다
func riding(fig: Stick3D) -> float:
	for sv in cars:
		var s: Dictionary = sv
		if String(s["sw"]) != "" and (s["rider"] as Stick3D) == fig: return float(s["dir"])
	return 0.0

## 차에서 떠난 몸 — 자세의 메타를 거둔다
func leave(fig: Stick3D) -> void:
	if fig == null: return
	for key: String in ["pedal_m", "pedal_k", "pedal_b", "pedal_a"]:
		if fig.has_meta(key): fig.remove_meta(key)

## 차를 비운다 — 꼭대기면 hold_s 의 시계가 돈다
func _leave(s: Dictionary) -> void:
	leave(s["rider"] as Stick3D)
	s["rider"] = null; s["sw"] = ""; s["pressed"] = false; s["v"] = 0.0; s["idle_t0"] = -1.0
	if float(s["u"]) >= 1.0: s["latch_t0"] = t

## n0..n1 층의 지은 차에서 오늘 꼭대기까지 오른 수·전체·오늘 탄 수 — {top, total, rides}
func top_today(n0: int, n1: int) -> Dictionary:
	var top := 0; var total := 0; var rides := 0
	for sv in cars:
		var s: Dictionary = sv
		if int(s["n"]) < n0 or int(s["n"]) > n1: continue
		total += 1
		if int(s["day"]) == day(): top += 1
		if int(s["ride_day"]) == day(): rides += int(s["day_rides"])
	return { "top": top, "total": total, "rides": rides }

## 쉼터 판(n 층)에 붙는 줄 — 위 다섯 층(n..n+4)의 차, 없으면 아래 다섯 층(n−5..n−1), 그것도 없으면 빈 줄. climb_signs.notes 에 넣는다
func note(n: int) -> String:
	for span: Array in [[n, n + 4], [n - 5, n - 1]]:
		var v := top_today(int(span[0]), int(span[1]))
		if int(v["total"]) > 0:
			var line := "Rack cars, floors %d–%d: %d of %d %s ridden to the top today" % [int(span[0]), int(span[1]), int(v["top"]), int(v["total"]), "car" if int(v["total"]) == 1 else "cars"]
			if int(v["rides"]) > 0: line += ", %d %s today" % [int(v["rides"]), "ride" if int(v["rides"]) == 1 else "rides"]
			return line + "."
	return ""

func _find_seat(id: String) -> Dictionary:
	for sv in cars:
		if String(((sv as Dictionary)["seat"] as Dictionary)["id"]) == id: return sv
	return {}

func _play(p: AudioStreamPlayer3D) -> void:
	if p.playing: p.stop()
	p.play()

## 빈 차의 시계와 그림 — 꼭대기의 빈 차는 hold_s 뒤 굴러 내려온다; 탄 몸이 STOOD_T 동안 stand 를 안 주면 사라진 것이라 차를 비운다
func _process(delta: float) -> void:
	t += delta
	cars = cars.filter(func(s: Dictionary) -> bool: return is_instance_valid(s["node"]))   # 지운 층의 것은 뺀다(climb_bellows 와 같은 식)
	var dt := minf(delta, 1.0 / 30.0)
	for sv in cars:
		var s: Dictionary = sv
		if s["rider"] != null and t - float(s["stand_t"]) > STOOD_T: _leave(s)
		if s["rider"] == null and float(s["u"]) > 0.0: _roll_home(s, dt)
		_place(s)

func _roll_home(s: Dictionary, dt: float) -> void:
	if float(s["latch_t0"]) >= 0.0 and t - float(s["latch_t0"]) < hold_s(): return
	s["latch_t0"] = -1.0
	s["v"] = maxf(-v_back(), float(s["v"]) - v_back() / roll_s() * dt)
	_travel(s, float(s["v"]) * dt)
	if float(s["u"]) <= 0.0: _bottom(s, true)

## 차를 궤도 위 u 로, 톱니바퀴를 간 만큼, 크랭크를 밟은 만큼 돌린다
func _place(s: Dictionary) -> void:
	var p := pos(s, float(s["u"])); var dir := float(s["dir"])
	(s["car"] as Node3D).position = Vector3((p.x - float(s["x0"])) * C.K, (p.y - float(s["y0"])) * C.K, 0.0)
	(s["cog"] as Node3D).rotation.z = -dir * float(s["u"]) * float(s["rail_len"]) * C.K / COG_R
	(s["cranks"] as Node3D).rotation.z = -dir * float(s["ang"])

## 궤도와 차를 짓는다 — root 는 그 층의 노드. 노드 원점은 (아랫역의 x, a 윗면, PLAYER_Z); 궤도(봉·톱니·절벽 받침 둘·역판 둘·멈춤쇠), 차(틀·톱니바퀴·안장 기둥·안장·손잡이 기둥·손잡이·크랭크 둘과 페달), 소리 셋
func build(root: Node3D, planned: Array) -> void:
	for sv in planned:
		var s: Dictionary = (sv as Dictionary).duplicate(true)
		var dir := float(s["dir"]); var dx := (float(s["x1"]) - float(s["x0"])) * C.K; var dy := float(s["dy"]) * C.K; var L := float(s["rail_len"]) * C.K
		var node := Node3D.new(); node.position = C.to3(float(s["x0"]), float(s["y0"]), C.PLAYER_Z * C.K); root.add_child(node)
		var iron := _mat(Color("4a4a52")); var brass := _mat(Color("c9a24a")); var dark := _mat(Color("1b0c15")); var mauve := _mat(Color("ad7096"))
		var rail := Node3D.new(); rail.rotation.z = atan2(dy, dx); node.add_child(rail)
		_box(rail, Vector3(L, 0.05, 0.08), iron).position = Vector3(L / 2.0, 0.0, 0.0)   # 봉 — 두 역 사이
		var teeth := mini(MAX_TEETH, floori(float(s["rail_len"]) / tooth()))
		for i in teeth: _box(rail, Vector3(0.03, 0.035, 0.06), brass).position = Vector3(L * (float(i) + 0.5) / float(teeth), 0.04, 0.0)   # 톱니 — 봉 위
		var arm_len := (C.PLAYER_Z - C.WALL_Z) * C.K
		for u: float in [1.0 / 3.0, 2.0 / 3.0]:
			_box(node, Vector3(0.05, 0.05, arm_len), iron).position = Vector3(dx * u, dy * u - 0.06, -arm_len / 2.0)   # 절벽 받침 둘
		_box(node, Vector3(0.3, 0.03, 0.2), brass).position = Vector3(0.0, 0.015, 0.0)        # 아랫역 판
		_box(node, Vector3(0.3, 0.03, 0.2), brass).position = Vector3(dx, dy + 0.015, 0.0)     # 윗역 판
		_box(node, Vector3(0.05, 0.12, 0.05), dark).position = Vector3(dx + dir * 0.12, dy + 0.1, 0.0)   # 멈춤쇠 — 윗역 너머
		var car := Node3D.new(); node.add_child(car)
		_box(car, Vector3(0.5, 0.05, 0.14), iron).position = Vector3(0.0, 0.17, 0.0)          # 틀
		var cog := Node3D.new(); cog.position = Vector3(0.0, COG_R, 0.0); car.add_child(cog)
		var wheel := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = COG_R; cm.bottom_radius = COG_R; cm.height = 0.05; cm.radial_segments = 12; wheel.mesh = cm; wheel.material_override = brass
		wheel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; wheel.rotation.x = PI / 2.0; cog.add_child(wheel)   # 톱니바퀴 — 카메라를 보고 z 로 돈다
		for i in 6:
			var spoke := _box(cog, Vector3(0.03, 2.0 * COG_R + 0.04, 0.05), dark); spoke.rotation.z = float(i) * PI / 6.0   # 살 — 도는 게 보이게
		var seat_y := SEAT_H + ride_dy() * C.K
		_box(car, Vector3(0.04, seat_y - 0.17, 0.04), iron).position = Vector3(-dir * 0.05, (seat_y + 0.17) / 2.0, 0.0)   # 안장 기둥
		_box(car, Vector3(0.2, 0.04, 0.12), mauve).position = Vector3(-dir * 0.05, seat_y, 0.0)                             # 안장 — 강조색은 이 한 조각
		_box(car, Vector3(0.04, 0.42, 0.04), iron).position = Vector3(dir * 0.3, 0.38, 0.0)                                 # 손잡이 기둥
		_box(car, Vector3(0.04, 0.03, 0.2), iron).position = Vector3(dir * 0.3, 0.6, 0.0)                                   # 손잡이
		var cranks := Node3D.new(); cranks.position = Vector3(dir * AXLE_F, ride_dy() * C.K + 0.02, 0.0); car.add_child(cranks)
		for sd: float in [1.0, -1.0]:
			var arm := _box(cranks, Vector3(0.02, CRANK_R, 0.02), iron); arm.position = Vector3(0.0, sd * CRANK_R / 2.0, sd * 0.08)   # 크랭크 둘 — 서로 반대쪽
			_box(cranks, Vector3(0.06, 0.015, 0.04), dark).position = Vector3(0.0, sd * CRANK_R, sd * 0.1)                           # 페달
		s["node"] = node; s["car"] = car; s["cog"] = cog; s["cranks"] = cranks
		s["seat"] = { "kind": "railcar", "id": "%s.c" % String(s["id"]), "x": 0.0, "w": 0.0, "y": 0.0, "z": C.PLAYER_Z, "d": deck_d() }
		s["u"] = 0.0; s["v"] = 0.0; s["ang"] = 0.0; s["sw"] = ""; s["sw_t0"] = -99.0; s["rider"] = null; s["pressed"] = false; s["idle_t0"] = -1.0; s["stand_t"] = -99.0
		s["count"] = true; s["latch_t0"] = -1.0; s["moved"] = false; s["day"] = -1; s["rides"] = 0; s["ride_day"] = -1; s["day_rides"] = 0; s["me_t"] = -99.0; s["top"] = false; s["tooth_acc"] = 0.0; s["clicks"] = 0
		s["tick"] = _snd(node, float(kind.get("tick_hz", 1800)), 0.04, 14.0, -20.0); s["clack"] = _snd(node, float(kind.get("clack_hz", 700)), 0.12, 9.0, -12.0); s["bump"] = _snd(node, float(kind.get("bump_hz", 160)), 0.3, 6.0, -14.0)
		_seat(s)
		cars.append(s)
		_place(s)

func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.albedo_color = c; m.roughness = 1.0
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON; m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return m

func _box(parent: Node3D, size: Vector3, m: StandardMaterial3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = size; mi.mesh = bm; mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF   # 발판과 같은 규칙 — 그림자는 사람만
	parent.add_child(mi); return mi

func _snd(parent: Node3D, hz: float, secs: float, decay: float, db: float) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new(); p.stream = _tick_wav(hz, secs, decay); p.volume_db = db; p.unit_size = 6.0; p.max_distance = 30.0
	parent.add_child(p); return p

## 소리 — 짧은 기음이 잦아든다: tick(0.04초, 높게 — 톱니 하나가 바퀴 밑을 지난다)·clack(0.12초 — 멈춤쇠가 건다)·bump(0.3초, 낮게 — 차가 바닥에 멎는다). 한 번 재생, 반복 없음
static func _tick_wav(hz: float, secs: float, decay: float) -> AudioStreamWAV:
	var rate := 22050; var count := int(rate * secs)
	var data := PackedByteArray(); data.resize(count * 2)
	for i in count:
		var k := float(i) / count
		var ph := float(i) * hz * TAU / rate
		var v := (sin(ph) * 0.5 + sin(ph * 2.3) * 0.2 + sin(ph * 5.7) * 0.08) * exp(-k * decay)
		data.encode_s16(i * 2, int(v * 22000.0))
	var w := AudioStreamWAV.new(); w.format = AudioStreamWAV.FORMAT_16_BITS; w.mix_rate = rate; w.stereo = false; w.data = data
	return w
