class_name ClimbKite
extends Node3D
## Climb 콘텐츠 팩 '연줄'(운영자 2026-10-06 밤: "Climb는 컨텐츠 자체의 질과 양을 늘리는 거" — 팩은 data/climb/*.json 자료, 로더는 운영자 세션이 잇는다; climb.gd 는 CI 가 안 건드린다).
## 바람 절벽(Wind cliffs) 층의 잇단 두 발판 사이 틈 — 아래 발판 끝의 나무 말뚝과 실패에서 연줄이 올라가 틈 위 바람에 박힌 마름모 연(꼬리가 바람 쪽으로 흐른다), 연에서 줄이 내려와 손잡이 토글이 걸려 있다.
## 공중에서 ↑ 로 토글을 붙잡으면(홀드와 같은 손 범위; 발은 건너편 발판 윗면보다 lift 위) 몸무게로 연이 dip 만큼 내려앉고 바람이 몸을 틈 위로 수평으로 끌고 간다(drag_v + wind_k·|바람|, ease_s 에 걸쳐 속도가 붙는다);
## 건너편 발판 위로 set_in 들어서면 연이 land_s 동안 몸을 발판에 내려놓고 놓는다(done — 그 틱의 y 가 발판 윗면이라 다음 틱 로더의 착지 판정이 밟는다). ↓·SPACE 는 연의 속도를 안고 놓는다; 실패의 줄이 다 풀리면 줄이 처져 떨어진다(lost).
## 40층부터는 그 층의 바람(climb.gd wind_of)이 방향을 정한다 — 건너편 발판이 바람 아래쪽인 짝만; 그 아래 층은 바람이 없어 절벽의 제 돌풍이 건너편 쪽으로 분다. 빈 연은 return_s 에 걸쳐 제자리로 돌아오고, 집에 오면 흔들리며(bob·sway) 다시 잡힌다.
## 밀지도, 떨어뜨리지도, 거절하지도 않는다 — 점프 하나를 바람에 맡기는 길. 매달린 자세는 kite(stick3d_kite.gd — 두 손이 머리 위 한 줄의 토글을 모아 쥐고 다리가 바람에 끌려 뒤로 흐르며 펄럭인다, 내려놓을 땐 다리가 앞으로 내려온다). 잡을 때·내려놓을 때 줄이 팽팽해지는 snap, 놓으면 돛이 펄럭이는 flap.
## 로더가 할 일(climb.gd, 운영자 세션): `var ck := ClimbKite.new(); add_child(ck)`; 층을 지을 때 `ck.build(root, ck.plan(n, plats, wind_of(n)))`; 매 틱 `ck.sync(_t)`;
## 공중에서 ↑(dirz < 0)이고 홀드·다른 팩의 잡기가 비었으면 `var g := ck.grab(x, y, z); if not g.is_empty(): kiting = g; on = {}; vx = 0.0; vy = 0.0; charge = 0.0; face = float(g["dir"])` (kiting 은 로더의 새 사전 — holding 처럼);
## 매달린 매 틱(`_hold` 와 같은 자리, 맨 앞): `var r := ck.hang_on(kiting, fig); x = r["x"]; y = r["y"]; apex = y; fig.pose_request = "kite"; stamina -= dt * 0.09; if r["done"] or r["lost"]: kiting = {}; fig.pose_request = ""`;
## SPACE 를 놓으면 `var v := ck.let_go(kiting); vy = (JUMP_MIN + (JUMP_V - JUMP_MIN) * (charge / CHARGE)) * 0.9; vx = dir * RUN * 0.9 + v["vx"]; kiting = {}; 자세 ""`; ↓ 나 힘이 다하면 `vx = v["vx"]; vy = 0.0; kiting = {}`.
## 단위는 climb.gd 와 같은 px(36px = 1m, +y 위). 점검은 tools/probe_kite.gd

const PACK := "res://data/climb/kite.json"
const C = preload("res://scripts/games/climb.gd")

var pack: Dictionary = {}
var kind: Dictionary = {}       # kinds.kite
var kites: Array = []           # 지은 연 {id, kind "kite", x, y, w, z, d, hx, dir, gap, v, drift, a_y, b_y, b_x0, b_x1, feet_y, hand_y, kite_y, peg_x, node, kite, tether, bows, snap, flap, held, t0, set0, d0, rel, roff, rdip}
var t := 0.0                    # 로더의 _t 와 같이 간다(sync)

func _ready() -> void:
	var f := FileAccess.open(PACK, FileAccess.READ)
	if f: pack = JSON.parse_string(f.get_as_text()) as Dictionary
	kind = (pack.get("kinds", {}) as Dictionary).get("kite", {})

func sync(now: float) -> void:
	t = now

func hang() -> float:
	return float(kind.get("hang", 58.0))

func ease_s() -> float:
	return maxf(0.01, float(kind.get("ease_s", 0.25)))

func land_s() -> float:
	return maxf(0.01, float(kind.get("land_s", 0.3)))

func return_s() -> float:
	return maxf(0.01, float(kind.get("return_s", 2.0)))

## 이 층의 바람에서 끌려가는 속도 px/s — 돌풍 drag_v 에 바람의 wind_k 배를 얹고 max_v 로 막는다
func speed_for(wind: float) -> float:
	return minf(float(kind.get("max_v", 260.0)), float(kind.get("drag_v", 150.0)) + absf(wind) * float(kind.get("wind_k", 0.5)))

## 잡은 뒤 k 초 동안 끌려간 거리 px — ease_s 까지 속도가 곧게 붙고(거리는 포물선) 그 뒤 v 로
func dist(s: Dictionary, k: float) -> float:
	var v := float(s["v"]); var e := ease_s()
	if k < e: return v * k * k / (2.0 * e)
	return v * (k - e / 2.0)

## 잡은 뒤 k 초의 속도 비 0..1
func vel_k(k: float) -> float:
	return clampf(k / ease_s(), 0.0, 1.0)

## 몸무게로 연이 내려앉은 px — dip_s 에 걸쳐 곧게
func dip_at(k: float) -> float:
	return float(kind.get("dip", 12.0)) * clampf(k / maxf(0.01, float(kind.get("dip_s", 0.4))), 0.0, 1.0)

## 연(과 토글)의 지금 자리 — 제 자리에서 바람 쪽으로 밀린 x(px)와 내려앉은 y(px, 양수가 내려앉음) {ox, dy}: 매달렸으면 끌린 거리와 dip, 놓인 뒤엔 return_s 에 걸쳐 돌아오고(smoothstep), 집에서는 fade_s 에 걸쳐 흔들림이 돌아온다
func offset(s: Dictionary, at: float) -> Vector2:
	if bool(s.get("held", false)):
		var k := at - float(s["t0"]); var set0 := float(s.get("set0", -9.0))
		var d := dist(s, k) if set0 < -1.0 else float(s["d0"]) + float(s["v"]) * (at - set0) * (1.0 - 0.5 * clampf((at - set0) / land_s(), 0.0, 1.0))
		return Vector2(float(s["dir"]) * d, dip_at(k))
	var rel := float(s.get("rel", -9.0))
	var home := at - rel - return_s()   # 집에 온 뒤 흐른 시간(음수면 돌아오는 중)
	if rel > -1.0 and home < 0.0:
		var back := 1.0 - smoothstep(0.0, 1.0, (at - rel) / return_s())
		return Vector2(float(s["roff"]) * back, float(s["rdip"]) * back)
	var fade := 1.0 if rel < -1.0 else smoothstep(0.0, maxf(0.01, float(kind.get("fade_s", 1.0))), home)
	var sway := float(kind.get("sway", 8.0)) * sin(TAU * float(kind.get("sway_hz", 0.25)) * at) * fade
	var bob := float(kind.get("bob", 6.0)) * sin(TAU * float(kind.get("bob_hz", 0.5)) * at) * fade
	return Vector2(sway, -bob)

## 토글의 자리(px) — 손이 잡는 곳
func toggle(s: Dictionary, at: float) -> Vector2:
	var o := offset(s, at)
	return Vector2(float(s["hx"]) + o.x, float(s["hand_y"]) - o.y)

## 돌아온 연은 집에 선다; 노드를 지금 자리로
func _process(delta: float) -> void:
	t += delta
	kites = kites.filter(func(s: Dictionary) -> bool: return is_instance_valid(s["node"]))   # 지운 층의 것은 뺀다(climb_pendulum 과 같은 식)
	for sv in kites:
		var s: Dictionary = sv
		_place(s)

## 층 n(테마 층만)의 잇단 두 still 발판(조각의 on) 중 틈이 min_gap..max_gap 이고 위 발판이 max_dy 안으로 높으며 바람 아래쪽에 있고(wind 0 이면 어느 쪽이든) 연·몸이 지날 상자를 다른 발판이 가르지 않는 짝들 중 가장 넓은 틈 하나 — 거기에 연. 같은 층·같은 바람은 늘 같은 답
func plan(n: int, plats: Array, wind: float) -> Array:
	var out: Array = []
	if not (String(C.theme(n)[0]) in (pack.get("themes", []) as Array)): return out
	for pv in (pack.get("pieces", []) as Array):
		var piece: Dictionary = pv
		var only: Dictionary = piece.get("only", {})
		if not only.is_empty() and not _on(n, only): continue
		var kinds: Array = piece.get("on", ["std"])
		var min_gap := float(kind.get("min_gap", 60.0)); var max_gap := float(kind.get("max_gap", 200.0)); var max_dy := float(kind.get("max_dy", 150.0))
		var over := clampf(float(kind.get("over", 0.4)), 0.0, 1.0); var lift := float(kind.get("lift", 20.0)); var slen := float(kind.get("string_len", 120.0))
		var kw := float(kind.get("kite_w", 40.0)); var kh := float(kind.get("kite_h", 48.0))
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
			if wind != 0.0 and signf(wind) != dir: continue   # 바람을 거슬러선 못 끌고 간다
			var gap := bx0 - ax1 if dir > 0.0 else ax0 - bx1
			if gap < min_gap or gap > max_gap: continue
			var edge := ax1 if dir > 0.0 else ax0
			var hx := edge + dir * gap * over
			var feet := float(b["y"]) + lift; var handy := feet + hang(); var ky := handy + slen
			var lo := (hx - kw / 2.0 if dir > 0.0 else bx0) - C.HW; var hi := (bx1 if dir > 0.0 else hx + kw / 2.0) + C.HW   # 연의 바람 위쪽 끝에서 건너편 발판 끝까지
			if not _clear(plats, a, b, lo, hi, float(b["y"]) + 1.0, ky + kh / 2.0): continue
			var d := minf(float(a.get("d", C.DEPTH_HALF * 2.0)), float(b.get("d", C.DEPTH_HALF * 2.0)))
			spans.append({ "gap": gap, "hx": hx, "dir": dir, "d": d, "a_y": float(a["y"]), "b_y": float(b["y"]), "b_x0": bx0, "b_x1": bx1, "feet_y": feet, "hand_y": handy, "kite_y": ky,
				"peg_x": edge - dir * 14.0, "drift": gap * (1.0 - over) + float(b["w"]) + 30.0, "x": edge if dir > 0.0 else bx1 })
		spans.sort_custom(func(p: Dictionary, q: Dictionary) -> bool: return float(p["gap"]) > float(q["gap"]))
		for i in range(0, mini(int(piece.get("max", 1)), spans.size())):
			var g: Dictionary = spans[i]
			var s: Dictionary = g.duplicate()
			s["id"] = "%d.K%d" % [n, i]; s["kind"] = "kite"; s["y"] = float(g["feet_y"]); s["w"] = float(g["gap"]); s["z"] = C.WALL_Z + float(g["d"]) / 2.0; s["v"] = speed_for(wind); s["wind"] = wind
			out.append(s)
	return out

## 층 n 이 {from, every} 에 드나
static func _on(n: int, rule: Dictionary) -> bool:
	var from := int(rule.get("from", 0))
	return n >= from and (n - from) % maxi(1, int(rule.get("every", 1))) == 0

## 연과 매달린 몸이 지날 상자(틈..건너편 발판 끝, 건너편 윗면..연 꼭대기)에 두 발판 말고 다른 발판이 걸리지 않나 — 지름길 판이나 위에 겹친 턱이 가르면 연이 걸린다
static func _clear(plats: Array, a: Dictionary, b: Dictionary, x0: float, x1: float, ylo: float, yhi: float) -> bool:
	for pv in plats:
		var p: Dictionary = pv
		if p["id"] == a["id"] or p["id"] == b["id"]: continue
		var py := float(p["y"])
		if py < ylo or py > yhi: continue
		var px0 := float(p["x"]) - 10.0; var px1 := float(p["x"]) + float(p["w"]) + 10.0
		if x1 > px0 and x0 < px1: return false
	return true

## 공중에서 ↑ — 손(발 + hang)이 토글의 reach_x·reach_y 안이고 연이 비어 집에 있으면 잡는다(snap): 돌려주는 사전의 x·y 가 몸의 자리(토글 밑 hang), dir 이 끌려갈 쪽. 아니면 빈 사전
func grab(x: float, y: float, z: float) -> Dictionary:
	var rx := float(kind.get("reach_x", 26.0)); var ry := float(kind.get("reach_y", 22.0))
	for sv in kites:
		var s: Dictionary = sv
		if absf(z - float(s["z"])) >= float(s["d"]) / 2.0 + C.HZ: continue
		if bool(s.get("held", false)) or t < float(s.get("rel", -9.0)) + return_s(): continue   # 누가 매달렸거나 돌아오는 중
		var h := toggle(s, t)
		if absf(x - h.x) < rx and absf(y + hang() - h.y) < ry:
			s["held"] = true; s["t0"] = t; s["set0"] = -9.0; s["d0"] = 0.0
			_play(s["snap"])
			return { "id": String(s["id"]), "kind": "kite", "x": h.x, "y": h.y - hang(), "t0": t, "dir": float(s["dir"]) }
	return {}

## 매달린 매 틱 — {x, y, done, lost}: 바람 쪽으로 끌려가며(ease_s 에 속도가 붙고 dip 만큼 내려앉는다) 건너편 발판 위로 set_in 들어서면 내려놓기(land_s, 드리프트는 반으로) → 발판 윗면에서 done(snap). 줄이 다 풀리면 lost(처진다). 연이 사라졌으면 lost.
## fig 가 있으면 자세의 메타를 적는다: kite_v 끌려가는 x 속도 −1..1(+x 가 +), kite_set 내려놓기 0..1
func hang_on(riding: Dictionary, fig: Stick3D = null) -> Dictionary:
	var s := _find(String(riding.get("id", "")))
	if s.is_empty() or not bool(s.get("held", false)): return { "x": float(riding.get("x", 0.0)), "y": float(riding.get("y", 0.0)), "done": false, "lost": true }
	var dir := float(s["dir"]); var k := t - float(s["t0"])
	var set0 := float(s.get("set0", -9.0))
	if set0 < -1.0:
		var d := dist(s, k)
		if d >= float(s["drift"]):   # 실패의 줄이 다 풀렸다 — 처진다
			_release(s, dir * d, dip_at(k))
			if fig: fig.set_meta("kite_v", 0.0); fig.set_meta("kite_set", 0.0)
			return { "x": float(s["hx"]) + dir * d, "y": float(s["hand_y"]) - dip_at(k) - hang(), "done": false, "lost": true }
		var kx := float(s["hx"]) + dir * d
		var into := kx - float(s["b_x0"]) if dir > 0.0 else float(s["b_x1"]) - kx
		if into >= float(kind.get("set_in", 20.0)): s["set0"] = t; s["d0"] = d; set0 = t   # 건너편 발판 위 — 내려놓기 시작
	var o := offset(s, t)
	var px := float(s["hx"]) + o.x
	var feet := float(s["hand_y"]) - o.y - hang()
	var ks := 0.0; var done := false
	if set0 > -1.0:
		ks = clampf((t - set0) / land_s(), 0.0, 1.0)
		var feet0 := float(s["hand_y"]) - dip_at(set0 - float(s["t0"])) - hang()
		feet = lerpf(feet0, float(s["b_y"]), smoothstep(0.0, 1.0, ks))
		done = ks >= 1.0
	if done:
		_release(s, o.x, o.y)
		feet = float(s["b_y"])
		_play(s["snap"])
	if fig:
		fig.set_meta("kite_v", dir * vel_k(k) * (1.0 - 0.5 * ks))
		fig.set_meta("kite_set", ks)
	return { "x": px, "y": feet, "done": done, "lost": false }

## 놓는 순간 연의 속도 {vx, vy} px/s — 바람 쪽으로 끌려가던 만큼 안고 간다(flap); 빈 연은 제자리로 돌아간다
func let_go(riding: Dictionary) -> Dictionary:
	var s := _find(String(riding.get("id", "")))
	if s.is_empty() or not bool(s.get("held", false)): return { "vx": 0.0, "vy": 0.0 }
	var k := t - float(s["t0"]); var o := offset(s, t)
	var ks := 0.0 if float(s.get("set0", -9.0)) < -1.0 else clampf((t - float(s["set0"])) / land_s(), 0.0, 1.0)
	_release(s, o.x, o.y)
	_play(s["flap"])
	return { "vx": float(s["dir"]) * float(s["v"]) * vel_k(k) * (1.0 - 0.5 * ks), "vy": 0.0 }

## 연을 비운다 — 지금 밀린 x(부호 그대로)·내려앉음에서 return_s 에 걸쳐 돌아온다
func _release(s: Dictionary, roff: float, rdip: float) -> void:
	s["held"] = false; s["rel"] = t; s["roff"] = roff; s["rdip"] = rdip; s["set0"] = -9.0

func _find(id: String) -> Dictionary:
	for sv in kites:
		if String((sv as Dictionary)["id"]) == id: return sv
	return {}

func _play(p: AudioStreamPlayer3D) -> void:
	if p.playing: p.stop()
	p.play()

## 연을 짓는다 — root 는 그 층의 노드. 노드 원점은 토글의 집 자리(hx, hand_y, z); 아래 발판 끝의 말뚝과 실패, 연까지의 연줄(tether — _place 가 길이·각을 맞춘다), 연 노드(kite: 마름모 돛·살 둘·토글까지의 줄·토글·꼬리 줄·고리 셋), snap·flap
func build(root: Node3D, planned: Array) -> void:
	var kw := float(kind.get("kite_w", 40.0)) * C.K; var kh := float(kind.get("kite_h", 48.0)) * C.K
	var slen := float(kind.get("string_len", 120.0)) * C.K; var tail := float(kind.get("tail", 70.0)) * C.K
	for sv in planned:
		var s: Dictionary = (sv as Dictionary).duplicate()
		var dir := float(s["dir"])
		var node := Node3D.new(); node.position = C.to3(float(s["hx"]), float(s["hand_y"]), float(s["z"]) * C.K); root.add_child(node)
		var wood := _mat(Color("8a6a4a")); var paper := _mat(Color("efe9e2")); var sail := _mat(Color("ad7096")); var ink := _mat(Color("2f2a4e")); var line := _mat(Color("c9a07a"))
		var body_z := (C.PLAYER_Z - float(s["z"])) * C.K   # 몸이 서는 깊이 — 토글은 손 자리에
		var peg_x := (float(s["peg_x"]) - float(s["hx"])) * C.K; var peg_y := (float(s["a_y"]) - float(s["hand_y"])) * C.K
		_box(node, Vector3(0.06, 0.3, 0.06), wood).position = Vector3(peg_x, peg_y + 0.15, body_z - 0.2)   # 말뚝
		var reel := MeshInstance3D.new(); var rm := CylinderMesh.new(); rm.top_radius = 0.09; rm.bottom_radius = 0.09; rm.height = 0.08; rm.radial_segments = 10; reel.mesh = rm
		reel.material_override = line; reel.rotation.x = PI / 2.0; reel.position = Vector3(peg_x, peg_y + 0.26, body_z - 0.2); reel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; node.add_child(reel)   # 실패
		var tether := _box(node, Vector3(0.015, 1.0, 0.015), line)   # 실패에서 연까지 — 길이·각은 _place
		var kite := Node3D.new(); node.add_child(kite)   # 연 — 원점은 토글의 집 자리, 돛은 slen 위
		var sail_n := Node3D.new(); sail_n.position = Vector3(0, slen, body_z - 0.3); sail_n.rotation.z = -dir * 0.3; kite.add_child(sail_n)   # 머리가 바람 쪽으로 기운다
		var dia := Node3D.new(); dia.scale = Vector3(kw / sqrt(2.0), kh / sqrt(2.0), 1.0); sail_n.add_child(dia)
		_box(dia, Vector3(1.0, 1.0, 0.02), sail).rotation.z = PI / 4.0   # 45° 돌린 네모 = 마름모(대각선이 kite_w·kite_h)
		_box(sail_n, Vector3(0.03, kh, 0.02), wood).position = Vector3(0, 0, 0.02)   # 세로 살
		_box(sail_n, Vector3(kw, 0.03, 0.02), wood).position = Vector3(0, kh * 0.15, 0.02)   # 가로 살 — 가운데보다 위
		_box(kite, Vector3(0.02, slen, 0.02), line).position = Vector3(0, slen / 2.0, body_z - 0.3)   # 연에서 토글까지
		_box(kite, Vector3(0.22, 0.05, 0.05), wood).position = Vector3(0, 0, body_z - 0.3)   # 토글 — 손이 쥔다
		var tdir := Vector3(dir * 0.8, -0.6, 0).normalized()   # 꼬리는 바람 쪽 아래로 흐른다
		var tbase := Vector3(0, slen - kh / 2.0, body_z - 0.3)
		var tstr := _box(kite, Vector3(0.012, tail, 0.012), line)
		tstr.transform = Transform3D(Basis(Quaternion(Vector3.UP, tdir)), tbase + tdir * tail / 2.0)   # 꼬리 줄(look_at 은 트리 밖에서 못 쓴다)
		var bows: Array = []
		for i in 3:
			var bow := _box(kite, Vector3(0.14, 0.06, 0.02), paper if i != 1 else ink)
			bow.position = tbase + tdir * tail * (float(i + 1) / 3.0); bow.set_meta("home", bow.position)
			bows.append(bow)
		var snap := AudioStreamPlayer3D.new(); snap.stream = _tick_wav(float(kind.get("snap_hz", 180)), 0.08); snap.volume_db = -10.0; snap.unit_size = 6.0; snap.max_distance = 30.0; kite.add_child(snap)
		var flap := AudioStreamPlayer3D.new(); flap.stream = _tick_wav(float(kind.get("flap_hz", 900)), 0.07); flap.volume_db = -14.0; flap.unit_size = 6.0; flap.max_distance = 30.0; kite.add_child(flap)
		s["node"] = node; s["kite"] = kite; s["tether"] = tether; s["bows"] = bows; s["snap"] = snap; s["flap"] = flap
		s["held"] = false; s["t0"] = -9.0; s["set0"] = -9.0; s["d0"] = 0.0; s["rel"] = -9.0; s["roff"] = 0.0; s["rdip"] = 0.0
		kites.append(s)
		_place(s)

## 연·토글·연줄·꼬리를 지금 자리로 — 연줄은 실패에서 돛 가운데까지, 꼬리 고리는 바람에 물결친다
func _place(s: Dictionary) -> void:
	var o := offset(s, t)
	var kite: Node3D = s["kite"]; kite.position = Vector3(o.x * C.K, -o.y * C.K, 0)
	var slen := float(kind.get("string_len", 120.0)) * C.K
	var body_z := (C.PLAYER_Z - float(s["z"])) * C.K
	var from := Vector3((float(s["peg_x"]) - float(s["hx"])) * C.K, (float(s["a_y"]) - float(s["hand_y"])) * C.K + 0.26, body_z - 0.2)
	var to := kite.position + Vector3(0, slen, body_z - 0.3)
	var tether: Node3D = s["tether"]
	var tl := maxf(0.05, (to - from).length())
	tether.transform = Transform3D(Basis(Quaternion(Vector3.UP, (to - from) / tl)) * Basis.from_scale(Vector3(1, tl, 1)), (from + to) / 2.0)   # 돌린 뒤 제 축으로 늘인다
	var i := 0
	for bv in (s["bows"] as Array):
		var bow: Node3D = bv
		var home: Vector3 = bow.get_meta("home")
		bow.position = home + Vector3(0, sin(t * 5.0 + float(i) * 1.1) * 0.05 * float(i + 1), 0)
		bow.rotation.z = sin(t * 5.0 + float(i) * 1.1) * 0.4
		i += 1

func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.albedo_color = c; m.roughness = 1.0
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON; m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return m

func _box(parent: Node3D, size: Vector3, m: StandardMaterial3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = size; mi.mesh = bm; mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF   # 발판과 같은 규칙 — 그림자는 사람만
	parent.add_child(mi); return mi

## 줄 소리 — 짧은 기음이 아주 빠르게 잦아든다: snap(0.08초, 낮고 팽팽하다)·flap(0.07초, 종이처럼 높고 메마르다; 덤웨이터의 click 과 같은 식). 한 번 재생, 반복 없음
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
