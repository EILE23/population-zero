class_name ClimbDumbwaiter
extends Node3D
## Climb 콘텐츠 팩 '덤웨이터'(운영자 2026-10-06 밤: "Climb는 컨텐츠 자체의 질과 양을 늘리는 거" — 팩은 data/climb/*.json 자료, 로더는 운영자 세션이 잇는다; climb.gd 는 CI 가 안 건드린다).
## 서재(Library) 층의 위아래로 겹쳐 선 두 발판(오르는 순서로 둘 떨어진 i·i+2 — 층 생성기는 발판을 지그재그로 쌓아 둘 건너는 자주 겹친다) 사이 — 절벽에 안내 레일 둘, 위 발판보다 beam_above 위에 들보와 두 줄 도르래, 줄에 매달린 상자, 그 뒤 절벽 쪽 다른 줄에 평형추(도서관의 책 올리는 승강기).
## 발판 위 상자 옆에서 C: 상자가 이 끝에 있으면 올라탄다(mount_s 에 한 걸음) — 아래 발판에서면 C 한 번이 한 번의 당김(손 바꿔 줄을 가슴까지): 상자가 pull 만큼 오르고(heave_s, 완만하게) 멈춤쇠가 hold_s 붙잡다가 다음 당김까지 slip_v 로 조금씩 되미끄러진다(바닥 아래론 안 간다); 위 발판 높이에 닿으면 멈춤쇠가 걸리고(clack) 내려선다.
## 위 발판에서면 실린 상자가 저절로 내려간다 — 평형추보다 무거워서, 줄을 쥔 손이 제동하며 down_v 로(완만하게) — 바닥에서 내려선다. 상자가 건너편 끝에 있으면 C 는 부르기 — 빈 채 call_v 로 온다. 타는 중 ↓ 는 그 자리에서 내리고(빈 상자는 가까운 끝까지 저절로 간다), SPACE 로 모았다 놓으면 홀드처럼 0.9 로 뛰되 상자의 세로 속도를 얹는다.
## 밀지도, 떨어뜨리지도, 거절하지도 않는다 — 점프 둘을 손힘으로 바꾸는 느리고 확실한 길. 타는 동안 자세는 heave(stick3d_heave.gd — 당길 땐 한 손이 머리 위에서 가슴까지 내려오고 다른 손이 위로 올라 번갈아, 내려갈 땐 두 손이 머리 위 줄을 쥐고 무릎을 굽혀 제동). 당길 때마다 멈춤쇠 click, 설 때 clack.
## 사다리(ladder)는 잇단 발판 사이 틈에, 덤웨이터는 둘 건너 발판의 겹친 기둥에 — 같은 층에 둘이 있어도 자리가 다르다(상자는 두 발판 끝에서 margin 안쪽, 서가 벽이 발판 위로 24px 나온 것도 비켜 간다).
## 로더가 할 일(climb.gd, 운영자 세션): `var cd := ClimbDumbwaiter.new(); add_child(cd)`; 층을 지을 때 `cd.build(root, cd.plan(n, plats))`; 매 틱 `cd.sync(_t)`;
## `_after_step` 의 C 자리(판 읽기·쉼터 문 다음): `elif not locked and Input.is_action_just_pressed("act") and not on.is_empty(): var g := cd.grab(on, x, z); if not g.is_empty(): lifting = g; on = {}; vx = 0.0; vy = 0.0; charge = 0.0` (lifting 은 로더의 새 사전 — holding 처럼; 빈 사전이면 부르기였거나 닿지 않는 것);
## 타는 매 틱(`_hold` 와 같은 자리, 맨 앞): `if Input.is_action_just_pressed("act"): cd.heave(lifting)`; `var r := cd.ride_on(lifting, fig); x = r["x"]; y = r["y"]; apex = y; fig.pose_request = "heave"; if r["done"] or r["lost"]: lifting = {}; fig.pose_request = ""`
## SPACE 를 놓으면 `var v := cd.let_go(lifting); vy = (JUMP_MIN + (JUMP_V - JUMP_MIN) * (charge / CHARGE)) * 0.9 + maxf(0.0, v["vy"]); vx = dir * RUN * 0.9; lifting = {}; 자세 ""`; ↓ 면 `vy = minf(0.0, v["vy"]); lifting = {}`.
## done 인 틱의 x·y 는 건너편 발판 위 자리라 다음 틱 로더 자신의 착지 판정이 그 발판을 밟는다. 단위는 climb.gd 와 같은 px(36px = 1m, +y 위). 점검은 tools/probe_dumbwaiter.gd

const PACK := "res://data/climb/dumbwaiter.json"
const C = preload("res://scripts/games/climb.gd")

var pack: Dictionary = {}
var kind: Dictionary = {}       # kinds.dumbwaiter
var lifts: Array = []           # 지은 덤웨이터 {id, kind "dumbwaiter", x, y, w, z, d, hx, a_y, b_y, beam_y, a_id, b_id, node, car, rope, rope2, weight, click, clack, end, go, gy, to, rider, mode, t0, pt, pf, pto, hand}
var t := 0.0                    # 로더의 _t 와 같이 간다(sync)

func _ready() -> void:
	var f := FileAccess.open(PACK, FileAccess.READ)
	if f: pack = JSON.parse_string(f.get_as_text()) as Dictionary
	kind = (pack.get("kinds", {}) as Dictionary).get("dumbwaiter", {})

func sync(now: float) -> void:
	t = now

func pull() -> float:
	return maxf(1.0, float(kind.get("pull", 36.0)))

func heave_s() -> float:
	return maxf(0.05, float(kind.get("heave_s", 0.3)))

func hold_s() -> float:
	return maxf(0.0, float(kind.get("hold_s", 0.4)))

func slip_v() -> float:
	return maxf(0.0, float(kind.get("slip_v", 30.0)))

func down_v() -> float:
	return maxf(10.0, float(kind.get("down_v", 120.0)))

func call_v() -> float:
	return maxf(10.0, float(kind.get("call_v", 160.0)))

func mount_s() -> float:
	return maxf(0.0, float(kind.get("mount_s", 0.25)))

## 실린 상자가 위에서 바닥까지 내려가는 시간 — 가운데에서 down_v, 양 끝에선 0 (smoothstep 의 가운데 기울기 1.5)
func desc_s(s: Dictionary) -> float:
	return (float(s["b_y"]) - float(s["a_y"])) * 1.5 / down_v()

## 상자 바닥의 y(px) — 타는 중이면 당김·멈춤·되미끄러짐(오를 때)이나 제동 하강(내릴 때), 빈 채 가는 중이면 호(smoothstep), 아니면 서 있는 끝
func cy(s: Dictionary, at: float) -> float:
	var bot := float(s["a_y"]); var top := float(s["b_y"])
	if bool(s.get("rider", false)) and at >= float(s.get("t0", at)) + mount_s():
		if int(s.get("mode", 1)) > 0:
			var pt := float(s.get("pt", -9.0))
			if pt < -1.0: return bot
			var k := at - pt; var pto := float(s["pto"])
			if k < heave_s(): return lerpf(float(s["pf"]), pto, smoothstep(0.0, 1.0, k / heave_s()))
			if k < heave_s() + hold_s(): return pto
			return maxf(bot, pto - slip_v() * (k - heave_s() - hold_s()))
		return lerpf(top, bot, smoothstep(0.0, 1.0, clampf((at - float(s["t0"]) - mount_s()) / desc_s(s), 0.0, 1.0)))
	var go := float(s.get("go", -9.0))
	if go > -1.0 and at >= go:
		var to := top if int(s.get("to", 1)) == 1 else bot
		var gy := float(s.get("gy", bot))
		return lerpf(gy, to, smoothstep(0.0, 1.0, clampf((at - go) / (absf(to - gy) * 1.5 / call_v()), 0.0, 1.0)))
	return top if int(s.get("end", 0)) == 1 else bot

## 상자의 세로 속도 px/s(위가 +) — 두 틱 사이 차로(짧은 h 의 중앙차분)
func cvy(s: Dictionary, at: float) -> float:
	return (cy(s, at + 0.01) - cy(s, at - 0.01)) / 0.02

## 빈 채 가던 상자가 끝에 닿으면 선다(clack); 노드를 지금 자리로
func _process(delta: float) -> void:
	t += delta
	lifts = lifts.filter(func(s: Dictionary) -> bool: return is_instance_valid(s["node"]))   # 지운 층의 것은 뺀다(climb_ladder 와 같은 식)
	for sv in lifts:
		var s: Dictionary = sv
		var go := float(s.get("go", -9.0))
		if go > -1.0 and not bool(s.get("rider", false)):
			var to := float(s["b_y"]) if int(s.get("to", 1)) == 1 else float(s["a_y"])
			if t >= go + absf(to - float(s.get("gy", float(s["a_y"])))) * 1.5 / call_v():
				s["end"] = int(s["to"]); s["go"] = -9.0
				_play(s["clack"])
		_place(s)

## 층 n(테마 층만, 조각의 'only' 층만)의 둘 건너 선 발판 짝(조각의 on) 중 x 가 min_overlap 이상 겹치고 높이차가 min_dy..max_dy 에 들며 기둥이 막히지 않은 것들 중 가장 넓게 겹친 하나 — 거기에 덤웨이터. 같은 층은 늘 같은 답
func plan(n: int, plats: Array) -> Array:
	var out: Array = []
	if not (String(C.theme(n)[0]) in (pack.get("themes", []) as Array)): return out
	for pv in (pack.get("pieces", []) as Array):
		var piece: Dictionary = pv
		var only: Dictionary = piece.get("only", {})
		if not only.is_empty() and not _on(n, only): continue
		var kinds: Array = piece.get("on", ["std"])
		var min_dy := float(kind.get("min_dy", 160.0)); var max_dy := float(kind.get("max_dy", 330.0)); var above := float(kind.get("beam_above", 96.0))
		var cw := float(kind.get("crate_w", 44.0)); var margin := float(kind.get("margin", 30.0))
		var hops := plats.filter(func(p: Dictionary) -> bool: return not (String(p["kind"]) in ["rest", "short", "ledge"]))
		var shafts: Array = []
		for i in range(2, hops.size()):
			var a: Dictionary = hops[i - 2]; var b: Dictionary = hops[i]   # a 가 아래 발판(band() 는 오르는 순서로 쌓는다)
			if not (String(a["kind"]) in kinds and String(b["kind"]) in kinds): continue
			var dy := float(b["y"]) - float(a["y"])
			if dy < min_dy or dy > max_dy: continue
			var ox0 := maxf(float(a["x"]), float(b["x"])); var ox1 := minf(float(a["x"]) + float(a["w"]), float(b["x"]) + float(b["w"]))
			if ox1 - ox0 < cw + margin * 2.0: continue
			var hx := (ox0 + ox1) / 2.0
			if not _clear(plats, a, b, hx - cw / 2.0 - C.HW, hx + cw / 2.0 + C.HW, float(a["y"]) + 1.0, float(b["y"]) + above): continue
			var d := minf(float(a.get("d", C.DEPTH_HALF * 2.0)), float(b.get("d", C.DEPTH_HALF * 2.0)))
			shafts.append({ "ov": ox1 - ox0, "hx": hx, "d": d, "a_y": float(a["y"]), "b_y": float(b["y"]), "a_id": String(a["id"]), "b_id": String(b["id"]) })
		shafts.sort_custom(func(p: Dictionary, q: Dictionary) -> bool: return float(p["ov"]) > float(q["ov"]))
		for i in range(0, mini(int(piece.get("max", 1)), shafts.size())):
			var g: Dictionary = shafts[i]
			out.append({ "id": "%d.D%d" % [n, i], "kind": "dumbwaiter", "x": float(g["hx"]) - cw / 2.0, "y": float(g["a_y"]), "w": cw, "z": C.WALL_Z + float(g["d"]) / 2.0, "d": float(g["d"]),
				"hx": float(g["hx"]), "a_y": float(g["a_y"]), "b_y": float(g["b_y"]), "beam_y": float(g["b_y"]) + above, "a_id": String(g["a_id"]), "b_id": String(g["b_id"]) })
	return out

## 층 n 이 {from, every} 에 드나
static func _on(n: int, rule: Dictionary) -> bool:
	var from := int(rule.get("from", 0))
	return n >= from and (n - from) % maxi(1, int(rule.get("every", 1))) == 0

## 기둥(상자 폭 + 몸, 아래 윗면..들보)에 두 발판 말고 다른 발판이 걸리지 않나 — 지름길 판이나 가운데 턱이 가르면 못 읽는다
static func _clear(plats: Array, a: Dictionary, b: Dictionary, x0: float, x1: float, ylo: float, yhi: float) -> bool:
	for pv in plats:
		var p: Dictionary = pv
		if p["id"] == a["id"] or p["id"] == b["id"]: continue
		var py := float(p["y"])
		if py < ylo or py > yhi: continue
		var px0 := float(p["x"]) - 10.0; var px1 := float(p["x"]) + float(p["w"]) + 10.0
		if x1 > px0 and x0 < px1: return false
	return true

## 발판 on 에 선 몸이 C — 그 발판이 덤웨이터의 두 발판 중 하나고 몸이 상자 가운데에서 reach_x 안이면: 상자가 이 끝에 서 있으면 올라탄다(돌려주는 사전이 로더의 lifting — dir +1 오르는 길, −1 내려가는 길, t0 탄 시각, x0 선 자리),
## 건너편에 서 있으면 부른다(빈 채 온다, 빈 사전), 가는 중·누가 타는 중이면 아무것도(빈 사전)
func grab(on: Dictionary, x: float, z: float) -> Dictionary:
	var rx := float(kind.get("reach_x", 40.0))
	var id := String(on.get("id", ""))
	for sv in lifts:
		var s: Dictionary = sv
		if absf(z - float(s["z"])) >= float(s["d"]) / 2.0 + C.HZ: continue
		var here := -1
		if id == String(s["a_id"]): here = 0
		elif id == String(s["b_id"]): here = 1
		if here < 0 or absf(x - float(s["hx"])) >= rx: continue
		if float(s.get("go", -9.0)) > -1.0 or bool(s.get("rider", false)): return {}   # 가는 중·누가 타는 중
		if int(s.get("end", 0)) != here:   # 건너편에 서 있다 — 부른다
			s["gy"] = cy(s, t); s["to"] = here; s["go"] = t
			return {}
		s["rider"] = true; s["mode"] = 1 if here == 0 else -1; s["t0"] = t; s["pt"] = -9.0; s["hand"] = 1.0
		return { "id": String(s["id"]), "kind": "dumbwaiter", "dir": 1.0 if here == 0 else -1.0, "t0": t, "x0": x, "y0": float(on.get("y", 0.0)) }
	return {}

## 타는 중 C 한 번 — 오르는 길에서 올라탄 다음이면 한 번의 당김: 지금 높이에서 pull 위까지(꼭대기에서 멈춘다), 손을 바꾼다, click. 내려가는 길·올라타는 중엔 아무것도(false)
func heave(riding: Dictionary) -> bool:
	var s := _find(String(riding.get("id", "")))
	if s.is_empty() or not bool(s.get("rider", false)) or int(s.get("mode", 1)) < 0 or t < float(s["t0"]) + mount_s(): return false
	s["pf"] = cy(s, t); s["pto"] = minf(float(s["b_y"]), float(s["pf"]) + pull()); s["pt"] = t; s["hand"] = -float(s.get("hand", 1.0))
	_play(s["click"])
	return true

## 타는 매 틱 — {x, y, done, lost}: 올라타기(mount_s) → 오르는 길은 당김마다 오르고 위 발판 높이에서 끝, 내려가는 길은 제동 하강(desc_s) → 바닥에서 끝. 끝나면 상자는 그 끝에 선다(clack).
## fig 가 있으면 자세의 메타를 적는다: heave_k 당김 1 → 0 (heave_s 에 걸쳐), heave_h 당기는 손 ±1, heave_v 세로 속도 −1..1. 덤웨이터가 사라졌으면 lost
func ride_on(riding: Dictionary, fig: Stick3D = null) -> Dictionary:
	var s := _find(String(riding.get("id", "")))
	if s.is_empty(): return { "x": float(riding.get("x0", 0.0)), "y": float(riding.get("y0", 0.0)), "done": false, "lost": true }
	var up := float(riding.get("dir", 1.0)) > 0.0
	var k := t - float(riding.get("t0", t))
	var hx := float(s["hx"]); var top := float(s["b_y"]); var bot := float(s["a_y"])
	var px := hx; var py := bot if up else top; var done := false
	var hk := 0.0; var hv := 0.0
	if k < mount_s():   # 올라타기 — 발판에서 상자 가운데로 한 걸음
		px = lerpf(float(riding.get("x0", hx)), hx, smoothstep(0.0, 1.0, k / maxf(0.01, mount_s())))
	else:
		py = cy(s, t)
		hv = clampf(cvy(s, t) / (pull() / heave_s() if up else down_v()), -1.0, 1.0)
		if up:
			var pt := float(s.get("pt", -9.0))
			if pt > -1.0: hk = clampf(1.0 - (t - pt) / heave_s(), 0.0, 1.0)
			done = py >= top - 0.5
		else: done = k >= mount_s() + desc_s(s)
	if done:
		s["rider"] = false; s["end"] = 1 if up else 0; s["go"] = -9.0
		py = top if up else bot; hk = 0.0; hv = 0.0
		_play(s["clack"])
	if fig:
		fig.set_meta("heave_k", hk)
		fig.set_meta("heave_h", float(s.get("hand", 1.0)))
		fig.set_meta("heave_v", hv)
	return { "x": px, "y": py, "done": done, "lost": false }

## 놓는 순간 상자의 세로 속도 {vy} px/s(위가 +) — 뛰면 얹고, 떨어지면 안고 간다; 빈 상자는 가까운 끝까지 저절로 간다(call_v)
func let_go(riding: Dictionary) -> Dictionary:
	var s := _find(String(riding.get("id", "")))
	if s.is_empty(): return { "vy": 0.0 }
	var v := cvy(s, t) if t >= float(s.get("t0", t)) + mount_s() else 0.0
	var now := cy(s, t)
	s["gy"] = now; s["rider"] = false; s["to"] = 1 if now > (float(s["a_y"]) + float(s["b_y"])) / 2.0 else 0; s["go"] = t   # 빈 상자는 가까운 끝으로
	return { "vy": v }

func _find(id: String) -> Dictionary:
	for sv in lifts:
		if String((sv as Dictionary)["id"]) == id: return sv
	return {}

func _play(p: AudioStreamPlayer3D) -> void:
	if p.playing: p.stop()
	p.play()

## 덤웨이터를 짓는다 — root 는 그 층의 노드. 노드 원점은 상자 기둥 가운데·아래 발판 높이·발판 깊이 가운데; 절벽에 안내 레일 둘, 위에 들보와 두 줄 도르래, 상자(car — 바닥·네 벽·뒤 모서리의 책 두 덩이·뒤로 기운 손잡이 고리)와 그 줄, 절벽 쪽 평형추와 그 줄, click·clack
func build(root: Node3D, planned: Array) -> void:
	var cw := float(kind.get("crate_w", 44.0)) * C.K; var ch := float(kind.get("crate_h", 26.0)) * C.K; var cd := float(kind.get("crate_d", 40.0)) * C.K
	var bail := float(kind.get("bail_h", 54.0)) * C.K
	for sv in planned:
		var s: Dictionary = (sv as Dictionary).duplicate()
		var node := Node3D.new(); node.position = C.to3(float(s["hx"]), float(s["a_y"]), float(s["z"]) * C.K); root.add_child(node)
		var wood := _mat(Color("6b4a35")); var oak := _mat(Color("c9a07a")); var brass := _mat(Color("c9a24a")); var iron := _mat(Color("4a4a52")); var paper := _mat(Color("efe9e2"))
		var wall_z := (C.WALL_Z - float(s["z"])) * C.K + 0.06   # 절벽 면(노드 기준)
		var body_z := (C.PLAYER_Z - float(s["z"])) * C.K        # 몸이 서는 깊이
		var rope_z := body_z - 10.0 * C.K                        # 줄은 몸 바로 뒤
		var beam_y := (float(s["beam_y"]) - float(s["a_y"])) * C.K
		var shaft_h := beam_y - 0.1
		for i in 2:   # 안내 레일 — 상자 뒤 모서리가 타는 홈
			_box(node, Vector3(0.04, shaft_h, 0.06), iron).position = Vector3(cw * (0.5 if i == 0 else -0.5), shaft_h / 2.0, wall_z + 0.03)
		var beam_len := rope_z - wall_z + 0.3
		_box(node, Vector3(0.14, 0.12, beam_len), wood).position = Vector3(0, beam_y + 0.06, wall_z + beam_len / 2.0 - 0.1)   # 절벽에서 나온 들보
		for i in 2:   # 두 줄 도르래 — 앞바퀴는 상자 줄, 뒷바퀴는 평형추 줄
			var pz := rope_z if i == 0 else wall_z + 0.18
			var wheel := MeshInstance3D.new(); var wm := CylinderMesh.new(); wm.top_radius = 0.13; wm.bottom_radius = 0.13; wm.height = 0.05; wm.radial_segments = 12; wheel.mesh = wm
			wheel.material_override = brass; wheel.rotation.x = PI / 2.0; wheel.position = Vector3(0, beam_y - 0.1, pz); wheel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; node.add_child(wheel)
		var rope := _box(node, Vector3(0.025, 1.0, 0.025), oak); rope.position = Vector3(0, 0, rope_z)   # 상자 줄 — 길이는 _place 가 scale 로
		var rope2 := _box(node, Vector3(0.025, 1.0, 0.025), oak); rope2.position = Vector3(0, 0, wall_z + 0.18)   # 평형추 줄
		var weight := _box(node, Vector3(0.14, 0.34, 0.1), iron); weight.position = Vector3(0, 0, wall_z + 0.18)
		var car := Node3D.new(); node.add_child(car)   # 상자 — 원점은 바닥 가운데
		_box(car, Vector3(cw, 0.04, cd), wood).position = Vector3(0, -0.02, body_z)
		_box(car, Vector3(cw, ch, 0.03), oak).position = Vector3(0, ch / 2.0, body_z + cd / 2.0)   # 앞 벽(몸 정강이를 가린다)
		_box(car, Vector3(cw, ch, 0.03), oak).position = Vector3(0, ch / 2.0, body_z - cd / 2.0)
		for i in 2: _box(car, Vector3(0.03, ch, cd), oak).position = Vector3(cw * (0.5 if i == 0 else -0.5), ch / 2.0, body_z)
		_box(car, Vector3(0.16, 0.12, 0.1), paper).position = Vector3(-cw * 0.3, 0.06, body_z - cd * 0.3)   # 실려 있던 책 두 덩이 — 뒤 모서리
		_box(car, Vector3(0.12, 0.16, 0.1), _mat(Color("2f2a4e"))).position = Vector3(-cw * 0.3 + 0.1, 0.08, body_z - cd * 0.3)
		for i in 2:   # 손잡이 고리 — 두 뒤 모서리에서 줄까지 기울어 오른다(몸 뒤)
			var sx := cw * (0.5 if i == 0 else -0.5)
			var top := Vector3(0, bail, rope_z); var base := Vector3(sx, ch, body_z - cd / 2.0)
			var arm := _box(car, Vector3(0.03, (top - base).length(), 0.03), iron)
			arm.transform = Transform3D(Basis(Quaternion(Vector3.UP, (top - base).normalized())), (top + base) / 2.0)   # 상자의 y 축을 고리 방향으로(look_at 은 트리 밖에서 못 쓴다)
		var click := AudioStreamPlayer3D.new(); click.stream = _tick_wav(float(kind.get("click_hz", 700)), 0.05); click.volume_db = -14.0; click.unit_size = 6.0; click.max_distance = 30.0; car.add_child(click)
		var clack := AudioStreamPlayer3D.new(); clack.stream = _tick_wav(float(kind.get("clack_hz", 240)), 0.12); clack.volume_db = -10.0; clack.unit_size = 6.0; clack.max_distance = 30.0; car.add_child(clack)
		s["node"] = node; s["car"] = car; s["rope"] = rope; s["rope2"] = rope2; s["weight"] = weight; s["click"] = click; s["clack"] = clack
		s["end"] = 0; s["go"] = -9.0; s["gy"] = float(s["a_y"]); s["to"] = 1; s["rider"] = false; s["mode"] = 1; s["t0"] = -9.0; s["pt"] = -9.0; s["pf"] = float(s["a_y"]); s["pto"] = float(s["a_y"]); s["hand"] = 1.0
		lifts.append(s)
		_place(s)

## 상자·줄·평형추를 지금 자리로 — 줄은 고리 끝에서 도르래까지, 평형추는 상자와 반대로 오르내린다
func _place(s: Dictionary) -> void:
	var y := (cy(s, t) - float(s["a_y"])) * C.K
	var bail := float(kind.get("bail_h", 54.0)) * C.K
	var beam_y := (float(s["beam_y"]) - float(s["a_y"])) * C.K - 0.1
	(s["car"] as Node3D).position.y = y
	var rope: Node3D = s["rope"]; var rl := maxf(0.05, beam_y - y - bail)
	rope.scale.y = rl; rope.position.y = beam_y - rl / 2.0
	var wy := beam_y - 0.5 - y   # 평형추: 상자가 바닥이면 도르래 밑, 꼭대기면 바닥 가까이
	var weight: Node3D = s["weight"]; weight.position.y = wy
	var rope2: Node3D = s["rope2"]; var rl2 := maxf(0.05, beam_y - wy - 0.17)
	rope2.scale.y = rl2; rope2.position.y = beam_y - rl2 / 2.0

func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.albedo_color = c; m.roughness = 1.0
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON; m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return m

func _box(parent: Node3D, size: Vector3, m: StandardMaterial3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = size; mi.mesh = bm; mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF   # 발판과 같은 규칙 — 그림자는 사람만
	parent.add_child(mi); return mi

## 멈춤쇠 소리 — 짧은 기음이 아주 빠르게 잦아든다: click(0.05초, 높고 메마르다)·clack(0.12초, 둔하다; 사다리의 clunk 과 같은 식). 한 번 재생, 반복 없음
static func _tick_wav(hz: float, secs: float) -> AudioStreamWAV:
	var rate := 22050; var count := int(rate * secs)
	var data := PackedByteArray(); data.resize(count * 2)
	for i in count:
		var k := float(i) / count
		var ph := float(i) * hz * TAU / rate
		var v := (sin(ph) * 0.5 + sin(ph * 2.7) * 0.2) * exp(-k * 14.0)
		data.encode_s16(i * 2, int(v * 22000.0))
	var w := AudioStreamWAV.new(); w.format = AudioStreamWAV.FORMAT_16_BITS; w.mix_rate = rate; w.stereo = false; w.data = data
	return w
