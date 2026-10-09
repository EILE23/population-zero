class_name ClimbBookcase
extends Node3D
## Climb 콘텐츠 팩 '미는 서가'(운영자 2026-10-06 밤: "Climb는 컨텐츠 자체의 질과 양을 늘리는 거" — 팩은 data/climb/*.json 자료, 로더는 운영자 세션이 잇는다; climb.gd 는 CI 가 안 건드린다).
## 서재(Library) 층의 넓은 발판(min_w 이상) 위 — 발판 윗면을 따라 놋쇠 궤도, 그 위에 바퀴 달린 키 큰 서가(case_w × case_h, 책이 세 줄)가 다음 발판 반대쪽 끝에서 behind 안쪽에 서 있다. 궤도는 다음 발판 쪽으로 뻗어 그 끝 stop 앞에서 멈춘다(사다리의 타는 자리 16px 는 비워 둔다).
## 서가 뒤에 서서 C 를 쥔 채 서가 쪽으로 밀면(손 = x + dir·HW 가 뒷면 reach 안) 서가가 궤도를 따라 굴러가고 몸이 함께 걷는다 — ease_s 에 속도가 붙고 push_s 에 궤도를 다 간다(무겁다); 끝막이에 닿으면 몸이 버티며 용을 쓴다(shunt_v 0). 손을 떼면(C·방향·뛰기) rest_s 뒤에 roll_s 에 걸쳐 제자리로 굴러 돌아온다(rumble, 끝에 thud).
## 서가 윗면은 디딤 — 떨어지는 몸이 올라서고(land) 굴러가는 동안 실려 간다(stand). 밀린 서가 위에서 다음 발판까지는 dy − 72 px: 어려운 점프가 쉬운 점프가 된다. 발판 위를 걷는 몸은 서가를 지나친다 — 아무것도 막지 않는다.
## 밀지도, 떨어뜨리지도, 거절하지도 않는다 — 점프 하나를 가구 하나로 낮추는 길. 미는 자세는 shunt(stick3d_shunt.gd — 운영자 보드의 '가구 밀기' 가족: 두 팔을 앞으로 뻗어 손을 대고 몸을 깊이 기울여 다리로 민다, 멈추면 벌린 두 발로 버틴다).
## 로더가 할 일(climb.gd, 운영자 세션): `var cs := ClimbBookcase.new(); add_child(cs)`; 층을 지을 때 `cs.build(root, cs.plan(n, plats, cl.plan(n, plats) + cd.plan(n, plats)))` (사다리·덤웨이터의 계획을 taken 으로 — 셋이 한 자리를 안 나눈다); 매 틱 `cs.sync(_t)`;
## 발판에 선 틱의 걷기 자리(`_physics_process` 의 `else:` — target 을 정하기 전): `var r := cs.push(on, x, z, dir, Input.is_action_pressed("act"), dt, fig); if r["pushing"]: x = r["x"]; vx = 0.0; fig.pose_request = "shunt"; elif fig.pose_request == "shunt": fig.pose_request = ""`;
## 로더 자신의 착지 판정이 비면 `landed = cs.land(x, y, ny, z)` (kind "shelf" — 서가 윗면);
## `on["kind"] == "shelf"` 인 매 틱, 'move' 발판 자리에서: `var r := cs.stand(on, x, dt); x = r["x"]; y = r["y"]; if r["off"]: on = {}; apex = y` — 로더 자신의 떠남 판정은 shelf 를 건너뛴다(on["x"] 는 집 자리).
## 단위는 climb.gd 와 같은 px(36px = 1m, +y 위). 점검은 tools/probe_bookcase.gd

const PACK := "res://data/climb/bookcase.json"
const C = preload("res://scripts/games/climb.gd")
const CASE_D := 16.0      # 서가 깊이(px) — 몸이 선 깊이(PLAYER_Z)에 걸쳐 선다
const LET_GO_T := 0.35    # 미는 틱이 이만큼 끊기면(뛰었다, 떠났다) 손을 뗀 것

var pack: Dictionary = {}
var kind: Dictionary = {}       # kinds.bookcase
var cases: Array = []           # 지은 서가 {id, kind "bookcase", x, y, w, z, d, a_id, a_y, dir, hx0, track, top_y, push_v, node, case, books, rumble, thud, pos, pushing, t0, last, rel, pos_rel, hit, ride_cx}
var t := 0.0                    # 로더의 _t 와 같이 간다(sync)

func _ready() -> void:
	var f := FileAccess.open(PACK, FileAccess.READ)
	if f: pack = JSON.parse_string(f.get_as_text()) as Dictionary
	kind = (pack.get("kinds", {}) as Dictionary).get("bookcase", {})

func sync(now: float) -> void:
	t = now
	for sv in cases:   # 미는 틱이 끊겼으면(뛰었다, 떠났다) 손을 뗀 것
		var s: Dictionary = sv
		if bool(s["pushing"]) and t - float(s["last"]) > LET_GO_T: _release(s)

func case_w() -> float:
	return float(kind.get("case_w", 40.0))

func case_h() -> float:
	return float(kind.get("case_h", 72.0))

func ease_s() -> float:
	return maxf(0.01, float(kind.get("ease_s", 0.3)))

func rest_s() -> float:
	return float(kind.get("rest_s", 4.0))

func roll_s() -> float:
	return maxf(0.01, float(kind.get("roll_s", 2.0)))

## 궤도를 따라 간 거리 px(0 집 .. track 끝막이): 미는 동안은 pos, 놓은 뒤엔 rest_s 쉬고 roll_s 에 걸쳐 집으로(smoothstep)
func pos_at(s: Dictionary, at: float) -> float:
	if bool(s["pushing"]): return float(s["pos"])
	var rel := float(s["rel"])
	if rel < -1.0: return 0.0
	var k := (at - rel - rest_s()) / roll_s()
	if k <= 0.0: return float(s["pos_rel"])
	if k >= 1.0: return 0.0
	return float(s["pos_rel"]) * (1.0 - smoothstep(0.0, 1.0, k))

## 서가 가운데 x(px)
func centre(s: Dictionary, at: float) -> float:
	return float(s["hx0"]) + float(s["dir"]) * pos_at(s, at)

## 돌아온 서가는 집에 선다; 노드를 지금 자리로
func _process(delta: float) -> void:
	t += delta
	cases = cases.filter(func(s: Dictionary) -> bool: return is_instance_valid(s["node"]))   # 지운 층의 것은 뺀다(climb_kite 와 같은 식)
	for sv in cases:
		var s: Dictionary = sv
		if bool(s["pushing"]) and t - float(s["last"]) > LET_GO_T: _release(s)
		_place(s)

## 층 n(테마 층만)의 still 발판(조각의 on) 중 min_w 이상 넓고 다음 발판이 더 높이 한쪽으로 비켜 선 것들 — 궤도 상자(서가 + 그 위의 몸)를 다른 발판이나 taken 조각이 가르지 않는 — 중 dy 가 가장 큰 하나(같으면 넓은 쪽)에 서가. 같은 층·같은 taken 은 늘 같은 답
func plan(n: int, plats: Array, taken: Array = []) -> Array:
	var out: Array = []
	if not (String(C.theme(n)[0]) in (pack.get("themes", []) as Array)): return out
	for pv in (pack.get("pieces", []) as Array):
		var piece: Dictionary = pv
		var only: Dictionary = piece.get("only", {})
		if not only.is_empty() and not _on(n, only): continue
		var kinds: Array = piece.get("on", ["std"])
		var min_w := float(kind.get("min_w", 150.0)); var cw := case_w(); var ch := case_h()
		var behind := float(kind.get("behind", 26.0)); var stop := float(kind.get("stop", 30.0))
		var hops := plats.filter(func(p: Dictionary) -> bool: return not (String(p["kind"]) in ["rest", "short", "ledge"]))
		var spots: Array = []
		for i in range(0, hops.size() - 1):
			var a: Dictionary = hops[i]; var b: Dictionary = hops[i + 1]   # a 가 서가의 발판, b 가 다음(band() 는 오르는 순서로 쌓는다)
			if not (String(a["kind"]) in kinds): continue
			var aw := float(a["w"])
			if aw < min_w: continue
			var dy := float(b["y"]) - float(a["y"])
			if dy <= 0.0: continue
			var ax0 := float(a["x"]); var ax1 := ax0 + aw; var bx0 := float(b["x"]); var bx1 := bx0 + float(b["w"])
			var dir := 1.0 if (bx0 + bx1) / 2.0 > (ax0 + ax1) / 2.0 else -1.0
			if (dir > 0.0 and bx0 < ax1) or (dir < 0.0 and bx1 > ax0): continue   # 겹친 발판 — 곧장 위로 뛰는 자리, 디딤이 소용없다
			var track := aw - behind - stop - cw
			if track < 20.0: continue
			var hx0 := ax0 + behind + cw / 2.0 if dir > 0.0 else ax1 - behind - cw / 2.0
			var x0 := minf(hx0, hx0 + dir * track) - cw / 2.0; var x1 := maxf(hx0, hx0 + dir * track) + cw / 2.0
			var top := float(a["y"]) + ch
			if not _clear(plats, a, x0 - C.HW, x1 + C.HW, float(a["y"]) + 1.0, top + 50.0): continue
			if not _free(taken, x0, x1, float(a["y"]), top): continue
			var d := float(a.get("d", C.DEPTH_HALF * 2.0))
			spots.append({ "dy": dy, "aw": aw, "hx0": hx0, "dir": dir, "track": track, "top_y": top, "a_id": String(a["id"]), "a_y": float(a["y"]), "d": d, "x": hx0 - cw / 2.0 })
		spots.sort_custom(func(p: Dictionary, q: Dictionary) -> bool: return float(p["dy"]) > float(q["dy"]) if float(p["dy"]) != float(q["dy"]) else float(p["aw"]) > float(q["aw"]))
		for i in range(0, mini(int(piece.get("max", 1)), spots.size())):
			var g: Dictionary = spots[i]
			var s: Dictionary = g.duplicate()
			s["id"] = "%d.B%d" % [n, i]; s["kind"] = "bookcase"; s["y"] = float(g["a_y"]); s["w"] = cw; s["z"] = C.PLAYER_Z + 2.0; s["push_v"] = float(g["track"]) / maxf(0.01, float(kind.get("push_s", 1.2)))
			out.append(s)
	return out

## 층 n 이 {from, every} 에 드나
static func _on(n: int, rule: Dictionary) -> bool:
	var from := int(rule.get("from", 0))
	return n >= from and (n - from) % maxi(1, int(rule.get("every", 1))) == 0

## 궤도 상자(서가가 지날 x, 발판 윗면..서가 위의 몸)에 그 발판 말고 다른 발판이 걸리지 않나 — 지름길 판이 가르면 서가가 걸린다
static func _clear(plats: Array, a: Dictionary, x0: float, x1: float, ylo: float, yhi: float) -> bool:
	for pv in plats:
		var p: Dictionary = pv
		if p["id"] == a["id"]: continue
		var py := float(p["y"])
		if py < ylo or py > yhi: continue
		var px0 := float(p["x"]) - 10.0; var px1 := float(p["x"]) + float(p["w"]) + 10.0
		if x1 > px0 and x0 < px1: return false
	return true

## 다른 팩의 조각(taken: x, w, y, 있으면 b_y·beam_y 까지의 기둥)이 궤도 상자와 겹치지 않나 — 덤웨이터의 기둥, 사다리의 틈
static func _free(taken: Array, x0: float, x1: float, ylo: float, yhi: float) -> bool:
	for tv in taken:
		var q: Dictionary = tv
		var qx0 := float(q.get("x", 0.0)) - 10.0; var qx1 := float(q.get("x", 0.0)) + float(q.get("w", 0.0)) + 10.0
		var qy0 := float(q.get("y", 0.0)) - 10.0
		var qy1 := maxf(maxf(float(q.get("y", 0.0)), float(q.get("b_y", -1e9))), float(q.get("beam_y", -1e9))) + 10.0
		if x1 > qx0 and x0 < qx1 and yhi > qy0 and ylo < qy1: return false
	return true

## 발판에 선 틱 — on 이 서가의 발판이고 C 를 쥔 채 서가 쪽(dir)으로 밀며 손(x + dir·HW)이 뒷면 reach 안이면 민다: {pushing, x} 의 x 는 뒷면에 붙어 걷는 몸의 자리. 아니면 {pushing false}
## fig 가 있으면 자세의 메타를 적는다: shunt_v 굴러가는 속도 0..1(끝막이에서 0 — 버틴다)
func push(on: Dictionary, x: float, z: float, dir: float, held: bool, dt: float, fig: Stick3D = null) -> Dictionary:
	var s := _reached(on, x, z, dir) if held and dir != 0.0 and not on.is_empty() else {}
	for sv in cases:   # 이 틱에 밀지 않는 서가는 손을 뗀 것 — 바로 놓인다
		if bool((sv as Dictionary)["pushing"]) and sv != s: _release(sv)
	if not s.is_empty():
		if not bool(s["pushing"]):
			s["pos"] = pos_at(s, t); s["pushing"] = true; s["t0"] = t; s["rel"] = -9.0; s["hit"] = false   # 돌아오던 서가는 그 자리에서 다시 밀린다(pos 는 pushing 을 세우기 전에 읽는다)
		s["last"] = t
		var v := float(s["push_v"]) * clampf((t - float(s["t0"])) / ease_s(), 0.0, 1.0)
		var np := minf(float(s["track"]), float(s["pos"]) + v * dt)
		var at_stop := np >= float(s["track"]) - 0.001
		if at_stop and not bool(s["hit"]): s["hit"] = true; _play(s["thud"])
		s["pos"] = np
		var nb := float(s["hx0"]) + dir * np - dir * case_w() / 2.0
		if fig: fig.set_meta("shunt_v", 0.0 if at_stop else v / maxf(0.01, float(s["push_v"])))
		return { "pushing": true, "x": nb - dir * (C.HW + 2.0) }
	return { "pushing": false, "x": x }

## on 이 발판이고 손(x + dir·HW)이 뒷면 reach 안인 서가 — 없으면 빈 사전
func _reached(on: Dictionary, x: float, z: float, dir: float) -> Dictionary:
	var reach := float(kind.get("reach", 18.0))
	for sv in cases:
		var s: Dictionary = sv
		if String(on.get("id", "")) != String(s["a_id"]) or dir != float(s["dir"]): continue
		if absf(z - float(s["z"])) >= CASE_D / 2.0 + C.HZ: continue
		if absf((x + dir * C.HW) - (centre(s, t) - dir * case_w() / 2.0)) <= reach: return s
	return {}

## 로더 자신의 착지 판정이 빈 뒤 — 떨어지는 몸이 서가 윗면을 지나면 올라선다: {kind "shelf", id, x, y, w, z, d}. 아니면 빈 사전
func land(x: float, y: float, ny: float, z: float) -> Dictionary:
	for sv in cases:
		var s: Dictionary = sv
		var top := float(s["top_y"])
		if y < top or ny > top: continue
		if absf(z - float(s["z"])) >= CASE_D / 2.0 + C.HZ: continue
		var cx := centre(s, t)
		if x + C.HW <= cx - case_w() / 2.0 or x - C.HW >= cx + case_w() / 2.0: continue
		s["ride_cx"] = cx
		return { "kind": "shelf", "id": String(s["id"]), "x": cx - case_w() / 2.0, "y": top, "w": case_w(), "z": float(s["z"]), "d": CASE_D }
	return {}

## 서가 위에 선 매 틱 — {x, y, off}: 서가가 굴러간 만큼 실려 가고, 윗면을 벗어나면 off
func stand(on: Dictionary, x: float, _dt: float) -> Dictionary:
	var s := _find(String(on.get("id", "")))
	if s.is_empty(): return { "x": x, "y": float(on.get("y", 0.0)), "off": true }
	var cx := centre(s, t)
	var nx := x + cx - float(s["ride_cx"]); s["ride_cx"] = cx
	var off := nx + C.HW <= cx - case_w() / 2.0 or nx - C.HW >= cx + case_w() / 2.0
	return { "x": nx, "y": float(s["top_y"]), "off": off }

## 손을 뗀다 — 지금 자리에서 rest_s 쉬고 집으로 굴러간다
func _release(s: Dictionary) -> void:
	s["pushing"] = false; s["rel"] = t; s["pos_rel"] = float(s["pos"]); s["hit"] = false

func _find(id: String) -> Dictionary:
	for sv in cases:
		if String((sv as Dictionary)["id"]) == id: return sv
	return {}

func _play(p: AudioStreamPlayer3D) -> void:
	if p.playing: p.stop()
	p.play()

## 서가를 짓는다 — root 는 그 층의 노드. 노드 원점은 서가의 집 자리 가운데(hx0, 발판 윗면, z); 궤도(놋쇠 띠)와 끝막이 둘, 서가 노드(case: 뒷판·옆판 둘·윗판·선반 셋·책 셋×books·바퀴 넷·rumble·thud)
func build(root: Node3D, planned: Array) -> void:
	var cw := case_w() * C.K; var ch := case_h() * C.K; var cd := CASE_D * C.K
	var rows := maxi(1, int(kind.get("shelves", 3))); var per := maxi(1, int(kind.get("books", 5)))
	for sv in planned:
		var s: Dictionary = (sv as Dictionary).duplicate()
		var dir := float(s["dir"]); var track := float(s["track"]) * C.K
		var node := Node3D.new(); node.position = C.to3(float(s["hx0"]), float(s["a_y"]), float(s["z"]) * C.K); root.add_child(node)
		var wood := _mat(Color("6b4a35")); var brass := _mat(Color("c9a07a")); var paper := _mat(Color("efe9e2")); var ink := _mat(Color("2f2a4e")); var sail := _mat(Color("ad7096"))
		var rail := _box(node, Vector3(track + cw, 0.02, cd * 0.6), brass); rail.position = Vector3(dir * track / 2.0, 0.01, 0)   # 놋쇠 궤도 — 집에서 끝막이까지
		_box(node, Vector3(0.05, 0.08, cd), wood).position = Vector3(-dir * (cw / 2.0 + 0.03), 0.04, 0)   # 집 쪽 끝막이
		_box(node, Vector3(0.05, 0.08, cd), wood).position = Vector3(dir * (track + cw / 2.0 + 0.03), 0.04, 0)   # 다음 발판 쪽 끝막이
		var unit := Node3D.new(); node.add_child(unit)
		var lift := 0.06   # 바퀴 높이
		_box(unit, Vector3(cw, ch - lift, 0.03), wood).position = Vector3(0, lift + (ch - lift) / 2.0, -cd / 2.0 + 0.015)   # 뒷판
		for sx: float in [-1.0, 1.0]: _box(unit, Vector3(0.03, ch - lift, cd), wood).position = Vector3(sx * (cw / 2.0 - 0.015), lift + (ch - lift) / 2.0, 0)   # 옆판
		_box(unit, Vector3(cw, 0.03, cd), wood).position = Vector3(0, ch - 0.015, 0)   # 윗판 — 디딤
		var books: Array = []
		for r in rows:
			var sy := lift + (ch - lift) * (float(r) + 0.25) / float(rows + 0.4)
			_box(unit, Vector3(cw - 0.06, 0.025, cd - 0.03), wood).position = Vector3(0, sy, 0)   # 선반
			for i in per:
				var bw := (cw - 0.1) / float(per); var bh := 0.16 + 0.05 * float((i * 7 + r * 3) % 3)
				var m := paper if (i + r) % 3 == 0 else (ink if (i + r) % 3 == 1 else sail)
				var book := _box(unit, Vector3(bw * 0.8, bh, cd - 0.06), m)
				book.position = Vector3(-cw / 2.0 + 0.05 + bw * (float(i) + 0.5), sy + 0.0125 + bh / 2.0, 0)
				book.rotation.z = 0.12 if i == per - 1 else 0.0   # 끝 책은 기대 선다
				book.set_meta("home", book.position); book.set_meta("tilt", book.rotation.z)
				books.append(book)
		for i in 4:
			var cast := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = 0.04; cm.bottom_radius = 0.04; cm.height = 0.03; cm.radial_segments = 8; cast.mesh = cm
			cast.material_override = ink; cast.rotation.x = PI / 2.0; cast.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			cast.position = Vector3((-1.0 if i % 2 == 0 else 1.0) * (cw / 2.0 - 0.08), 0.04, (-1.0 if i < 2 else 1.0) * (cd / 2.0 - 0.02)); unit.add_child(cast)   # 바퀴 넷
		var rumble := AudioStreamPlayer3D.new(); rumble.stream = _loop_wav(float(kind.get("rumble_hz", 70)), 0.3); rumble.volume_db = -16.0; rumble.unit_size = 6.0; rumble.max_distance = 30.0; unit.add_child(rumble)
		var thud := AudioStreamPlayer3D.new(); thud.stream = _tick_wav(float(kind.get("thud_hz", 110)), 0.1); thud.volume_db = -8.0; thud.unit_size = 6.0; thud.max_distance = 30.0; unit.add_child(thud)
		s["node"] = node; s["case"] = unit; s["books"] = books; s["rumble"] = rumble; s["thud"] = thud
		s["pos"] = 0.0; s["pushing"] = false; s["t0"] = -9.0; s["last"] = -9.0; s["rel"] = -9.0; s["pos_rel"] = 0.0; s["hit"] = false; s["ride_cx"] = float(s["hx0"]); s["moving"] = false
		cases.append(s)
		_place(s)

## 서가를 지금 자리로 — 구르는 동안 책이 흔들리고 rumble 이 돈다; 집에 닿으면 thud
func _place(s: Dictionary) -> void:
	var was := float(s.get("shown", 0.0))
	var p := pos_at(s, t)
	var unit: Node3D = s["case"]; unit.position = Vector3(float(s["dir"]) * p * C.K, 0, 0)
	var moving := absf(p - was) > 0.001
	if was > 0.001 and p <= 0.001 and not bool(s["pushing"]): _play(s["thud"])   # 집에 닿았다
	var rumble: AudioStreamPlayer3D = s["rumble"]
	if moving and not rumble.playing: rumble.play()
	elif not moving and rumble.playing: rumble.stop()
	var i := 0
	for bv in (s["books"] as Array):
		var book: Node3D = bv
		var tilt := float(book.get_meta("tilt"))
		book.rotation.z = tilt + (sin(t * 11.0 + float(i) * 0.9) * 0.06 if moving else 0.0)
		i += 1
	s["shown"] = p; s["moving"] = moving

func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.albedo_color = c; m.roughness = 1.0
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON; m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return m

func _box(parent: Node3D, size: Vector3, m: StandardMaterial3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = size; mi.mesh = bm; mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF   # 발판과 같은 규칙 — 그림자는 사람만
	parent.add_child(mi); return mi

## 끝막이 소리 — 짧은 기음이 아주 빠르게 잦아든다(연줄의 snap 과 같은 식). 한 번 재생, 반복 없음
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

## 바퀴 소리 — 낮은 기음에 거친 결을 얹어 돌려 튼다(구르는 동안만 play/stop)
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
