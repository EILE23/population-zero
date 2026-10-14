class_name ClimbLens
extends Node3D
## Climb 콘텐츠 팩 '등대 렌즈'(운영자 2026-10-06 밤: "Climb는 컨텐츠 자체의 질과 양을 늘리는 거" — 팩은 data/climb/*.json 자료, 로더는 운영자 세션이 잇는다; climb.gd 는 CI 가 안 건드린다).
## 구름바다(Cloud sea) 층의 잇단 두 still 발판 사이 틈(90..220 px — 탑의 구름바다 틈은 93..124) — 틈 한가운데 절벽에 박힌 짧은 돌탑(tower_w × tower_h, 좁은 틈에선 그 1/4 폭, 꼭대기가 아래 발판 윗면 높이) 위의 놋쇠 렌즈 북, 그리고 틈의 1/4·1/2·3/4 자리에 걸린 구름 뭉치 셋(틈의 1/4 에서 손 하나 뺀 폭 puff_w_min..puff_w × puff_h, 위 발판 쪽으로 rise 씩 높아진다 — rise 는 높이차의 1/4 까지).
## 렌즈는 로더의 시계로 turn_s 마다 한 바퀴 돈다(누구에게나 같다): 앞 반 바퀴는 빛줄기가 틈 쪽을 쓴다 — 아래 발판에서 구름 셋을 지나 위 발판까지 — 뭉치 k 는 빛의 가운데가 반 바퀴의 k/4 에 닿고 lit_s 동안 머물며 지나간 뒤 glow_s 빛을 머금는다, 그래서 세 뭉치는 어두운 틈 없이 차례로 단단하다(보통 속도로 1.1..2.6, 2.6..4.1, 4.1..5.6초); 뒤 반 바퀴는 절벽을 쓸고 아무것도 켜지지 않는다.
## 뭉치는 켜진 동안만 발판이다(유령 판의 박자처럼) — 건너기는 때 맞춘 세 번의 뜀. 꺼지기 fade_s 전 선 몸은 기존 teeter 로 경고를 받고, 꺼질 때 아직 선 몸은 기존 lurch 로 떨어지며, 되켜질 땐 appear_s 에 굳고 종이 울린다.
## 아래 발판의 틈 쪽 가장자리 reach 안에서 C: 렌즈의 손바퀴를 돌린다(spin — 한 손이 허리 높이의 바퀴를 돌린다, 팔꿈치가 앞서고 어깨가 바퀴마다 꺼지며 다른 팔은 균형으로 벌린다; 예비, 네 바퀴, 느려지는 놓음): 렌즈가 fast_s 동안 fast_rate 배 빨리 돌아 빛이 두 배로 자주 오고 창은 반으로 짧다. 이미 빠른 동안의 C 는 아무것도 아니다(거절 대사 없음).
## 밀지도, 떨어뜨리지도, 거절하지도, 값을 받지도 않는다 — 틈을 건너는 맨 점프는 그대로다(뭉치는 직선 위에 걸렸고 꺼진 뭉치는 그냥 지나가며, 탑은 아래 발판 윗면 밑에 있어 뛰는 몸과 만나지 않는다).
## 유령 판(run 120 — 제 박자로 사라지는 판 하나)·뗏목(run 126 — 떠다니는 구름)과 다르다: 이건 빛이 차례로 켜 주는 계단, 그리고 플레이어가 손으로 시계를 빨리 돌리는 첫 조각. 자세는 spin(stick3d_spin.gd — 운영자 보드의 '손잡이 돌리기·윈치' 가족).
## 로더가 할 일(climb.gd, 운영자 세션): `var ln := ClimbLens.new(); add_child(ln)`; 층을 지을 때 `var tk := cr.plan(n, plats) + mu.plan(n, plats); var pp := cp.plan(n, plats, tk); var bp := ba.plan(n, plats, tk + pp); ln.build(root, ln.plan(n, plats, tk + pp + bp))` (뗏목·버섯·널·열기구의 계획을 taken 으로 — 한 틈을 둘이 안 나눈다); 매 틱 `ln.sync(_t)`;
## 발판에 선 가지에서 act 가 막 눌렸으면(`Input.is_action_just_pressed("act")`) `var r := ln.spin(on, x, z, true, fig); if r["spun"]: fig.pose_request = "spin"; _scene_until = now + SpinPoses.SPIN_T` (도는 동안 몸은 선 자리에), `SpinPoses.done(fig)` 면 자세를 비운다 (바퀴 밖에선 C 는 로더의 것 — 판 읽기·쉼터 문);
## 로더 자신의 착지 판정이 비고 vy <= 0 이면 `landed = ln.land(x, y, ny, z)` (kind "puff" — 켜진 뭉치의 윗면);
## 서 있을 때 `on["kind"] == "puff" and not ln.holds(on)` 이면 `on = {}; apex = y; fig.pose_request = "lurch"` (착지 뒤 `LurchPoses.done(fig)` 면 비운다); 서 있는 뭉치가 `ln.fading(on)` 이면 `fig.pose_request = "teeter"`, 아니면 비운다 — 유령 판과 같은 손.
## 단위는 climb.gd 와 같은 px(36px = 1m, +y 위). 점검은 tools/probe_lens.gd

const PACK := "res://data/climb/lens.json"
const C = preload("res://scripts/games/climb.gd")
const BAND_IN := 20.0      # taken 조각이 이 틈의 것인가: y 가 아래 발판 윗면 − BAND_IN 부터 위 발판 윗면 − BAND_IN 앞까지(탑은 지그재그라 모든 틈이 한 x 열에 쌓인다 — 목록함의 220 px 띠로는 뗏목 하나가 위의 모든 틈을 막는다)
const BODY_UP := 50.0      # 맨 위 뭉치에 선 몸의 키(px) — 상자 위쪽 여유
const TOWER_D := 18.0      # 돌탑의 깊이(px) — 절벽 면에 묻힌다
const WHEEL_R := 7.0       # 손바퀴(px)
const PUFF_K := 3          # 뭉치 수 — 틈의 1/4·1/2·3/4
const ALPHA_DIM := 0.18    # 꺼진 뭉치의 농도 — 어디 있는지는 보인다

var pack: Dictionary = {}
var kind: Dictionary = {}       # kinds.lens
var lenses: Array = []          # 지은 렌즈 {id, kind "lens", n, x, w, y, y_top, tx, tw, mid_x, hinge_x, dir, gap, rise, a_id, b_id, a_y, b_y, puffs [{id, k, x, y, w, z, d, lens, node, mats, chime, was}], spin_t0, boost, node, beam, beam_mat, drum, wheel, spin_snd}
var t := 0.0                    # 로더의 _t 와 같이 간다(sync)

func _ready() -> void:
	var f := FileAccess.open(PACK, FileAccess.READ)
	if f: pack = JSON.parse_string(f.get_as_text()) as Dictionary
	kind = (pack.get("kinds", {}) as Dictionary).get("lens", {})

func sync(now: float) -> void:
	t = now

func tower_w() -> float:
	return maxf(8.0, float(kind.get("tower_w", 36.0)))

func tower_h() -> float:
	return maxf(8.0, float(kind.get("tower_h", 60.0)))

func puff_w() -> float:
	return maxf(2.0 * C.HW, float(kind.get("puff_w", 34.0)))

func puff_w_min() -> float:
	return clampf(float(kind.get("puff_w_min", 18.0)), 4.0, puff_w())

## 틈에 맞춘 뭉치 폭 — 틈의 1/4 에서 손 하나를 뺀 것(puff_w_min..puff_w): 탑의 구름바다 틈은 93..124 px 라 대개 19..27
func puff_w_in(gap: float) -> float:
	return clampf(gap / 4.0 - 4.0, puff_w_min(), puff_w())

## 틈에 맞춘 돌탑 폭 — 좁은 틈에선 그 1/4
func tower_w_in(gap: float) -> float:
	return minf(tower_w(), gap / 4.0)

func puff_h() -> float:
	return maxf(4.0, float(kind.get("puff_h", 16.0)))

func rise() -> float:
	return maxf(4.0, float(kind.get("rise", 30.0)))

func turn_s() -> float:
	return maxf(1.0, float(kind.get("turn_s", 12.0)))

func lit_s() -> float:
	return maxf(0.1, float(kind.get("lit_s", 0.8)))

func glow_s() -> float:
	return maxf(0.0, float(kind.get("glow_s", 0.7)))

func fade_s() -> float:
	return maxf(0.0, float(kind.get("fade_s", 0.4)))

func appear_s() -> float:
	return maxf(0.01, float(kind.get("appear_s", 0.15)))

func reach() -> float:
	return maxf(0.0, float(kind.get("reach", 18.0)))

func fast_rate() -> float:
	return maxf(1.0, float(kind.get("fast_rate", 2.0)))

func fast_s() -> float:
	return maxf(0.0, float(kind.get("fast_s", 12.0)))

## 지금 도는 빠르기(배) — 돌린 뒤 fast_s 동안 fast_rate, 아니면 1
func rate_at(c: Dictionary, at: float) -> float:
	var s0 := float(c["spin_t0"])
	return fast_rate() if s0 >= 0.0 and at >= s0 and at < s0 + fast_s() else 1.0

## 렌즈의 시계(바퀴-초): 흐른 시간에 빨리 돈 만큼을 얹는다 — 지난 돌림들은 boost 에 접혀 있고 지금 돌림은 fast_s 까지만
func vt(c: Dictionary, at: float) -> float:
	var s0 := float(c["spin_t0"])
	var now := clampf(at - s0, 0.0, fast_s()) * (fast_rate() - 1.0) if s0 >= 0.0 else 0.0
	return at + float(c["boost"]) + now

## 한 바퀴 안의 자리(바퀴-초, 0..turn_s) — 앞 반이 틈 쪽
func half_at(c: Dictionary, at: float) -> float:
	return fposmod(vt(c, at), turn_s())

## 뭉치 k(1..3)의 창 [켜짐, 꺼짐) — 바퀴-초: 빛의 가운데가 반 바퀴의 k/4 에 닿기 lit_s/2 전부터 지나고 glow_s 뒤까지
func window(k: int) -> Array:
	var ck := turn_s() / 2.0 * float(k) / float(PUFF_K + 1)
	return [ck - lit_s() / 2.0, ck + lit_s() / 2.0 + glow_s()]

func lit(c: Dictionary, k: int, at: float) -> bool:
	var s := half_at(c, at); var w := window(k)
	return s >= float(w[0]) and s < float(w[1])

## 꺼지기까지 남은 진짜 초(꺼져 있으면 0) — 빨리 도는 동안은 그만큼 짧다
func left(c: Dictionary, k: int, at: float) -> float:
	if not lit(c, k, at): return 0.0
	return (float(window(k)[1]) - half_at(c, at)) / rate_at(c, at)

## 그림 농도 0..1: 켜질 때 appear_s 에 1 로, 끝 fade_s 동안 0 으로, 꺼져 있으면 0
func solidity(c: Dictionary, k: int, at: float) -> float:
	if not lit(c, k, at): return 0.0
	var since := (half_at(c, at) - float(window(k)[0])) / rate_at(c, at)
	return minf(clampf(since / appear_s(), 0.0, 1.0), clampf(left(c, k, at) / fade_s(), 0.0, 1.0))

## 빛줄기의 각(rad, 아래 발판 쪽 수평이 0, 위로 돌아 위 발판 쪽 수평이 π; 뒤 반 바퀴는 π..2π 로 절벽을 쓴다) — 앞 반 바퀴는 뭉치 셋을 차례로 겨눈다(기준점 사이는 직선)
func beam_angle(c: Dictionary, at: float) -> float:
	var H := turn_s() / 2.0; var s := half_at(c, at)
	if s >= H: return PI + (s - H) / H * PI
	var q := float(c["gap"]) / 4.0; var r := float(c["rise"])
	var ang: Array = [0.0, atan2(r, q), PI / 2.0, PI - atan2(3.0 * r, q), PI]
	var u := s / H * 4.0; var i := mini(3, floori(u))
	return lerpf(float(ang[i]), float(ang[i + 1]), u - float(i))

## 층 n(테마 층·조각의 only 층만)의 잇단 두 still 발판(조각의 on; 아래 a·위 b) 중 틈이 min_gap..max_gap 이고 b 가 min_dy..max_dy 높으며 틈의 상자를 다른 발판이 가르지 않고 taken 조각이 닿지 않는 짝들 중 가장 넓은 틈 하나. 같은 층·같은 taken 은 늘 같은 답
func plan(n: int, plats: Array, taken: Array = []) -> Array:
	var out: Array = []
	if not (String(C.theme(n)[0]) in (pack.get("themes", []) as Array)): return out
	var min_gap := maxf(4.0 * puff_w_min() + 8.0, float(kind.get("min_gap", 90.0))); var max_gap := float(kind.get("max_gap", 220.0))
	var min_dy := float(kind.get("min_dy", 40.0)); var max_dy := float(kind.get("max_dy", 150.0))
	for pv in (pack.get("pieces", []) as Array):
		var piece: Dictionary = pv
		var only: Dictionary = piece.get("only", {})
		if not only.is_empty() and not _on(n, only): continue
		var kinds: Array = piece.get("on", ["std", "ice"])
		var hops: Array = plats.filter(func(p: Dictionary) -> bool: return not (String(p["kind"]) in ["rest", "short", "ledge"]))
		var found: Array = []
		for i in range(1, hops.size()):
			var a: Dictionary = hops[i - 1]; var b: Dictionary = hops[i]   # a 가 아래 발판(band() 는 오르는 순서로 쌓는다)
			if not (String(a["kind"]) in kinds and String(b["kind"]) in kinds): continue
			var dy := float(b["y"]) - float(a["y"])
			if dy < min_dy or dy > max_dy: continue
			var ax0 := float(a["x"]); var ax1 := ax0 + float(a["w"]); var bx0 := float(b["x"]); var bx1 := bx0 + float(b["w"])
			if bx0 < ax1 and bx1 > ax0: continue   # 겹친 발판 — 틈이 없다
			var dir := 1.0 if bx0 >= ax1 else -1.0   # 아래 발판에서 위 발판 쪽
			var gap := bx0 - ax1 if dir > 0.0 else ax0 - bx1
			if gap < min_gap or gap > max_gap: continue
			if float(a["w"]) < 2.0 * C.HW + 4.0: continue
			var hinge := ax1 if dir > 0.0 else ax0
			var rs := minf(rise(), dy / 4.0)
			var x0 := minf(hinge, hinge + dir * gap) - 4.0; var x1 := maxf(hinge, hinge + dir * gap) + 4.0
			var yhi := float(a["y"]) + rs * PUFF_K + BODY_UP
			if not _clear(plats, a, b, x0, x1, float(a["y"]) + 1.0, yhi): continue
			if not _free(taken, x0, x1, float(a["y"]) - BAND_IN, float(b["y"]) - BAND_IN): continue
			found.append({ "gap": gap, "dir": dir, "hinge_x": hinge, "mid_x": hinge + dir * gap / 2.0, "rise": rs,
				"a_id": String(a["id"]), "b_id": String(b["id"]), "a_y": float(a["y"]), "b_y": float(b["y"]), "z": float(a.get("z", 0.0)), "d": float(a.get("d", C.DEPTH_HALF * 2.0)) })
		found.sort_custom(func(p: Dictionary, q: Dictionary) -> bool: return float(p["gap"]) > float(q["gap"]) if float(p["gap"]) != float(q["gap"]) else float(p["a_y"]) < float(q["a_y"]))
		for i in range(0, mini(int(piece.get("max", 1)), found.size())):
			var g: Dictionary = found[i]
			var s: Dictionary = g.duplicate()
			s["id"] = "%d.L%d" % [n, i]; s["kind"] = "lens"; s["n"] = n; s["x"] = minf(float(g["hinge_x"]), float(g["hinge_x"]) + float(g["dir"]) * float(g["gap"])); s["w"] = float(g["gap"]); s["y"] = float(g["a_y"])
			var pw := puff_w_in(float(g["gap"])); s["tw"] = tower_w_in(float(g["gap"]))
			s["tx"] = float(g["mid_x"]) - float(s["tw"]) / 2.0; s["y_top"] = float(g["a_y"]) + float(g["rise"]) * PUFF_K + puff_h()
			var puffs: Array = []
			for k in range(1, PUFF_K + 1):
				puffs.append({ "id": "%s.p%d" % [String(s["id"]), k], "kind": "puff", "k": k, "x": float(g["hinge_x"]) + float(g["dir"]) * float(g["gap"]) * float(k) / float(PUFF_K + 1) - pw / 2.0, "y": float(g["a_y"]) + float(g["rise"]) * float(k), "w": pw, "z": float(g["z"]), "d": float(g["d"]), "lens": String(s["id"]) })
			s["puffs"] = puffs
			out.append(s)
	return out

## 층 n 이 {from, every} 에 드나
static func _on(n: int, rule: Dictionary) -> bool:
	var from := int(rule.get("from", 0))
	return n >= from and (n - from) % maxi(1, int(rule.get("every", 1))) == 0

## 틈의 상자(틈 ± 손 하나, 아래 발판 윗면..맨 위 뭉치에 선 몸)에 두 발판 말고 다른 발판이 걸리지 않나 — 움직이는 발판은 진폭째
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

## 다른 팩의 조각(taken: x·w·y, 있으면 rail_y·beam_y·y_top 까지의 키)이 이 틈에 들지 않나 — 틈의 x 와 겹치고 조각의 높이 띠가 [ylo, yhi) 와 겹치면 그 틈은 그 팩의 것(뗏목은 틈 가운데, 널·열기구·버섯은 아래 발판 높이나 틈 안에 있다; 위 발판 높이의 조각은 위 틈의 것)
static func _free(taken: Array, x0: float, x1: float, ylo: float, yhi: float) -> bool:
	for tv in taken:
		var q: Dictionary = tv
		var qx0 := float(q["x"]) - 10.0; var qx1 := float(q["x"]) + float(q.get("w", 0.0)) + 10.0
		var qy := float(q.get("y", 0.0)); var qtop := qy
		for key in ["rail_y", "beam_y", "y_top"]:
			if q.has(key): qtop = maxf(qtop, float(q[key]))
		if x1 > qx0 and x0 < qx1 and qtop >= ylo and qy < yhi: return false
	return true

## C 를 누른 틱 — 아래 발판 위에서 틈 쪽 가장자리 HW + reach 안이면 손바퀴를 돌린다: {spun, until, fast}. 이미 빠른 동안(fast)은 아무것도 아니다. 걷는 깊이여야 한다
func spin(on: Dictionary, x: float, z: float, pressed: bool, fig: Stick3D = null) -> Dictionary:
	var none := { "spun": false, "until": -1.0, "fast": false }
	if not pressed: return none
	var oid := String(on.get("id", ""))
	for cv in lenses:
		var c: Dictionary = cv
		if oid != String(c["a_id"]): continue
		if absf(z - C.PLAYER_Z) >= C.HZ + 4.0: continue
		if absf(x - float(c["hinge_x"])) > C.HW + reach(): continue
		if rate_at(c, t) > 1.0: return { "spun": false, "until": float(c["spin_t0"]) + fast_s(), "fast": true }
		if float(c["spin_t0"]) >= 0.0: c["boost"] = float(c["boost"]) + fast_s() * (fast_rate() - 1.0)   # 지난 돌림은 다 흘렀다 — 접는다
		c["spin_t0"] = t
		_play(c["spin_snd"])
		if fig: fig.set_meta("spin_t0", t)   # 자세의 시계는 pose_t — 메타는 점검·주민 시연용 표시일 뿐
		return { "spun": true, "until": t + fast_s(), "fast": false }
	return none

## 로더의 착지 판정과 같은 규칙(HW·HZ) — 이 틱에 켜진 뭉치의 윗면을 지나 떨어지는 몸만 받고 그 뭉치(발판 모양 사전, kind "puff")를 돌려준다; 꺼진 뭉치는 그냥 지나간다
func land(x: float, y: float, ny: float, z: float) -> Dictionary:
	for cv in lenses:
		var c: Dictionary = cv
		for pv in (c["puffs"] as Array):
			var p: Dictionary = pv
			if not lit(c, int(p["k"]), t): continue
			var px := float(p["x"]); var py := float(p["y"])
			if x + C.HW > px and x - C.HW < px + float(p["w"]) and y >= py and ny <= py and absf(z - float(p["z"])) < float(p["d"]) / 2.0 + C.HZ: return p
	return {}

## 서 있는 뭉치가 아직 받쳐 주나 — 아니면 로더가 on 을 비우고 lurch 를 고른다
func holds(on: Dictionary) -> bool:
	var c := _lens(String(on.get("lens", "")))
	return not c.is_empty() and lit(c, int(on.get("k", 0)), t)

## 서 있는 몸이 경고를 받는 때 — 켜져 있지만 fade_s 안에 꺼진다
func fading(on: Dictionary) -> bool:
	var c := _lens(String(on.get("lens", "")))
	return not c.is_empty() and lit(c, int(on.get("k", 0)), t) and left(c, int(on.get("k", 0)), t) < fade_s()

func _lens(id: String) -> Dictionary:
	for cv in lenses:
		if String((cv as Dictionary)["id"]) == id: return cv
	return {}

func _play(p: AudioStreamPlayer3D) -> void:
	if p.playing: p.stop()
	p.play()

## 노드를 지금 자리로
func _process(delta: float) -> void:
	t += delta
	lenses = lenses.filter(func(c: Dictionary) -> bool: return is_instance_valid(c["node"]))   # 지운 층의 것은 뺀다(climb_catalogue 와 같은 식)
	for cv in lenses:
		_place(cv)

## 렌즈를 짓는다 — root 는 그 층의 노드. 노드 원점은 (틈 한가운데, 아래 발판 윗면, 절벽 면); 돌탑(절벽에 묻힘)·갓돌·놋쇠 북·빛줄기(북에 매단 피벗)·아래 발판 가장자리의 손바퀴와 축·뭉치 셋(판 + 솜뭉치, 농도는 빛을 따른다)·톱니 소리·종
func build(root: Node3D, planned: Array) -> void:
	var th := tower_h() * C.K; var dr := float(kind.get("drum_r", 9.0)) * C.K; var bl := float(kind.get("beam_len", 120.0)) * C.K
	for sv in planned:
		var s: Dictionary = (sv as Dictionary).duplicate(true)
		var tw := float(s["tw"]) * C.K
		var node := Node3D.new(); node.position = C.to3(float(s["mid_x"]), float(s["a_y"]), C.WALL_Z * C.K); root.add_child(node)
		var stone := _mat(Color("c9dde6")); var cap := _mat(Color("f7f4ef")); var brass := _mat(Color("b08d57")); var band := _mat(Color("ad7096"))
		_box(node, Vector3(tw, th, TOWER_D * C.K), stone).position = Vector3(0.0, -th / 2.0, TOWER_D * C.K / 2.0)                  # 돌탑 — 꼭대기가 아래 발판 윗면
		_box(node, Vector3(tw + 8.0 * C.K, 4.0 * C.K, TOWER_D * C.K + 4.0 * C.K), cap).position = Vector3(0.0, 2.0 * C.K, TOWER_D * C.K / 2.0)   # 갓돌
		_box(node, Vector3(tw, 3.0 * C.K, 1.0 * C.K), band).position = Vector3(0.0, -th * 0.35, TOWER_D * C.K + 0.5 * C.K)       # 띠 — 강조색만
		var drum := Node3D.new(); drum.position = Vector3(0.0, 4.0 * C.K + dr, 12.0 * C.K); node.add_child(drum)
		var dm := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = dr; cm.bottom_radius = dr; cm.height = 10.0 * C.K; cm.radial_segments = 12
		dm.mesh = cm; dm.material_override = brass; dm.rotation.x = PI / 2.0; dm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; drum.add_child(dm)
		_box(drum, Vector3(dr * 2.2, 1.5 * C.K, 11.0 * C.K), band)                                                               # 북의 테 — 도는 게 보인다
		var beam := Node3D.new(); beam.position = drum.position; node.add_child(beam)
		var beam_mat := _mat(Color("f2c84b"), true); beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_box(beam, Vector3(bl, 8.0 * C.K, 2.0 * C.K), beam_mat).position = Vector3(bl / 2.0, 0.0, 0.0)                           # 빛줄기 — 피벗의 +x 로 뻗는다
		var wheel := Node3D.new(); wheel.position = Vector3((float(s["hinge_x"]) + float(s["dir"]) * 4.0 - float(s["mid_x"])) * C.K, 16.0 * C.K, (C.PLAYER_Z - C.WALL_Z) * C.K); node.add_child(wheel)
		var wm := MeshInstance3D.new(); var wc := CylinderMesh.new(); wc.top_radius = WHEEL_R * C.K; wc.bottom_radius = WHEEL_R * C.K; wc.height = 2.0 * C.K; wc.radial_segments = 10
		wm.mesh = wc; wm.material_override = brass; wm.rotation.z = PI / 2.0; wm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; wheel.add_child(wm)   # 축이 x — 몸 앞에서 세로로 돈다
		_box(wheel, Vector3(2.0 * C.K, WHEEL_R * 1.8 * C.K, 1.5 * C.K), band)                                                     # 바퀴살 하나 — 도는 게 보인다
		var shaft := (float(s["gap"]) / 2.0 - float(s["tw"]) / 2.0 - 4.0) * C.K
		_box(node, Vector3(absf(shaft), 2.0 * C.K, 2.0 * C.K), brass).position = Vector3(wheel.position.x - float(s["dir"]) * absf(shaft) / 2.0, wheel.position.y, wheel.position.z)   # 축 — 바퀴에서 탑까지
		var spin_snd := _snd(node, float(kind.get("spin_hz", 520)), 0.5, -14.0)
		s["spin_t0"] = -99.0; s["boost"] = 0.0   # 뭉치보다 먼저 — lit 이 읽는다
		for pv in (s["puffs"] as Array):
			_build_puff(node, s, pv)
		s["node"] = node; s["beam"] = beam; s["beam_mat"] = beam_mat; s["drum"] = drum; s["wheel"] = wheel; s["spin_snd"] = spin_snd
		lenses.append(s)
		_place(s)

## 뭉치 하나 — 판(연한 구름)·윗줄의 솜뭉치 puffs 개·앞테(자주)·종; 농도는 _place 가 빛을 따라 적는다
func _build_puff(node: Node3D, s: Dictionary, p: Dictionary) -> void:
	var w := float(p["w"]) * C.K; var h := puff_h() * C.K; var dep := float(p["d"]) * C.K
	var pn := Node3D.new(); pn.position = Vector3((float(p["x"]) + float(p["w"]) / 2.0 - float(s["mid_x"])) * C.K, (float(p["y"]) - float(s["a_y"])) * C.K, (float(p["z"]) - C.WALL_Z) * C.K); node.add_child(pn)
	var mats: Array = []
	mats.append(_abox(pn, Vector3(w, h, dep), Vector3(0.0, -h / 2.0, 0.0), Color("f7f4ef")))
	mats.append(_abox(pn, Vector3(w, h, 0.06), Vector3(0.0, -h / 2.0, dep / 2.0), Color("ad7096")))   # 앞테 — 턱 끝이 또렷하게
	var balls := maxi(2, int(kind.get("puffs", 4)))
	for i in balls:
		var bm := MeshInstance3D.new(); var sm := SphereMesh.new(); sm.radius = 7.0 * C.K; sm.height = 14.0 * C.K; sm.radial_segments = 10; sm.rings = 5
		var m := _mat(Color("f7f4ef")); m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		bm.mesh = sm; bm.material_override = m; bm.position = Vector3((float(i) / float(balls - 1) - 0.5) * (w - 10.0 * C.K), 0.0, dep * (0.3 if i % 2 == 0 else -0.1))
		bm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; pn.add_child(bm); mats.append(m)
	var chime := _snd(pn, float(kind.get("chime_hz", 880)), 0.25, -10.0)
	p["node"] = pn; p["mats"] = mats; p["chime"] = chime; p["was"] = lit(s, int(p["k"]), t)

## 빛줄기와 북은 각대로, 손바퀴는 렌즈의 네 배로, 뭉치는 농도대로(꺼져도 ALPHA_DIM — 어디 있는지는 보인다); 굳는 순간 종이 울린다
func _place(c: Dictionary) -> void:
	var th := beam_angle(c, t); var dir := float(c["dir"])
	var phi := th if dir < 0.0 else PI - th   # 피벗의 +x 가 빛의 방향: 각은 아래 발판 쪽 수평에서 위로
	(c["beam"] as Node3D).rotation.z = phi
	(c["drum"] as Node3D).rotation.z = -dir * th
	(c["wheel"] as Node3D).rotation.x = vt(c, t) / turn_s() * TAU * 4.0
	var bm: StandardMaterial3D = c["beam_mat"]
	bm.albedo_color = Color(bm.albedo_color, 0.35 if half_at(c, t) < turn_s() / 2.0 else 0.1)
	for pv in (c["puffs"] as Array):
		var p: Dictionary = pv
		var on := lit(c, int(p["k"]), t)
		var a := ALPHA_DIM + (1.0 - ALPHA_DIM) * solidity(c, int(p["k"]), t)
		for mv in (p["mats"] as Array):
			var m: StandardMaterial3D = mv
			m.albedo_color = Color(m.albedo_color, a)
		if on and not bool(p["was"]): _play(p["chime"])
		p["was"] = on

func _mat(c: Color, unshaded := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.albedo_color = c; m.roughness = 1.0
	if unshaded: m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	else: m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON; m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return m

func _box(parent: Node3D, size: Vector3, m: StandardMaterial3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = size; mi.mesh = bm; mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF   # 발판과 같은 규칙 — 그림자는 사람만
	parent.add_child(mi); return mi

## 농도가 오가는 상자(호환 렌더러에서도 되는 알파) — 재질을 돌려준다
func _abox(parent: Node3D, size: Vector3, at: Vector3, c: Color) -> StandardMaterial3D:
	var m := _mat(c); m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_box(parent, size, m).position = at
	return m

func _snd(parent: Node3D, hz: float, secs: float, db: float) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new(); p.stream = _tick_wav(hz, secs); p.volume_db = db; p.unit_size = 6.0; p.max_distance = 30.0
	parent.add_child(p); return p

## 소리 — 짧은 기음이 잦아든다: spin(0.5초, 톱니가 튄다 — 기음에 빠른 떨림)·chime(0.25초, 뭉치가 굳는다). 한 번 재생, 반복 없음
static func _tick_wav(hz: float, secs: float) -> AudioStreamWAV:
	var rate := 22050; var count := int(rate * secs)
	var data := PackedByteArray(); data.resize(count * 2)
	for i in count:
		var k := float(i) / count
		var ph := float(i) * hz * TAU / rate
		var v := (sin(ph) * 0.5 + sin(ph * 3.0) * 0.15) * exp(-k * 6.0) * (0.6 + 0.4 * absf(sin(k * secs * 48.0)))
		data.encode_s16(i * 2, int(v * 22000.0))
	var w := AudioStreamWAV.new(); w.format = AudioStreamWAV.FORMAT_16_BITS; w.mix_rate = rate; w.stereo = false; w.data = data
	return w
