class_name ClimbBalloon
extends Node3D
## Climb 콘텐츠 팩 '열기구'(운영자 2026-10-06 밤: "Climb는 컨텐츠 자체의 질과 양을 늘리는 거" — 팩은 data/climb/*.json 자료, 로더는 운영자 세션이 잇는다; climb.gd 는 CI 가 안 건드린다).
## 구름바다(Cloud sea) 층의 잇단 두 발판 사이 틈(min_gap..max_gap) 중 건너편이 min_dy..max_dy 높은 것(기구는 오르기만 한다) — 아래 발판의 틈 쪽 턱에 말뚝과 매는 줄, 틈 안에 발판 턱에 붙여 매인 고리버들 바구니(바닥은 발판 윗면과 같은 높이), 네 줄 위의 버너, 불꽃, 종이 풍선(자주 띠), 안에 머리 높이로 늘어진 버너 줄의 토글.
## 아래 발판에서 바구니 옆 C: 올라탄다(mount_s 에 한 걸음; 건너편 발판·떠 있는 중·되내려오는 중엔 빈 사전). 탄 채 C 한 번이 버너 줄 한 번 당김(whoosh, 불꽃이 커진다): 기구가 lift 만큼 tug_s 에 걸쳐 오르고 그동안 바람이 건너편 쪽으로 dx/tugs 만큼(drift 까지) 실어 가며, hold_s 버티다 식어 cool_v 로 가라앉는다(매인 자리 밑으론 안 간다).
## 바구니 바닥이 건너편 윗면에 닿으면 내려선다(done 인 틱의 x·y 는 건너편 발판 위 자리 — 다음 틱 로더 자신의 착지 판정이 그 발판을 밟는다); 빈 기구는 오른 만큼의 sink_s 로 매인 자리에 되내려와 앉는다(thud). SPACE 로 모았다 놓으면 홀드처럼 0.9 로 뛰되 기구의 오르는 속도를 얹고, ↓ 는 그 자리에서 내린다.
## 밀지도, 거절하지도, 값을 받지도 않는다 — 발판에서 틈을 그냥 뛰어 건너는 길은 그대로; 기구는 바구니에 올라탄 몸에게만 있다. 타는 동안 자세는 tug(stick3d_tug.gd — 한 손은 테에, 다른 손이 머리 위 토글을 어깨까지 홱 당기고 되올리며, 무릎이 눌리고 고개가 불꽃을 본다).
## 덤웨이터(heave — 줄을 손 바꿔 제 몸을 올린다)와 다르다: 이건 한 번의 짧은 당김이 불을 키우고 기구가 스스로 오르는 것, 그리고 바람이 옆으로 실어 가는 첫 탈것.
## 로더가 할 일(climb.gd, 운영자 세션): `var ba := ClimbBalloon.new(); add_child(ba)`; 층을 지을 때 `var tk := cr.plan(n, plats) + mu.plan(n, plats); ba.build(root, ba.plan(n, plats, tk + cp.plan(n, plats, tk)))` (뗏목·버섯·널의 계획을 taken 으로 — 한 틈을 둘이 안 나눈다); 매 틱 `ba.sync(_t)`;
## `_after_step` 의 C 자리(판 읽기·쉼터 문·덤웨이터 다음): `elif not locked and Input.is_action_just_pressed("act") and not on.is_empty(): var g := ba.grab(on, x, z); if not g.is_empty(): ballooning = g; on = {}; vx = 0.0; vy = 0.0; charge = 0.0` (ballooning 은 로더의 새 사전 — holding 처럼; 빈 사전이면 닿지 않거나 기구가 없는 것);
## 타는 매 틱(`_hold` 와 같은 자리, 맨 앞): `if Input.is_action_just_pressed("act"): ba.tug(ballooning)`; `var r := ba.ride_on(ballooning, fig); x = r["x"]; y = r["y"]; apex = y; fig.pose_request = "tug"; if r["done"] or r["lost"]: ballooning = {}; fig.pose_request = ""`
## SPACE 를 놓으면 `var v := ba.let_go(ballooning); vy = (JUMP_MIN + (JUMP_V - JUMP_MIN) * (charge / CHARGE)) * 0.9 + maxf(0.0, v["vy"]); vx = dir * RUN * 0.9; ballooning = {}; 자세 ""`; ↓ 면 `vy = minf(0.0, v["vy"]); ballooning = {}`.
## 단위는 climb.gd 와 같은 px(36px = 1m, +y 위). 점검은 tools/probe_balloon.gd

const PACK := "res://data/climb/balloon.json"
const C = preload("res://scripts/games/climb.gd")
const TAKEN_UP := 220.0    # taken 조각(뗏목·버섯·널) 위로 비워 두는 높이(px)
const STAKE_IN := 8.0      # 말뚝이 턱에서 발판 안쪽으로 들어선 거리(px)
const PILOT := 0.15        # 당기지 않을 때의 불씨 크기 0..1

var pack: Dictionary = {}
var kind: Dictionary = {}       # kinds.balloon
var balloons: Array = []        # 지은 기구 {id, kind "balloon", x, y, w, z, d, hx, ex, out_x, dir, a_y, b_y, dy, dx, gap, tugs, a_id, b_id, node, car, env, flame, rope, creak, whoosh, thud, rider, t0, pt, pf, pto, hand, go, gh}
var t := 0.0                    # 로더의 _t 와 같이 간다(sync)

func _ready() -> void:
	var f := FileAccess.open(PACK, FileAccess.READ)
	if f: pack = JSON.parse_string(f.get_as_text()) as Dictionary
	kind = (pack.get("kinds", {}) as Dictionary).get("balloon", {})

func sync(now: float) -> void:
	t = now

func basket_w() -> float:
	return maxf(20.0, float(kind.get("basket_w", 44.0)))

func lift() -> float:
	return maxf(1.0, float(kind.get("lift", 50.0)))

func drift() -> float:
	return maxf(1.0, float(kind.get("drift", 40.0)))

func tug_s() -> float:
	return maxf(0.05, float(kind.get("tug_s", 0.8)))

func hold_s() -> float:
	return maxf(0.0, float(kind.get("hold_s", 0.6)))

func cool_v() -> float:
	return maxf(0.0, float(kind.get("cool_v", 10.0)))

func sink_s() -> float:
	return maxf(0.1, float(kind.get("sink_s", 4.0)))

func mount_s() -> float:
	return maxf(0.0, float(kind.get("mount_s", 0.25)))

func yank_s() -> float:
	return maxf(0.05, float(kind.get("yank_s", 0.45)))

## 빈 기구가 매인 자리까지 되내려오는 시간 — 오른 높이에 비례(꼭대기에서 sink_s)
func sink_secs(s: Dictionary) -> float:
	return maxf(0.01, sink_s() * float(s.get("gh", 0.0)) / maxf(1.0, float(s["dy"])))

## 되내려오던 기구가 매인 자리에 닿았나
func _settled(s: Dictionary) -> bool:
	return float(s.get("go", -9.0)) > -1.0 and t >= float(s["go"]) + sink_secs(s)

## 바구니 바닥이 매인 자리에서 오른 높이(px) — 타는 중이면 당김의 오름(smoothstep)·버팀·식어 가라앉음, 빈 채면 되내려오는 호, 아니면 0
func hgt(s: Dictionary, at: float) -> float:
	var dy := float(s["dy"])
	if bool(s.get("rider", false)) and at >= float(s.get("t0", at)) + mount_s():
		var pt := float(s.get("pt", -9.0))
		if pt < -1.0: return 0.0
		var k := at - pt; var pto := float(s["pto"])
		if k < tug_s(): return lerpf(float(s["pf"]), pto, smoothstep(0.0, 1.0, k / tug_s()))
		if k < tug_s() + hold_s(): return pto
		return maxf(0.0, pto - cool_v() * (k - tug_s() - hold_s()))
	var go := float(s.get("go", -9.0))
	if go > -1.0 and at >= go:
		var gh := float(s.get("gh", 0.0))
		return lerpf(gh, 0.0, smoothstep(0.0, 1.0, clampf((at - go) / sink_secs(s), 0.0, 1.0)))
	return 0.0

## 그 높이에서 바구니 가운데의 x — 바람이 매인 자리에서 건너편 자리까지 높이에 비례해 실어 간다
func x_of(s: Dictionary, h: float) -> float:
	return float(s["hx"]) + float(s["dx"]) * float(s["dir"]) * clampf(h / maxf(1.0, float(s["dy"])), 0.0, 1.0)

## 기구의 세로 속도 px/s(위가 +) — 두 틱 사이 차로(짧은 h 의 중앙차분)
func hvy(s: Dictionary, at: float) -> float:
	return (hgt(s, at + 0.01) - hgt(s, at - 0.01)) / 0.02

## 불꽃 크기 0..1 — 당긴 순간 1 에서 tug_s 에 걸쳐 불씨로
func flame_k(s: Dictionary, at: float) -> float:
	if not bool(s.get("rider", false)) or float(s.get("pt", -9.0)) < -1.0: return PILOT
	return lerpf(PILOT, 1.0, clampf(1.0 - (at - float(s["pt"])) / tug_s(), 0.0, 1.0))

## 되내려온 빈 기구는 매인 자리에 앉는다(thud); 노드를 지금 자리로
func _process(delta: float) -> void:
	t += delta
	balloons = balloons.filter(func(s: Dictionary) -> bool: return is_instance_valid(s["node"]))   # 지운 층의 것은 뺀다(climb_plank 와 같은 식)
	for sv in balloons:
		var s: Dictionary = sv
		if not bool(s.get("rider", false)) and _settled(s):
			s["go"] = -9.0; s["gh"] = 0.0
			_play(s["thud"])
		_place(s)

## 층 n(테마 층만, 조각의 'only' 층만)의 잇단 두 발판(아래는 조각의 on, 건너편은 far 이고 min_dy..max_dy 높다) 중 틈이 min_gap..max_gap 이고 당김 수(ceil(dy/lift))의 바람(drift)으로 건널 수 있으며
## 기구가 지나는 상자(두 자리를 풍선 반지름만큼 넓힌 x, 아래 윗면 −10..건너편의 풍선 꼭대기)를 다른 발판이 가르지 않고 taken 조각(뗏목·버섯·널)이 닿지 않는 것들 중 가장 높이 오르는 하나. 같은 층·같은 taken 은 늘 같은 답
func plan(n: int, plats: Array, taken: Array = []) -> Array:
	var out: Array = []
	if not (String(C.theme(n)[0]) in (pack.get("themes", []) as Array)): return out
	var hops := plats.filter(func(p: Dictionary) -> bool: return not (String(p["kind"]) in ["rest", "short", "ledge"]))
	var bw := basket_w(); var moor := float(kind.get("moor", 6.0)); var er := float(kind.get("env_r", 32.0))
	var top_up := float(kind.get("env_bottom", 88.0)) + 0.4 / C.K + er * 2.0 + 4.0   # 치마 밑..풍선 꼭대기(치마 0.4m, 풍선 높이 2·er) + 여유
	for pv in (pack.get("pieces", []) as Array):
		var piece: Dictionary = pv
		var only: Dictionary = piece.get("only", {})
		if not only.is_empty() and not _on(n, only): continue
		var kinds: Array = piece.get("on", ["std"]); var fars: Array = piece.get("far", ["std", "ice", "spring", "crumble"])
		var min_gap := float(kind.get("min_gap", 64.0)); var max_gap := float(kind.get("max_gap", 200.0))
		var min_dy := float(kind.get("min_dy", 60.0)); var max_dy := float(kind.get("max_dy", 160.0))
		var rides: Array = []
		for i in range(1, hops.size()):
			var a: Dictionary = hops[i - 1]; var b: Dictionary = hops[i]   # a 가 아래 발판(band() 는 오르는 순서로 쌓는다)
			if not (String(a["kind"]) in kinds and String(b["kind"]) in fars): continue
			var dy := float(b["y"]) - float(a["y"])
			if dy < min_dy or dy > max_dy: continue
			var ax0 := float(a["x"]); var ax1 := ax0 + float(a["w"]); var bx0 := float(b["x"]); var bx1 := bx0 + float(b["w"])
			if bx0 < ax1 and bx1 > ax0: continue   # 겹친 발판 — 틈이 없다
			var dir := 1.0 if bx0 >= ax1 else -1.0
			var gap := bx0 - ax1 if dir > 0.0 else ax0 - bx1
			if gap < min_gap or gap > max_gap: continue
			var dx := gap - bw - moor * 2.0
			var tugs := ceili(dy / lift())
			if dx > float(tugs) * drift(): continue   # 바람이 수평이 되기 전에 다 못 실어 간다
			var edge_a := ax1 if dir > 0.0 else ax0; var edge_b := bx0 if dir > 0.0 else bx1
			var hx := edge_a + dir * (bw / 2.0 + moor); var ex := hx + dir * dx
			var ay := float(a["y"]); var by := float(b["y"])
			var ok := true
			for q in 5:   # 비스듬한 길을 다섯 자리로 — 한 큰 상자보다 정직하다(지그재그로 되돌아오는 위 발판은 매인 자리 위엔 없고 건너편 위엔 비켜 있다)
				var k := float(q) / 4.0
				var cx := lerpf(hx, ex, k); var cy := lerpf(ay, by, k)
				if not _clear(plats, a, b, cx - er, cx + er, cy - 10.0, cy + top_up): ok = false; break
				if not _free(taken, cx - er, cx + er, cy - 10.0, cy + top_up): ok = false; break
			if not ok: continue
			var d := minf(float(a.get("d", C.DEPTH_HALF * 2.0)), float(b.get("d", C.DEPTH_HALF * 2.0)))
			rides.append({ "dy": dy, "gap": gap, "dx": dx, "tugs": tugs, "dir": dir, "hx": hx, "ex": ex, "out_x": edge_b + dir * float(kind.get("step_out", 16.0)), "d": d, "a_y": ay, "b_y": by, "a_id": String(a["id"]), "b_id": String(b["id"]) })
		rides.sort_custom(func(p: Dictionary, q: Dictionary) -> bool: return float(p["dy"]) > float(q["dy"]) if float(p["dy"]) != float(q["dy"]) else (float(p["gap"]) > float(q["gap"]) if float(p["gap"]) != float(q["gap"]) else float(p["a_y"]) < float(q["a_y"])))
		for i in range(0, mini(int(piece.get("max", 1)), rides.size())):
			var g: Dictionary = rides[i]
			var s: Dictionary = g.duplicate()
			s["id"] = "%d.B%d" % [n, i]; s["kind"] = "balloon"; s["x"] = float(g["hx"]) - bw / 2.0; s["y"] = float(g["a_y"]); s["w"] = bw; s["z"] = C.WALL_Z + float(g["d"]) / 2.0
			out.append(s)
	return out

## 층 n 이 {from, every} 에 드나
static func _on(n: int, rule: Dictionary) -> bool:
	var from := int(rule.get("from", 0))
	return n >= from and (n - from) % maxi(1, int(rule.get("every", 1))) == 0

## 기구가 지나는 상자에 두 발판 말고 다른 발판이 걸리지 않나 — 지름길 판이 틈에 있으면 풍선이 걸린다
static func _clear(plats: Array, a: Dictionary, b: Dictionary, x0: float, x1: float, ylo: float, yhi: float) -> bool:
	for pv in plats:
		var p: Dictionary = pv
		if p["id"] == a["id"] or p["id"] == b["id"]: continue
		var py := float(p["y"])
		if py < ylo or py > yhi: continue
		var px0 := float(p["x"]) - 10.0; var px1 := float(p["x"]) + float(p["w"]) + 10.0
		if x1 > px0 and x0 < px1: return false
	return true

## 다른 팩의 조각(taken: 뗏목·널 x·w·y, 버섯 x·y)이 기구의 상자에 닿지 않나 — 조각 위 TAKEN_UP 까지 그 조각의 몸
static func _free(taken: Array, x0: float, x1: float, ylo: float, yhi: float) -> bool:
	for tv in taken:
		var q: Dictionary = tv
		var qx0 := float(q["x"]) - 10.0; var qx1 := float(q["x"]) + float(q.get("w", 0.0)) + 10.0
		var qy := float(q.get("y", 0.0)); var qy0 := qy - 10.0; var qy1 := qy + TAKEN_UP
		if x1 > qx0 and x0 < qx1 and yhi > qy0 and ylo < qy1: return false
	return true

## 발판 on 에 선 몸이 C — 그 발판이 기구의 아래 발판이고 몸이 바구니 가운데에서 reach_x 안이며 기구가 매인 자리에 비어 있으면 올라탄다(돌려주는 사전이 로더의 ballooning — t0 탄 시각, x0 선 자리, creak).
## 건너편 발판·떠 있는 중·누가 타는 중·되내려오는 중이면 아무것도(빈 사전)
func grab(on: Dictionary, x: float, z: float) -> Dictionary:
	var rx := float(kind.get("reach_x", 40.0))
	var id := String(on.get("id", ""))
	for sv in balloons:
		var s: Dictionary = sv
		if absf(z - float(s["z"])) >= float(s["d"]) / 2.0 + C.HZ: continue
		if id != String(s["a_id"]) or absf(x - float(s["hx"])) >= rx: continue
		if bool(s.get("rider", false)) or (float(s.get("go", -9.0)) > -1.0 and not _settled(s)): return {}
		s["go"] = -9.0; s["gh"] = 0.0
		s["rider"] = true; s["t0"] = t; s["pt"] = -9.0; s["hand"] = 1.0
		_play(s["creak"])
		return { "id": String(s["id"]), "kind": "balloon", "t0": t, "x0": x, "y0": float(on.get("y", 0.0)) }
	return {}

## 타는 중 C 한 번 — 올라탄 다음이면 버너 줄 한 번 당김: 지금 높이에서 lift 위까지(건너편 높이에서 멈춘다), 손을 바꾼다, whoosh. 올라타는 중엔 아무것도(false)
func tug(riding: Dictionary) -> bool:
	var s := _find(String(riding.get("id", "")))
	if s.is_empty() or not bool(s.get("rider", false)) or t < float(s["t0"]) + mount_s(): return false
	s["pf"] = hgt(s, t); s["pto"] = minf(float(s["dy"]), float(s["pf"]) + lift()); s["pt"] = t; s["hand"] = -float(s.get("hand", 1.0))
	_play(s["whoosh"])
	return true

## 타는 매 틱 — {x, y, done, lost}: 올라타기(mount_s) → 당김마다 오르며 바람에 실려 가고 바구니 바닥이 건너편 윗면에 닿으면 끝(내려선다 — x 는 건너편 발판 위, creak; 빈 기구는 되내려간다).
## fig 가 있으면 자세의 메타를 적는다: tug_k 당김 1 → 0 (yank_s 에 걸쳐), tug_h 당기는 손 ±1, tug_v 오르는 속도 −1..1. 기구가 사라졌으면 lost
func ride_on(riding: Dictionary, fig: Stick3D = null) -> Dictionary:
	var s := _find(String(riding.get("id", "")))
	if s.is_empty(): return { "x": float(riding.get("x0", 0.0)), "y": float(riding.get("y0", 0.0)), "done": false, "lost": true }
	var k := t - float(riding.get("t0", t))
	var hx := float(s["hx"]); var ay := float(s["a_y"])
	var px := hx; var py := ay; var done := false
	var tk := 0.0; var tv := 0.0
	if k < mount_s():   # 올라타기 — 발판에서 바구니 가운데로 한 걸음
		px = lerpf(float(riding.get("x0", hx)), hx, smoothstep(0.0, 1.0, k / maxf(0.01, mount_s())))
	else:
		var h := hgt(s, t)
		px = x_of(s, h); py = ay + h
		var pt := float(s.get("pt", -9.0))
		if pt > -1.0: tk = clampf(1.0 - (t - pt) / yank_s(), 0.0, 1.0)
		tv = clampf(hvy(s, t) / (lift() / tug_s()), -1.0, 1.0)
		done = h >= float(s["dy"]) - 0.5
	if done:
		s["rider"] = false; s["gh"] = float(s["dy"]); s["go"] = t
		px = float(s["out_x"]); py = float(s["b_y"]); tk = 0.0; tv = 0.0
		_play(s["creak"])
	if fig:
		fig.set_meta("tug_k", tk)
		fig.set_meta("tug_h", float(s.get("hand", 1.0)))
		fig.set_meta("tug_v", tv)
	return { "x": px, "y": py, "done": done, "lost": false }

## 놓는 순간 기구의 세로 속도 {vy} px/s(위가 +) — 뛰면 얹고, 내리면 안고 간다; 빈 기구는 매인 자리로 되내려간다
func let_go(riding: Dictionary) -> Dictionary:
	var s := _find(String(riding.get("id", "")))
	if s.is_empty(): return { "vy": 0.0 }
	var v := hvy(s, t) if t >= float(s.get("t0", t)) + mount_s() else 0.0
	s["gh"] = hgt(s, t); s["rider"] = false; s["go"] = t
	return { "vy": v }

func _find(id: String) -> Dictionary:
	for sv in balloons:
		if String((sv as Dictionary)["id"]) == id: return sv
	return {}

func _play(p: AudioStreamPlayer3D) -> void:
	if p.playing: p.stop()
	p.play()

## 기구를 짓는다 — root 는 그 층의 노드. 노드 원점은 매인 바구니 가운데·아래 발판 높이·발판 깊이 가운데; 턱 안쪽의 말뚝, 매는 줄(_place 가 늘인다), car(바구니 — 바닥·네 벽·테·네 줄·버너·불꽃·풍선·버너 줄·토글), creak, whoosh, thud
func build(root: Node3D, planned: Array) -> void:
	var bw := basket_w() * C.K; var bh := float(kind.get("basket_h", 26.0)) * C.K; var bd := float(kind.get("basket_d", 40.0)) * C.K
	var er := float(kind.get("env_r", 32.0)) * C.K; var eb := float(kind.get("env_bottom", 88.0)) * C.K
	var cord_top := bh + 50.0 * C.K   # 네 줄이 모이는 버너 고리 — 머리(1.94m) 위
	for sv in planned:
		var s: Dictionary = (sv as Dictionary).duplicate()
		var dir := float(s["dir"])
		var node := Node3D.new(); node.position = C.to3(float(s["hx"]), float(s["a_y"]), float(s["z"]) * C.K); root.add_child(node)
		var wicker := _mat(Color("c9a07a")); var oak := _mat(Color("6b4a35")); var paper := _mat(Color("f7f4ef")); var band := _mat(Color("ad7096")); var iron := _mat(Color("3a3640")); var hemp := _mat(Color("e4cfa6"))
		var fire := _mat(Color("e08a2a")); fire.emission_enabled = true; fire.emission = Color("e08a2a"); fire.emission_energy_multiplier = 0.6
		var body_z := (C.PLAYER_Z - float(s["z"])) * C.K        # 몸이 서는 깊이
		var stake_x := -dir * (bw / 2.0 + (float(kind.get("moor", 6.0)) + STAKE_IN) * C.K)
		_box(node, Vector3(0.08, 0.34, 0.08), oak).position = Vector3(stake_x, 0.17, body_z)   # 턱 안쪽의 말뚝
		var rope := _box(node, Vector3(0.025, 1.0, 0.025), hemp)   # 매는 줄 — 말뚝에서 바구니 모서리까지, _place 가 놓는다
		var car := Node3D.new(); node.add_child(car)   # 바구니 — 원점은 바닥 가운데
		_box(car, Vector3(bw, 0.04, bd), wicker).position = Vector3(0, -0.02, body_z)
		_box(car, Vector3(bw, bh, 0.03), wicker).position = Vector3(0, bh / 2.0, body_z + bd / 2.0)   # 앞 벽(몸 정강이를 가린다)
		_box(car, Vector3(bw, bh, 0.03), wicker).position = Vector3(0, bh / 2.0, body_z - bd / 2.0)
		for i in 2: _box(car, Vector3(0.03, bh, bd), wicker).position = Vector3(bw * (0.5 if i == 0 else -0.5), bh / 2.0, body_z)
		_box(car, Vector3(bw + 0.04, 0.04, bd + 0.04), oak).position = Vector3(0, bh, body_z)   # 테 — 손이 쥐는 자리
		for i in 4:   # 네 줄 — 테의 네 모서리에서 버너 고리로 모인다
			var sx := bw * (0.5 if i % 2 == 0 else -0.5); var sz := bd * (0.5 if i < 2 else -0.5)
			var top := Vector3(sx * 0.3, cord_top, body_z + sz * 0.3); var base := Vector3(sx, bh, body_z + sz)
			var cord := _box(car, Vector3(0.02, (top - base).length(), 0.02), hemp)
			cord.transform = Transform3D(Basis(Quaternion(Vector3.UP, (top - base).normalized())), (top + base) / 2.0)   # 바구니의 y 축을 줄 방향으로(look_at 은 트리 밖에서 못 쓴다)
		_box(car, Vector3(0.16, 0.1, 0.16), iron).position = Vector3(0, cord_top + 0.05, body_z)   # 버너
		var flame := MeshInstance3D.new(); var fm := CylinderMesh.new(); fm.top_radius = 0.0; fm.bottom_radius = 0.08; fm.height = 0.3; fm.radial_segments = 8; flame.mesh = fm
		flame.material_override = fire; flame.position = Vector3(0, cord_top + 0.1 + 0.15, body_z); flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; car.add_child(flame)   # 불꽃 — 크기는 _place 가
		var env := Node3D.new(); env.position = Vector3(0, eb, body_z); car.add_child(env)   # 풍선 — 원점은 치마 밑
		var skirt := MeshInstance3D.new(); var km := CylinderMesh.new(); km.top_radius = er * 0.85; km.bottom_radius = 0.3; km.height = 0.4; km.radial_segments = 12; skirt.mesh = km
		skirt.material_override = paper; skirt.position = Vector3(0, 0.2, 0); skirt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; env.add_child(skirt)
		var bulb := MeshInstance3D.new(); var sm := SphereMesh.new(); sm.radius = er; sm.height = er * 2.0; sm.radial_segments = 16; sm.rings = 8; bulb.mesh = sm
		bulb.material_override = paper; bulb.position = Vector3(0, 0.4 + er, 0); bulb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; env.add_child(bulb)
		var stripe := MeshInstance3D.new(); var tm := CylinderMesh.new(); tm.top_radius = er * 1.01; tm.bottom_radius = er * 1.01; tm.height = 0.14; tm.radial_segments = 16; stripe.mesh = tm
		stripe.material_override = band; stripe.position = Vector3(0, 0.4 + er, 0); stripe.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; env.add_child(stripe)   # 자주 띠 — 강조색만
		var hang := cord_top - 1.7   # 버너에서 토글까지(얼굴 높이 1.7m 에 토글 — 손이 올라가 쥔다)
		_box(car, Vector3(0.015, hang, 0.015), hemp).position = Vector3(dir * 0.22, cord_top - hang / 2.0, body_z)   # 버너 줄 — 몸 옆에 늘어진다
		_box(car, Vector3(0.05, 0.08, 0.05), oak).position = Vector3(dir * 0.22, 1.7 - 0.04, body_z)   # 토글
		var creak := AudioStreamPlayer3D.new(); creak.stream = _tick_wav(float(kind.get("creak_hz", 140)), 0.2); creak.volume_db = -10.0; creak.unit_size = 6.0; creak.max_distance = 30.0; node.add_child(creak)
		var whoosh := AudioStreamPlayer3D.new(); whoosh.stream = _whoosh_wav(float(kind.get("whoosh_s", 0.5))); whoosh.volume_db = -8.0; whoosh.unit_size = 6.0; whoosh.max_distance = 30.0; node.add_child(whoosh)
		var thud := AudioStreamPlayer3D.new(); thud.stream = _tick_wav(float(kind.get("thud_hz", 180)), 0.15); thud.volume_db = -8.0; thud.unit_size = 6.0; thud.max_distance = 30.0; node.add_child(thud)
		s["node"] = node; s["car"] = car; s["env"] = env; s["flame"] = flame; s["rope"] = rope; s["creak"] = creak; s["whoosh"] = whoosh; s["thud"] = thud
		s["rider"] = false; s["t0"] = -9.0; s["pt"] = -9.0; s["pf"] = 0.0; s["pto"] = 0.0; s["hand"] = 1.0; s["go"] = -9.0; s["gh"] = 0.0
		balloons.append(s)
		_place(s)

## 바구니·줄·불꽃·풍선을 지금 자리로 — 바구니는 높이와 바람에 실린 x 로, 매는 줄은 말뚝 끝에서 바구니 모서리로 늘고, 불꽃은 당김 뒤 잦아들며, 풍선은 떠 있을수록 느리게 흔들린다(살아 있는 것은 움직인다)
func _place(s: Dictionary) -> void:
	var h := hgt(s, t); var dir := float(s["dir"])
	var bw := basket_w() * C.K; var bh := float(kind.get("basket_h", 26.0)) * C.K
	var car: Node3D = s["car"]
	car.position = Vector3((x_of(s, h) - float(s["hx"])) * C.K, h * C.K, 0)
	var body_z := (C.PLAYER_Z - float(s["z"])) * C.K
	var stake_x := -dir * (bw / 2.0 + (float(kind.get("moor", 6.0)) + STAKE_IN) * C.K)
	var a := Vector3(stake_x, 0.3, body_z); var b := car.position + Vector3(-dir * bw / 2.0, bh, body_z)
	var rope: Node3D = s["rope"]; var rl := maxf(0.05, (b - a).length())
	rope.transform = Transform3D(Basis(Quaternion(Vector3.UP, (b - a).normalized())), (a + b) / 2.0)
	rope.scale = Vector3(1.0, rl, 1.0)
	var f := flame_k(s, t)
	(s["flame"] as Node3D).scale = Vector3(0.6 + 0.4 * f, 0.2 + 0.8 * f, 0.6 + 0.4 * f)
	(s["env"] as Node3D).rotation.z = 0.03 * sin(t * 1.3) * (0.3 + 0.7 * clampf(h / maxf(1.0, float(s["dy"])), 0.0, 1.0))

func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.albedo_color = c; m.roughness = 1.0
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON; m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return m

func _box(parent: Node3D, size: Vector3, m: StandardMaterial3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = size; mi.mesh = bm; mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF   # 발판과 같은 규칙 — 그림자는 사람만
	parent.add_child(mi); return mi

## 고리버들·앉는 소리 — 짧은 기음이 빠르게 잦아든다(널의 creak 과 같은 식). 한 번 재생, 반복 없음
static func _tick_wav(hz: float, secs: float) -> AudioStreamWAV:
	var rate := 22050; var count := int(rate * secs)
	var data := PackedByteArray(); data.resize(count * 2)
	for i in count:
		var k := float(i) / count
		var ph := float(i) * hz * TAU / rate
		var v := (sin(ph) * 0.5 + sin(ph * 2.3) * 0.2) * exp(-k * 9.0)
		data.encode_s16(i * 2, int(v * 22000.0))
	var w := AudioStreamWAV.new(); w.format = AudioStreamWAV.FORMAT_16_BITS; w.mix_rate = rate; w.stereo = false; w.data = data
	return w

## 버너 소리 — 저역만 남긴 잡음이 부풀었다 잦아든다(whoosh). 씨앗을 고정해 늘 같은 소리, 한 번 재생, 반복 없음
static func _whoosh_wav(secs: float) -> AudioStreamWAV:
	var rate := 22050; var count := int(rate * secs)
	var data := PackedByteArray(); data.resize(count * 2)
	var r := RandomNumberGenerator.new(); r.seed = 0x6261
	var lp := 0.0
	for i in count:
		var k := float(i) / count
		lp += (r.randf() * 2.0 - 1.0 - lp) * 0.18   # 저역 통과 — 바람 같은 숨
		var env := pow(sin(PI * k), 0.6)
		data.encode_s16(i * 2, int(clampf(lp * env * 2.2, -1.0, 1.0) * 20000.0))
	var w := AudioStreamWAV.new(); w.format = AudioStreamWAV.FORMAT_16_BITS; w.mix_rate = rate; w.stereo = false; w.data = data
	return w
