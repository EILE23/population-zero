class_name ClimbBarrow
extends Node3D
## Climb 콘텐츠 팩 '반납 손수레'(운영자 2026-10-06 밤: "Climb는 컨텐츠 자체의 질과 양을 늘리는 거" — 팩은 data/climb/*.json 자료, 로더는 운영자 세션이 잇는다; climb.gd 는 CI 가 안 건드린다).
## 서재(Library) 층의 넓은 still 발판(min_w 이상, std 만) 가운데 다음 발판 b 가 가장 높이 오르는 발판 a — 틈 반대쪽 끝 park_in 의 RETURNS 자국 위에 나무 외바퀴 손수레(length: 손잡이 끝에서 바퀴까지)가 바퀴를 틈 쪽으로 두고 서 있고, 통에 반납된 책 books 권.
## 손잡이 뒤(손잡이 끝 HW + reach 안, 손잡이 쪽)에 서서 C 한 번: 잡는다(grip_s, busy) → 민다(push: 걸음 slow 배 — 통이 비면 slow_empty, 점프 없음, 수레는 손 앞 HW + AHEAD): 바퀴가 발판 끝에 닿으면 수레는 서고, 그 너머로 SLACK 더 걷거나 등을 돌리거나 발판을 떠나면 손을 놓는다(drop_s — 수레는 그 자리).
## 밀며 C 를 뗄 때: 내려놓는다(set_s, busy). 밀며 선 채 C 를 tip_s 누르면 엎는다(tip): swing_s 동안 틀이 바퀴 축을 중심으로 올라가 코와 바퀴로 선다(up) — 책은 바퀴 앞 heap_dx 에 더미로 쏟아지고, 바퀴가 발판 끝이면 틈으로(잃는다, 돌아올 때까지).
## 디딤(land): 바퀴로 선 수레의 통 윗면(tray_h — 미는 중엔 아니다), 세운 수레의 손잡이 끝(wheel_r + length — 탑에서 손으로 세운 가장 높은 것, step_w 폭), 책 더미(heap_h). 세운 수레 곁(바퀴 HW + wheel_r + reach)에서 C: 바로 세운다(right_s, busy); 그 back_s 뒤 더미 곁에 아무도 없으면 책이 통으로 돌아온다(잃은 것도).
## 통·손잡이에 올라선 것을 탑의 하루(day_s)에 한 번 센다(land 는 플레이어만 온다); 쉼터 판이 note(n) 으로 읽는다: 'Returns barrows, floors 10–14: 1 of 1 stood on today, 2 tipped out today, 5 pushes today.'
## 손잡이 뒤에서 C 를 누르지 않는 몸에겐 아무것도 바뀌지 않는다: a 를 달려 지나는 길, 틈을 건너는 맨 점프, 바퀴 곁·앞의 C 는 그대로(평이한 결과 100%). 값도 없다. 자세는 barrow(stick3d_barrow.gd — 운영자 보드의 '외바퀴 손수레' 가족: 숙여 잡고 드는 몸, 상체를 밀어 넣고 다리로 미는 몸, 팔을 올리며 뒷다리를 버티는 엎기, 손을 놓으며 팔이 튀는 몸 — 정지화가 아니다).
## lug(안아 옮긴다)·shunt(서가를 민다)·log(발밑이 구른다)와 다르다: 이건 바퀴 달린 것을 밀어 놓고 뒤집어 세우는 첫 것 — 세운 자리가 디딤이 된다. 주민 반쪽(반납 담당)은 다음 run 의 것.
## 로더가 할 일(climb.gd, 운영자 세션): `var cw := ClimbBarrow.new(); add_child(cw); signs.notes.append(cw.note)`; 층을 지을 때 `var lp := cl.plan(n, plats); var dp := cd.plan(n, plats); var bp := cs.plan(n, plats, lp + dp); var np := pn.plan(n, plats, lp + dp + bp); var sp := sc.plan(n, plats, lp + dp + bp + np); cw.build(root, cw.plan(n, plats, lp + dp + bp + np + sp + cc.plan(n, plats, lp + dp + bp + np + sp)))`
## (사다리·덤웨이터·서가·파터노스터·두루마리 선반·카드 목록함의 계획을 taken 으로 — 그 발판은 비켜 간다); 매 틱 `cw.sync(_t)`; `_physics_process` 에서 jump_held 를 읽은 뒤, 발판 위든 공중이든:
## `var bw := cw.step(on, x, z, face, not locked and Input.is_action_just_pressed("act"), not locked and Input.is_action_pressed("act"), dt, fig); if bw["busy"]: dir = 0.0; jump_held = false; charge = 0.0 elif bw["push"]: dir *= cw.slow_of(fig); jump_held = false; charge = 0.0`
## `if bw["busy"] or bw["push"]: fig.pose_request = "barrow" elif fig.pose_request == "barrow": fig.pose_request = ""` (step 이 매 틱 와야 한다 — HELD_T 동안 안 오면 미는 몸이 사라진 것이라 손을 놓는다);
## 로더 자신의 착지 판정이 비면 `landed = cw.land(x, y, ny, z)` (kind "barrow" — 통 윗면·손잡이 끝·책 더미; 로더의 떠남 판정은 x·w·z·d 로 그대로 된다 — 디딤이 된 수레는 안 움직인다). 쉼터 판 C 는 signs.tick 이 먼저.
## step 의 tally: 비우면 플레이어(판에 세고, C 가 없어도 수레·더미 곁 NEAR 안에 선 틱을 near_t 에 적는다 — 책이 그 발밑에서 돌아가지 않는다), 다른 몸은 거짓을 준다. 단위는 climb.gd 와 같은 px(36px = 1m, +y 위). 점검은 tools/probe_barrow.gd

const PACK := "res://data/climb/barrow.json"
const C = preload("res://scripts/games/climb.gd")
const BAND_LO := 20.0      # taken 조각이 이 발판의 것인가: y 가 발판 − BAND_LO 부터 + BAND_HI 앞까지(run 152 의 띠 규칙)
const BAND_HI := 60.0
const BODY_UP := 50.0      # 세운 손잡이 위에 선 몸의 키(px)
const SIDE := 10.0         # 수레 상자의 x 여유(px) — 손 하나
const HELD_T := 0.25       # 이만큼 step 이 안 오면 미는 몸이 사라진 것 — 손을 놓는다
const AHEAD := 3.0         # 손잡이 끝은 손 앞 HW + AHEAD(px)
const SLACK := 8.0         # 바퀴가 끝에 선 뒤 몸이 이만큼 더 가면 손을 놓는다(px)
const NEAR := 60.0         # 플레이어가 수레·더미 곁 이 안에 선 틱을 near_t 에 적는다(px)
const LOSE_S := 0.5        # 틈으로 떨어지는 책이 사라지기까지(s)
const SOUND_N := 3

var pack: Dictionary = {}
var kind: Dictionary = {}       # kinds.barrow
var barrows: Array = []         # 지은 수레 {id, kind "barrow", n, a_id, a_x, a_w, a_y, b_id, dy, dir, px, x, w, y, y_top, z, d, node, body, piv, wheel, bx, swing, up, sw, sw_t0, holder, step_t, last_x, hold_t, was_held, books [Node3D], heap [Node3D], heap_x, lost [{node, t0}], lost_n, righted_t, near_t, me_t, day, stands, tips, pushes, tip_day, day_tips, push_day, day_pushes, roll, squeak, clunk, slither}
var t := 0.0                    # 로더의 _t 와 같이 간다(sync)

func _ready() -> void:
	var f := FileAccess.open(PACK, FileAccess.READ)
	if f: pack = JSON.parse_string(f.get_as_text()) as Dictionary
	kind = (pack.get("kinds", {}) as Dictionary).get("barrow", {})

func sync(now: float) -> void:
	t = now

func min_w() -> float:
	return maxf(length() + 4.0 * C.HW, float(kind.get("min_w", 140.0)))
func park_in() -> float:
	return maxf(length() / 2.0, float(kind.get("park_in", 30.0)))
func reach() -> float:
	return maxf(0.0, float(kind.get("reach", 14.0)))
func length() -> float:
	return maxf(16.0, float(kind.get("len", 44.0)))
func tray_w() -> float:
	return clampf(float(kind.get("tray_w", 24.0)), 2.0 * C.HW, length() - wheel_r())
func tray_h() -> float:
	return maxf(4.0, float(kind.get("tray_h", 30.0)))
func tray_d() -> float:
	return maxf(2.0, float(kind.get("tray_d", 20.0)))
func wheel_r() -> float:
	return maxf(2.0, float(kind.get("wheel_r", 7.0)))
func books() -> int:
	return maxi(1, int(kind.get("books", 4)))
func step_w() -> float:
	return maxf(2.0 * C.HW, float(kind.get("step_w", 20.0)))
func heap_dx() -> float:
	return maxf(0.0, float(kind.get("heap_dx", 22.0)))
func heap_w() -> float:
	return maxf(2.0 * C.HW, float(kind.get("heap_w", 30.0)))
func heap_h() -> float:
	return maxf(2.0, float(kind.get("heap_h", 14.0)))
func grip_s() -> float:
	return maxf(0.05, float(kind.get("grip_s", 0.4)))
func set_s() -> float:
	return maxf(0.05, float(kind.get("set_s", 0.3)))
func tip_s() -> float:
	return maxf(0.05, float(kind.get("tip_s", 0.5)))
func swing_s() -> float:
	return maxf(0.05, float(kind.get("swing_s", 0.6)))
func drop_s() -> float:
	return maxf(0.05, float(kind.get("drop_s", 0.3)))
func right_s() -> float:
	return maxf(0.05, float(kind.get("right_s", 0.5)))
func back_s() -> float:
	return maxf(0.5, float(kind.get("back_s", 8.0)))
func slow() -> float:
	return clampf(float(kind.get("slow", 0.6)), 0.1, 1.0)
func slow_empty() -> float:
	return clampf(float(kind.get("slow_empty", 0.85)), slow(), 1.0)
func day_s() -> float:
	return maxf(1.0, float(kind.get("day_s", 600.0)))

## 탑의 오늘 — 로더의 시계를 day_s 로 나눈 몫
func day() -> int:
	return floori(t / day_s())

## 세운 수레의 손잡이 끝 높이(px, 발판 위) — 바퀴 축 + 틀 길이
func up_h() -> float:
	return wheel_r() + length()

## 이 몸이 미는 수레의 걸음 몫 — 통이 비면 가볍다; 안 밀면 1
func slow_of(fig: Stick3D) -> float:
	var s := _held_by(fig)
	if s.is_empty(): return 1.0
	return slow() if (s["books"] as Array).size() > 0 else slow_empty()

## 층 n(테마 층)의 still 발판 a(조각의 on, min_w 이상) 가운데 다음 발판 b 가 가장 높이 오르고 수레의 상자를 다른 발판이 가르지 않고 taken 조각이 발판에 닿지 않는 것 하나. 같은 층·같은 taken 은 늘 같은 답
func plan(n: int, plats: Array, taken: Array = []) -> Array:
	var out: Array = []
	if not (String(C.theme(n)[0]) in (pack.get("themes", []) as Array)): return out
	for pv in (pack.get("pieces", []) as Array):
		var piece: Dictionary = pv
		var kinds: Array = piece.get("on", ["std"])
		var hops: Array = plats.filter(func(p: Dictionary) -> bool: return not (String(p["kind"]) in ["rest", "short", "ledge"]))
		var found: Array = []
		for i in range(1, hops.size()):
			var a: Dictionary = hops[i - 1]; var b: Dictionary = hops[i]   # a 가 아래 발판(band() 는 오르는 순서로 쌓는다)
			if not (String(a["kind"]) in kinds): continue
			var ax := float(a["x"]); var aw := float(a["w"]); var ay := float(a["y"])
			if aw < min_w(): continue
			var dy := float(b["y"]) - ay
			if dy <= 0.0: continue
			var dir := 1.0 if float(b["x"]) + float(b["w"]) / 2.0 >= ax + aw / 2.0 else -1.0   # a 에서 b 쪽 — 바퀴가 향하는 쪽
			var px := ax + park_in() if dir > 0.0 else ax + aw - park_in()   # 수레 가운데 — 틈 반대쪽 끝, 뜀길을 안 막는다
			var lo := ax - SIDE; var hi := ax + aw + SIDE   # 수레는 발판 어디에나 간다
			var ylo := ay - 10.0; var yhi := ay + up_h() + BODY_UP
			if not _clear(plats, a, lo, hi, ylo, yhi): continue
			if not _free(taken, lo, hi, ay - BAND_LO, ay + BAND_HI): continue
			found.append({ "a_id": String(a["id"]), "a_x": ax, "a_w": aw, "a_y": ay, "b_id": String(b["id"]), "dy": dy, "dir": dir, "px": px, "x": px - length() / 2.0 - SIDE, "w": length() + 2.0 * SIDE })
		found.sort_custom(func(p: Dictionary, q: Dictionary) -> bool: return float(p["dy"]) > float(q["dy"]) if float(p["dy"]) != float(q["dy"]) else float(p["a_y"]) < float(q["a_y"]))
		for i in range(0, mini(int(piece.get("max", 1)), found.size())):
			var g: Dictionary = found[i]
			var s: Dictionary = g.duplicate(true)
			s["id"] = "%d.W%d" % [n, i]; s["kind"] = "barrow"; s["n"] = n
			s["y"] = float(g["a_y"]); s["y_top"] = float(g["a_y"]) + up_h()   # 다른 팩의 _free 가 읽는 키 — 세운 손잡이까지
			s["z"] = C.PLAYER_Z; s["d"] = tray_d()
			out.append(s)
	return out

## 수레의 상자(x 폭, a 윗면 조금 밑..세운 손잡이 위 선 몸)에 a 말고 다른 발판이 걸리지 않나 — 움직이는 발판은 진폭째
static func _clear(plats: Array, a: Dictionary, x0: float, x1: float, ylo: float, yhi: float) -> bool:
	for pv in plats:
		var p: Dictionary = pv
		if p["id"] == a["id"]: continue
		var py := float(p["y"])
		if py < ylo or py > yhi: continue
		var amp := float(p.get("amp", 0.0))
		var px0 := float(p["x"]) - amp - 10.0; var px1 := float(p["x"]) + float(p["w"]) + amp + 10.0
		if x1 > px0 and x0 < px1: return false
	return true

## 다른 팩의 조각(taken: x·w·y, 있으면 len·y_top)이 발판에 닿지 않나 — 조각의 몸은 y − BAND_LO 부터 y + BAND_HI(제 꼭대기 len·y_top 가 더 높으면 거기 + 10)까지
static func _free(taken: Array, x0: float, x1: float, ylo: float, yhi: float) -> bool:
	for tv in taken:
		var q: Dictionary = tv
		var qx0 := float(q.get("x", 0.0)) - 10.0; var qx1 := float(q.get("x", 0.0)) + float(q.get("w", 0.0)) + 10.0
		var qy := float(q.get("y", 0.0)); var qy0 := qy - BAND_LO; var qy1 := qy + BAND_HI
		if q.has("len"): qy1 = maxf(qy1, qy + float(q["len"]) + 10.0)
		if q.has("y_top"): qy1 = maxf(qy1, float(q["y_top"]) + 10.0)
		if x1 > qx0 and x0 < qx1 and yhi > qy0 and ylo < qy1: return false
	return true

## 수레의 디딤들 — {id, x, y, w}: 바퀴로 선 수레의 통(미는 중·엎는 중은 아니다), 세운 수레의 손잡이 끝, 책 더미
func steps_of(s: Dictionary) -> Array:
	var out: Array = []
	var bx := float(s["bx"]); var dir := float(s["dir"]); var ay := float(s["a_y"])
	if bool(s["up"]) and float(s["swing"]) >= 1.0:
		out.append({ "id": "%s.h" % String(s["id"]), "x": bx + dir * (length() / 2.0 - wheel_r()) - step_w() / 2.0, "y": ay + up_h(), "w": step_w() })
	elif not bool(s["up"]) and String(s["sw"]) in ["", "drop"]:
		out.append({ "id": "%s.t" % String(s["id"]), "x": _tray_cx(s) - tray_w() / 2.0, "y": ay + tray_h(), "w": tray_w() })
	if (s["heap"] as Array).size() > 0:
		out.append({ "id": "%s.b" % String(s["id"]), "x": float(s["heap_x"]) - heap_w() / 2.0, "y": ay + heap_h(), "w": heap_w() })
	return out

## 로더 자신의 착지 판정이 빈 뒤 — 떨어지는 몸이 디딤을 지나면 올라선다: {kind "barrow", id, x, y, w, z, d}. 아니면 빈 사전. 통·손잡이에 올라서면 오늘을 센다(플레이어만 여기 온다)
func land(x: float, y: float, ny: float, z: float) -> Dictionary:
	if absf(z - C.PLAYER_Z) >= tray_d() / 2.0 + C.HZ: return {}
	for sv in barrows:
		var s: Dictionary = sv
		for kv in steps_of(s):
			var k: Dictionary = kv
			var top := float(k["y"])
			if y < top or ny > top: continue
			var kx := float(k["x"]); var kw := float(k["w"])
			if x + C.HW <= kx or x - C.HW >= kx + kw: continue
			if not String(k["id"]).ends_with(".b"):
				s["stands"] = int(s["stands"]) + 1
				if int(s["day"]) != day(): s["day"] = day(); s["me_t"] = t
			return { "kind": "barrow", "id": String(k["id"]), "x": kx, "y": top, "w": kw, "z": C.PLAYER_Z, "d": tray_d() }
	return {}

## 매 틱 — {busy, push}: 미는 수레가 있으면 그 틱(_push), 없으면 C 가 막 눌리고 a 위에 서서 손잡이 뒤면 잡고(busy), 세운 수레 곁이면 바로 세운다(busy). 아무것도 아니면 둘 다 거짓
func step(on: Dictionary, x: float, z: float, face: float, pressed: bool, held: bool, dt: float, fig: Stick3D = null, tally := true) -> Dictionary:
	if fig == null: return { "busy": false, "push": false }
	var mine := _held_by(fig)
	if not mine.is_empty(): return _push(mine, on, x, face, pressed, held, dt)
	if on.is_empty() or absf(z - C.PLAYER_Z) >= C.HZ + 4.0: return { "busy": false, "push": false }
	var here := _here(on)
	if here.is_empty() or fig.torso == null: return { "busy": false, "push": false }
	if tally and _near(here, x): here["near_t"] = t   # 플레이어가 수레·더미 곁에 선 틱(C 없이도)
	if not pressed or String(here["sw"]) != "" or String(on.get("id", "")) != String(here["a_id"]): return { "busy": false, "push": false }
	if bool(here["up"]):
		if absf(x - _wheel_x(here)) > C.HW + wheel_r() + reach(): return { "busy": false, "push": false }
		_begin(here, "right", x, fig, tally); _metas(here, 1.0, 0.0, 1.0, 0.0)
		return { "busy": true, "push": false }
	var hx := _handle_x(here)
	if absf(x - hx) > C.HW + reach() or (x - float(here["bx"])) * float(here["dir"]) > 0.0: return { "busy": false, "push": false }   # 손잡이 쪽에서만
	_begin(here, "grip", x, fig, tally); _metas(here, 0.0, 0.0, 0.0, 0.0)
	if tally:
		if int(here["push_day"]) != day(): here["push_day"] = day(); here["day_pushes"] = 0
		here["day_pushes"] = int(here["day_pushes"]) + 1
	here["pushes"] = int(here["pushes"]) + 1
	return { "busy": true, "push": false }

func _begin(s: Dictionary, sw: String, x: float, fig: Stick3D, tally: bool) -> void:
	s["holder"] = fig; s["sw"] = sw; s["sw_t0"] = t; s["step_t"] = t; s["last_x"] = x; s["hold_t"] = 0.0; s["was_held"] = true; s["count"] = tally

## 미는 몸의 틱 — 잡기(grip)·밀기(push: 끝에 서고, 떠나면 놓고, C 로 내려놓거나 엎는다)·내려놓기(set)·엎기(tip)·놓기(drop)·세우기(right)
func _push(s: Dictionary, on: Dictionary, x: float, face: float, pressed: bool, held: bool, dt: float) -> Dictionary:
	s["step_t"] = t
	var u := t - float(s["sw_t0"])
	var dir := float(s["dir"])
	match String(s["sw"]):
		"grip":
			_metas(s, clampf(u / grip_s(), 0.0, 1.0), 0.0, 0.0, 0.0)
			if u >= grip_s(): s["sw"] = "push"; s["sw_t0"] = t; s["last_x"] = x; return { "busy": false, "push": true }
			return { "busy": true, "push": false }
		"push":
			var gone := on.is_empty() or String(on.get("id", "")) != String(s["a_id"]) or (face >= 0.0) != (dir > 0.0)   # 발판을 떠났거나 등을 돌렸다
			var want := x + dir * (C.HW + AHEAD + length() / 2.0)
			var bx := _clamp_x(s, want)
			if absf(want - bx) > SLACK: gone = true   # 끝에 선 수레를 두고 더 갔다
			if gone: _drop(s); return { "busy": false, "push": true }
			var moved := bx - float(s["bx"])
			s["bx"] = bx; _place(s)
			if absf(moved) > 0.001: _roll(s, moved)
			var v := clampf(absf(x - float(s["last_x"])) / dt / (C.WALK * slow()), 0.0, 1.0) if dt > 0.0 else 0.0
			s["last_x"] = x
			if held and v < 0.05: s["hold_t"] = float(s["hold_t"]) + dt
			elif not held: s["hold_t"] = 0.0
			if held and float(s["hold_t"]) >= tip_s(): s["sw"] = "tip"; s["sw_t0"] = t; _metas(s, 1.0, 0.0, 0.0, 0.0); return { "busy": true, "push": false }
			if not held and bool(s["was_held"]) and not pressed and u > 0.05: s["sw"] = "set"; s["sw_t0"] = t; _metas(s, 1.0, 0.0, 0.0, 0.0); return { "busy": true, "push": false }
			s["was_held"] = held
			_metas(s, 1.0, v, 0.0, 0.0)
			return { "busy": false, "push": true }
		"set":
			_metas(s, 1.0 - clampf(u / set_s(), 0.0, 1.0), 0.0, 0.0, 0.0)
			if u >= set_s(): _play(s["clunk"] as AudioStreamPlayer3D); _release(s); return { "busy": false, "push": false }
			return { "busy": true, "push": false }
		"tip":
			var k1 := clampf(u / swing_s(), 0.0, 1.0)
			s["swing"] = k1; _place(s); _metas(s, 1.0, 0.0, k1, 0.0)
			if u >= swing_s(): s["up"] = true; _spill(s); s["sw"] = "drop"; s["sw_t0"] = t; return { "busy": false, "push": true }
			return { "busy": true, "push": false }
		"drop":
			_metas(s, 1.0, 0.0, 1.0 if bool(s["up"]) else 0.0, clampf(u / drop_s(), 0.0, 1.0))
			if u >= drop_s(): _release(s); return { "busy": false, "push": false }
			return { "busy": false, "push": true }
		"right":
			var k2 := 1.0 - clampf(u / right_s(), 0.0, 1.0)
			s["swing"] = k2; _place(s); _metas(s, 1.0, 0.0, k2, 0.0)
			if u >= right_s(): s["up"] = false; s["righted_t"] = t; _play(s["clunk"] as AudioStreamPlayer3D); _release(s); return { "busy": false, "push": false }
			return { "busy": true, "push": false }
	return { "busy": false, "push": false }

## 선 발판(on)이 어느 수레의 a 또는 그 디딤인가 — 아니면 빈 사전
func _here(on: Dictionary) -> Dictionary:
	var oid := String(on.get("id", ""))
	for sv in barrows:
		var s: Dictionary = sv
		if oid == String(s["a_id"]) or oid.begins_with(String(s["id"]) + "."): return s
	return {}

## 이 몸이 미는(잡기·밀기·내려놓기·엎기·놓기·세우기 중) 수레 — 아니면 빈 사전
func _held_by(fig: Stick3D) -> Dictionary:
	for sv in barrows:
		var s: Dictionary = sv
		if String(s["sw"]) != "" and is_instance_valid(s["holder"]) and (s["holder"] as Stick3D) == fig: return s   # 사라진 몸은 as 전에 거른다
	return {}

## 이 몸이 수레를 잡고 있나(잡기·밀기·내려놓기·엎기·놓기·세우기)
func pushing(fig: Stick3D) -> bool:
	return not _held_by(fig).is_empty()

func _handle_x(s: Dictionary) -> float:
	return float(s["bx"]) - float(s["dir"]) * length() / 2.0

func _wheel_x(s: Dictionary) -> float:
	return float(s["bx"]) + float(s["dir"]) * length() / 2.0

func _tray_cx(s: Dictionary) -> float:
	return float(s["bx"]) + float(s["dir"]) * 4.0

## 바퀴가 발판 끝을 넘지 않는 수레 가운데
func _clamp_x(s: Dictionary, bx: float) -> float:
	var ax := float(s["a_x"]); var aw := float(s["a_w"])
	if float(s["dir"]) > 0.0: return minf(bx, ax + aw - length() / 2.0)
	return maxf(bx, ax + length() / 2.0)

## x 가 수레나 더미의 NEAR 안인가
func _near(s: Dictionary, x: float) -> bool:
	if absf(x - float(s["bx"])) <= NEAR: return true
	return (s["heap"] as Array).size() > 0 and absf(x - float(s["heap_x"])) <= NEAR

## 바퀴가 moved 만큼 굴렀다 — 사분의 한 바퀴마다 삐걱
func _roll(s: Dictionary, moved: float) -> void:
	var before := floori(float(s["roll"]) / (TAU / 4.0))
	s["roll"] = float(s["roll"]) + moved / wheel_r()
	(s["wheel"] as Node3D).rotation.z = -float(s["roll"])
	if floori(float(s["roll"]) / (TAU / 4.0)) != before: _play(s["squeak"] as AudioStreamPlayer3D)

## 손을 놓는다(발판을 떠났다·등을 돌렸다·끝을 두고 갔다·몸이 사라졌다) — drop_s 동안 팔이 튀어 오른다, 수레는 그 자리
func _drop(s: Dictionary) -> void:
	s["sw"] = "drop"; s["sw_t0"] = t; _play(s["clunk"] as AudioStreamPlayer3D)

## 책이 통에서 쏟아진다 — 바퀴 앞 heap_dx 에 더미로; 더미가 발판 밖이면 틈으로(잃는다)
func _spill(s: Dictionary) -> void:
	var bks: Array = s["books"]
	if bks.is_empty(): return
	var hx := _wheel_x(s) + float(s["dir"]) * heap_dx()
	var node := s["node"] as Node3D
	var on_hop := hx - heap_w() / 2.0 >= float(s["a_x"]) and hx + heap_w() / 2.0 <= float(s["a_x"]) + float(s["a_w"])
	for i in bks.size():
		var nd := bks[i] as Node3D
		_reparent(nd, node, Vector3.ZERO)
		if on_hop:
			(s["heap"] as Array).append(nd)
			nd.position = Vector3((hx - float(s["px"]) + (float(i) - float(bks.size() - 1) / 2.0) * 5.0) * C.K, (heap_h() * (0.35 + 0.5 * float(i % 2))) * C.K, (float(i % 3) - 1.0) * 0.08)
			nd.rotation = Vector3(0.0, 0.0, 0.35 * (1.0 if i % 2 == 0 else -1.0) + 0.1 * float(i))
		else:
			(s["lost"] as Array).append({ "node": nd, "t0": t, "from": Vector3((hx - float(s["px"])) * C.K, (heap_h() + 8.0 * float(i)) * C.K, 0.0) })
	s["heap_x"] = hx if on_hop else 0.0
	s["lost_n"] = int(s["lost_n"]) + (0 if on_hop else bks.size())
	s["books"] = []
	s["tips"] = int(s["tips"]) + 1
	if int(s["tip_day"]) != day(): s["tip_day"] = day(); s["day_tips"] = 0
	s["day_tips"] = int(s["day_tips"]) + 1
	_play(s["slither"] as AudioStreamPlayer3D)

## 책이 통으로 돌아온다(세운 뒤 back_s, 더미 곁에 아무도 없을 때) — 더미와 잃은 것 모두
func _restock(s: Dictionary) -> void:
	var bks: Array = s["books"]
	for hv in (s["heap"] as Array): bks.append(hv)
	for lv in (s["lost"] as Array):
		var l: Dictionary = lv
		var nd: Node3D = l["node"]
		if not is_instance_valid(nd): nd = _book(s["node"] as Node3D, bks.size())
		nd.visible = true; bks.append(nd)
	s["heap"] = []; s["lost"] = []; s["lost_n"] = 0
	for i in bks.size(): _reparent(bks[i] as Node3D, s["tray"] as Node3D, _book_at(i)); (bks[i] as Node3D).rotation = Vector3(0.0, 0.0, 0.06 * (float(i) - 1.5))
	_play(s["slither"] as AudioStreamPlayer3D)

## 자세의 메타 — bar_t 잡은 몫 0..1, bar_v 미는 속도 0..1, bar_k 엎은 몫 0..1, bar_x 놓는 몫 0..1
func _metas(s: Dictionary, bt: float, v: float, k: float, x: float) -> void:
	if not is_instance_valid(s["holder"]): return
	var fig := s["holder"] as Stick3D
	fig.set_meta("bar_t", bt); fig.set_meta("bar_v", v); fig.set_meta("bar_k", k); fig.set_meta("bar_x", x)

## 수레에서 떠난 몸 — 자세의 메타를 거둔다
func leave(fig: Stick3D) -> void:
	if fig == null or not is_instance_valid(fig): return
	for key: String in ["bar_t", "bar_v", "bar_k", "bar_x"]:
		if fig.has_meta(key): fig.remove_meta(key)

func _release(s: Dictionary) -> void:
	if is_instance_valid(s["holder"]): leave(s["holder"] as Stick3D)
	s["holder"] = null; s["sw"] = ""; s["hold_t"] = 0.0

## 수레를 제자리에 — 몸은 가운데 bx 에, 틀은 바퀴 축을 중심으로 swing 만큼 세워진다
func _place(s: Dictionary) -> void:
	(s["body"] as Node3D).position.x = (float(s["bx"]) - float(s["px"])) * C.K
	(s["piv"] as Node3D).rotation.z = -float(s["dir"]) * (PI / 2.0) * float(s["swing"])

static func _reparent(nd: Node3D, to: Node3D, at: Vector3) -> void:
	var p := nd.get_parent()
	if p != null: p.remove_child(nd)
	to.add_child(nd); nd.position = at; nd.rotation = Vector3.ZERO

## n0..n1 층의 수레에서 오늘 올라선 수·전체·오늘 엎은 수·오늘 민 수 — {stood, total, tips, pushes}
func top_today(n0: int, n1: int) -> Dictionary:
	var stood := 0; var total := 0; var tips := 0; var pushes := 0
	for sv in barrows:
		var s: Dictionary = sv
		if int(s["n"]) < n0 or int(s["n"]) > n1: continue
		total += 1
		if int(s["day"]) == day(): stood += 1
		if int(s["tip_day"]) == day(): tips += int(s["day_tips"])
		if int(s["push_day"]) == day(): pushes += int(s["day_pushes"])
	return { "stood": stood, "total": total, "tips": tips, "pushes": pushes }

## 쉼터 판(n 층)에 붙는 줄 — 위 다섯 층(n..n+4)의 수레, 없으면 아래 다섯 층(n−5..n−1), 그것도 없으면 빈 줄. climb_signs.notes 에 넣는다
func note(n: int) -> String:
	for span: Array in [[n, n + 4], [n - 5, n - 1]]:
		var v := top_today(int(span[0]), int(span[1]))
		if int(v["total"]) > 0:
			return "Returns barrows, floors %d–%d: %d of %d stood on today, %d tipped out today, %d %s today." % [int(span[0]), int(span[1]), int(v["stood"]), int(v["total"]), int(v["tips"]), int(v["pushes"]), "push" if int(v["pushes"]) == 1 else "pushes"]
	return ""

func _play(p: AudioStreamPlayer3D) -> void:
	if p.playing: p.stop()
	p.play()

## 사라진 몸·떨어지는 책·돌아오는 책 — 미는 몸이 HELD_T 동안 step 을 안 주면(탑을 나갔다) 손을 놓은 것; 틈으로 간 책은 LOSE_S 떨어지다 숨는다; 세운 지 back_s 가 지나고 더미 곁에 아무도 없으면 책이 통으로
func _process(delta: float) -> void:
	t += delta
	barrows = barrows.filter(func(s: Dictionary) -> bool: return is_instance_valid(s["node"]))   # 지운 층의 것은 뺀다(climb_bellows 와 같은 식)
	for sv in barrows:
		var s: Dictionary = sv
		if String(s["sw"]) != "" and (not is_instance_valid(s["holder"]) or t - float(s["step_t"]) > HELD_T):
			if String(s["sw"]) == "tip": s["swing"] = 1.0; s["up"] = true; _place(s); _spill(s)
			elif String(s["sw"]) == "right": s["swing"] = 0.0; s["up"] = false; s["righted_t"] = t; _place(s)
			_release(s)
		for lv in (s["lost"] as Array):
			var l: Dictionary = lv
			var nd: Node3D = l["node"]
			if not is_instance_valid(nd): continue
			var k := clampf((t - float(l["t0"])) / LOSE_S, 0.0, 1.0)
			var from: Vector3 = l["from"]
			nd.position = from + Vector3(float(s["dir"]) * 0.3 * k, -2.0 * k * k, 0.0); nd.rotation.z = TAU * k
			if k >= 1.0: nd.visible = false   # 틈 밑으로 사라진다 — 노드는 두고 숨긴다(돌아올 때 같은 책)
		if not bool(s["up"]) and String(s["sw"]) == "" and (s["books"] as Array).size() < books() and float(s["righted_t"]) >= 0.0 and t - float(s["righted_t"]) >= back_s() and t - float(s["near_t"]) > 1.0:
			_restock(s); s["righted_t"] = -1.0

## 수레를 짓는다 — root 는 그 층의 노드. 노드 원점은 (주차 자리 px, a 윗면, PLAYER_Z); RETURNS 자국, 수레 몸(바퀴 축의 피벗 아래 틀: 통·다리 둘·손잡이 둘, 바퀴, 책 books 권), 소리 셋
func build(root: Node3D, planned: Array) -> void:
	for sv in planned:
		var s: Dictionary = (sv as Dictionary).duplicate(true)
		var node := Node3D.new(); node.position = C.to3(float(s["px"]), float(s["a_y"]), C.PLAYER_Z * C.K); root.add_child(node)
		var dir := float(s["dir"])
		var mark := _box(node, Vector3((length() + 10.0) * C.K, 0.01, (tray_d() + 10.0) * C.K), _mat(Color("efe9e2")))   # RETURNS 자국 — 주차 자리
		mark.position = Vector3(0.0, 0.005, 0.0)
		_box(node, Vector3(0.16, 0.012, 0.06), _mat(Color("ad7096"))).position = Vector3(0.0, 0.012, 0.0)   # 자국의 스텐실(강조색은 이 한 조각)
		var body := Node3D.new(); node.add_child(body)
		var piv := Node3D.new(); piv.position = Vector3(dir * length() / 2.0 * C.K, wheel_r() * C.K, 0.0); body.add_child(piv)   # 바퀴 축 — 엎을 때 이걸 중심으로 돈다
		var frame := Node3D.new(); frame.position = Vector3(-dir * length() / 2.0 * C.K, -wheel_r() * C.K, 0.0); piv.add_child(frame)   # 틀의 원점은 수레 가운데·발판 윗면
		var wood := _mat(Color("c9a07a")); var dark := _mat(Color("6b4a35")); var iron := _mat(Color("1b0c15"))
		var tray := Node3D.new(); tray.position = Vector3(dir * 4.0 * C.K, 0.0, 0.0); frame.add_child(tray)
		_box(tray, Vector3(tray_w() * C.K, (tray_h() - 8.0) * C.K, tray_d() * C.K), wood).position = Vector3(0.0, (8.0 + (tray_h() - 8.0) / 2.0) * C.K, 0.0)   # 통
		for sd: float in [-1.0, 1.0]:
			_box(frame, Vector3(0.03, 8.0 * C.K, 0.03), dark).position = Vector3(-dir * (length() / 2.0 - 6.0) * C.K, 4.0 * C.K, sd * (tray_d() / 2.0 - 2.0) * C.K)   # 다리 둘(손잡이 쪽)
			var hb := _box(frame, Vector3((length() / 2.0 + 6.0) * C.K, 0.025, 0.025), dark)   # 손잡이 둘 — 통 뒤에서 손잡이 끝까지, 뒤가 조금 들린다
			hb.position = Vector3(-dir * (length() / 4.0 - 2.0) * C.K, 12.0 * C.K, sd * (tray_d() / 2.0 - 1.0) * C.K); hb.rotation.z = -dir * 0.12
			_box(frame, Vector3(0.02, 0.05, 0.02), iron).position = Vector3(-dir * (length() / 2.0 - 1.0) * C.K, 14.0 * C.K, sd * (tray_d() / 2.0 - 1.0) * C.K)   # 손잡이 끝의 쇠 — 손이 잡는 자리
		var wheel := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = wheel_r() * C.K; cm.bottom_radius = wheel_r() * C.K; cm.height = 0.06
		wheel.mesh = cm; wheel.material_override = iron; wheel.rotation.x = PI / 2.0; wheel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var hub := Node3D.new(); piv.add_child(hub); hub.add_child(wheel)   # 바퀴는 축에 — 굴러도 틀과 함께 선다
		var bks: Array = []
		for i in books(): bks.append(_book(tray, i)); (bks[i] as Node3D).position = _book_at(i); (bks[i] as Node3D).rotation = Vector3(0.0, 0.0, 0.06 * (float(i) - 1.5))
		s["node"] = node; s["body"] = body; s["piv"] = piv; s["tray"] = tray; s["wheel"] = hub
		s["bx"] = float(s["px"]); s["swing"] = 0.0; s["up"] = false; s["roll"] = 0.0
		s["sw"] = ""; s["sw_t0"] = -99.0; s["holder"] = null; s["step_t"] = -99.0; s["last_x"] = 0.0; s["hold_t"] = 0.0; s["was_held"] = false; s["count"] = true
		s["books"] = bks; s["heap"] = []; s["heap_x"] = 0.0; s["lost"] = []; s["lost_n"] = 0; s["righted_t"] = -1.0; s["near_t"] = -99.0; s["me_t"] = -99.0
		s["day"] = -1; s["stands"] = 0; s["tips"] = 0; s["pushes"] = 0; s["tip_day"] = -1; s["day_tips"] = 0; s["push_day"] = -1; s["day_pushes"] = 0
		s["squeak"] = _snd(node, float(kind.get("squeak_hz", 900)), 0.12, 14.0, -18.0); s["clunk"] = _snd(node, float(kind.get("clunk_hz", 120)), 0.2, 10.0, -12.0); s["slither"] = _snd(node, float(kind.get("slither_hz", 700)), 0.35, 5.0, -16.0)
		_place(s)
		barrows.append(s)

## 통 안 i 번째 책의 자리 — 통 바닥 위에 나란히 세워, 통 위로 조금 보인다
func _book_at(i: int) -> Vector3:
	return Vector3((float(i) - float(books() - 1) / 2.0) * 5.0 * C.K, (tray_h() - 5.0) * C.K, 0.0)

## 책 한 권 — 서재의 색(theme 의 셋)과 강조색이 번갈아 든다
func _book(parent: Node3D, i: int) -> Node3D:
	var cols: Array = [Color("6b4a35"), Color("efe9e2"), Color("ad7096"), Color("8a7f86")]
	var nd := Node3D.new(); parent.add_child(nd)
	_box(nd, Vector3(0.03, 0.2, 0.14), _mat(cols[i % cols.size()]))
	_box(nd, Vector3(0.034, 0.02, 0.12), _mat(Color("1b0c15"))).position = Vector3(0.0, 0.04, 0.0)   # 등의 띠
	return nd

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

## 소리 — 짧은 기음이 잦아든다: squeak(0.12초, 높게 — 바퀴의 사분의 한 바퀴)·clunk(0.2초, 낮게 — 다리가 발판에)·slither(0.35초 — 책이 쏟아진다). 한 번 재생, 반복 없음
static func _tick_wav(hz: float, secs: float, decay: float) -> AudioStreamWAV:
	var rate := 22050; var n := int(rate * secs)
	var data := PackedByteArray(); data.resize(n * 2)
	for i in n:
		var k := float(i) / n
		var ph := float(i) * hz * TAU / rate
		var v := (sin(ph) * 0.5 + sin(ph * 2.3) * 0.2 + sin(ph * 5.7) * 0.08) * exp(-k * decay)
		data.encode_s16(i * 2, int(v * 22000.0))
	var wav := AudioStreamWAV.new(); wav.format = AudioStreamWAV.FORMAT_16_BITS; wav.mix_rate = rate; wav.stereo = false; wav.data = data
	return wav
