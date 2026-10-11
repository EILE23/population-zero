class_name ClimbZip
extends Node3D
## Climb 콘텐츠 팩 '집라인'(운영자 2026-10-06 밤: "Climb는 컨텐츠 자체의 질과 양을 늘리는 거" — 팩은 data/climb/*.json 자료, 로더는 운영자 세션이 잇는다; climb.gd 는 CI 가 안 건드린다).
## 공중정원(Hanging garden) 층(바람구멍 층은 뺀다)의 잇단 두 still 발판 사이 틈 — 위 발판의 틈 쪽 가장자리 안 inset 에 선 높은 말뚝에서 아래 발판의 낮은 말뚝으로 케이블이 내려가고, 꼭대기에 트롤리(바퀴 둘·걸이·가로대)가 서 있다; 아래 말뚝 stop 앞엔 고무 범퍼, 트롤리에서 위 말뚝의 윈치로 되감는 줄.
## 공중에서 ↑ 로 가로대를 붙잡으면(홀드와 같은 손 범위) 트롤리가 멎은 데서 G·sin(기울기)·roll 로 굴러 내려가고(max_v 까지; 몸무게에 케이블이 가운데서 sag 처진다), 범퍼 앞 brake 에서 v_end 로 늦춰져 범퍼에 닿으면(clunk) land_s 동안 몸을 아래 발판에 내려놓고 놓는다(done — 그 틱의 y 가 발판 윗면이라 다음 틱 로더의 착지 판정이 밟는다).
## ↓·SPACE 는 트롤리의 속도를 기울기대로 나눠 안고 놓는다(vx = dir·v·cos, vy = −v·sin). 일부러 내려가는 첫 팩: 놓친 발판으로 돌아가는 빠른 길, 또는 제 점프로는 갈 데 없는 발판에서 나가는 길.
## 빈 트롤리는 return_s 에 걸쳐 윈치가 되감아 올리고(click_s 마다 딸깍) 꼭대기에 서기 전엔 잡히지 않는다. 밀지도, 떨어뜨리지도, 거절하지도 않는다 — 발판의 제 점프는 그대로.
## 매달린 자세는 zip(stick3d_zip.gd — 두 손을 벌려 가로대를 쥐고 무릎을 가슴으로 접은 채 속도만큼 트롤리 뒤로 처졌다가 제동에 앞으로 쏠리고, 범퍼에선 다리가 내려와 발판을 디딘다).
## 연줄(kite — 바람이 수평으로 끌고 간다)·추(dangle — 호를 그린다)와 다르다: 이건 제 무게로 비탈을 내려가는 몸, 속도가 비탈의 것이다.
## 로더가 할 일(climb.gd, 운영자 세션): `var cz := ClimbZip.new(); add_child(cz)`; 층을 지을 때 `cz.build(root, cz.plan(n, plats, ch.plan(n, plats, wind_of(n)) + cb.plan(n, plats) + cg.plan(n, plats) + cm.plan(n, plats)))` (그물·다리·유령 판·버섯의 계획을 taken 으로 — 그 틈은 비켜 간다); 매 틱 `cz.sync(_t)`;
## 공중에서 ↑(dirz < 0)이고 홀드·다른 팩의 잡기가 비었으면 `var g := cz.grab(x, y, z); if not g.is_empty(): zipping = g; on = {}; vx = 0.0; vy = 0.0; charge = 0.0; face = float(g["dir"])` (zipping 은 로더의 새 사전 — holding 처럼);
## 매달린 매 틱(`_hold` 와 같은 자리, 맨 앞): `var r := cz.ride(zipping, dt, fig); x = r["x"]; y = r["y"]; apex = y; fig.pose_request = "zip"; if r["done"] or r["lost"]: zipping = {}; fig.pose_request = ""`;
## SPACE 를 놓으면 `var v := cz.let_go(zipping); vy = (JUMP_MIN + (JUMP_V - JUMP_MIN) * (charge / CHARGE)) * 0.9 + v["vy"]; vx = dir * RUN * 0.9 + v["vx"]; zipping = {}; 자세 ""`; ↓ 면 `vx = v["vx"]; vy = v["vy"]; zipping = {}`.
## 단위는 climb.gd 와 같은 px(36px = 1m, +y 위). 점검은 tools/probe_zip.gd

const PACK := "res://data/climb/zip.json"
const C = preload("res://scripts/games/climb.gd")
const TAKEN_UP := 120.0    # taken 조각(그물·다리·유령 판·버섯) 위로 비워 두는 높이(px) — 그 위에 선 몸
const DROP := 8.0          # 케이블에서 가로대까지(px) — 바퀴와 걸이
const WHEEL_R := 0.07      # 트롤리 바퀴 반지름(m)
const WINCH_R := 0.1       # 윈치 반지름(m)

var pack: Dictionary = {}
var kind: Dictionary = {}       # kinds.zip
var zips: Array = []            # 지은 집라인 {id, kind "zip", x, y, w, z, d, dir, gap, top_x, top_y, bot_x, bot_y, len, sin, cos, bar_y, feet_y, a_id, b_id, a_y, b_y, node, trolley, wheels, winch, up, down, haul, zing, clunk, click, held, t0, pos, v, vb, set0, rel, rpos, clicks}
var t := 0.0                    # 로더의 _t 와 같이 간다(sync)

func _ready() -> void:
	var f := FileAccess.open(PACK, FileAccess.READ)
	if f: pack = JSON.parse_string(f.get_as_text()) as Dictionary
	kind = (pack.get("kinds", {}) as Dictionary).get("zip", {})

func sync(now: float) -> void:
	t = now

func hang() -> float:
	return float(kind.get("hang", 58.0))

func inset() -> float:
	return maxf(0.0, float(kind.get("inset", 16.0)))

func stop() -> float:
	return maxf(0.0, float(kind.get("stop", 24.0)))

func brake() -> float:
	return maxf(1.0, float(kind.get("brake", 48.0)))

func max_v() -> float:
	return maxf(1.0, float(kind.get("max_v", 420.0)))

func v_end() -> float:
	return clampf(float(kind.get("v_end", 60.0)), 0.0, max_v())

func land_s() -> float:
	return maxf(0.01, float(kind.get("land_s", 0.25)))

func return_s() -> float:
	return maxf(0.01, float(kind.get("return_s", 3.0)))

func click_s() -> float:
	return maxf(0.05, float(kind.get("click_s", 0.25)))

## 비탈을 굴러 내려가는 가속 px/s² — G·sin(기울기)의 roll 배
func accel(s: Dictionary) -> float:
	return C.G * float(s["sin"]) * clampf(float(kind.get("roll", 0.35)), 0.0, 1.0)

## 케이블 위 꼭대기에서 d px 간 자리(px)
func along(s: Dictionary, d: float) -> Vector2:
	var u := clampf(d / maxf(1.0, float(s["len"])), 0.0, 1.0)
	return Vector2(lerpf(float(s["top_x"]), float(s["bot_x"]), u), lerpf(float(s["top_y"]), float(s["bot_y"]), u))

## 바퀴의 자리 — 몸이 매달리면 케이블이 가운데서 sag 만큼 처진다
func wheel(s: Dictionary, d: float, held: bool) -> Vector2:
	var p := along(s, d)
	if held: p.y -= float(kind.get("sag", 10.0)) * sin(PI * clampf(d / maxf(1.0, float(s["len"])), 0.0, 1.0))
	return p

## 가로대의 자리 — 손이 쥐는 곳, 바퀴 밑 DROP
func bar(s: Dictionary, d: float, held: bool) -> Vector2:
	return wheel(s, d, held) - Vector2(0.0, DROP)

## 지금 트롤리가 꼭대기에서 간 거리 px — 매달렸으면 제 자리, 놓인 뒤엔 return_s 에 걸쳐 되감겨 오르고(smoothstep), 그 뒤엔 꼭대기
func dist(s: Dictionary, at: float) -> float:
	if bool(s.get("held", false)): return float(s["pos"])
	var rel := float(s.get("rel", -9.0))
	if rel > -1.0 and at < rel + return_s(): return float(s["rpos"]) * (1.0 - smoothstep(0.0, 1.0, (at - rel) / return_s()))
	return 0.0

## 꼭대기에 서 있어 잡힐 수 있나
func parked(s: Dictionary, at: float) -> bool:
	return not bool(s.get("held", false)) and at >= float(s.get("rel", -9.0)) + return_s()

## 되감는 동안 윈치가 click_s 마다 딸깍; 트롤리·케이블을 지금 자리로
func _process(delta: float) -> void:
	t += delta
	zips = zips.filter(func(s: Dictionary) -> bool: return is_instance_valid(s["node"]))   # 지운 층의 것은 뺀다(climb_kite 와 같은 식)
	for sv in zips:
		var s: Dictionary = sv
		var rel := float(s.get("rel", -9.0))
		if not bool(s["held"]) and rel > -1.0 and t < rel + return_s():
			var n := floori((t - rel) / click_s())
			if n != int(s["clicks"]): s["clicks"] = n; _play(s["click"])
		_place(s)

## 층 n(테마 층만, 바람구멍 층은 뺀다)의 잇단 두 still 발판(조각의 on; 아래 a·위 b) 중 틈이 min_gap..max_gap 이고 b 가 min_dy..max_dy 높으며 케이블 상자를 다른 발판이 가르지 않고 taken 조각이 닿지 않는 짝들 중 가장 넓은 틈 하나 — 거기에 집라인. 같은 층·같은 taken 은 늘 같은 답
func plan(n: int, plats: Array, taken: Array = []) -> Array:
	var out: Array = []
	if not (String(C.theme(n)[0]) in (pack.get("themes", []) as Array)): return out
	var min_gap := float(kind.get("min_gap", 60.0)); var max_gap := float(kind.get("max_gap", 200.0))
	var min_dy := float(kind.get("min_dy", 60.0)); var max_dy := float(kind.get("max_dy", 150.0))
	var post_h := float(kind.get("post_h", 96.0)); var low_h := float(kind.get("low_h", 70.0)); var ins := inset()
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
			var dir := 1.0 if ax0 >= bx1 else -1.0   # 위 발판에서 아래 발판 쪽 — 아래가 오른쪽이면 +x 로 내려간다
			var gap := ax0 - bx1 if dir > 0.0 else bx0 - ax1
			if gap < min_gap or gap > max_gap: continue
			if float(a["w"]) < ins + stop() + 2.0 * C.HW: continue   # 아래 발판에 말뚝·범퍼·선 몸이 들어갈 폭
			var top_x := bx1 - ins if dir > 0.0 else bx0 + ins
			var bot_x := ax0 + ins if dir > 0.0 else ax1 - ins
			var top_y := float(b["y"]) + post_h; var bot_y := float(a["y"]) + low_h
			var x0 := minf(top_x, bot_x) - C.HW - 4.0; var x1 := maxf(top_x, bot_x) + C.HW + 4.0
			if not _clear(plats, a, b, x0, x1, float(a["y"]) + 1.0, top_y + 10.0): continue
			if not _free(taken, x0, x1, float(a["y"]) + 1.0, top_y + 10.0): continue
			var d := minf(float(a.get("d", C.DEPTH_HALF * 2.0)), float(b.get("d", C.DEPTH_HALF * 2.0)))
			spans.append({ "gap": gap, "dir": dir, "top_x": top_x, "top_y": top_y, "bot_x": bot_x, "bot_y": bot_y, "d": d,
				"a_id": String(a["id"]), "b_id": String(b["id"]), "a_y": float(a["y"]), "b_y": float(b["y"]), "a_x0": ax0, "a_x1": ax1 })
		spans.sort_custom(func(p: Dictionary, q: Dictionary) -> bool: return float(p["gap"]) > float(q["gap"]) if float(p["gap"]) != float(q["gap"]) else float(p["a_y"]) < float(q["a_y"]))
		for i in range(0, mini(int(piece.get("max", 1)), spans.size())):
			var g: Dictionary = spans[i]
			var s: Dictionary = g.duplicate()
			var run := absf(float(g["bot_x"]) - float(g["top_x"])); var fall := float(g["top_y"]) - float(g["bot_y"])
			var cl := sqrt(run * run + fall * fall)
			s["id"] = "%d.Z%d" % [n, i]; s["kind"] = "zip"; s["x"] = minf(float(g["top_x"]), float(g["bot_x"])); s["w"] = run; s["y"] = float(g["a_y"]); s["z"] = C.WALL_Z + float(g["d"]) / 2.0
			s["len"] = cl; s["sin"] = fall / cl; s["cos"] = run / cl; s["bar_y"] = float(g["top_y"]) - DROP; s["feet_y"] = float(g["top_y"]) - DROP - hang()
			out.append(s)
	return out

## 층 n 이 {from, every} 에 드나
static func _on(n: int, rule: Dictionary) -> bool:
	var from := int(rule.get("from", 0))
	return n >= from and (n - from) % maxi(1, int(rule.get("every", 1))) == 0

## 케이블 상자(두 말뚝 사이 + 몸 폭, 아래 발판 윗면..위 말뚝 머리)에 두 발판 말고 다른 발판이 걸리지 않나 — 움직이는 발판은 진폭째
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

## 다른 팩의 조각(taken: x·w·y)이 케이블 상자에 닿지 않나 — 조각 위 TAKEN_UP 까지 그 조각의 몸
static func _free(taken: Array, x0: float, x1: float, ylo: float, yhi: float) -> bool:
	for tv in taken:
		var q: Dictionary = tv
		var qx0 := float(q["x"]) - 10.0; var qx1 := float(q["x"]) + float(q.get("w", 0.0)) + 10.0
		var qy := float(q.get("y", 0.0)); var qy0 := qy - 10.0; var qy1 := qy + TAKEN_UP
		if x1 > qx0 and x0 < qx1 and yhi > qy0 and ylo < qy1: return false
	return true

## 공중에서 ↑ — 손(발 + hang)이 꼭대기에 선 가로대의 reach_x·reach_y 안이면 잡는다(zing): 돌려주는 사전의 x·y 가 몸의 자리(가로대 밑 hang), dir 이 내려갈 쪽. 되감기는 중이거나 누가 탔으면 아니다
func grab(x: float, y: float, z: float) -> Dictionary:
	var rx := float(kind.get("reach_x", 26.0)); var ry := float(kind.get("reach_y", 22.0))
	for sv in zips:
		var s: Dictionary = sv
		if absf(z - float(s["z"])) >= float(s["d"]) / 2.0 + C.HZ: continue
		if not parked(s, t): continue
		var h := bar(s, 0.0, false)
		if absf(x - h.x) < rx and absf(y + hang() - h.y) < ry:
			s["held"] = true; s["t0"] = t; s["pos"] = 0.0; s["v"] = 0.0; s["vb"] = -1.0; s["set0"] = -9.0
			_play(s["zing"])
			return { "id": String(s["id"]), "kind": "zip", "x": h.x, "y": h.y - hang(), "t0": t, "dir": float(s["dir"]) }
	return {}

## 매달린 매 틱 — {x, y, done, lost, vx, vy}: 트롤리가 비탈을 굴러 내려가고(accel, max_v 까지; 범퍼 앞 brake 에서 v_end 로) 범퍼에 닿으면(clunk) land_s 에 걸쳐 몸을 아래 발판 윗면에 내려놓고 done. 집라인이 사라졌거나 잡고 있지 않으면 lost.
## fig 가 있으면 자세의 메타를 적는다: zip_v 속도 −1..1(+x 가 +), zip_brk 제동 0..1, zip_set 내려놓기 0..1
func ride(riding: Dictionary, dt: float, fig: Stick3D = null) -> Dictionary:
	var s := _find(String(riding.get("id", "")))
	if s.is_empty() or not bool(s.get("held", false)): return { "x": float(riding.get("x", 0.0)), "y": float(riding.get("y", 0.0)), "done": false, "lost": true, "vx": 0.0, "vy": 0.0 }
	var dir := float(s["dir"]); var end := float(s["len"]) - stop()
	var d := float(s["pos"]); var v := float(s["v"]); var brk := 0.0
	if float(s["set0"]) < -1.0:
		v = minf(v + accel(s) * dt, max_v())
		var left := end - d
		if left < brake():
			if float(s["vb"]) < 0.0: s["vb"] = v   # 제동 구간에 든 속도 — 거기서 v_end 로 곧게
			v = minf(v, v_end() + (float(s["vb"]) - v_end()) * left / brake()); brk = 1.0 - left / brake()
		d = minf(end, d + v * dt)
		if d >= end: s["set0"] = t; v = 0.0; brk = 1.0; _play(s["clunk"])
		s["pos"] = d; s["v"] = v
	var b := bar(s, d, true)
	var feet := b.y - hang()
	var ks := 0.0; var done := false
	if float(s["set0"]) > -1.0:
		ks = clampf((t - float(s["set0"])) / land_s(), 0.0, 1.0); brk = 1.0
		feet = lerpf(feet, float(s["a_y"]), smoothstep(0.0, 1.0, ks))
		done = ks >= 1.0
	if done:
		_release(s)
		feet = float(s["a_y"])
	if fig:
		fig.set_meta("zip_v", dir * v / max_v())
		fig.set_meta("zip_brk", brk)
		fig.set_meta("zip_set", ks)
	return { "x": b.x, "y": feet, "done": done, "lost": false, "vx": dir * v * float(s["cos"]), "vy": -v * float(s["sin"]) }

## 놓는 순간 트롤리의 속도 {vx, vy} px/s — 비탈대로 나눠 안고 간다(zing); 빈 트롤리는 되감긴다
func let_go(riding: Dictionary) -> Dictionary:
	var s := _find(String(riding.get("id", "")))
	if s.is_empty() or not bool(s.get("held", false)): return { "vx": 0.0, "vy": 0.0 }
	var v := float(s["v"])
	_release(s)
	_play(s["zing"])
	return { "vx": float(s["dir"]) * v * float(s["cos"]), "vy": -v * float(s["sin"]) }

## 트롤리를 비운다 — 지금 자리에서 return_s 에 걸쳐 되감긴다
func _release(s: Dictionary) -> void:
	s["held"] = false; s["rel"] = t; s["rpos"] = float(s["pos"]); s["set0"] = -9.0; s["clicks"] = -1

func _find(id: String) -> Dictionary:
	for sv in zips:
		if String((sv as Dictionary)["id"]) == id: return sv
	return {}

func _play(p: AudioStreamPlayer3D) -> void:
	if p.playing: p.stop()
	p.play()

## 집라인을 짓는다 — root 는 그 층의 노드. 노드 원점은 위 말뚝 밑(top_x, b_y, z); 말뚝 둘과 머리쇠, 윈치, 범퍼, 케이블 둘(위 말뚝→트롤리, 트롤리→아래 말뚝 — _place 가 길이·각을 맞춘다), 되감는 줄, 트롤리(바퀴 둘·걸이·가로대), zing·clunk·click
func build(root: Node3D, planned: Array) -> void:
	for sv in planned:
		var s: Dictionary = (sv as Dictionary).duplicate()
		var node := Node3D.new(); node.position = C.to3(float(s["top_x"]), float(s["b_y"]), float(s["z"]) * C.K); root.add_child(node)
		var wood := _mat(Color("8a6a4a")); var iron := _mat(Color("3a3640")); var brass := _mat(Color("c9a07a")); var rubber := _mat(Color("1b0c15")); var plate := _mat(Color("ad7096"))
		var body_z := (C.PLAYER_Z - float(s["z"])) * C.K   # 몸이 서는 깊이 — 가로대는 손 자리에
		var ph := (float(s["top_y"]) - float(s["b_y"])) * C.K; var lh := (float(s["bot_y"]) - float(s["a_y"])) * C.K
		var bx := (float(s["bot_x"]) - float(s["top_x"])) * C.K; var by := (float(s["a_y"]) - float(s["b_y"])) * C.K
		_box(node, Vector3(0.08, ph, 0.08), wood).position = Vector3(0, ph / 2.0, body_z)                       # 위 말뚝
		_box(node, Vector3(0.16, 0.05, 0.16), brass).position = Vector3(0, ph + 0.025, body_z)                   # 머리쇠
		_box(node, Vector3(0.08, lh, 0.08), wood).position = Vector3(bx, by + lh / 2.0, body_z)                  # 아래 말뚝
		_box(node, Vector3(0.16, 0.05, 0.16), brass).position = Vector3(bx, by + lh + 0.025, body_z)             # 머리쇠
		var winch := MeshInstance3D.new(); var wm := CylinderMesh.new(); wm.top_radius = WINCH_R; wm.bottom_radius = WINCH_R; wm.height = 0.05; wm.radial_segments = 10; winch.mesh = wm
		winch.material_override = brass; winch.rotation.x = PI / 2.0; winch.position = Vector3(0, ph + 0.15, body_z); winch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; node.add_child(winch)   # 윈치
		var stop_p := along(s, float(s["len"]) - stop())
		_box(node, Vector3(0.1, 0.1, 0.1), rubber).position = Vector3((stop_p.x - float(s["top_x"])) * C.K, (stop_p.y - float(s["b_y"])) * C.K, body_z)   # 범퍼
		var up := _box(node, Vector3(0.015, 1.0, 0.015), iron)      # 케이블 위 토막 — 길이·각은 _place
		var down := _box(node, Vector3(0.015, 1.0, 0.015), iron)    # 케이블 아래 토막
		var haul := _box(node, Vector3(0.01, 1.0, 0.01), brass)     # 되감는 줄
		var trolley := Node3D.new(); node.add_child(trolley)         # 원점은 바퀴 축
		var wheels: Array = []
		for k in [-1.0, 1.0]:
			var wh := MeshInstance3D.new(); var m := CylinderMesh.new(); m.top_radius = WHEEL_R; m.bottom_radius = WHEEL_R; m.height = 0.04; m.radial_segments = 10; wh.mesh = m
			wh.material_override = iron; wh.rotation.x = PI / 2.0; wh.position = Vector3((k as float) * 0.09, 0, 0); wh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; trolley.add_child(wh)
			wheels.append(wh)
		_box(trolley, Vector3(0.22, DROP * C.K + 0.04, 0.03), iron).position = Vector3(0, -DROP * C.K / 2.0, 0)   # 걸이
		_box(trolley, Vector3(0.44, 0.04, 0.04), wood).position = Vector3(0, -DROP * C.K, 0)                     # 가로대 — 손이 쥔다
		_box(trolley, Vector3(0.08, 0.06, 0.01), plate).position = Vector3(0, -DROP * C.K / 2.0, 0.02)           # 번호판 — 강조색만
		var zing := AudioStreamPlayer3D.new(); zing.stream = _tick_wav(float(kind.get("zing_hz", 520)), 0.1); zing.volume_db = -10.0; zing.unit_size = 6.0; zing.max_distance = 30.0; node.add_child(zing)
		var clunk := AudioStreamPlayer3D.new(); clunk.stream = _tick_wav(float(kind.get("clunk_hz", 110)), 0.15); clunk.volume_db = -8.0; clunk.unit_size = 6.0; clunk.max_distance = 30.0; node.add_child(clunk)
		var click := AudioStreamPlayer3D.new(); click.stream = _tick_wav(float(kind.get("click_hz", 700)), 0.04); click.volume_db = -16.0; click.unit_size = 6.0; click.max_distance = 30.0; node.add_child(click)
		s["node"] = node; s["trolley"] = trolley; s["wheels"] = wheels; s["winch"] = winch; s["up"] = up; s["down"] = down; s["haul"] = haul; s["zing"] = zing; s["clunk"] = clunk; s["click"] = click
		s["held"] = false; s["t0"] = -9.0; s["pos"] = 0.0; s["v"] = 0.0; s["vb"] = -1.0; s["set0"] = -9.0; s["rel"] = -9.0; s["rpos"] = 0.0; s["clicks"] = -1
		zips.append(s)
		_place(s)

## 트롤리를 지금 자리로, 케이블 두 토막과 되감는 줄을 그 사이로, 바퀴·윈치는 간 만큼 돈다(살아 있는 것은 움직인다)
func _place(s: Dictionary) -> void:
	var d := dist(s, t); var held := bool(s["held"])
	var body_z := (C.PLAYER_Z - float(s["z"])) * C.K
	var w := wheel(s, d, held)
	var at := Vector3((w.x - float(s["top_x"])) * C.K, (w.y - float(s["b_y"])) * C.K, body_z)
	var trolley: Node3D = s["trolley"]; trolley.position = at
	for wv in (s["wheels"] as Array): (wv as Node3D).rotation.z = -float(s["dir"]) * d * C.K / WHEEL_R
	var top := Vector3(0, (float(s["top_y"]) - float(s["b_y"])) * C.K, body_z)
	var bot := Vector3((float(s["bot_x"]) - float(s["top_x"])) * C.K, (float(s["bot_y"]) - float(s["b_y"])) * C.K, body_z)
	_line(s["up"], top, at); _line(s["down"], at, bot)
	var winch: Node3D = s["winch"]; winch.rotation.z = d * C.K / WINCH_R
	_line(s["haul"], winch.position, at + Vector3(0, 0.02, 0.03))

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

## 줄·범퍼 소리 — 짧은 기음이 빠르게 잦아든다: zing(0.1초, 케이블이 운다)·clunk(0.15초, 낮고 둔하다)·click(0.04초, 윈치의 톱니). 한 번 재생, 반복 없음
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
