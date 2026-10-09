class_name ClimbLantern
extends Node3D
## Climb 콘텐츠 팩 '별 등롱'(운영자 2026-10-06 밤: "Climb는 컨텐츠 자체의 질과 양을 늘리는 거" — 팩은 data/climb/*.json 자료, 로더는 운영자 세션이 잇는다; climb.gd 는 CI 가 안 건드린다).
## 별밤(Starlit) 층의 잇단 두 발판 사이 틈 — 아래 발판의 틈 쪽 끝 돌 발판에 핀으로 선 긴 장대, 놋쇠 가로 갈고리(hook 높이), 잉크 손잡이 띠, 꼭대기 팔에 종이 별 등롱이 매달려 빛난다.
## 장대 옆에서 뛰어 ↑ 로 갈고리를 잡으면(홀드와 같은 손 범위) 장대를 안고 오른다(cling, shin_v px/s); 손이 h 에 닿으면 몸무게에 장대가 핀을 축으로 틈 너머로 넘어간다 — swing_s 의 한 방향 호(smoothstep), 끝에서 발이 건너편 발판 set_in 안·lift 위에 오고 settle_s 뒤에 내려놓는다(done — 그 틱의 y 가 발판 윗면이라 다음 틱 로더의 착지 판정이 밟는다).
## SPACE·↓ 는 장대의 속도를 안고 놓는다(let_go). 빈 장대는 back_s 에 걸쳐 곧게 돌아오고(움직이는 동안 creak, 자리에 앉으면 clack) 돌아오는 동안은 못 잡는다. 길이는 기하로: 발이 건너편에 닿게 r = sqrt(D² + H²), 기울기 amax = atan2(D, H).
## 밀지도, 떨어뜨리지도, 거절하지도 않는다 — 점프 하나를 장대 하나에 맡기는 길. 매달린 자세는 cling(stick3d_cling.gd — 운영자 보드의 '장대 타기' 가족: 두 팔과 두 무릎으로 장대를 안고 당기고 밀어 오르다, 넘어갈 땐 꼭 안은 채 골반째 장대와 같이 기운다).
## 로더가 할 일(climb.gd, 운영자 세션): `var cn := ClimbLantern.new(); add_child(cn)`; 층을 지을 때 `cn.build(root, cn.plan(n, plats, ci.plan(n, plats)))` (고드름의 계획을 taken 으로 — 같은 층의 둘이 한 자리를 안 나눈다); 매 틱 `cn.sync(_t)`;
## 공중에서 ↑(dirz < 0)이고 홀드·다른 팩의 잡기가 비었으면 `var g := cn.grab(x, y, z); if not g.is_empty(): clinging = g; on = {}; vx = 0.0; vy = 0.0; charge = 0.0; face = float(g["dir"])` (clinging 은 로더의 새 사전 — holding 처럼);
## 매달린 매 틱(`_hold` 와 같은 자리, 맨 앞): `var r := cn.hang_on(clinging, fig); x = r["x"]; y = r["y"]; apex = y; fig.pose_request = "cling"; stamina -= dt * 0.09; if r["done"] or r["lost"]: clinging = {}; fig.pose_request = ""`;
## SPACE 를 놓으면 `var v := cn.let_go(clinging); vy = (JUMP_MIN + (JUMP_V - JUMP_MIN) * (charge / CHARGE)) * 0.9 + maxf(0.0, v["vy"]); vx = dir * RUN * 0.9 + v["vx"]; clinging = {}; 자세 ""`; ↓ 나 힘이 다하면 `vx = v["vx"]; vy = v["vy"]; clinging = {}`.
## 단위는 climb.gd 와 같은 px(36px = 1m, +y 위). 점검은 tools/probe_lantern.gd

const PACK := "res://data/climb/lantern.json"
const C = preload("res://scripts/games/climb.gd")
const POLE_D := 20.0      # 장대의 앞뒤 폭(px) — 몸이 선 깊이(PLAYER_Z)보다 조금 뒤에 서서 몸이 앞에서 안는다
const SAMPLES := 6        # 쓸고 지나는 장대를 점검할 때 각마다 재는 점의 수
const MARGIN := 14.0      # 그 점이 다른 발판에서 이만큼 안이면 걸린 것(px)

var pack: Dictionary = {}
var kind: Dictionary = {}       # kinds.lantern
var poles: Array = []           # 지은 장대 {id, kind "lantern", x, y, w, z, d, a_id, a_y, b_y, dir, px, tgt, r, amax, h, len, shin_s, node, pole, cord, glow, creak, clack, held, t0, rel, rang, shown, phase}
var t := 0.0                    # 로더의 _t 와 같이 간다(sync)

func _ready() -> void:
	var f := FileAccess.open(PACK, FileAccess.READ)
	if f: pack = JSON.parse_string(f.get_as_text()) as Dictionary
	kind = (pack.get("kinds", {}) as Dictionary).get("lantern", {})

func sync(now: float) -> void:
	t = now

func hang() -> float:
	return float(kind.get("hang", 58.0))

func hook() -> float:
	return float(kind.get("hook", 70.0))

func shin_v() -> float:
	return maxf(1.0, float(kind.get("shin_v", 90.0)))

func swing_s() -> float:
	return maxf(0.01, float(kind.get("swing_s", 1.8)))

func settle_s() -> float:
	return float(kind.get("settle_s", 0.2))

func back_s() -> float:
	return maxf(0.01, float(kind.get("back_s", 2.0)))

## 매달린 뒤 k 초의 손 높이(핀에서 장대를 따라, px) — 갈고리에서 shin_v 로 오르다 h 에서 멈춘다
func hands_at(s: Dictionary, k: float) -> float:
	return minf(float(s["h"]), hook() + shin_v() * maxf(0.0, k))

## 넘어가기 진행 0..1 — 손이 h 에 닿은 뒤(shin_s) swing_s 에 걸쳐
func tip_u(s: Dictionary, k: float) -> float:
	return clampf((k - float(s["shin_s"])) / swing_s(), 0.0, 1.0)

## 장대의 각(라디안; 0 곧게 선 것 .. amax 건너편으로 넘어간 것) — 매달렸으면 t0 부터, 놓인 뒤엔 rang 에서 back_s 에 걸쳐 돌아온다
func ang(s: Dictionary, at: float) -> float:
	if bool(s["held"]): return float(s["amax"]) * smoothstep(0.0, 1.0, tip_u(s, at - float(s["t0"])))
	var rel := float(s["rel"])
	if rel < -1.0: return 0.0
	return float(s["rang"]) * (1.0 - smoothstep(0.0, 1.0, (at - rel) / back_s()))

## 핀에서 장대를 따라 dist 만큼 간 점의 자리(px) — 각 a 로 dir 쪽으로 기운 장대
func along(s: Dictionary, dist: float, a: float) -> Vector2:
	return Vector2(float(s["px"]) + float(s["dir"]) * dist * sin(a), float(s["a_y"]) + dist * cos(a))

## 장대를 돌리고 등롱을 깜박인다 — 빈 장대도 돌아온다
func _process(delta: float) -> void:
	t += delta
	poles = poles.filter(func(s: Dictionary) -> bool: return is_instance_valid(s["node"]))   # 지운 층의 것은 뺀다(climb_pendulum 과 같은 식)
	for sv in poles:
		var s: Dictionary = sv
		_turn(s)

## 층 n(테마 층만)의 잇단 두 still 발판(조각의 on) 사이 틈 중 min_gap..max_gap 이고 위 발판이 max_dy 안으로 높으며 기하가 max_tilt·min_r..max_r 안이고 장대가 쓸고 지나는 길을 다른 발판이나 taken 조각이 가르지 않는 것들 중 가장 넓은 틈 하나 — 아래 발판의 틈 쪽 끝에 장대. 같은 층·같은 taken 은 늘 같은 답
func plan(n: int, plats: Array, taken: Array = []) -> Array:
	var out: Array = []
	if not (String(C.theme(n)[0]) in (pack.get("themes", []) as Array)): return out
	for pv in (pack.get("pieces", []) as Array):
		var piece: Dictionary = pv
		var only: Dictionary = piece.get("only", {})
		if not only.is_empty() and not _on(n, only): continue
		var kinds: Array = piece.get("on", ["std"])
		var min_gap := float(kind.get("min_gap", 60.0)); var max_gap := float(kind.get("max_gap", 170.0)); var max_dy := float(kind.get("max_dy", 150.0))
		var foot_in := float(kind.get("foot_in", 8.0)); var set_in := float(kind.get("set_in", 16.0)); var lift := float(kind.get("lift", 10.0))
		var max_tilt := float(kind.get("max_tilt", 1.0)); var min_r := float(kind.get("min_r", 60.0)); var max_r := float(kind.get("max_r", 300.0))
		var over := float(kind.get("tip", 40.0)) + float(kind.get("cord", 18.0)) + float(kind.get("star", 11.0)) * 2.0   # 손 위로 더 긴 장대와 등롱
		var hops := plats.filter(func(p: Dictionary) -> bool: return not (String(p["kind"]) in ["rest", "short", "ledge"]))
		var spans: Array = []
		for i in range(1, hops.size()):
			var a: Dictionary = hops[i - 1]; var b: Dictionary = hops[i]   # a 가 아래 발판(band() 는 오르는 순서로 쌓는다)
			if not (String(a["kind"]) in kinds and String(b["kind"]) in kinds): continue
			var dy := float(b["y"]) - float(a["y"])
			if dy < 0.0 or dy > max_dy: continue
			var ax0 := float(a["x"]); var ax1 := ax0 + float(a["w"]); var bx0 := float(b["x"]); var bx1 := bx0 + float(b["w"])
			if bx0 < ax1 and bx1 > ax0: continue   # 겹친 발판 — 틈이 없다
			var dir := 1.0 if bx0 >= ax1 else -1.0
			var gap := bx0 - ax1 if dir > 0.0 else ax0 - bx1
			if gap < min_gap or gap > max_gap: continue
			var px := (ax1 if dir > 0.0 else ax0) - dir * foot_in
			var tgt := bx0 + set_in if dir > 0.0 else bx1 - set_in
			var dd := absf(tgt - px); var hh := dy + lift
			var r := sqrt(dd * dd + hh * hh); var amax := atan2(dd, hh)
			if amax > max_tilt or r < min_r or r > max_r: continue
			var h := r + hang()
			if h < hook() + 20.0: continue   # 오를 데가 없다
			var a_y := float(a["y"]); var len := h + over
			if not _clear(plats, a, b, px, dir, amax, len, a_y): continue
			if not _free(taken, minf(px - MARGIN, tgt - C.HW), maxf(px + MARGIN, tgt + C.HW), a_y + 1.0, a_y + len): continue
			var d := minf(float(a.get("d", C.DEPTH_HALF * 2.0)), float(b.get("d", C.DEPTH_HALF * 2.0)))
			spans.append({ "gap": gap, "px": px, "tgt": tgt, "dir": dir, "r": r, "amax": amax, "h": h, "len": h + float(kind.get("tip", 40.0)), "shin_s": (h - hook()) / shin_v(),
				"a_id": String(a["id"]), "a_y": a_y, "b_y": float(b["y"]), "d": d, "x": minf(px, tgt), "w": absf(tgt - px) })
		spans.sort_custom(func(p: Dictionary, q: Dictionary) -> bool: return float(p["gap"]) > float(q["gap"]))
		for i in range(0, mini(int(piece.get("max", 1)), spans.size())):
			var g: Dictionary = spans[i]
			var s: Dictionary = g.duplicate()
			s["id"] = "%d.L%d" % [n, i]; s["kind"] = "lantern"; s["y"] = float(g["a_y"]); s["z"] = C.PLAYER_Z - 8.0
			out.append(s)
	return out

## 층 n 이 {from, every} 에 드나
static func _on(n: int, rule: Dictionary) -> bool:
	var from := int(rule.get("from", 0))
	return n >= from and (n - from) % maxi(1, int(rule.get("every", 1))) == 0

## 장대가 선 채로, 그리고 amax 까지 넘어가며 쓸고 지나는 점들(각 넷 × 길이 SAMPLES 점)이 두 발판 말고 다른 발판의 MARGIN 안에 들지 않나 — 지름길 판이나 위에 겹친 턱이 가르면 장대가 걸린다
static func _clear(plats: Array, a: Dictionary, b: Dictionary, px: float, dir: float, amax: float, len: float, a_y: float) -> bool:
	for pv in plats:
		var p: Dictionary = pv
		if p["id"] == a["id"] or p["id"] == b["id"]: continue
		var px0 := float(p["x"]) - MARGIN; var px1 := float(p["x"]) + float(p["w"]) + MARGIN; var py := float(p["y"])
		for j in 4:
			var ang_j := amax * float(j) / 3.0
			for k in range(1, SAMPLES + 1):
				var dist := len * float(k) / float(SAMPLES)
				var qx := px + dir * dist * sin(ang_j); var qy := a_y + dist * cos(ang_j)
				if qx > px0 and qx < px1 and absf(qy - py) < MARGIN + 10.0: return false
	return true

## 다른 팩의 조각(taken: x, w, y, 있으면 b_y·beam_y·floor 까지)이 장대가 쓸 상자와 겹치지 않나 — 고드름의 lip
static func _free(taken: Array, x0: float, x1: float, ylo: float, yhi: float) -> bool:
	for tv in taken:
		var q: Dictionary = tv
		var qx0 := float(q.get("x", 0.0)) - 10.0; var qx1 := float(q.get("x", 0.0)) + float(q.get("w", 0.0)) + 10.0
		var ys: Array = [float(q.get("y", 0.0)), float(q.get("b_y", float(q.get("y", 0.0)))), float(q.get("beam_y", float(q.get("y", 0.0)))), float(q.get("floor", float(q.get("y", 0.0))))]
		var qy0 := float(ys.min()) - 10.0; var qy1 := float(ys.max()) + 10.0
		if x1 > qx0 and x0 < qx1 and yhi > qy0 and ylo < qy1: return false
	return true

## 공중에서 ↑ — 손(발 + hang)이 곧게 선 장대의 갈고리 reach_x·reach_y 안이고 장대가 비어 집에 있으면 잡는다(clack): 돌려주는 사전의 x·y 가 몸의 자리(갈고리 밑 hang), dir 이 넘어갈 쪽. 아니면 빈 사전
func grab(x: float, y: float, z: float) -> Dictionary:
	var rx := float(kind.get("reach_x", 26.0)); var ry := float(kind.get("reach_y", 22.0))
	for sv in poles:
		var s: Dictionary = sv
		if absf(z - float(s["z"])) >= POLE_D / 2.0 + C.HZ: continue
		if bool(s["held"]) or t < float(s["rel"]) + back_s(): continue   # 누가 안고 있거나 돌아오는 중
		var hk := along(s, hook(), 0.0)
		if absf(x - hk.x) < rx and absf(y + hang() - hk.y) < ry:
			s["held"] = true; s["t0"] = t
			_play(s["clack"])
			return { "id": String(s["id"]), "kind": "lantern", "x": hk.x, "y": hk.y - hang(), "t0": t, "dir": float(s["dir"]) }
	return {}

## 매달린 매 틱 — {x, y, done, lost}: 손이 갈고리에서 h 까지 오르고(장대는 곧게), 닿으면 장대가 swing_s 에 걸쳐 넘어가 발이 건너편 발판 위에 오고, settle_s 뒤 내려놓는다(done — y 는 발판 윗면). 장대가 사라졌으면 lost
## fig 가 있으면 자세의 메타를 적는다: cling_v 오르는 중 1·넘어가는 중 0, cling_a 장대의 기울기(rad, +면 +x 로)
func hang_on(clinging: Dictionary, fig: Stick3D = null) -> Dictionary:
	var s := _find(String(clinging.get("id", "")))
	if s.is_empty() or not bool(s["held"]): return { "x": float(clinging.get("x", 0.0)), "y": float(clinging.get("y", 0.0)), "done": false, "lost": true }
	var k := t - float(s["t0"]); var a := ang(s, t); var dir := float(s["dir"])
	var p := along(s, hands_at(s, k) - hang(), a)
	var shin := 1.0 if k < float(s["shin_s"]) else 0.0
	var done := k >= float(s["shin_s"]) + swing_s() + settle_s()
	if done:
		_release(s, a)
		p.y = float(s["b_y"])
		_play(s["clack"])
	if fig:
		fig.set_meta("cling_v", shin)
		fig.set_meta("cling_a", dir * a)
	return { "x": p.x, "y": p.y, "done": done, "lost": false }

## 놓는 순간 몸의 속도 {vx, vy} px/s — 오르는 중엔 위로 shin_v, 넘어가는 중엔 장대 끝의 접선 속도(넘어가는 쪽·아래로); 빈 장대는 곧게 돌아간다
func let_go(clinging: Dictionary) -> Dictionary:
	var s := _find(String(clinging.get("id", "")))
	if s.is_empty() or not bool(s["held"]): return { "vx": 0.0, "vy": 0.0 }
	var k := t - float(s["t0"]); var a := ang(s, t)
	var out := { "vx": 0.0, "vy": shin_v() }
	if k >= float(s["shin_s"]):
		var u := tip_u(s, k)
		var w := float(s["amax"]) * 6.0 * u * (1.0 - u) / swing_s()   # smoothstep 의 미분 — 호의 가운데서 가장 빠르다
		var v := (float(s["h"]) - hang()) * w
		out = { "vx": float(s["dir"]) * v * cos(a), "vy": -v * sin(a) }
	_release(s, a)
	return out

## 장대를 비운다 — 지금 각에서 back_s 에 걸쳐 곧게 돌아온다
func _release(s: Dictionary, a: float) -> void:
	s["held"] = false; s["rel"] = t; s["rang"] = a

func _find(id: String) -> Dictionary:
	for sv in poles:
		if String((sv as Dictionary)["id"]) == id: return sv
	return {}

func _play(p: AudioStreamPlayer3D) -> void:
	if p.playing: p.stop()
	p.play()

## 장대를 짓는다 — root 는 그 층의 노드. 노드 원점은 핀(px, 발판 윗면, z); 돌 발판·쇠 핀·장대 노드(pole: 장대·손잡이 띠 셋·놋쇠 갈고리·꼭대기 팔·등롱 노드)·creak·clack. 등롱 노드(cord: 끈·별 두 판·잉크 갓)는 장대가 기울어도 늘 아래로 드리운다(_turn 이 되돌린다)
func build(root: Node3D, planned: Array) -> void:
	var cordl := float(kind.get("cord", 18.0)) * C.K; var sr := float(kind.get("star", 11.0)) * C.K; var hk := hook() * C.K
	for sv in planned:
		var s: Dictionary = (sv as Dictionary).duplicate()
		var dir := float(s["dir"]); var len := float(s["len"]) * C.K
		var node := Node3D.new(); node.position = C.to3(float(s["px"]), float(s["a_y"]), float(s["z"]) * C.K); root.add_child(node)
		var wood := _mat(Color("5a4634")); var iron := _mat(Color("3a3640")); var stone := _mat(Color("6e6878")); var brass := _mat(Color("c9a24a")); var ink := _mat(Color("2f2a4e"))
		var glow := _mat(Color("efe9e2")); glow.emission_enabled = true; glow.emission = Color("f2c84b"); glow.emission_energy_multiplier = 1.1   # 종이 별 — 별밤의 노란빛
		_box(node, Vector3(0.6, 0.04, POLE_D * C.K + 0.2), stone).position = Vector3(0, 0.02, 0)   # 돌 발판 — 장대의 발
		var pin := MeshInstance3D.new(); var pm := CylinderMesh.new(); pm.top_radius = 0.03; pm.bottom_radius = 0.03; pm.height = POLE_D * C.K + 0.06; pm.radial_segments = 8; pin.mesh = pm
		pin.material_override = iron; pin.rotation.x = PI / 2.0; pin.position = Vector3(0, 0.08, 0); pin.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; node.add_child(pin)
		var pole := Node3D.new(); pole.position = Vector3(0, 0.08, 0); node.add_child(pole)
		_box(pole, Vector3(0.06, len, 0.06), wood).position = Vector3(0, len / 2.0, 0)   # 장대 — 핀에서 꼭대기까지
		for by: float in [0.9, 1.7, 2.6]:   # 손잡이 띠 — 같은 간격이 아니다
			if by < len - 0.3: _box(pole, Vector3(0.075, 0.06, 0.075), ink).position = Vector3(0, by, 0)
		_box(pole, Vector3(0.34, 0.035, 0.06), brass).position = Vector3(0, hk, 0)   # 놋쇠 갈고리 — 손이 잡는 곳
		_box(pole, Vector3(0.3, 0.035, 0.035), wood).position = Vector3(dir * 0.12, len - 0.02, 0)   # 꼭대기 팔 — 틈 쪽으로
		var cord := Node3D.new(); cord.position = Vector3(dir * 0.26, len - 0.02, 0); pole.add_child(cord)
		_box(cord, Vector3(0.015, cordl, 0.015), ink).position = Vector3(0, -cordl / 2.0, 0)   # 끈
		var star := Node3D.new(); star.position = Vector3(0, -cordl - sr, 0); cord.add_child(star)
		_box(star, Vector3(sr * 2.0, sr * 2.0, 0.08), glow)
		_box(star, Vector3(sr * 2.0, sr * 2.0, 0.08), glow).rotation.z = PI / 4.0   # 두 판이 엇갈려 여덟 꼭지 별
		_box(star, Vector3(0.12, 0.05, 0.1), ink).position = Vector3(0, sr + 0.02, 0)   # 갓
		var creak := AudioStreamPlayer3D.new(); creak.stream = _loop_wav(float(kind.get("creak_hz", 55)), 0.3); creak.volume_db = -16.0; creak.unit_size = 6.0; creak.max_distance = 30.0; node.add_child(creak)
		var clack := AudioStreamPlayer3D.new(); clack.stream = _tick_wav(float(kind.get("clack_hz", 90)), 0.1); clack.volume_db = -8.0; clack.unit_size = 6.0; clack.max_distance = 30.0; node.add_child(clack)
		s["node"] = node; s["pole"] = pole; s["cord"] = cord; s["glow"] = glow; s["creak"] = creak; s["clack"] = clack
		s["held"] = false; s["t0"] = -9.0; s["rel"] = -9.0; s["rang"] = 0.0; s["shown"] = 0.0; s["phase"] = fposmod(float(s["px"]) * 0.37, TAU)
		poles.append(s)
		_turn(s)

## 장대를 지금 각으로(+z 돌림이면 꼭대기가 −x 로 가니 dir 의 반대로), 등롱은 되돌려 아래로; 움직이는 동안 creak, 집에 앉으면 clack; 등롱이 천천히 깜박인다
func _turn(s: Dictionary) -> void:
	var a := ang(s, t); var dir := float(s["dir"])
	(s["pole"] as Node3D).rotation.z = -dir * a
	(s["cord"] as Node3D).rotation.z = dir * a
	var was := float(s["shown"]); var moving := absf(a - was) > 0.0005
	if was > 0.0005 and a <= 0.0005 and not bool(s["held"]): _play(s["clack"])   # 집에 앉았다
	var creak: AudioStreamPlayer3D = s["creak"]
	if moving and not creak.playing: creak.play()
	elif not moving and creak.playing: creak.stop()
	(s["glow"] as StandardMaterial3D).emission_energy_multiplier = 1.1 + 0.3 * sin(t * TAU * float(kind.get("glow_hz", 0.7)) + float(s["phase"])) + 0.08 * sin(t * 7.3)
	s["shown"] = a

func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.albedo_color = c; m.roughness = 1.0
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON; m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return m

func _box(parent: Node3D, size: Vector3, m: StandardMaterial3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = size; mi.mesh = bm; mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF   # 발판과 같은 규칙 — 그림자는 사람만
	parent.add_child(mi); return mi

## 앉는 소리 — 짧은 기음이 아주 빠르게 잦아든다(서가의 thud 와 같은 식). 한 번 재생, 반복 없음
static func _tick_wav(hz: float, secs: float) -> AudioStreamWAV:
	var rate := 22050; var count := int(rate * secs)
	var data := PackedByteArray(); data.resize(count * 2)
	for i in count:
		var k := float(i) / count
		var ph := float(i) * hz * TAU / rate
		var v := (sin(ph) * 0.5 + sin(ph * 2.3) * 0.2) * exp(-k * 12.0)
		data.encode_s16(i * 2, int(v * 22000.0))
	var w := AudioStreamWAV.new(); w.format = AudioStreamWAV.FORMAT_16_BITS; w.mix_rate = rate; w.stereo = false; w.data = data
	return w

## 핀의 삐걱임 — 낮은 기음에 거친 결을 얹어 돌려 튼다(움직이는 동안만 play/stop)
static func _loop_wav(hz: float, secs: float) -> AudioStreamWAV:
	var rate := 22050; var count := int(rate * secs)
	var data := PackedByteArray(); data.resize(count * 2)
	for i in count:
		var ph := float(i) * hz * TAU / rate
		var grit := sin(float(i) * 7919.0) * 0.25   # 결정적인 거친 결 — 난수가 아니다
		var v := sin(ph) * 0.45 + sin(ph * 1.5) * 0.15 + grit
		data.encode_s16(i * 2, int(v * 18000.0))
	var w := AudioStreamWAV.new(); w.format = AudioStreamWAV.FORMAT_16_BITS; w.mix_rate = rate; w.stereo = false; w.data = data
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD; w.loop_begin = 0; w.loop_end = count
	return w
