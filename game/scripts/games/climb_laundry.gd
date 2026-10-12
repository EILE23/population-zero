class_name ClimbLaundry
extends Node3D
## Climb 콘텐츠 팩 '빨랫줄'(운영자 2026-10-06 밤: "Climb는 컨텐츠 자체의 질과 양을 늘리는 거" — 팩은 data/climb/*.json 자료, 로더는 운영자 세션이 잇는다; climb.gd 는 CI 가 안 건드린다).
## 옛 회관(Old hall) 층(바람구멍 층은 뺀다)의 잇단 두 still 발판 사이 틈 — 아래 발판의 틈 쪽 가장자리 안 inset 에 선 말뚝(post_lo)에서 위 발판의 말뚝(post_hi)으로 삼줄이 올라가고, 줄엔 홑이불 셋이 집게로 걸려 제 박자로 펄럭인다.
## 공중에서 ↑ 로 줄 아래 어디서든 손이 닿으면(hang 위 reach_y 안) 붙잡고(creak) ← → 로 손을 번갈아 옮겨 간다(pace; stride 마다 한 손) — 몸무게에 줄이 가운데서 sag 처진다. 이불 밑에선 손이 반으로 느려지고(sheet_k) 이불이 얼굴로 펄럭여 든다(flap).
## 한 이불 밑에 peg_s 넘게 매달려 있으면 집게가 튄다(pop): 이불이 머리 위로 떨어져 덮인다 — 줄에선 손은 계속 가되 고개는 천 속, 내려선 뒤엔 hood_s 동안 눈먼 걸음(blind — 자세가 천을 당겨 벗고 걸음은 반), 그 뒤 이불은 아래 말뚝 밑에 무더기로 놓였다가 repeg_s 뒤 도로 줄에 걸린다.
## 부드러운 장애물이 처음으로 몸에 따라오는 팩. 밀지도, 떨어뜨리지도, 거절하지도 않는다 — 틈을 건너는 맨 점프는 그대로(이불은 천, 줄은 ↑ 로만 잡힌다), 어느 말뚝에서든 놓으면 제 발판에 떨어진다.
## 매달린 자세는 shimmy(stick3d_shimmy.gd — 두 손이 머리 위 줄을 번갈아 쥐고 발목을 꼰 다리가 흔들리며 이불이 들면 고개를 돌린다; 덮이면 고개가 천 속으로, 내려선 뒤엔 두 손이 천을 당겨 벗는다).
## zip(가로대를 쥐고 비탈을 미끄러진다)·dangle(흔들리는 가로대)·fly(그네)와 다르다: 이건 손이 제 걸음을 내는 몸, 빠르기가 손의 것이다.
## 로더가 할 일(climb.gd, 운영자 세션): `var cl := ClimbLaundry.new(); add_child(cl)`; 층을 지을 때 `var bl := cb.plan(n, plats); cl.build(root, cl.plan(n, plats, bl + cr.plan(n, plats, bl)))` (종 줄·회전문의 계획을 taken 으로 — 그 틈은 비켜 간다); 매 틱 `cl.sync(_t)`;
## 공중에서 ↑(dirz < 0)이고 홀드·다른 팩의 잡기가 비었으면 `var g := cl.grab(x, y, z); if not g.is_empty(): shimmying = g; on = {}; vx = 0.0; vy = 0.0; charge = 0.0` (shimmying 은 로더의 새 사전 — holding 처럼);
## 매달린 매 틱(`_hold` 와 같은 자리, 맨 앞): `var r := cl.ride(shimmying, dt, dir, fig); x = r["x"]; y = r["y"]; apex = y; if dir != 0.0: face = dir; fig.pose_request = "shimmy"; stamina -= dt * 0.09; if r["lost"]: shimmying = {}; fig.pose_request = ""`;
## SPACE 를 놓으면 `cl.let_go(shimmying); vy = (JUMP_MIN + (JUMP_V - JUMP_MIN) * (charge / CHARGE)) * 0.9; vx = dir * RUN * 0.9; shimmying = {}; 자세 ""`; ↓ 나 힘이 다하면 `cl.let_go(shimmying); vy = 0.0; shimmying = {}; 자세 ""`.
## 매달리지 않은 매 틱(로더 제 착지 판정 뒤): `if cl.blind(not on.is_empty(), fig): fig.pose_request = "shimmy"; dir *= 0.5; elif fig.pose_request == "shimmy" and shimmying.is_empty(): fig.pose_request = ""` — 덮인 몸은 땅에 선 뒤 hood_s 동안 반걸음.
## 단위는 climb.gd 와 같은 px(36px = 1m, +y 위). 점검은 tools/probe_laundry.gd

const PACK := "res://data/climb/laundry.json"
const C = preload("res://scripts/games/climb.gd")
const TAKEN_UP := 120.0    # taken 조각(종 줄·회전문) 위로 비워 두는 높이(px) — 그 위에 선 몸
const PEG_W := 0.025       # 집게 폭(m)

var pack: Dictionary = {}
var kind: Dictionary = {}       # kinds.line
var lines: Array = []           # 지은 빨랫줄 {id, kind "laundry", x, y, w, z, d, dir, gap, lo_x, lo_y, hi_x, hi_y, run, rise, len, a_id, b_id, a_y, b_y, node, seg1, seg2, sheets, creak, flap, pop, held, pos, under, under_t}
var hood: Dictionary = {}       # 머리를 덮은 이불 {line, k, fig, land}
var t := 0.0                    # 로더의 _t 와 같이 간다(sync)

func _ready() -> void:
	var f := FileAccess.open(PACK, FileAccess.READ)
	if f: pack = JSON.parse_string(f.get_as_text()) as Dictionary
	kind = (pack.get("kinds", {}) as Dictionary).get("line", {})

func sync(now: float) -> void:
	t = now

func hang() -> float:
	return float(kind.get("hang", 58.0))

func inset() -> float:
	return maxf(0.0, float(kind.get("inset", 24.0)))

func pace() -> float:
	return maxf(1.0, float(kind.get("pace", 110.0)))

func sheet_k() -> float:
	return clampf(float(kind.get("sheet_k", 0.5)), 0.05, 1.0)

func stride() -> float:
	return maxf(1.0, float(kind.get("stride", 24.0)))

func sheet_w() -> float:
	return maxf(2.0, float(kind.get("sheet_w", 30.0)))

func sheet_h() -> float:
	return maxf(2.0, float(kind.get("sheet_h", 48.0)))

func peg_s() -> float:
	return maxf(0.05, float(kind.get("peg_s", 1.5)))

func hood_s() -> float:
	return maxf(0.05, float(kind.get("hood_s", 1.0)))

func repeg_s() -> float:
	return maxf(0.05, float(kind.get("repeg_s", 8.0)))

## 줄 위 아래 말뚝에서 p px 간 자리(px) — 처짐 없이
func along(s: Dictionary, p: float) -> Vector2:
	var u := clampf(p / maxf(1.0, float(s["run"])), 0.0, 1.0)
	return Vector2(float(s["lo_x"]) + float(s["dir"]) * u * float(s["run"]), lerpf(float(s["lo_y"]), float(s["hi_y"]), u))

## 몸이 매달린 자리의 처짐(px) — 가운데서 sag, 말뚝에선 0
func dip(s: Dictionary, p: float) -> float:
	return float(kind.get("sag", 8.0)) * sin(PI * clampf(p / maxf(1.0, float(s["run"])), 0.0, 1.0))

## 이불 k 가 걸린 자리(아래 말뚝에서 px) — run 을 sheets + 1 로 나눈 자리
func sheet_p(s: Dictionary, k: int) -> float:
	var n := maxi(1, int(kind.get("sheets", 3)))
	return float(s["run"]) * float(k + 1) / float(n + 1)

## 몸(p)이 이불 밑인가 — 그 이불 번호, 아니면 −1 (줄에 걸린 이불만)
func under(s: Dictionary, p: float) -> int:
	for k in (s["sheets"] as Array).size():
		var sh: Dictionary = (s["sheets"] as Array)[k]
		if String(sh["state"]) != "pegged": continue
		if absf(p - sheet_p(s, k)) <= sheet_w() / 2.0: return k
	return -1

## 집게가 튄 이불의 되걸기, 이불의 펄럭임, 줄의 처짐 — 살아 있는 것은 움직인다
func _process(delta: float) -> void:
	t += delta
	lines = lines.filter(func(s: Dictionary) -> bool: return is_instance_valid(s["node"]))   # 지운 층의 것은 뺀다(climb_zip 과 같은 식)
	if not hood.is_empty() and (not is_instance_valid(hood["fig"]) or not is_instance_valid((hood["line"] as Dictionary)["node"])): hood = {}
	for sv in lines:
		var s: Dictionary = sv
		for k in (s["sheets"] as Array).size():
			var sh: Dictionary = (s["sheets"] as Array)[k]
			if String(sh["state"]) == "heap" and t >= float(sh["t_heap"]) + repeg_s(): _repeg(s, k)
		_place(s)

## 층 n(테마 층만, 바람구멍 층은 뺀다)의 잇단 두 still 발판(조각의 on; 아래 a·위 b) 중 틈이 min_gap..max_gap 이고 b 가 min_dy..max_dy 높으며 줄 상자를 다른 발판이 가르지 않고 taken 조각이 닿지 않는 짝들 중 가장 넓은 틈 하나 — 거기에 빨랫줄. 같은 층·같은 taken 은 늘 같은 답
func plan(n: int, plats: Array, taken: Array = []) -> Array:
	var out: Array = []
	if not (String(C.theme(n)[0]) in (pack.get("themes", []) as Array)): return out
	var min_gap := float(kind.get("min_gap", 90.0)); var max_gap := float(kind.get("max_gap", 220.0))
	var min_dy := float(kind.get("min_dy", 60.0)); var max_dy := float(kind.get("max_dy", 120.0))
	var post_lo := float(kind.get("post_lo", 136.0)); var post_hi := float(kind.get("post_hi", 96.0)); var ins := inset()
	var room := ins + 2.0 * C.HW + 4.0   # 말뚝과 그 안쪽에 내려서는 몸이 들어갈 발판 폭
	for pv in (pack.get("pieces", []) as Array):
		var piece: Dictionary = pv
		var only: Dictionary = piece.get("only", {})
		if not only.is_empty() and not _on(n, only): continue
		var kinds: Array = piece.get("on", ["std", "ice"])
		var hops: Array = plats.filter(func(p: Dictionary) -> bool: return not (String(p["kind"]) in ["rest", "short", "ledge"]))
		var spans: Array = []
		for i in range(1, hops.size()):
			var a: Dictionary = hops[i - 1]; var b: Dictionary = hops[i]   # a 가 아래 발판(band() 는 오르는 순서로 쌓는다)
			if not (String(a["kind"]) in kinds and String(b["kind"]) in kinds): continue
			var dy := float(b["y"]) - float(a["y"])
			if dy < min_dy or dy > max_dy: continue
			var ax0 := float(a["x"]); var ax1 := ax0 + float(a["w"]); var bx0 := float(b["x"]); var bx1 := bx0 + float(b["w"])
			if bx0 < ax1 and bx1 > ax0: continue   # 겹친 발판 — 틈이 없다
			var dir := 1.0 if bx0 >= ax1 else -1.0   # 아래 발판에서 위 발판 쪽 — 위가 오른쪽이면 +x 로 올라간다
			var gap := bx0 - ax1 if dir > 0.0 else ax0 - bx1
			if gap < min_gap or gap > max_gap: continue
			if float(a["w"]) < room or float(b["w"]) < room: continue
			var lo_x := ax1 - ins if dir > 0.0 else ax0 + ins
			var hi_x := bx0 + ins if dir > 0.0 else bx1 - ins
			var lo_y := float(a["y"]) + post_lo; var hi_y := float(b["y"]) + post_hi
			var x0 := minf(lo_x, hi_x) - C.HW - 4.0; var x1 := maxf(lo_x, hi_x) + C.HW + 4.0
			if not _clear(plats, a, b, x0, x1, float(a["y"]) + 1.0, hi_y + 10.0): continue
			if not _free(taken, x0, x1, float(a["y"]) + 1.0, hi_y + 10.0): continue
			var d := minf(float(a.get("d", C.DEPTH_HALF * 2.0)), float(b.get("d", C.DEPTH_HALF * 2.0)))
			spans.append({ "gap": gap, "dir": dir, "lo_x": lo_x, "lo_y": lo_y, "hi_x": hi_x, "hi_y": hi_y, "d": d,
				"a_id": String(a["id"]), "b_id": String(b["id"]), "a_y": float(a["y"]), "b_y": float(b["y"]) })
		spans.sort_custom(func(p: Dictionary, q: Dictionary) -> bool: return float(p["gap"]) > float(q["gap"]) if float(p["gap"]) != float(q["gap"]) else float(p["a_y"]) < float(q["a_y"]))
		for i in range(0, mini(int(piece.get("max", 1)), spans.size())):
			var g: Dictionary = spans[i]
			var s: Dictionary = g.duplicate()
			var run := absf(float(g["hi_x"]) - float(g["lo_x"])); var rise := float(g["hi_y"]) - float(g["lo_y"])
			s["id"] = "%d.L%d" % [n, i]; s["kind"] = "laundry"; s["x"] = minf(float(g["lo_x"]), float(g["hi_x"])); s["w"] = run; s["y"] = float(g["a_y"]); s["z"] = C.WALL_Z + float(g["d"]) / 2.0
			s["run"] = run; s["rise"] = rise; s["len"] = sqrt(run * run + rise * rise)
			out.append(s)
	return out

## 층 n 이 {from, every} 에 드나
static func _on(n: int, rule: Dictionary) -> bool:
	var from := int(rule.get("from", 0))
	return n >= from and (n - from) % maxi(1, int(rule.get("every", 1))) == 0

## 줄 상자(두 말뚝 사이 + 몸 폭, 아래 발판 윗면..위 말뚝 머리)에 두 발판 말고 다른 발판이 걸리지 않나 — 움직이는 발판은 진폭째
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

## 다른 팩의 조각(taken: x·w·y)이 줄 상자에 닿지 않나 — 조각 위 TAKEN_UP 까지 그 조각의 몸
static func _free(taken: Array, x0: float, x1: float, ylo: float, yhi: float) -> bool:
	for tv in taken:
		var q: Dictionary = tv
		var qx0 := float(q["x"]) - 10.0; var qx1 := float(q["x"]) + float(q.get("w", 0.0)) + 10.0
		var qy := float(q.get("y", 0.0)); var qy0 := qy - 10.0; var qy1 := qy + TAKEN_UP
		if x1 > qx0 and x0 < qx1 and yhi > qy0 and ylo < qy1: return false
	return true

## 공중에서 ↑ — 손(발 + hang)이 두 말뚝 사이 줄의 reach_y 안이면 잡는다(creak): 돌려주는 사전의 x·y 가 몸의 자리(줄 밑 hang, 처짐째), dir 이 올라가는 쪽. 누가 잡고 있으면 아니다
func grab(x: float, y: float, z: float) -> Dictionary:
	var ry := float(kind.get("reach_y", 22.0))
	for sv in lines:
		var s: Dictionary = sv
		if absf(z - float(s["z"])) >= float(s["d"]) / 2.0 + C.HZ: continue
		if bool(s.get("held", false)): continue
		var p := float(s["dir"]) * (x - float(s["lo_x"]))
		if p < 0.0 or p > float(s["run"]): continue
		var r := along(s, p)
		if absf(y + hang() - r.y) < ry:
			s["held"] = true; s["pos"] = p; s["under"] = -1; s["under_t"] = 0.0
			_play(s["creak"])
			return { "id": String(s["id"]), "kind": "laundry", "x": r.x, "y": r.y - dip(s, p) - hang(), "t0": t, "dir": float(s["dir"]) }
	return {}

## 매달린 매 틱 — {x, y, lost, hooded, end}: ← → (dir) 로 손이 pace 로 간다(이불 밑에선 sheet_k 배, 그 이불이 얼굴로 든다; 한 이불 밑에 peg_s 넘게 있으면 집게가 튀어 이불이 머리를 덮는다). end 는 손이 닿은 말뚝(−1 아래, +1 위, 0 사이). 줄이 사라졌거나 잡고 있지 않으면 lost.
## fig 가 있으면 자세의 메타를 적는다: shimmy_v 가는 속도 −1..1(+x 가 +), shimmy_ph 손 번갈음 0..1, shimmy_sheet 얼굴에 든 이불 0..1, shimmy_hood 머리를 덮은 이불 0..1, shimmy_walk 0(매달림)
func ride(riding: Dictionary, dt: float, dir: float, fig: Stick3D = null) -> Dictionary:
	var s := _find(String(riding.get("id", "")))
	if s.is_empty() or not bool(s.get("held", false)): return { "x": float(riding.get("x", 0.0)), "y": float(riding.get("y", 0.0)), "lost": true, "hooded": false, "end": 0 }
	var p := float(s["pos"]); var run := float(s["run"])
	var uk := under(s, p)
	var k := sheet_k() if uk >= 0 else 1.0
	var step := signf(dir) * float(s["dir"]) * pace() * k * dt
	p = clampf(p + step, 0.0, run)
	if uk >= 0 and uk == int(s["under"]): s["under_t"] = float(s["under_t"]) + dt
	else:
		s["under_t"] = 0.0
		if uk >= 0: _play(s["flap"])   # 이불 밑에 든다 — 얼굴에 펄럭
	s["under"] = uk; s["pos"] = p
	if uk >= 0 and float(s["under_t"]) >= peg_s() and hood.is_empty(): _pop(s, uk, fig)
	var r := along(s, p)
	var hooded := _hooded(s)
	if fig:
		fig.set_meta("shimmy_v", signf(dir) * float(s["dir"]) * k)
		fig.set_meta("shimmy_ph", fposmod(p / stride(), 1.0))
		fig.set_meta("shimmy_sheet", 1.0 if (uk >= 0 and not hooded) else 0.0)
		fig.set_meta("shimmy_hood", 1.0 if hooded else 0.0)
		fig.set_meta("shimmy_walk", 0.0)
	return { "x": r.x, "y": r.y - dip(s, p) - hang(), "lost": false, "hooded": hooded, "end": -1 if p <= 0.0 else (1 if p >= run else 0) }

## 놓는다(creak) — 줄은 곧바로 다시 잡힌다. 머리를 덮은 이불은 그대로 따라간다(hooded)
func let_go(riding: Dictionary) -> Dictionary:
	var s := _find(String(riding.get("id", "")))
	if s.is_empty() or not bool(s.get("held", false)): return { "hooded": false }
	s["held"] = false; s["under"] = -1; s["under_t"] = 0.0
	_play(s["creak"])
	return { "hooded": _hooded(s) }

## 매달리지 않은 틱의 눈먼 걸음 — 머리를 덮은 이불이 있으면 true: 땅에 선 첫 틱(landed)부터 hood_s 동안 자세 메타(shimmy_walk 0..1)를 적고, 다 되면 이불을 아래 말뚝 밑 무더기로 떨어뜨리고 false
func blind(landed: bool, fig: Stick3D = null) -> bool:
	if hood.is_empty(): return false
	if float(hood["land"]) < 0.0:
		if landed: hood["land"] = t
		else: return true
	var w := (t - float(hood["land"])) / hood_s()
	if w >= 1.0:
		_heap(hood["line"], int(hood["k"]))
		if fig:
			for m in ["shimmy_v", "shimmy_ph", "shimmy_sheet", "shimmy_hood", "shimmy_walk"]:
				if fig.has_meta(m): fig.remove_meta(m)
		hood = {}
		return false
	if fig:
		fig.set_meta("shimmy_v", 0.0); fig.set_meta("shimmy_sheet", 0.0); fig.set_meta("shimmy_hood", 1.0); fig.set_meta("shimmy_walk", w)
	return true

## 집게가 튄다 — 이불이 머리(socket_hat)로 옮겨 간다(pop); fig 가 없으면 바로 무더기로
func _pop(s: Dictionary, k: int, fig: Stick3D) -> void:
	var sh: Dictionary = (s["sheets"] as Array)[k]
	_play(s["pop"])
	s["under"] = -1; s["under_t"] = 0.0
	if fig == null:
		_heap(s, k); return
	sh["state"] = "hood"
	var pivot: Node3D = sh["pivot"]
	_move(pivot, fig.socket_hat)
	pivot.position = Vector3(0, 0.08, 0); pivot.rotation = Vector3.ZERO; pivot.scale = Vector3(0.75, 0.75, 0.75)
	hood = { "line": s, "k": k, "fig": fig, "land": -9.0 }

## 이불을 아래 말뚝 밑에 무더기로 — repeg_s 뒤 도로 걸린다
func _heap(s: Dictionary, k: int) -> void:
	var sh: Dictionary = (s["sheets"] as Array)[k]
	var pivot: Node3D = sh["pivot"]
	_move(pivot, s["node"])
	pivot.position = Vector3(float(s["dir"]) * 0.25, 0.05, 0.0); pivot.rotation = Vector3(-PI / 2.0, 0, 0); pivot.scale = Vector3(1.0, 0.45, 1.0)
	sh["state"] = "heap"; sh["t_heap"] = t

## 이불을 줄에 도로 건다
func _repeg(s: Dictionary, k: int) -> void:
	var sh: Dictionary = (s["sheets"] as Array)[k]
	var pivot: Node3D = sh["pivot"]
	pivot.rotation = Vector3.ZERO; pivot.scale = Vector3.ONE
	sh["state"] = "pegged"

## 한 노드를 다른 부모 밑으로 — 트리 밖에서도 된다
static func _move(n: Node3D, to: Node3D) -> void:
	var p := n.get_parent()
	if p == to: return
	if p: p.remove_child(n)
	to.add_child(n)

## 이 줄의 이불이 머리를 덮고 있나
func _hooded(s: Dictionary) -> bool:
	return not hood.is_empty() and String((hood["line"] as Dictionary)["id"]) == String(s["id"])

func _find(id: String) -> Dictionary:
	for sv in lines:
		if String((sv as Dictionary)["id"]) == id: return sv
	return {}

func _play(p: AudioStreamPlayer3D) -> void:
	if p.playing: p.stop()
	p.play()

## 빨랫줄을 짓는다 — root 는 그 층의 노드. 노드 원점은 아래 말뚝 밑(lo_x, a_y, z); 말뚝 둘과 머리쇠, 줄 두 토막(아래 말뚝→손, 손→위 말뚝 — _place 가 길이·각을 맞춘다), 이불 셋(집게 둘씩), creak·flap·pop
func build(root: Node3D, planned: Array) -> void:
	for sv in planned:
		var s: Dictionary = (sv as Dictionary).duplicate()
		var node := Node3D.new(); node.position = C.to3(float(s["lo_x"]), float(s["a_y"]), float(s["z"]) * C.K); root.add_child(node)
		var wood := _mat(Color("8a6a4a")); var hemp := _mat(Color("c9b48a")); var brass := _mat(Color("c9a07a")); var paper := _mat(Color("f7f4ef")); var plate := _mat(Color("ad7096"))
		var body_z := (C.PLAYER_Z - float(s["z"])) * C.K   # 몸이 서는 깊이 — 줄은 손 자리에
		var lh := (float(s["lo_y"]) - float(s["a_y"])) * C.K; var hh := (float(s["hi_y"]) - float(s["b_y"])) * C.K
		var hx := (float(s["hi_x"]) - float(s["lo_x"])) * C.K; var hy := (float(s["b_y"]) - float(s["a_y"])) * C.K
		_box(node, Vector3(0.08, lh, 0.08), wood).position = Vector3(0, lh / 2.0, body_z)                        # 아래 말뚝
		_box(node, Vector3(0.14, 0.04, 0.14), brass).position = Vector3(0, lh + 0.02, body_z)                    # 머리쇠
		_box(node, Vector3(0.08, hh, 0.08), wood).position = Vector3(hx, hy + hh / 2.0, body_z)                  # 위 말뚝
		_box(node, Vector3(0.14, 0.04, 0.14), brass).position = Vector3(hx, hy + hh + 0.02, body_z)              # 머리쇠
		var seg1 := _box(node, Vector3(0.015, 1.0, 0.015), hemp)     # 줄 아래 토막 — 길이·각은 _place
		var seg2 := _box(node, Vector3(0.015, 1.0, 0.015), hemp)     # 줄 위 토막
		var sheets: Array = []
		for k in maxi(1, int(kind.get("sheets", 3))):
			var pivot := Node3D.new(); node.add_child(pivot)          # 원점은 줄 위의 집게 자리
			var cloth := _box(pivot, Vector3(sheet_w() * C.K, sheet_h() * C.K, 0.01), paper)
			cloth.position = Vector3(0, -sheet_h() * C.K / 2.0, 0)
			if k == 1: _box(pivot, Vector3(sheet_w() * C.K, 0.05, 0.012), plate).position = Vector3(0, -sheet_h() * C.K + 0.12, 0)   # 가운데 이불의 띠 — 강조색만
			for q in [-1.0, 1.0]:
				_box(pivot, Vector3(PEG_W, 0.06, 0.03), brass).position = Vector3((q as float) * (sheet_w() * C.K / 2.0 - 0.03), 0.01, 0)   # 집게
			sheets.append({ "pivot": pivot, "state": "pegged", "t_heap": -9.0 })
		var creak := AudioStreamPlayer3D.new(); creak.stream = _tick_wav(float(kind.get("creak_hz", 140)), 0.12); creak.volume_db = -12.0; creak.unit_size = 6.0; creak.max_distance = 30.0; node.add_child(creak)
		var flap := AudioStreamPlayer3D.new(); flap.stream = _tick_wav(float(kind.get("flap_hz_snd", 180)), 0.08); flap.volume_db = -14.0; flap.unit_size = 6.0; flap.max_distance = 30.0; node.add_child(flap)
		var pop := AudioStreamPlayer3D.new(); pop.stream = _tick_wav(float(kind.get("pop_hz", 900)), 0.05); pop.volume_db = -10.0; pop.unit_size = 6.0; pop.max_distance = 30.0; node.add_child(pop)
		s["node"] = node; s["seg1"] = seg1; s["seg2"] = seg2; s["sheets"] = sheets; s["creak"] = creak; s["flap"] = flap; s["pop"] = pop
		s["held"] = false; s["pos"] = 0.0; s["under"] = -1; s["under_t"] = 0.0
		lines.append(s)
		_place(s)

## 줄 두 토막을 손 자리(처짐째)로, 걸린 이불을 제 자리에서 펄럭이게(얼굴에 든 이불은 더 크게)
func _place(s: Dictionary) -> void:
	var held := bool(s["held"]); var p := float(s["pos"])
	var body_z := (C.PLAYER_Z - float(s["z"])) * C.K
	var lo := Vector3(0, (float(s["lo_y"]) - float(s["a_y"])) * C.K, body_z)
	var hi := Vector3((float(s["hi_x"]) - float(s["lo_x"])) * C.K, (float(s["hi_y"]) - float(s["a_y"])) * C.K, body_z)
	var hp := along(s, p); var mid := Vector3((hp.x - float(s["lo_x"])) * C.K, (hp.y - dip(s, p) - float(s["a_y"])) * C.K, body_z) if held else hi
	_line(s["seg1"], lo, mid); _line(s["seg2"], mid, hi)
	var amp := float(kind.get("flap_amp", 0.35)); var hz := float(kind.get("flap_hz", 0.7))
	for k in (s["sheets"] as Array).size():
		var sh: Dictionary = (s["sheets"] as Array)[k]
		if String(sh["state"]) != "pegged": continue
		var sp := sheet_p(s, k); var r := along(s, sp)
		var y := r.y
		if held: y -= dip(s, p) * (sp / p if sp < p else (float(s["run"]) - sp) / maxf(1.0, float(s["run"]) - p))   # 두 토막 줄 위의 자리
		var pivot: Node3D = sh["pivot"]
		pivot.position = Vector3((r.x - float(s["lo_x"])) * C.K, (y - float(s["a_y"])) * C.K, body_z)
		pivot.rotation.x = amp * sin(t * hz * TAU + float(k) * 2.1) * (1.6 if (held and int(s["under"]) == k) else 1.0)

## 한 토막 상자를 두 점 사이로 — 돌린 뒤 제 축으로 늘인다(look_at 은 트리 밖에서 못 쓴다)
static func _line(mi: Node3D, from: Vector3, to: Vector3) -> void:
	var l := maxf(0.02, (to - from).length())
	mi.transform = Transform3D(Basis(Quaternion(Vector3.UP, (to - from) / l)) * Basis.from_scale(Vector3(1, l, 1)), (from + to) / 2.0)

func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.albedo_color = c; m.roughness = 1.0
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON; m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return m

func _box(parent: Node3D, size: Vector3, m: StandardMaterial3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = size; mi.mesh = bm; mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF   # 발판과 같은 규칙 — 그림자는 사람만
	parent.add_child(mi); return mi

## 줄·천·집게 소리 — 짧은 기음이 빠르게 잦아든다: creak(0.12초, 삼줄이 운다)·flap(0.08초, 천이 얼굴을 친다)·pop(0.05초, 집게가 튄다). 한 번 재생, 반복 없음
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
