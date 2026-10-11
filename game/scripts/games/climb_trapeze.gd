class_name ClimbTrapeze
extends Node3D
## Climb 콘텐츠 팩 '공중그네'(운영자 2026-10-06 밤: "Climb는 컨텐츠 자체의 질과 양을 늘리는 거" — 팩은 data/climb/*.json 자료, 로더는 운영자 세션이 잇는다; climb.gd 는 CI 가 안 건드린다).
## 별밤(Starlit) 층의 잇단 두 still 발판 사이 틈 — 위 발판보다 rise 위 절벽에서 나온 나무 들보, 쇠고리 둘, 밧줄 둘이 어깨 폭의 가로대를 틈 한가운데에 곧게 늘어뜨린다. 빈 가로대는 흔들리지 않는다(멈춰 있다).
## 공중에서 ↑ 로 가로대를 붙잡으면(홀드와 같은 손 범위) 밧줄이 팽팽해지며(twang) 몸의 가로 속도의 catch_k 만 각속도로 남는다 — 그 뒤의 박자는 층의 것이 아니라 사람의 것: 가로대는 period_s 의 진자로 흔들리고,
## 가는 쪽으로 방향키를 누르면 펌프질(pump rad/s², 다리를 모아 찬다)로 진폭이 붙어 기하가 정한 amax(가로대 끝이 두 턱 끝에서 clear 만큼 떨어진 곳)까지 오른다; 양 끝에서 고리가 삐걱인다(creak).
## 끝에서 SPACE 를 놓으면 가로대의 속도를 안고 홀드 점프로 날아가 몸을 접는다(fly 의 tuck — 자세 제 0.45초; 로더는 끝나거나 착지하면 자세를 비운다); ↓ 는 가로대의 속도만 안고 떨어진다.
## 빈 가로대는 empty_damp 로 잦아들며 흔들리다 진폭이 settle_a 아래면 다시 곧게 멈추고, 그때까진 잡히지 않는다. 밀지도, 떨어뜨리지도, 거절하지도 않는다 — 틈 너머 제 점프는 그대로.
## 매달린 자세는 fly(stick3d_fly.gd — 운영자 보드의 '매달리기·철봉' 가족: 두 손으로 가로대를 쥐고 다리를 모아 펌프질하며 양 끝에서 등이 휘고, 놓으면 몸을 접는다).
## 추(dangle — 시계의 박자로 흔들리고 몸은 실려 간다)와 다르다: 이건 몸이 박자를 만드는 가로대, 멈춘 데서 시작해 사람이 흔든다.
## 로더가 할 일(climb.gd, 운영자 세션): `var ct := ClimbTrapeze.new(); add_child(ct)`; 층을 지을 때 `var ic := ci.plan(n, plats); ct.build(root, ct.plan(n, plats, ic + cn.plan(n, plats, ic)))` (고드름·등롱 장대의 계획을 taken 으로 — 그 틈은 비켜 간다); 매 틱 `ct.sync(_t)`;
## 공중에서 ↑(dirz < 0)이고 홀드·다른 팩의 잡기가 비었으면 `var g := ct.grab(x, y, z, vx); if not g.is_empty(): flying = g; on = {}; vx = 0.0; vy = 0.0; charge = 0.0; face = float(g["dir"])` (flying 은 로더의 새 사전 — holding 처럼; vx 는 지우기 전의 몸 속도);
## 매달린 매 틱(`_hold` 와 같은 자리, 맨 앞): `var r := ct.swing(flying, dt, dir, fig); x = r["x"]; y = r["y"]; apex = y; fig.pose_request = "fly"; stamina -= dt * 0.09; if float(r["face"]) != 0.0: face = float(r["face"]); if r["lost"]: flying = {}; fig.pose_request = ""`;
## SPACE 를 놓으면 `var v := ct.let_go(flying, fig); vy = (JUMP_MIN + (JUMP_V - JUMP_MIN) * (charge / CHARGE)) * 0.9 + maxf(0.0, v["vy"]); vx = dir * RUN * 0.9 + v["vx"]; flying = {}` — 자세는 "fly" 그대로(접기), 매 틱 `if fig.pose_request == "fly" and flying.is_empty() and (FlyPoses.done(fig) or not on.is_empty()): fig.pose_request = ""`;
## ↓ 나 힘이 다하면 `var v := ct.let_go(flying); vx = v["vx"]; vy = v["vy"]; flying = {}; fig.pose_request = ""`.
## 단위는 climb.gd 와 같은 px(36px = 1m, +y 위). 점검은 tools/probe_trapeze.gd

const PACK := "res://data/climb/trapeze.json"
const C = preload("res://scripts/games/climb.gd")
const PAD := 2.0            # 몸이 쓸 상자 가장자리 여유(px) — taken 조각과 겹침을 볼 때
const PUMP_EASE := 8.0      # 펌프질 메타가 따라붙는 빠르기(/s) — 다리가 툭 바뀌지 않게

var pack: Dictionary = {}
var kind: Dictionary = {}       # kinds.trapeze
var bars: Array = []            # 지은 그네 {id, kind "trapeze", x, y, w, z, d, dir, gap, hx, hp, len, amax, reach, low_y, a_id, b_id, a_y, b_y, node, arm, twang, creak, held, t0, th, om, pk, rel, ra, rp}
var t := 0.0                    # 로더의 _t 와 같이 간다(sync)

func _ready() -> void:
	var f := FileAccess.open(PACK, FileAccess.READ)
	if f: pack = JSON.parse_string(f.get_as_text()) as Dictionary
	kind = (pack.get("kinds", {}) as Dictionary).get("trapeze", {})

func sync(now: float) -> void:
	t = now

func period() -> float:
	return maxf(0.5, float(kind.get("period_s", 3.0)))

## 진자의 각진동수(rad/s) — 박자는 자료의 것, 밧줄의 그린 길이가 아니다(진짜 3초 진자는 547 px, 한 층보다 길다)
func omega() -> float:
	return TAU / period()

func hang() -> float:
	return float(kind.get("hang", 58.0))

func bar_w() -> float:
	return maxf(4.0, float(kind.get("bar_w", 28.0)))

func pump() -> float:
	return maxf(0.0, float(kind.get("pump", 0.9)))

func catch_k() -> float:
	return clampf(float(kind.get("catch_k", 0.3)), 0.0, 1.0)

func damp() -> float:
	return maxf(0.0, float(kind.get("damp", 0.05)))

func empty_damp() -> float:
	return maxf(0.01, float(kind.get("empty_damp", 1.0)))

func settle_a() -> float:
	return maxf(0.001, float(kind.get("settle_a", 0.03)))

## 진폭(라디안) — 선형 진자의 에너지에서: (θ² + (θ'/ω)²)^½
func amp(th: float, om: float) -> float:
	var u := om / omega()
	return sqrt(th * th + u * u)

## 놓인 뒤 빈 가로대가 멈추기까지(초) — A0·e^(−d·τ) 가 settle_a 아래로 내려가는 τ
func settle_s(s: Dictionary) -> float:
	var a0 := float(s.get("ra", 0.0))
	if a0 <= settle_a(): return 0.0
	return log(a0 / settle_a()) / empty_damp()

## 곧게 멈춰 있어 잡힐 수 있나
func parked(s: Dictionary, at: float) -> bool:
	return not bool(s.get("held", false)) and at >= float(s.get("rel", -9.0)) + settle_s(s)

## 지금 각(라디안; + 면 +x 쪽으로 기울었다) — 매달렸으면 적분한 제 각, 놓인 뒤엔 잦아드는 닫힌꼴, 멈춘 뒤엔 0
func ang(s: Dictionary, at: float) -> float:
	if bool(s.get("held", false)): return float(s["th"])
	if parked(s, at): return 0.0
	var tau := at - float(s["rel"])
	return float(s["ra"]) * exp(-empty_damp() * tau) * cos(omega() * tau + float(s["rp"]))

## 지금 각속도(rad/s) — ang 의 시간 미분
func om_at(s: Dictionary, at: float) -> float:
	if bool(s.get("held", false)): return float(s["om"])
	if parked(s, at): return 0.0
	var tau := at - float(s["rel"]); var e := float(s["ra"]) * exp(-empty_damp() * tau); var ph := omega() * tau + float(s["rp"])
	return -e * (empty_damp() * cos(ph) + omega() * sin(ph))

## 가로대 가운데의 자리(px) — 손이 잡는 곳
func bar(s: Dictionary, at: float) -> Vector2:
	var a := ang(s, at)
	return Vector2(float(s["hx"]) + float(s["len"]) * sin(a), float(s["hp"]) - float(s["len"]) * cos(a))

## 가로대의 속도 px/s — 접선 방향, 각속도 × 길이 (d/dt (sin a, −cos a) = a'·(cos a, sin a))
func speed(s: Dictionary, th: float, om: float) -> Vector2:
	return Vector2(cos(th), sin(th)) * om * float(s["len"])

## 빈 가로대가 잦아들며 흔들리는 동안 양 끝(각속도의 부호가 바뀌는 틱)에 creak; 팔을 지금 각으로
func _process(delta: float) -> void:
	t += delta
	bars = bars.filter(func(s: Dictionary) -> bool: return is_instance_valid(s["node"]))   # 지운 층의 것은 뺀다(climb_pendulum 과 같은 식)
	for sv in bars:
		var s: Dictionary = sv
		if not bool(s["held"]) and not parked(s, t) and om_at(s, t - delta) * om_at(s, t) < 0.0: _play(s["creak"])
		_turn(s)

## 층 n(테마 층만)의 잇단 두 still 발판(조각의 on; 아래 a·위 b) 사이 틈 중 min_gap..max_gap 에 들고 높이차가 max_dy 안이며 쐐기를 다른 발판이 가르지 않고 taken 조각이 닿지 않는 것들 중 가장 넓은 틈 하나 — 그 한가운데에 그네. 같은 층·같은 taken 은 늘 같은 답
func plan(n: int, plats: Array, taken: Array = []) -> Array:
	var out: Array = []
	if not (String(C.theme(n)[0]) in (pack.get("themes", []) as Array)): return out
	var min_gap := float(kind.get("min_gap", 80.0)); var max_gap := float(kind.get("max_gap", 200.0)); var max_dy := float(kind.get("max_dy", 150.0))
	var rise := float(kind.get("rise", 170.0)); var clear := float(kind.get("clear", 8.0)); var bw := bar_w()
	for pv in (pack.get("pieces", []) as Array):
		var piece: Dictionary = pv
		var only: Dictionary = piece.get("only", {})
		if not only.is_empty() and not _on(n, only): continue
		var kinds: Array = piece.get("on", ["std"])
		var hops: Array = plats.filter(func(p: Dictionary) -> bool: return not (String(p["kind"]) in ["rest", "short", "ledge"]))
		var spans: Array = []
		for i in range(1, hops.size()):
			var a: Dictionary = hops[i - 1]; var b: Dictionary = hops[i]   # a 가 아래 발판(band() 는 오르는 순서로 쌓는다)
			if not (String(a["kind"]) in kinds and String(b["kind"]) in kinds): continue
			if absf(float(b["y"]) - float(a["y"])) > max_dy: continue
			var ax0 := float(a["x"]); var ax1 := ax0 + float(a["w"]); var bx0 := float(b["x"]); var bx1 := bx0 + float(b["w"])
			if bx0 < ax1 and bx1 > ax0: continue   # 겹친 발판 — 틈이 없다
			var dir := 1.0 if bx0 >= ax1 else -1.0   # 위 발판이 오른쪽이면 +x 로 건너간다
			var gap := bx0 - ax1 if dir > 0.0 else ax0 - bx1
			if gap < min_gap or gap > max_gap: continue
			var hx := (ax1 + bx0) / 2.0 if dir > 0.0 else (bx1 + ax0) / 2.0
			var mean := (float(a["y"]) + float(b["y"])) / 2.0
			var low_y := mean + hang()   # 흔들림의 바닥에서 가로대 높이 — 매달린 발이 두 발판 높이의 평균(추와 같은 규칙)
			var hp := maxf(float(a["y"]), float(b["y"])) + rise
			var len := hp - low_y
			var reach := gap / 2.0 - clear - bw / 2.0   # 끝에서 가로대 가운데가 들보 x 에서 떨어진 거리
			if reach < float(kind.get("min_reach", 14.0)) or reach > len * 0.7: continue
			var half := reach + bw / 2.0 + C.HW
			if not _clear(plats, a, b, hx, reach, bw, len, mean - 10.0, hp): continue
			if not _free(taken, hx - half - PAD, hx + half + PAD, mean - PAD, hp + PAD): continue
			var d := minf(float(a.get("d", C.DEPTH_HALF * 2.0)), float(b.get("d", C.DEPTH_HALF * 2.0)))
			spans.append({ "gap": gap, "dir": dir, "hx": hx, "hp": hp, "len": len, "amax": asin(reach / len), "reach": reach, "low_y": low_y, "d": d,
				"a_id": String(a["id"]), "b_id": String(b["id"]), "a_y": float(a["y"]), "b_y": float(b["y"]), "half": half })
		spans.sort_custom(func(p: Dictionary, q: Dictionary) -> bool: return float(p["gap"]) > float(q["gap"]) if float(p["gap"]) != float(q["gap"]) else float(p["a_y"]) < float(q["a_y"]))
		for i in range(0, mini(int(piece.get("max", 1)), spans.size())):
			var g: Dictionary = spans[i]
			var s: Dictionary = g.duplicate()
			s["id"] = "%d.T%d" % [n, i]; s["kind"] = "trapeze"; s["x"] = float(g["hx"]) - float(g["half"]); s["w"] = float(g["half"]) * 2.0
			s["y"] = float(g["low_y"]) - hang(); s["z"] = C.WALL_Z + float(g["d"]) / 2.0
			out.append(s)
	return out

## 층 n 이 {from, every} 에 드나
static func _on(n: int, rule: Dictionary) -> bool:
	var from := int(rule.get("from", 0))
	return n >= from and (n - from) % maxi(1, int(rule.get("every", 1))) == 0

## 그네가 쓸 쐐기(들보에서 아래로 벌어지는 — 가로대 위 높이에선 그 높이에서 밧줄이 닿는 x 만, 가로대 아래에선 가로대 반폭과 몸 반폭까지; 매달린 발 높이..들보) 안에 두 턱 말고 다른 발판이 걸리지 않나(추와 같은 식)
static func _clear(plats: Array, a: Dictionary, b: Dictionary, hx: float, reach: float, bw: float, len: float, y0: float, y1: float) -> bool:
	for pv in plats:
		var p: Dictionary = pv
		if p["id"] == a["id"] or p["id"] == b["id"]: continue
		var px0 := float(p["x"]); var px1 := px0 + float(p["w"]); var py := float(p["y"])
		if py <= y0 or py >= y1: continue
		var depth := y1 - py
		var half := depth / len * reach + 6.0 if depth < len else reach + bw / 2.0 + C.HW   # 가로대 위는 밧줄만, 가로대 아래는 가로대와 매달린 몸까지
		if px1 > hx - half and px0 < hx + half: return false
	return true

## 다른 팩의 조각(taken: x, w, y, 있으면 len·b_y·floor 까지 — 등롱 장대는 y..y+len, 고드름은 floor..y)이 그네의 상자와 겹치지 않나
static func _free(taken: Array, x0: float, x1: float, ylo: float, yhi: float) -> bool:
	for tv in taken:
		var q: Dictionary = tv
		var qx0 := float(q.get("x", 0.0)) - 6.0; var qx1 := float(q.get("x", 0.0)) + float(q.get("w", 0.0)) + 6.0
		var qy := float(q.get("y", 0.0))
		var ys: Array = [qy, qy + float(q.get("len", 0.0)), float(q.get("b_y", qy)), float(q.get("floor", qy))]
		var qy0 := float(ys.min()) - 6.0; var qy1 := float(ys.max()) + 6.0
		if x1 > qx0 and x0 < qx1 and yhi > qy0 and ylo < qy1: return false
	return true

## 공중에서 ↑ — 손(발 + hang)이 곧게 멈춘 가로대의 reach_x·reach_y 안이면 잡는다(twang): 밧줄이 몸 속도 vx 의 catch_k 만 각속도로 남긴다(진폭 amax 까지). 돌려주는 사전의 x·y 가 몸의 자리(가로대 밑 hang), dir 이 위 발판 쪽. 흔들리는 중이거나 누가 탔으면 아니다
func grab(x: float, y: float, z: float, vx: float = 0.0) -> Dictionary:
	var rx := float(kind.get("reach_x", 26.0)); var ry := float(kind.get("reach_y", 22.0))
	for sv in bars:
		var s: Dictionary = sv
		if absf(z - float(s["z"])) >= float(s["d"]) / 2.0 + C.HZ: continue
		if not parked(s, t): continue
		var h := bar(s, t)
		if absf(x - h.x) < rx and absf(y + hang() - h.y) < ry:
			var om := catch_k() * vx / float(s["len"])
			var cap := omega() * float(s["amax"])
			s["held"] = true; s["t0"] = t; s["th"] = 0.0; s["om"] = clampf(om, -cap, cap); s["pk"] = 0.0
			_play(s["twang"])
			return { "id": String(s["id"]), "kind": "trapeze", "x": h.x, "y": h.y - hang(), "t0": t, "dir": float(s["dir"]) }
	return {}

## 매달린 매 틱 — {x, y, lost, face, vx, vy}: 가는 쪽(멈췄으면 아무 쪽)으로 누른 dir 이 펌프질(amax 까지), 그 뒤 진자의 한 틱(반음해 오일러); 각속도의 부호가 바뀌는 끝에서 creak. 그네가 사라졌거나 잡고 있지 않으면 lost.
## fig 가 있으면 자세의 메타를 적는다: fly_v 속도 −1..1(+x 가 +, 진폭 끝의 최고 속도를 1 로), fly_a 각(rad, +x 가 +), fly_e 끝에 가까운 정도 0..1, fly_pump 펌프질 0..1
func swing(riding: Dictionary, dt: float, dir: float, fig: Stick3D = null) -> Dictionary:
	var s := _find(String(riding.get("id", "")))
	if s.is_empty() or not bool(s.get("held", false)): return { "x": float(riding.get("x", 0.0)), "y": float(riding.get("y", 0.0)), "lost": true, "face": 0.0, "vx": 0.0, "vy": 0.0 }
	var w := omega(); var cap := float(s["amax"])
	var th := float(s["th"]); var om := float(s["om"]); var pumping := false
	if dir != 0.0 and (om == 0.0 or signf(om) == dir) and amp(th, om) < cap - 0.001:
		om += dir * pump() * dt; pumping = true
		if amp(th, om) > cap: om = dir * w * sqrt(maxf(0.0, cap * cap - th * th))   # 진폭은 기하가 정한 끝까지만
	om += (-w * w * th - damp() * om) * dt
	th += om * dt
	if float(s["om"]) * om < 0.0: _play(s["creak"])   # 끝 — 방향이 바뀐다
	s["th"] = th; s["om"] = om
	s["pk"] = move_toward(float(s["pk"]), 1.0 if pumping else 0.0, PUMP_EASE * dt)
	var b := bar(s, t); var v := speed(s, th, om)
	if fig:
		fig.set_meta("fly_v", clampf(om / (w * cap), -1.0, 1.0))
		fig.set_meta("fly_a", th)
		fig.set_meta("fly_e", clampf(absf(th) / cap, 0.0, 1.0))
		fig.set_meta("fly_pump", float(s["pk"]))
	return { "x": b.x, "y": b.y - hang(), "lost": false, "face": signf(om) if absf(om) > 0.05 else 0.0, "vx": v.x, "vy": v.y }

## 놓는 순간 가로대의 속도 {vx, vy} px/s — 접선 방향(twang); 빈 가로대는 지금 각·각속도에서 잦아들며 흔들린다. fig 가 있으면 fly 의 접기를 시작한다(FlyPoses.release)
func let_go(riding: Dictionary, fig: Stick3D = null) -> Dictionary:
	var s := _find(String(riding.get("id", "")))
	if s.is_empty() or not bool(s.get("held", false)): return { "vx": 0.0, "vy": 0.0 }
	var th := float(s["th"]); var om := float(s["om"])
	var v := speed(s, th, om)
	s["held"] = false; s["rel"] = t; s["ra"] = amp(th, om); s["rp"] = atan2(-om / omega(), th)
	_play(s["twang"])
	if fig: FlyPoses.release(fig)
	return { "vx": v.x, "vy": v.y }

func _find(id: String) -> Dictionary:
	for sv in bars:
		if String((sv as Dictionary)["id"]) == id: return sv
	return {}

func _play(p: AudioStreamPlayer3D) -> void:
	if p.playing: p.stop()
	p.play()

## 그네를 짓는다 — root 는 그 층의 노드. 노드 원점은 들보(hx, hp, z); 절벽에서 나온 나무 들보, 쇠고리 둘, 끝의 강조색 깃, 팔 노드(들보에서 도는) 안에 밧줄 둘·가로대·잉크 손잡이 띠 둘, twang·creak
func build(root: Node3D, planned: Array) -> void:
	var bw := bar_w() * C.K
	for sv in planned:
		var s: Dictionary = (sv as Dictionary).duplicate()
		var dep := float(s["d"]) * C.K * 0.5
		var node := Node3D.new(); node.position = C.to3(float(s["hx"]), float(s["hp"]), float(s["z"]) * C.K); root.add_child(node)
		var wood := _mat(Color("8a6a4a")); var iron := _mat(Color("3a3640")); var rope := _mat(Color("c9b48a")); var ink := _mat(Color("2f2a4e")); var plate := _mat(Color("ad7096"))
		var beam_len := (float(s["z"]) - C.WALL_Z) * C.K + 0.3
		_box(node, Vector3(bw + 0.3, 0.1, beam_len), wood).position = Vector3(0, 0.05, -beam_len / 2.0 + 0.1)   # 절벽에서 나온 들보
		for k in [-1.0, 1.0]:
			var ring := MeshInstance3D.new(); var rm := CylinderMesh.new(); rm.top_radius = 0.035; rm.bottom_radius = 0.035; rm.height = 0.03; rm.radial_segments = 8; ring.mesh = rm
			ring.material_override = iron; ring.rotation.x = PI / 2.0; ring.position = Vector3((k as float) * bw / 2.0, -0.01, 0); ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; node.add_child(ring)   # 쇠고리
		_box(node, Vector3(0.06, 0.04, 0.01), plate).position = Vector3(bw / 2.0 + 0.12, 0.05, dep * 0.3)   # 들보 끝의 깃 — 강조색만
		var len := float(s["len"]) * C.K
		var arm := Node3D.new(); node.add_child(arm)
		for k in [-1.0, 1.0]:
			_box(arm, Vector3(0.012, len, 0.012), rope).position = Vector3((k as float) * bw / 2.0, -len / 2.0, 0)   # 밧줄 — 고리에서 가로대 끝까지
		_box(arm, Vector3(bw + 0.08, 0.035, 0.035), wood).position = Vector3(0, -len, 0)   # 손이 잡는 가로대
		for k in [-1.0, 1.0]:
			_box(arm, Vector3(0.05, 0.04, 0.04), ink).position = Vector3((k as float) * 0.07, -len, 0)   # 잉크 손잡이 띠
		var twang := AudioStreamPlayer3D.new(); twang.stream = _tick_wav(float(kind.get("twang_hz", 480)), 0.12); twang.volume_db = -10.0; twang.unit_size = 6.0; twang.max_distance = 30.0; node.add_child(twang)
		var creak := AudioStreamPlayer3D.new(); creak.stream = _tick_wav(float(kind.get("creak_hz", 70)), 0.1); creak.volume_db = -12.0; creak.unit_size = 6.0; creak.max_distance = 30.0; node.add_child(creak)
		s["node"] = node; s["arm"] = arm; s["twang"] = twang; s["creak"] = creak
		s["held"] = false; s["t0"] = -9.0; s["th"] = 0.0; s["om"] = 0.0; s["pk"] = 0.0; s["rel"] = -9.0; s["ra"] = 0.0; s["rp"] = 0.0
		bars.append(s)
		_turn(s)

## 팔을 지금 각으로 — +z 돌림이면 끝이 +x 로 간다(bar 와 같은 식)
func _turn(s: Dictionary) -> void:
	(s["arm"] as Node3D).rotation.z = ang(s, t)

func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.albedo_color = c; m.roughness = 1.0
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON; m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return m

func _box(parent: Node3D, size: Vector3, m: StandardMaterial3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = size; mi.mesh = bm; mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF   # 발판과 같은 규칙 — 그림자는 사람만
	parent.add_child(mi); return mi

## 밧줄·고리 소리 — 짧은 기음이 빠르게 잦아든다: twang(0.12초, 밧줄이 팽팽해진다)·creak(0.1초, 낮은 고리). 한 번 재생, 반복 없음
static func _tick_wav(hz: float, secs: float) -> AudioStreamWAV:
	var rate := 22050; var count := int(rate * secs)
	var data := PackedByteArray(); data.resize(count * 2)
	for i in count:
		var k := float(i) / count
		var ph := float(i) * hz * TAU / rate
		var v := (sin(ph) * 0.5 + sin(ph * 2.3) * 0.2) * exp(-k * 10.0)
		data.encode_s16(i * 2, int(v * 22000.0))
	var w := AudioStreamWAV.new(); w.format = AudioStreamWAV.FORMAT_16_BITS; w.mix_rate = rate; w.stereo = false; w.data = data
	return w
