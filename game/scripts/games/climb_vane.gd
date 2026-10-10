class_name ClimbVane
extends Node3D
## Climb 콘텐츠 팩 '풍향계'(운영자 2026-10-06 밤: "Climb는 컨텐츠 자체의 질과 양을 늘리는 거" — 팩은 data/climb/*.json 자료, 로더는 운영자 세션이 잇는다; climb.gd 는 CI 가 안 건드린다).
## 바람 절벽(Wind cliffs) 층의 잇단 두 still 발판 사이 틈(min_gap..max_gap, 높이차 max_dy 안; 바람 있는 층은 건너편이 바람 아래쪽인 짝만) — 틈 한가운데 절벽에서 나온 받침대 위에 쇠 기둥, 그 밑에 N·E·S·W 십자, 꼭대기의 녹슨 축에 놋쇠 화살.
## 화살의 꼬리 깃은 빈 채로 아래 발판 쪽을 가리키고(축에서 틈의 반 + over), 깃 끝엔 pennant 길이의 리본 — 그 끝이 손 자리. 공중에서 ↑ 로 리본을 잡으면(홀드와 같은 손 범위) take_s 동안 축이 무게를 받고(리본이 dip 늘어나며 삐걱), 그다음 돌풍이 깃을 밀어 화살을 기둥 둘레로 반 바퀴(turn_s — 그 층의 바람이 셀수록 빨리) 돌린다:
## 깃이 절벽 앞으로 휙 나왔다 돌아 들어가며 몸을 2·arm 만큼 옆으로 실어 건너편 발판 위로 — 거기서 화살이 멈춤쇠에 닿고(clack) land_s 에 걸쳐 몸을 발판에 내려놓는다(done — 그 틱의 y 가 발판 윗면이라 다음 틱 로더의 착지 판정이 밟는다).
## 도는 중 SPACE 는 깃의 옆 속도를 얹어 뛰고 ↓ 는 그 속도를 안고 떨어진다. 놓인 풍향계는 return_s 에 걸쳐 제자리로 되감기고(무거운 화살촉이 끌어온다) 그동안 아무도 못 잡는다; 빈 채 제자리면 바람에 떤다(바람 없는 층도 그 1/3 — 살아 있는 건 움직인다).
## 2.5D 의 결정: 축은 세로, 몸의 앞뒤 자리는 로더가 고정하므로(PLAYER_Z) 손은 늘 그 깊이에 있고 리본이 깃 끝에서 손까지 비스듬히 뻗는다 — 반 바퀴라야 잡는 끝과 내려놓는 끝이 둘 다 그 깊이에 온다(백로그의 '반의 반 바퀴'는 한 끝을 허공에 둔다).
## 밀지도, 떨어뜨리지도, 거절하지도 않는다 — 틈을 그냥 뛰어 건너는 길은 그대로; 풍향계는 손을 뻗어 올린 몸에게만 있다. 매달린 자세는 trail(stick3d_trail.gd — 한 손으로 리본을 쥐고 왼팔을 활짝, 다리로 허공을 젓다 내려놓을 땐 앞으로 내려온다).
## 로더가 할 일(climb.gd, 운영자 세션): `var cv := ClimbVane.new(); add_child(cv)`; 층을 지을 때 `cv.build(root, cv.plan(n, plats, wind_of(n), ck.plan(n, plats, wind_of(n))))` (연의 계획을 taken 으로 — 한 틈을 둘이 안 나눈다); 매 틱 `cv.sync(_t)`;
## 공중에서 ↑(dirz < 0)이고 홀드·다른 팩의 잡기가 비었으면 `var g := cv.grab(x, y, z); if not g.is_empty(): vaning = g; on = {}; vx = 0.0; vy = 0.0; charge = 0.0; face = float(g["dir"])` (vaning 은 로더의 새 사전 — holding 처럼);
## 매달린 매 틱(`_hold` 와 같은 자리, 맨 앞): `var r := cv.hang_on(vaning, fig); x = r["x"]; y = r["y"]; apex = y; fig.pose_request = "trail"; stamina -= dt * 0.09; if r["done"] or r["lost"]: vaning = {}; fig.pose_request = ""`;
## SPACE 를 놓으면 `var v := cv.let_go(vaning); vy = (JUMP_MIN + (JUMP_V - JUMP_MIN) * (charge / CHARGE)) * 0.9; vx = dir * RUN * 0.9 + v["vx"]; vaning = {}; 자세 ""`; ↓ 나 힘이 다하면 `vx = v["vx"]; vy = 0.0; vaning = {}`.
## 단위는 climb.gd 와 같은 px(36px = 1m, +y 위). 점검은 tools/probe_vane.gd

const PACK := "res://data/climb/vane.json"
const C = preload("res://scripts/games/climb.gd")
const TOP := 6.0           # 화살이 기둥 꼭대기 위로 뜬 높이(px)
const HEAD := 12.0         # 화살 위로 비워 두는 높이(px) — 돌림쇠와 화살촉
const TAKEN_UP := 220.0    # taken 조각(연: 발 자리부터 연 꼭대기까지) 위로 비워 두는 높이(px)

var pack: Dictionary = {}
var kind: Dictionary = {}       # kinds.vane
var vanes: Array = []           # 지은 풍향계 {id, kind "vane", x, y, w, z, d, hx, dir, gap, arm, a_y, b_y, b_x0, b_x1, feet_y, hand_y, tail_y, post_y, wind, turn, node, vane, ribbon, creak, clack, held, t0, set0, rel, rtheta}
var t := 0.0                    # 로더의 _t 와 같이 간다(sync)

func _ready() -> void:
	var f := FileAccess.open(PACK, FileAccess.READ)
	if f: pack = JSON.parse_string(f.get_as_text()) as Dictionary
	kind = (pack.get("kinds", {}) as Dictionary).get("vane", {})

func sync(now: float) -> void:
	t = now

func hang() -> float:
	return float(kind.get("hang", 58.0))

func pennant() -> float:
	return float(kind.get("pennant", 14.0))

func over() -> float:
	return float(kind.get("over", 26.0))

func lift() -> float:
	return float(kind.get("lift", 12.0))

func post_h() -> float:
	return float(kind.get("post_h", 96.0))

func take_s() -> float:
	return maxf(0.05, float(kind.get("take_s", 0.25)))

func land_s() -> float:
	return maxf(0.05, float(kind.get("land_s", 0.3)))

func return_s() -> float:
	return maxf(0.05, float(kind.get("return_s", 1.5)))

## 반 바퀴에 걸리는 초 — 바람이 셀수록 짧다(120 px/s 에 wind_k 만큼, 180 에서 끝)
func turn_s(wind: float) -> float:
	return maxf(0.2, float(kind.get("turn_s", 1.6))) / (1.0 + float(kind.get("wind_k", 0.5)) * clampf(absf(wind) / 120.0, 0.0, 1.5))

## 매달린 풍향계의 돌기 진행 0..1 — take_s 가 지난 뒤 turn 에 걸쳐
func prog(s: Dictionary, at: float) -> float:
	return clampf((at - float(s["t0"]) - take_s()) / float(s["turn"]), 0.0, 1.0)

## 깃의 각(라디안, 0 = 아래 발판 쪽 제자리, π = 건너편): 매달리면 반 바퀴를 부드럽게, 놓이면 return_s 에 걸쳐 되감기며 바람의 떨림이 돌아온다
func ang(s: Dictionary, at: float) -> float:
	if bool(s["held"]): return PI * smoothstep(0.0, 1.0, prog(s, at))
	var back := smoothstep(0.0, 1.0, clampf((at - float(s["rel"])) / return_s(), 0.0, 1.0))
	return float(s["rtheta"]) * (1.0 - back) + quiver(s, at) * back

## 빈 풍향계의 떨림(rad) — 바람 120 에 quiver_a, 바람 없는 층은 그 1/3; 풍향계마다 위상이 다르다
func quiver(s: Dictionary, at: float) -> float:
	var k := 0.33 + 0.67 * clampf(absf(float(s["wind"])) / 120.0, 0.0, 1.0)
	return float(kind.get("quiver_a", 0.06)) * k * sin(at * TAU / maxf(0.3, float(kind.get("quiver_s", 1.1))) + float(s["hx"]) * 0.01)

## 리본이 늘어난 만큼(px) — 축이 무게를 받는 take_s 동안
func dip_at(s: Dictionary, at: float) -> float:
	return float(kind.get("dip", 6.0)) * smoothstep(0.0, take_s(), at - float(s["t0"])) if bool(s["held"]) else 0.0

## 손 자리(px) — 깃 끝의 리본 끝: x 는 깃의 x, y 는 깃 높이에서 리본 길이와 늘어남을 뺀 높이
func hands(s: Dictionary, at: float) -> Vector2:
	return Vector2(float(s["hx"]) - float(s["dir"]) * float(s["arm"]) * cos(ang(s, at)), float(s["tail_y"]) - pennant() - dip_at(s, at))

## 깃의 옆 속도 px/s — x = hx − dir·arm·cos θ, θ = π·smoothstep(u) 의 미분(u 는 turn 에 걸쳐)
func speed(s: Dictionary, at: float) -> float:
	var u := prog(s, at)
	if u <= 0.0 or u >= 1.0 or not bool(s["held"]): return 0.0
	var th := PI * smoothstep(0.0, 1.0, u); var dth := PI * 6.0 * u * (1.0 - u) / float(s["turn"])
	return float(s["dir"]) * float(s["arm"]) * sin(th) * dth

## 옆 속도의 비 −1..1 — 자세가 읽는다(u 0.5 에서 1)
static func rate(u: float) -> float:
	return sin(PI * smoothstep(0.0, 1.0, u)) * 4.0 * u * (1.0 - u)

func _process(delta: float) -> void:
	t += delta
	vanes = vanes.filter(func(s: Dictionary) -> bool: return is_instance_valid(s["node"]))   # 지운 층의 것은 뺀다(climb_kite 와 같은 식)
	for sv in vanes: _place(sv)

## 층 n(테마 층만)의 잇단 두 still 발판(조각의 on) 중 틈이 min_gap..max_gap 이고 높이차가 max_dy 안이며 바람 있는 층은 건너편이 바람 아래쪽인 짝 중 쓸 상자(틈 ± over, 아래 발판 윗면..화살 위)를 다른 발판이 가르지 않고 taken 조각(연)이 닿지 않는 것들 중 가장 넓은 틈 하나. 같은 층·같은 바람·같은 taken 은 늘 같은 답
func plan(n: int, plats: Array, wind: float = 0.0, taken: Array = []) -> Array:
	var out: Array = []
	if not (String(C.theme(n)[0]) in (pack.get("themes", []) as Array)): return out
	var hops := plats.filter(func(p: Dictionary) -> bool: return not (String(p["kind"]) in ["rest", "short", "ledge"]))
	for pv in (pack.get("pieces", []) as Array):
		var piece: Dictionary = pv
		var only: Dictionary = piece.get("only", {})
		if not only.is_empty() and not _on(n, only): continue
		var kinds: Array = piece.get("on", ["std"])
		var min_gap := float(kind.get("min_gap", 70.0)); var max_gap := float(kind.get("max_gap", 170.0)); var max_dy := float(kind.get("max_dy", 140.0))
		var spans: Array = []
		for i in range(1, hops.size()):
			var a: Dictionary = hops[i - 1]; var b: Dictionary = hops[i]   # a 가 아래 발판(band() 는 오르는 순서로 쌓는다)
			if not (String(a["kind"]) in kinds and String(b["kind"]) in kinds): continue
			if absf(float(b["y"]) - float(a["y"])) > max_dy: continue
			var ax0 := float(a["x"]); var ax1 := ax0 + float(a["w"]); var bx0 := float(b["x"]); var bx1 := bx0 + float(b["w"])
			if bx0 < ax1 and bx1 > ax0: continue   # 겹친 발판 — 틈이 없다
			var dir := 1.0 if bx0 >= ax1 else -1.0
			if wind != 0.0 and signf(wind) != dir: continue   # 바람을 거슬러선 못 돌린다
			var gap := bx0 - ax1 if dir > 0.0 else ax0 - bx1
			if gap < min_gap or gap > max_gap: continue
			var hx := (ax1 + bx0) / 2.0 if dir > 0.0 else (bx1 + ax0) / 2.0
			var arm := gap / 2.0 + over()
			var feet := maxf(float(a["y"]), float(b["y"])) + lift(); var handy := feet + hang(); var tail := handy + pennant()
			var x0 := hx - arm - C.HW; var x1 := hx + arm + C.HW; var ylo := minf(float(a["y"]), float(b["y"]))
			if not _clear(plats, a, b, x0, x1, ylo + 1.0, tail + HEAD): continue
			if not _free(taken, x0, x1, ylo, tail + HEAD): continue
			var d := minf(float(a.get("d", C.DEPTH_HALF * 2.0)), float(b.get("d", C.DEPTH_HALF * 2.0)))
			spans.append({ "gap": gap, "hx": hx, "dir": dir, "arm": arm, "d": d, "a_y": float(a["y"]), "b_y": float(b["y"]), "b_x0": bx0, "b_x1": bx1, "feet_y": feet, "hand_y": handy, "tail_y": tail,
				"post_y": tail - TOP - post_h(), "a_id": String(a["id"]), "b_id": String(b["id"]), "x": ax1 if dir > 0.0 else bx1 })
		spans.sort_custom(func(p: Dictionary, q: Dictionary) -> bool: return float(p["gap"]) > float(q["gap"]) if float(p["gap"]) != float(q["gap"]) else float(p["post_y"]) < float(q["post_y"]))
		for i in range(0, mini(int(piece.get("max", 1)), spans.size())):
			var g: Dictionary = spans[i]
			var s: Dictionary = g.duplicate()
			s["id"] = "%d.V%d" % [n, i]; s["kind"] = "vane"; s["y"] = float(g["feet_y"]); s["w"] = float(g["gap"]); s["z"] = C.WALL_Z + float(g["d"]) / 2.0; s["wind"] = wind; s["turn"] = turn_s(wind)
			out.append(s)
	return out

## 층 n 이 {from, every} 에 드나
static func _on(n: int, rule: Dictionary) -> bool:
	var from := int(rule.get("from", 0))
	return n >= from and (n - from) % maxi(1, int(rule.get("every", 1))) == 0

## 쓸 상자(틈 ± over, 아래 발판 윗면..화살 위)에 두 발판 말고 다른 발판이 걸리지 않나 — 지름길 판이 틈에 있으면 깃이 걸린다
static func _clear(plats: Array, a: Dictionary, b: Dictionary, x0: float, x1: float, ylo: float, yhi: float) -> bool:
	for pv in plats:
		var p: Dictionary = pv
		if p["id"] == a["id"] or p["id"] == b["id"]: continue
		var py := float(p["y"])
		if py < ylo or py > yhi: continue
		var px0 := float(p["x"]) - 10.0; var px1 := float(p["x"]) + float(p["w"]) + 10.0
		if x1 > px0 and x0 < px1: return false
	return true

## 다른 팩의 조각(taken: 연 x, w, y)이 쓸 상자에 닿지 않나 — 조각 위 TAKEN_UP 까지 그 조각의 몸
static func _free(taken: Array, x0: float, x1: float, ylo: float, yhi: float) -> bool:
	for tv in taken:
		var q: Dictionary = tv
		var qx0 := float(q["x"]) - 10.0; var qx1 := float(q["x"]) + float(q.get("w", 0.0)) + 10.0
		var qy := float(q.get("y", 0.0)); var qy0 := qy - 10.0; var qy1 := qy + TAKEN_UP
		if x1 > qx0 and x0 < qx1 and yhi > qy0 and ylo < qy1: return false
	return true

## 공중에서 ↑ — 손(발 + hang)이 리본 끝의 reach_x·reach_y 안이고 풍향계가 비어 제자리면 잡는다(creak): 돌려주는 사전의 x·y 가 몸의 자리(리본 끝 밑 hang), dir 이 실려 갈 쪽. 아니면 빈 사전
func grab(x: float, y: float, z: float) -> Dictionary:
	var rx := float(kind.get("reach_x", 26.0)); var ry := float(kind.get("reach_y", 22.0))
	for sv in vanes:
		var s: Dictionary = sv
		if absf(z - float(s["z"])) >= float(s["d"]) / 2.0 + C.HZ: continue
		if bool(s["held"]) or t < float(s["rel"]) + return_s(): continue   # 누가 매달렸거나 되감기는 중
		var h := hands(s, t)
		if absf(x - h.x) < rx and absf(y + hang() - h.y) < ry:
			s["held"] = true; s["t0"] = t; s["set0"] = -9.0; s["rtheta"] = 0.0
			_play(s["creak"])
			return { "id": String(s["id"]), "kind": "vane", "x": h.x, "y": h.y - hang(), "t0": t, "dir": float(s["dir"]) }
	return {}

## 매달린 매 틱 — {x, y, done, lost}: take_s 동안 리본이 늘어나고, 그다음 깃이 반 바퀴 돌아 몸을 실어 가며, 건너편에서 멈춤쇠에 닿으면(clack) land_s 에 걸쳐 발판에 내려놓는다 → done. 풍향계가 사라졌으면 lost.
## fig 가 있으면 자세의 메타를 적는다: trail_v 옆 속도의 비 −1..1(+x 가 +), trail_set 내려놓기 0..1, trail_k 돌기 0..1
func hang_on(riding: Dictionary, fig: Stick3D = null) -> Dictionary:
	var s := _find(String(riding.get("id", "")))
	if s.is_empty() or not bool(s["held"]): return { "x": float(riding.get("x", 0.0)), "y": float(riding.get("y", 0.0)), "done": false, "lost": true }
	var u := prog(s, t); var h := hands(s, t)
	var feet := h.y - hang()
	var set0 := float(s["set0"])
	if set0 < -1.0 and u >= 1.0:   # 화살이 멈춤쇠에 — 건너편 발판 위, 내려놓기 시작
		s["set0"] = t; set0 = t; _play(s["clack"])
	var ks := 0.0; var done := false
	if set0 > -1.0:
		ks = clampf((t - set0) / land_s(), 0.0, 1.0)
		feet = lerpf(h.y - hang(), float(s["b_y"]), smoothstep(0.0, 1.0, ks)); done = ks >= 1.0
	if done: _release(s); feet = float(s["b_y"])
	if fig:
		fig.set_meta("trail_v", float(s["dir"]) * rate(u) * (1.0 - 0.5 * ks)); fig.set_meta("trail_set", ks); fig.set_meta("trail_k", u)
	return { "x": h.x, "y": feet, "done": done, "lost": false }

## 놓는 순간 깃의 옆 속도 {vx, vy} px/s — 도는 중이면 안고 간다(내려놓는 중엔 반으로), 양 끝에선 0; 풍향계는 되감긴다
func let_go(riding: Dictionary) -> Dictionary:
	var s := _find(String(riding.get("id", "")))
	if s.is_empty() or not bool(s["held"]): return { "vx": 0.0, "vy": 0.0 }
	var v := speed(s, t)
	var ks := 0.0 if float(s["set0"]) < -1.0 else clampf((t - float(s["set0"])) / land_s(), 0.0, 1.0)
	_release(s)
	return { "vx": v * (1.0 - 0.5 * ks), "vy": 0.0 }

## 풍향계를 비운다 — 지금 각에서 return_s 에 걸쳐 되감긴다
func _release(s: Dictionary) -> void:
	s["rtheta"] = ang(s, t); s["held"] = false; s["rel"] = t; s["set0"] = -9.0

func _find(id: String) -> Dictionary:
	for sv in vanes:
		if String((sv as Dictionary)["id"]) == id: return sv
	return {}

func _play(p: AudioStreamPlayer3D) -> void:
	if p.playing: p.stop()
	p.play()

## 풍향계를 짓는다 — root 는 그 층의 노드. 노드 원점은 받침대(hx, post_y, z); 절벽에서 나온 받침대, 쇠 기둥, N·E·S·W 십자(네 끝의 글자판), 녹슨 축, 화살 노드(축에서 도는) 안에 화살대·화살촉·꼬리 깃, 리본, creak, clack
func build(root: Node3D, planned: Array) -> void:
	var ph := post_h() * C.K
	for sv in planned:
		var s: Dictionary = (sv as Dictionary).duplicate()
		var node := Node3D.new(); node.position = C.to3(float(s["hx"]), float(s["post_y"]), float(s["z"]) * C.K); root.add_child(node)
		var wood := _mat(Color("8a6a4a")); var iron := _mat(Color("3a3640")); var brass := _mat(Color("c9a24a")); var rust := _mat(Color("8a4a3a")); var cloth := _mat(Color("ad7096"))
		var beam_len := (float(s["z"]) - C.WALL_Z) * C.K + 0.3
		_box(node, Vector3(0.12, 0.1, beam_len), wood).position = Vector3(0, 0.05, -beam_len / 2.0 + 0.1)   # 절벽에서 나온 받침대
		_box(node, Vector3(0.1, ph, 0.1), iron).position = Vector3(0, ph / 2.0, 0)   # 기둥
		_box(node, Vector3(0.9, 0.02, 0.02), iron).position = Vector3(0, ph - 0.22, 0)   # 동서 팔
		_box(node, Vector3(0.02, 0.02, 0.9), iron).position = Vector3(0, ph - 0.22, 0)   # 남북 팔
		for e in [Vector3(0.45, 0, 0), Vector3(-0.45, 0, 0), Vector3(0, 0, 0.45), Vector3(0, 0, -0.45)]:   # 팔 끝의 글자판(N·E·S·W)
			_box(node, Vector3(0.07, 0.07, 0.07), brass).position = Vector3(0, ph - 0.22, 0) + (e as Vector3)
		var spindle := MeshInstance3D.new(); var sm := CylinderMesh.new(); sm.top_radius = 0.025; sm.bottom_radius = 0.035; sm.height = 0.24; sm.radial_segments = 8; spindle.mesh = sm
		spindle.material_override = rust; spindle.position = Vector3(0, ph + 0.08, 0); spindle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; node.add_child(spindle)
		var vy := (float(s["tail_y"]) - float(s["post_y"])) * C.K; var arm := float(s["arm"]) * C.K; var dir := float(s["dir"])
		var vane := Node3D.new(); vane.position = Vector3(0, vy, 0); node.add_child(vane)
		_box(vane, Vector3(arm * 2.0, 0.03, 0.03), brass)   # 화살대
		_box(vane, Vector3(0.2, 0.03, 0.12), brass).position = Vector3(dir * (arm - 0.08), 0, 0)   # 화살촉 — 무거운 쪽
		_box(vane, Vector3(0.24, 0.2, 0.02), brass).position = Vector3(-dir * (arm - 0.12), 0, 0)   # 꼬리 깃
		s["ribbon"] = _box(node, Vector3(0.025, 0.025, 1.0), cloth)   # 깃 끝의 리본 — _place 가 깃 끝에서 손까지 잇는다
		var creak := AudioStreamPlayer3D.new(); creak.stream = _tick_wav(float(kind.get("creak_hz", 95)), 0.25); creak.volume_db = -8.0; creak.unit_size = 6.0; creak.max_distance = 30.0; node.add_child(creak)
		var clack := AudioStreamPlayer3D.new(); clack.stream = _tick_wav(float(kind.get("clack_hz", 260)), 0.1); clack.volume_db = -6.0; clack.unit_size = 6.0; clack.max_distance = 30.0; node.add_child(clack)
		s["node"] = node; s["vane"] = vane; s["creak"] = creak; s["clack"] = clack
		s["held"] = false; s["t0"] = -9.0; s["set0"] = -9.0; s["rel"] = -9.0; s["rtheta"] = 0.0
		vanes.append(s)
		_place(s)

## 화살을 지금 각으로(+y 돌림 dir·θ 면 깃이 절벽 앞으로 나온다), 리본은 깃 끝에서 손까지 — 빈 채론 깃 끝에서 곧장 아래로, 매달리면 로더가 고정한 깊이의 손까지 비스듬히
func _place(s: Dictionary) -> void:
	var th := ang(s, t); var dir := float(s["dir"]); var arm := float(s["arm"]) * C.K
	(s["vane"] as Node3D).rotation.y = dir * th
	var tip := Vector3(-dir * arm * cos(th), (float(s["tail_y"]) - float(s["post_y"])) * C.K, arm * sin(th))
	var h := hands(s, t)
	var end := Vector3((h.x - float(s["hx"])) * C.K, (h.y - float(s["post_y"])) * C.K, (C.PLAYER_Z - float(s["z"])) * C.K if bool(s["held"]) else tip.z)
	var v := end - tip
	var rib: Node3D = s["ribbon"]
	rib.basis = Basis.looking_at(v.normalized(), Vector3.FORWARD)
	rib.position = (tip + end) / 2.0
	rib.scale = Vector3(1, 1, maxf(0.01, v.length()))

func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.albedo_color = c; m.roughness = 1.0
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON; m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return m

func _box(parent: Node3D, size: Vector3, m: StandardMaterial3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = size; mi.mesh = bm; mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF   # 발판과 같은 규칙 — 그림자는 사람만
	parent.add_child(mi); return mi

## 축·멈춤쇠 소리 — 짧은 기음이 빠르게 잦아든다(해먹의 creak 과 같은 식). 한 번 재생, 반복 없음
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
