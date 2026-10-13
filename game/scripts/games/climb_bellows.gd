class_name ClimbBellows
extends Node3D
## Climb 콘텐츠 팩 '풀무 승강기'(운영자 2026-10-06 밤: "Climb는 컨텐츠 자체의 질과 양을 늘리는 거" — 팩은 data/climb/*.json 자료, 로더는 운영자 세션이 잇는다; climb.gd 는 CI 가 안 건드린다).
## 태엽(Clockwork) 층(바람구멍 층은 뺀다)의 잇단 두 발판 사이 틈(min_gap..max_gap, 위 발판이 min_dy..max_dy 높이; 아래 발판은 still, 위 발판은 부서지거나 튀어도 된다 — 서는 건 아래뿐) — 아래 발판의 틈 쪽 가장자리에 가죽 풀무가 박혀 있고 그 윗판(board_w, 발판 높이)이 발판이다;
## 풀무 밑에서 놋쇠 관이 내려가 틈을 건너 놋쇠 실린더로 이어지고, 실린더 속 피스톤의 판(piston_w, 틈 한가운데)은 아래 발판 윗면 rest_d 밑에 가라앉아 쉰다.
## 윗판에 서서 SPACE: 발을 구른다(stomp — 한 무릎이 높이 올라와 발이 내리꽂히고 팔이 위로 휘두르며 판이 give 만큼 눌리는 동안 몸이 뒤로 젖혀진다) → 바람이 관을 타고 내려가 피스톤이 stamp_px 만큼 오른다(wheeze); 꼭대기는 max_lift = dy + rest_d − top_short(판이 위 발판 top_short 밑, clank).
## 마지막 구름 뒤 hold_s 가 지나면 밸브가 풀려 sink_v px/s 로 가라앉는다(바닥에 닿으면 sigh) — 꾸준히 구르면 끝까지 걸어 오르고 느리면 땅을 잃는다. 올라온 판은 틈 가운데의 발판: 윗판 끝에서 톡 뛰어 건너고 거기서 위 발판은 톡 뛰는 한 단; 선 몸 밑에서도 같은 법으로 가라앉는다.
## 밀지도, 떨어뜨리지도, 거절하지도 않는다 — 틈을 건너는 맨 점프는 그대로(가라앉은 피스톤은 그 호 밑, 윗판은 발판의 연장). 몸의 발이 만든 힘으로 다른 자리가 오르는 첫 기계.
## 윗판 위의 자세는 stomp(stick3d_stomp.gd — 운영자 보드의 '밟기·구르기' 가족, bound 의 다음: 페달 위의 준비 자세와 구름의 박자 — 무릎이 높이, 발이 내리꽂히고, 팔이 휘두르고, 판이 눌리는 동안 뒤로 젖힌다; 쉬는 동안도 숨 쉬듯 무릎이 흔들린다).
## bound(널 끝에서 탭마다 널이 튄다 — 제 몸이 던져진다)·crank(윈치를 감는다 — 손의 일)·tread(띠 위를 걷는다)와 다르다: 이건 발로 다른 것을 올리는 몸, 던져지는 건 없다.
## 로더가 할 일(climb.gd, 운영자 세션): `var cl := ClimbBellows.new(); add_child(cl)`; 층을 지을 때 `var gp := cg.plan(n, plats); var hp := pk.plan(n, plats, cp.plan(n, plats) + gh.plan(n, plats) + cb.plan(n, plats) + cm.plan(n, plats)); cl.build(root, cl.plan(n, plats, gp + hp))` (톱니 띠·뻐꾸기 집의 계획을 taken 으로 — 그 틈과 띠 깔린 발판은 비켜 간다); 매 틱 `cl.sync(_t)`;
## 발판에 선 가지에서 jump 가 막 눌렸고(`Input.is_action_just_pressed("jump")`) `cl.poised(on, x)` 면 모으지 말고 `cl.stamp(on, x, fig); charge = 0.0` (윗판 밖에선 로더의 모아 뛰기 그대로 — 윗판에선 SPACE 가 풀무의 것, 뛰려면 윗판 끝에서 걸어 내리거나 발판 가장자리에서 뛴다);
## 로더 자신의 착지 판정이 비었고 vy <= 0 이면 `landed = cl.land(x, y, ny, z)` (kind "bellows" — "part" 가 "board"(윗판, 발판 높이에서 give 만큼 눌린다)·"piston"(판, 지금 높이); "y" 가 그 높이; "step" 이 참이면 내려선 걸음, "ramp" 가 참이면 걸어 올라선 걸음이라 vx 를 0 으로 안 해도 된다);
## `on["kind"] == "bellows"` 인 매 틱, 'move' 발판 자리에서: `var r := cl.stand(on, x, dt, fig); y = r["y"]; if r["off"]: on = {}; apex = y; fig.pose_request = ""; else: fig.pose_request = "stomp" if r["poised"] else ""`, 떠나면 자세를 비운다.
## 단위는 climb.gd 와 같은 px(36px = 1m, +y 위). 점검은 tools/probe_bellows.gd

const PACK := "res://data/climb/bellows.json"
const C = preload("res://scripts/games/climb.gd")
const TAKEN_UP := 220.0    # taken 조각(띠·뻐꾸기 집) 위로 비워 두는 높이(px) — 제 꼭대기(len)가 더 높으면 그것
const BODY_UP := 50.0      # 올라온 판에 선 몸의 키(px) — 상자 위쪽 여유
const GAUGE_ANG := 2.4     # 압력계 바늘이 꼭대기에서 도는 각(rad)
const PLEATS := 3

var pack: Dictionary = {}
var kind: Dictionary = {}       # kinds.bellows
var lifts: Array = []           # 지은 풀무 {id, kind "bellows", x, y, w, z, d, part, dir, gap, dy, a_edge, b_edge, a_y, b_y, a_id, b_id, px, max_lift, x_in, x_out, node, board, leather, rod, plate, needle, wheeze, clank, sigh, lift0, last, count, foot, up}
var t := 0.0                    # 로더의 _t 와 같이 간다(sync)

func _ready() -> void:
	var f := FileAccess.open(PACK, FileAccess.READ)
	if f: pack = JSON.parse_string(f.get_as_text()) as Dictionary
	kind = (pack.get("kinds", {}) as Dictionary).get("bellows", {})

func sync(now: float) -> void:
	t = now
	for sv in lifts:
		_settle(sv)

func board_w() -> float:
	return maxf(8.0, float(kind.get("board_w", 36.0)))

func piston_w() -> float:
	return maxf(8.0, float(kind.get("piston_w", 40.0)))

func step_px() -> float:
	return maxf(0.0, float(kind.get("step", 20.0)))

func rest_d() -> float:
	return maxf(0.0, float(kind.get("rest_d", 60.0)))

func top_short() -> float:
	return maxf(0.0, float(kind.get("top_short", 24.0)))

func stamp_px() -> float:
	return maxf(1.0, float(kind.get("stamp_px", 24.0)))

func hold_s() -> float:
	return maxf(0.0, float(kind.get("hold_s", 0.6)))

func sink_v() -> float:
	return maxf(0.0, float(kind.get("sink_v", 10.0)))

func give() -> float:
	return maxf(0.0, float(kind.get("give", 6.0)))

func press_s() -> float:
	return maxf(0.01, float(kind.get("press_s", 0.12)))

func back_s() -> float:
	return maxf(0.01, float(kind.get("back_s", 0.25)))

func bellows_h() -> float:
	return maxf(4.0, float(kind.get("bellows_h", 30.0)))

func cyl_h() -> float:
	return maxf(4.0, float(kind.get("cyl_h", 50.0)))

func base_d() -> float:
	return maxf(4.0, float(kind.get("base_d", 70.0)))

func catch_px() -> float:
	return maxf(0.0, float(kind.get("catch", 16.0)))

func deck_d() -> float:
	return maxf(2.0, float(kind.get("deck_d", 28.0)))

## 피스톤이 오른 높이(px) — 마지막 구름의 값에서 hold_s 뒤 sink_v 로 내려온 만큼; 틱에 안 끌리게 시각으로 센다
func lift_of(s: Dictionary) -> float:
	var last := float(s["last"])
	if last < 0.0: return 0.0
	return maxf(0.0, float(s["lift0"]) - sink_v() * maxf(0.0, t - last - hold_s()))

## 판의 지금 높이(px)
func plate_y(s: Dictionary) -> float:
	return float(s["a_y"]) - rest_d() + lift_of(s)

## 윗판이 눌린 깊이(px) — 구름 뒤 press_s 에 내려갔다 back_s 에 돌아온다
func dip_of(s: Dictionary) -> float:
	var last := float(s["last"])
	if last < 0.0: return 0.0
	var u := t - last
	if u < 0.0 or u >= press_s() + back_s(): return 0.0
	return give() * (u / press_s() if u < press_s() else 1.0 - (u - press_s()) / back_s())

## 윗판의 지금 높이(px)
func board_y(s: Dictionary) -> float:
	return float(s["a_y"]) - dip_of(s)

## x 가 윗판 위인가 — 아래 발판의 가장자리에서 잰다
func on_board(s: Dictionary, x: float) -> bool:
	var u := float(s["dir"]) * (x - float(s["x_in"]))
	return u >= 0.0 and u <= board_w()

## x 가 판 위인가
func on_plate(s: Dictionary, x: float) -> bool:
	return absf(x - float(s["px"])) <= piston_w() / 2.0

## 바닥에 닿은 피스톤 — 올라갔던 것이면 sigh 한 번
func _settle(s: Dictionary) -> void:
	if bool(s["up"]) and lift_of(s) <= 0.0:
		s["up"] = false
		_play(s["sigh"] as AudioStreamPlayer3D)

## 노드를 지금 자리로
func _process(delta: float) -> void:
	t += delta
	lifts = lifts.filter(func(s: Dictionary) -> bool: return is_instance_valid(s["node"]))   # 지운 층의 것은 뺀다(climb_tulip 과 같은 식)
	for sv in lifts:
		var s: Dictionary = sv
		_settle(s)
		_place(s)

## 층 n(테마 층, 조각의 not 규칙)의 잇단 두 발판(조각의 on·to; 아래 a·위 b) 중 틈이 min_gap..max_gap 이고 b 가 min_dy..max_dy 높으며 풀무의 상자를 다른 발판이 가르지 않고 taken 조각이 닿지 않는 짝들 중 가장 넓은 틈 하나. 같은 층·같은 taken 은 늘 같은 답
func plan(n: int, plats: Array, taken: Array = []) -> Array:
	var out: Array = []
	if not (String(C.theme(n)[0]) in (pack.get("themes", []) as Array)): return out
	var min_gap := float(kind.get("min_gap", 120.0)); var max_gap := float(kind.get("max_gap", 220.0))
	var min_dy := float(kind.get("min_dy", 40.0)); var max_dy := float(kind.get("max_dy", 120.0))
	for pv in (pack.get("pieces", []) as Array):
		var piece: Dictionary = pv
		var skip: Dictionary = piece.get("not", {})
		if not skip.is_empty() and _on(n, skip): continue
		var kinds: Array = piece.get("on", ["std", "ice"]); var to: Array = piece.get("to", kinds)   # on: 서는 아래 발판(still 만), to: 뛰어 건너는 위 발판(부서지거나 튀어도 된다)
		var hops: Array = plats.filter(func(p: Dictionary) -> bool: return not (String(p["kind"]) in ["rest", "short", "ledge"]))
		var found: Array = []
		for i in range(1, hops.size()):
			var a: Dictionary = hops[i - 1]; var b: Dictionary = hops[i]   # a 가 아래 발판(band() 는 오르는 순서로 쌓는다)
			if not (String(a["kind"]) in kinds and String(b["kind"]) in to): continue
			var dy := float(b["y"]) - float(a["y"])
			if dy < min_dy or dy > max_dy: continue
			var ax0 := float(a["x"]); var ax1 := ax0 + float(a["w"]); var bx0 := float(b["x"]); var bx1 := bx0 + float(b["w"])
			if bx0 < ax1 and bx1 > ax0: continue   # 겹친 발판 — 틈이 없다
			var dir := 1.0 if bx0 >= ax1 else -1.0   # a 에서 b 쪽 — b 가 오른쪽이면 +x
			var gap := bx0 - ax1 if dir > 0.0 else ax0 - bx1
			if gap < min_gap or gap > max_gap: continue
			var a_edge := ax1 if dir > 0.0 else ax0; var b_edge := bx0 if dir > 0.0 else bx1
			var off := maxf(gap / 2.0, board_w() + step_px() + piston_w() / 2.0)   # 판의 가운데 — 틈 한가운데, 좁으면 윗판 끝에서 step 뒤
			var max_lift := dy + rest_d() - top_short()
			var far := a_edge + dir * (off + piston_w() / 2.0)
			var x0 := minf(a_edge, far) - 4.0; var x1 := maxf(a_edge, far) + 4.0
			var ylo := float(a["y"]) - rest_d() - base_d() + 1.0; var yhi := float(b["y"]) - top_short() + BODY_UP
			if not _clear(plats, a, b, x0, x1, ylo, yhi): continue
			if not _free(taken, x0, x1, ylo, yhi): continue
			found.append({ "gap": gap, "dy": dy, "dir": dir, "a_edge": a_edge, "b_edge": b_edge, "px": a_edge + dir * off, "max_lift": max_lift, "x_in": a_edge, "x_out": a_edge + dir * board_w(),
				"a_id": String(a["id"]), "b_id": String(b["id"]), "a_y": float(a["y"]), "b_y": float(b["y"]) })
		found.sort_custom(func(p: Dictionary, q: Dictionary) -> bool: return float(p["gap"]) > float(q["gap"]) if float(p["gap"]) != float(q["gap"]) else float(p["a_y"]) < float(q["a_y"]))
		for i in range(0, mini(int(piece.get("max", 1)), found.size())):
			var g: Dictionary = found[i]
			var s: Dictionary = g.duplicate(true)
			s["id"] = "%d.B%d" % [n, i]; s["kind"] = "bellows"; s["part"] = "board"; s["x"] = minf(float(g["x_in"]), float(g["x_out"])); s["w"] = board_w(); s["y"] = float(g["a_y"]); s["z"] = C.PLAYER_Z; s["d"] = deck_d()
			out.append(s)
	return out

## 층 n 이 {from, every} 에 드나
static func _on(n: int, rule: Dictionary) -> bool:
	var from := int(rule.get("from", 0))
	return n >= from and (n - from) % maxi(1, int(rule.get("every", 1))) == 0

## 풀무의 상자(아래 발판 가장자리..판의 먼 끝, 실린더 바닥..올라온 판과 몸)에 두 발판 말고 다른 발판이 걸리지 않나 — 움직이는 발판은 진폭째
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

## 다른 팩의 조각(taken: x·w·y, 있으면 len·y_top)이 풀무의 상자에 닿지 않나 — 조각 위 TAKEN_UP 까지, 제 꼭대기가 더 높으면 거기까지 그 조각의 몸
static func _free(taken: Array, x0: float, x1: float, ylo: float, yhi: float) -> bool:
	for tv in taken:
		var q: Dictionary = tv
		var qx0 := float(q.get("x", 0.0)) - 10.0; var qx1 := float(q.get("x", 0.0)) + float(q.get("w", 0.0)) + 10.0
		var qy := float(q.get("y", 0.0)); var qy0 := qy - 10.0; var qy1 := qy + TAKEN_UP
		if q.has("len"): qy1 = maxf(qy1, qy + float(q["len"]) + 10.0)
		if q.has("y_top"): qy1 = maxf(qy1, float(q["y_top"]) + 60.0)
		if x1 > qx0 and x0 < qx1 and yhi > qy0 and ylo < qy1: return false
	return true

## 윗판에 선 몸인가 — 거기선 SPACE 가 풀무의 것
func poised(on: Dictionary, x: float) -> bool:
	if String(on.get("kind", "")) != "bellows" or String(on.get("part", "")) != "board": return false
	var s := _find(String(on.get("id", "")))
	return not s.is_empty() and on_board(s, x)

## SPACE 한 번 — {took, lift, count, top}: 윗판 밖이면 took 이 거짓(로더의 모아 뛰기 그대로). 안이면 발을 구른다(wheeze): 피스톤이 stamp_px 오르고(max_lift 에 닿는 순간 clank), 발이 바뀐다; fig 가 있으면 자세의 메타를 적는다
func stamp(on: Dictionary, x: float, fig: Stick3D = null) -> Dictionary:
	if not poised(on, x): return { "took": false, "lift": 0.0, "count": 0, "top": false }
	var s := _find(String(on.get("id", "")))
	var was := lift_of(s); var max_lift := float(s["max_lift"])
	var lift := minf(max_lift, was + stamp_px())
	s["lift0"] = lift; s["last"] = t; s["count"] = int(s["count"]) + 1; s["foot"] = -float(s["foot"]); s["up"] = true
	_play(s["wheeze"] as AudioStreamPlayer3D)
	var top := lift >= max_lift
	if top and was < max_lift: _play(s["clank"] as AudioStreamPlayer3D)
	if fig: _metas(s, fig)
	return { "took": true, "lift": lift, "count": int(s["count"]), "top": top }

## 자세의 메타 — stomp_s 마지막 구름 뒤 초(없었으면 99), stomp_f 구른 발, stomp_k 피스톤 높이 0..1, stomp_dip 판이 눌린 몫 0..1
func _metas(s: Dictionary, fig: Stick3D) -> void:
	var last := float(s["last"])
	fig.set_meta("stomp_s", t - last if last >= 0.0 else 99.0)
	fig.set_meta("stomp_f", float(s["foot"]))
	fig.set_meta("stomp_k", lift_of(s) / maxf(1.0, float(s["max_lift"])))
	fig.set_meta("stomp_dip", dip_of(s) / maxf(0.001, give()))

## 로더가 밟는 사전 — board: x·w 는 윗판의 왼끝과 폭, piston: 판의 것(다른 발판과 같은 꼴)
func _on_dict(s: Dictionary, part: String, step: bool, ramp: bool) -> Dictionary:
	var plate := part == "piston"
	return { "kind": "bellows", "id": String(s["id"]), "part": part, "x": float(s["px"]) - piston_w() / 2.0 if plate else float(s["x"]), "y": plate_y(s) if plate else board_y(s), "w": piston_w() if plate else float(s["w"]),
		"z": float(s["z"]), "d": deck_d(), "step": step, "ramp": ramp }

## 로더의 착지 판정이 빈 뒤(vy <= 0) — 윗판(발판 높이에서 눌린 만큼)이나 판(지금 높이)을 이 틱에 지나 떨어지는 몸, 그 위 catch 안에서 내려서는 몸, 또는 그것이 발 위 catch 안에 있는 몸(걸어 올라서는 걸음)을 받는다
func land(x: float, y: float, ny: float, z: float) -> Dictionary:
	if ny > y: return {}   # 오르는 몸은 받지 않는다
	var catch := catch_px()
	for sv in lifts:
		var s: Dictionary = sv
		if absf(z - float(s["z"])) >= deck_d() / 2.0 + C.HZ: continue
		var part := "board" if on_board(s, x) else ("piston" if on_plate(s, x) else "")
		if part == "": continue
		var sy := board_y(s) if part == "board" else plate_y(s)
		var cross := y >= sy and ny <= sy
		var step := not cross and y > sy and y - sy <= catch
		var ramp := not cross and y < sy and sy - y <= catch
		if not (cross or step or ramp): continue
		return _on_dict(s, part, step, ramp)
	return {}

## 풀무 위의 매 틱 — {y, off, poised, lift, part}: 윗판에선 눌린 높이를 주고 poised(자세 stomp, SPACE 는 풀무의 것); 판에선 지금 높이(선 몸 밑에서도 가라앉는다); 제 부분의 어느 끝이든 넘으면 off(떨어져 발판이나 바닥이 받는다); 모르는 풀무면 off
## fig 가 있으면 윗판에서 자세의 메타를 적는다
func stand(on: Dictionary, x: float, _dt: float, fig: Stick3D = null) -> Dictionary:
	var s := _find(String(on.get("id", "")))
	if s.is_empty(): return { "y": float(on.get("y", 0.0)), "off": true, "poised": false, "lift": 0.0, "part": "" }
	var part := String(on.get("part", "board"))
	var board := part == "board"
	var y := board_y(s) if board else plate_y(s)
	var here := on_board(s, x) if board else on_plate(s, x)
	if not here: return { "y": y, "off": true, "poised": false, "lift": lift_of(s), "part": part }
	if board and fig: _metas(s, fig)
	return { "y": y, "off": false, "poised": board, "lift": lift_of(s), "part": part }

func _find(id: String) -> Dictionary:
	for sv in lifts:
		if String((sv as Dictionary)["id"]) == id: return sv
	return {}

func _play(p: AudioStreamPlayer3D) -> void:
	if p.playing: p.stop()
	p.play()

## 풀무와 관과 실린더를 짓는다 — root 는 그 층의 노드. 노드 원점은 아래 발판의 틈 쪽 가장자리(a_edge, 발판 윗면, PLAYER_Z); 절벽 받침 팔·아랫판·주름 가죽(주름 셋)·윗판·관 둘·실린더 바닥·안내 레일 둘·막대·판(테)·압력계(바늘)·소리 셋
func build(root: Node3D, planned: Array) -> void:
	var bw := board_w() * C.K; var pw := piston_w() * C.K; var dd := deck_d() * C.K; var rd := rest_d() * C.K; var bh := bellows_h() * C.K; var ch := cyl_h() * C.K; var bd := base_d() * C.K
	for sv in planned:
		var s: Dictionary = (sv as Dictionary).duplicate(true)
		var dir := float(s["dir"]); var pxr := (float(s["px"]) - float(s["a_edge"])) * C.K   # 판의 가운데 — 노드 기준
		var node := Node3D.new(); node.position = C.to3(float(s["a_edge"]), float(s["a_y"]), float(s["z"]) * C.K); root.add_child(node)
		var wood := _mat(Color("a67c52")); var hide := _mat(Color("7a4a2e")); var seam := _mat(Color("4a2c1a")); var brass := _mat(Color("c9a24a")); var iron := _mat(Color("5a5a5a")); var mauve := _mat(Color("ad7096"))
		var arm_len := (C.PLAYER_Z - C.WALL_Z) * C.K + dd / 2.0
		_box(node, Vector3(0.06, 0.05, arm_len), iron).position = Vector3(dir * bw / 2.0, -bh - 0.12, -arm_len / 2.0 + dd / 2.0)   # 받침 팔 — 절벽에서
		_box(node, Vector3(bw, 0.08, dd), wood).position = Vector3(dir * bw / 2.0, -bh - 0.04, 0.0)                               # 아랫판 — 붙박이
		var leather := Node3D.new(); leather.position = Vector3(dir * bw / 2.0, -bh, 0.0); node.add_child(leather)
		_box(leather, Vector3(bw * 0.88, 1.0, dd * 0.88), hide).position = Vector3(0.0, 0.5, 0.0)                                 # 주름 가죽 — scale.y 가 높이
		for i in PLEATS:
			_box(leather, Vector3(bw * 0.9, 0.02, dd * 0.9), seam).position = Vector3(0.0, 0.25 + 0.25 * float(i), 0.0)            # 주름 — 가죽과 같이 눌린다
		var board := Node3D.new(); board.position = Vector3(dir * bw / 2.0, 0.0, 0.0); node.add_child(board)
		_box(board, Vector3(bw, 0.08, dd), wood).position = Vector3(0.0, -0.04, 0.0)                                                # 윗판 — 발판 높이, 구르면 눌린다
		_box(board, Vector3(bw * 0.6, 0.012, 0.04), seam).position = Vector3(0.0, 0.006, dd * 0.1)                                   # 발 자리의 홈
		var pipe_y := -(rd + bd) + 0.1
		_cyl(node, 0.04, -pipe_y - bh - 0.08, brass).position = Vector3(dir * bw * 0.3, (pipe_y - bh - 0.08) / 2.0, 0.0)           # 관 — 풀무 밑에서 내려간다
		var run := _cyl(node, 0.04, absf(pxr) - bw * 0.3, brass); run.rotation.z = PI / 2.0; run.position = Vector3((dir * bw * 0.3 + pxr) / 2.0, pipe_y, 0.0)   # 관 — 틈을 건넌다
		_cyl(node, pw / 2.0 + 0.06, bd, brass).position = Vector3(pxr, -rd - bd / 2.0, 0.0)                                         # 실린더 바닥 — 판이 그 위에 쉰다
		for d: float in [1.0, -1.0]:
			_box(node, Vector3(0.04, ch, 0.06), iron).position = Vector3(pxr + d * (pw / 2.0 + 0.05), -rd + ch / 2.0, dd * 0.3)       # 안내 레일 둘 — 판이 그 사이를 오른다
		var rod := Node3D.new(); rod.position = Vector3(pxr, -rd, 0.0); node.add_child(rod)
		_cyl(rod, 0.06, 1.0, iron).position = Vector3(0.0, 0.5, 0.0)                                                                 # 막대 — scale.y 가 오른 높이
		var plate := Node3D.new(); plate.position = Vector3(pxr, -rd, 0.0); node.add_child(plate)
		_box(plate, Vector3(pw, 0.08, dd), brass).position = Vector3(0.0, -0.04, 0.0)                                                # 판 — 발판
		_box(plate, Vector3(pw + 0.08, 0.03, dd + 0.06), iron).position = Vector3(0.0, -0.09, 0.0)                                   # 테
		var gauge := Node3D.new(); gauge.position = Vector3(pxr, -rd - bd / 2.0, dd / 2.0 + 0.07); node.add_child(gauge)
		var dial := _cyl(gauge, 0.14, 0.02, _mat(Color("efe9e2"))); dial.rotation.x = PI / 2.0                                       # 압력계 — 실린더 앞면
		var needle := Node3D.new(); needle.position = Vector3(0.0, 0.0, 0.015); gauge.add_child(needle)
		_box(needle, Vector3(0.02, 0.12, 0.01), mauve).position = Vector3(0.0, 0.06, 0.0)                                             # 바늘 — 오른 만큼 돈다
		var wheeze := _snd(node, float(kind.get("wheeze_hz", 90)), 0.25, 6.0, -14.0); var clank := _snd(node, float(kind.get("clank_hz", 520)), 0.12, 10.0, -12.0); var sigh := _snd(node, float(kind.get("sigh_hz", 200)), 0.5, 3.0, -18.0)
		s["node"] = node; s["board"] = board; s["leather"] = leather; s["rod"] = rod; s["plate"] = plate; s["needle"] = needle; s["wheeze"] = wheeze; s["clank"] = clank; s["sigh"] = sigh
		s["lift0"] = 0.0; s["last"] = -99.0; s["count"] = 0; s["foot"] = -1.0; s["up"] = false
		lifts.append(s)
		_place(s)

## 윗판을 눌린 만큼 내리고 가죽을 그만큼 줄이며, 막대를 오른 만큼 늘리고 판을 그 위로, 바늘을 오른 만큼 돌린다
func _place(s: Dictionary) -> void:
	var dip := dip_of(s) * C.K; var lift := lift_of(s) * C.K
	var board: Node3D = s["board"]; var leather: Node3D = s["leather"]; var rod: Node3D = s["rod"]; var plate: Node3D = s["plate"]; var needle: Node3D = s["needle"]
	board.position.y = -dip
	leather.scale.y = maxf(0.05, bellows_h() * C.K - dip)
	rod.scale.y = maxf(0.05, lift)
	plate.position.y = -rest_d() * C.K + lift
	needle.rotation.z = -GAUGE_ANG * lift_of(s) / maxf(1.0, float(s["max_lift"]))

func _snd(parent: Node3D, hz: float, secs: float, decay: float, db: float) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new(); p.stream = _tick_wav(hz, secs, decay); p.volume_db = db; p.unit_size = 6.0; p.max_distance = 30.0
	parent.add_child(p); return p

func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.albedo_color = c; m.roughness = 1.0
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON; m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return m

func _box(parent: Node3D, size: Vector3, m: StandardMaterial3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = size; mi.mesh = bm; mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF   # 발판과 같은 규칙 — 그림자는 사람만
	parent.add_child(mi); return mi

func _cyl(parent: Node3D, r: float, h: float, m: StandardMaterial3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = r; cm.bottom_radius = r; cm.height = maxf(0.02, h); cm.radial_segments = 10; mi.mesh = cm; mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi); return mi

## 소리 — 짧은 기음이 잦아든다: wheeze(0.25초, 낮고 거칠게 — 풀무가 바람을 뱉는다)·clank(0.12초 — 피스톤이 꼭대기에 닿는다)·sigh(0.5초, 느리게 — 피스톤이 바닥에 내려앉는다). 한 번 재생, 반복 없음
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
