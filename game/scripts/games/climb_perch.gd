class_name ClimbPerch
extends Node3D
## Climb 콘텐츠 팩 '뻐꾸기 발판'(운영자 2026-10-06 밤: "Climb는 컨텐츠 자체의 질과 양을 늘리는 거" — 팩은 data/climb/*.json 자료, 로더는 운영자 세션이 잇는다; climb.gd 는 CI 가 안 건드린다).
## 태엽(Clockwork) 층의 잇단 두 still 발판 사이 높이차가 큰 틈(min_dy 이상) 옆 — 틈 한가운데 절벽에 뻐꾸기시계 집이 박혀 있고 그 바닥은 두 발판 높이의 평균(높은 뜀의 절반). 톱니의 박자(beat = 띠의 run + stall, 5.6초)마다 문 둘이 열리며
## 널빤지가 reach 만큼 문간 밖으로 미끄러져 나와(out_s) 2초 머물고(hold_s) 다시 들어간다(in_s). 널빤지는 나와 있을 때만 발판이다 — 로더의 z 검사 그대로(몸은 절벽 앞 22px, 널빤지는 14px 넘게 나와야 받는다): 유령 판은 옅어질 뿐이지만 이건 시계가 허락할 때만 있는 발판.
## 널빤지에 선 몸은 들어갈 때 같이 실려 들어가(inside — 문이 몸 앞에서 닫힌다, x 는 집 벽 사이에 갇힌다) 다음 박자에 다시 밀려 나온다; 안에서 SPACE 를 누르면 문을 두드려(knock) 바로 열린다 — 뜀 자체는 평범한 차지 점프 그대로. 양 끝으로 걸어 나가는 평범한 추락도 그대로.
## 자세는 perch(stick3d_perch.gd — 운영자 보드의 '문간에 웅크리기' 가족: 무릎을 굽히고 두 손으로 문틀을 짚고 고개가 상인방 밑으로 숙는다; 안에선 손이 무릎으로 내려오고 더 웅크리며, 문이 열리는 순간 뻐꾸기처럼 고개를 내민다).
## 로더가 할 일(climb.gd, 운영자 세션): `var pk := ClimbPerch.new(); add_child(pk)`; 층을 지을 때 `pk.build(root, pk.plan(n, plats, cp.plan(n, plats) + gh.plan(n, plats) + cb.plan(n, plats) + cm.plan(n, plats)))` (추·유령 판·다리·버섯의 계획을 taken 으로 — 그 틈은 비켜 간다); 매 틱 `pk.sync(_t)`;
## 착지 판정에서 landed 가 비었고 vy <= 0 이면 `landed = pk.land(x, y, ny, z)` (널빤지가 나와 있을 때만 발판 사전을 준다);
## `on["kind"] == "perch"` 로 서 있는 매 틱, 'move' 발판의 드리프트 자리에서 `var r := pk.stand(on, x, dt, fig); x = r["x"]; fig.pose_request = "perch"; if r["inside"] and Input.is_action_just_pressed("jump"): pk.knock(on)` — stand 가 on 의 z·d 를 다시 적어 로더의 제 가장자리 검사가 몸을 붙들고, 떠나면(on 이 비거나 종류가 바뀌면) 자세를 "" 로.
## 단위는 climb.gd 와 같은 px(36px = 1m, +y 위). 점검은 tools/probe_perch.gd

const PACK := "res://data/climb/perch.json"
const C = preload("res://scripts/games/climb.gd")
const MIN_D := 14.0         # 로더의 z 검사가 널빤지를 받기 시작하는 깊이(px): 22 − d/2 < d/2 + HZ(8) ⇔ d > 14

var pack: Dictionary = {}
var kind: Dictionary = {}       # kinds.hatch
var hatches: Array = []         # 지은 집 {id, kind "perch", x, y, w, z, d, len, pw, hx, dy, gap, a_id, b_id, phase, node, plank, leaves, gear, call, knock, opened, was, rode}
var t := 0.0                    # 로더의 _t 와 같이 간다(sync)

func _ready() -> void:
	var f := FileAccess.open(PACK, FileAccess.READ)
	if f: pack = JSON.parse_string(f.get_as_text()) as Dictionary
	kind = (pack.get("kinds", {}) as Dictionary).get("hatch", {})

func sync(now: float) -> void:
	t = now

func beat() -> float:
	return maxf(0.5, float(kind.get("beat", 5.6)))

func reach() -> float:
	return maxf(MIN_D + 1.0, float(kind.get("reach", 60.0)))

func out_s() -> float:
	return maxf(0.05, float(kind.get("out_s", 0.4)))

func hold_s() -> float:
	return maxf(0.0, float(kind.get("hold_s", 2.0)))

func in_s() -> float:
	return maxf(0.05, float(kind.get("in_s", 0.4)))

func plank_w() -> float:
	return maxf(2.0 * C.HW + 4.0, float(kind.get("plank_w", 48.0)))

func house_w() -> float:
	return maxf(plank_w(), float(kind.get("house_w", 72.0)))

func house_top() -> float:
	return float(kind.get("house_h", 64.0)) + float(kind.get("roof_h", 22.0))

## 한 번 열림의 모양 — 시작 뒤 u 초: 나온다 → 머문다(hold) → 들어간다 → 0. 선형이라 점검이 정확하다
func _slide(u: float, hold: float) -> float:
	if u < 0.0: return 0.0
	if u < out_s(): return u / out_s()
	if u < out_s() + hold: return 1.0
	if u < out_s() + hold + in_s(): return 1.0 - (u - out_s() - hold) / in_s()
	return 0.0

## 널빤지가 나온 정도 0..1 at 시각 — 박자(phase 가 시작을 옮긴다)와 두드림(knock) 중 큰 쪽. 같은 시각엔 누구에게나 같다(두드림은 그 집만)
func ext(s: Dictionary, at: float) -> float:
	var k := _slide(fposmod(at + float(s.get("phase", 0.0)), beat()), hold_s())
	var kn := float(s.get("knock", -9.0))
	if kn > -9.0: k = maxf(k, _slide(at - kn, float(kind.get("knock_hold_s", 0.8))))
	return k

## 지금 널빤지의 깊이(px, 절벽에서)와 가운데 z — 로더의 발판 사전이 읽는 값
func depth(s: Dictionary, at: float) -> float:
	return reach() * ext(s, at)

func z_of(s: Dictionary, at: float) -> float:
	return C.WALL_Z + depth(s, at) / 2.0

## 널빤지가 발판인가(로더의 z 검사가 받는 깊이) at 시각
func is_out(s: Dictionary, at: float) -> bool:
	return depth(s, at) > MIN_D

## 널빤지에 선 몸이 안에 있나 — 문이 닫혀 있다
func inside(s: Dictionary, at: float) -> bool:
	return ext(s, at) < float(kind.get("shut_k", 0.25))

## 문이 열리는 틱에 뻐꾸기가 운다(몸이 있든 없든 — 박자를 귀로 잰다); 문·널빤지·톱니를 지금 값으로
func _process(delta: float) -> void:
	t += delta
	hatches = hatches.filter(func(s: Dictionary) -> bool: return is_instance_valid(s["node"]))   # 지운 층의 것은 뺀다(climb_ghost 와 같은 식)
	for sv in hatches:
		var s: Dictionary = sv
		var e := ext(s, t)
		if e > 0.0 and float(s["was"]) <= 0.0:
			s["opened"] = t
			var c: AudioStreamPlayer3D = s["call"]
			if c.playing: c.stop()
			c.play()
		s["was"] = e
		_pose_house(s, e)

## 층 n(테마 층만, not 층은 빼고)의 잇단 두 still 발판(조각의 on; 아래 a·위 b) 사이 틈 중 높이차 min_dy 이상·틈 min_gap..max_gap 이며 집 상자를 다른 발판도 taken 조각도 안 건드리는 것들 중 높이차가 가장 큰 하나(같으면 넓은 틈) — 틈 한가운데에 집. 같은 층·같은 taken 은 늘 같은 답
func plan(n: int, plats: Array, taken: Array = []) -> Array:
	var out: Array = []
	if not (String(C.theme(n)[0]) in (pack.get("themes", []) as Array)): return out
	var min_dy := float(kind.get("min_dy", 110.0)); var min_gap := float(kind.get("min_gap", 84.0)); var max_gap := float(kind.get("max_gap", 260.0)); var clear := float(kind.get("clear", 6.0))
	var hw := house_w() / 2.0
	for pv in (pack.get("pieces", []) as Array):
		var piece: Dictionary = pv
		var nt: Dictionary = piece.get("not", {})
		if not nt.is_empty() and _on(n, nt): continue
		var kinds: Array = piece.get("on", ["std"])
		var hops: Array = plats.filter(func(p: Dictionary) -> bool: return not (String(p["kind"]) in ["rest", "short", "ledge"]))
		var spans: Array = []
		for i in range(1, hops.size()):
			var a: Dictionary = hops[i - 1]; var b: Dictionary = hops[i]   # a 가 아래 발판(band() 는 오르는 순서로 쌓는다)
			if not (String(a["kind"]) in kinds and String(b["kind"]) in kinds): continue
			var dy := float(b["y"]) - float(a["y"])
			if dy < min_dy: continue
			var ax0 := float(a["x"]); var ax1 := ax0 + float(a["w"]); var bx0 := float(b["x"]); var bx1 := bx0 + float(b["w"])
			if bx0 < ax1 and bx1 > ax0: continue   # 겹친 발판 — 틈이 없다
			var gap := bx0 - ax1 if bx0 >= ax1 else ax0 - bx1
			if gap < min_gap or gap > max_gap or gap < house_w() + 2.0 * clear: continue
			var hx := (ax1 + bx0) / 2.0 if bx0 >= ax1 else (bx1 + ax0) / 2.0
			var py := (float(a["y"]) + float(b["y"])) / 2.0
			if not _clear(plats, a, b, hx - hw - 10.0, hx + hw + 10.0, py - 20.0, py + house_top() + 10.0): continue
			if not _free(taken, hx - hw - 6.0, hx + hw + 6.0, py - 6.0, py + house_top() + 6.0): continue
			spans.append({ "dy": dy, "gap": gap, "hx": hx, "py": py, "a_id": String(a["id"]), "b_id": String(b["id"]) })
		spans.sort_custom(func(p: Dictionary, q: Dictionary) -> bool: return float(p["dy"]) > float(q["dy"]) if float(p["dy"]) != float(q["dy"]) else float(p["gap"]) > float(q["gap"]))
		for i in range(0, mini(int(piece.get("max", 1)), spans.size())):
			var g: Dictionary = spans[i]
			out.append({ "id": "%d.H%d" % [n, i], "kind": "perch", "x": float(g["hx"]) - hw, "y": float(g["py"]), "w": house_w(), "z": C.WALL_Z, "d": 0.0, "len": house_top(), "pw": plank_w(),
				"hx": float(g["hx"]), "dy": float(g["dy"]), "gap": float(g["gap"]), "a_id": String(g["a_id"]), "b_id": String(g["b_id"]), "phase": float(piece.get("phase", 0.0)) })
	return out

## 층 n 이 {from, every} 에 드나
static func _on(n: int, rule: Dictionary) -> bool:
	var from := int(rule.get("from", 0))
	return n >= from and (n - from) % maxi(1, int(rule.get("every", 1))) == 0

## 집 상자(x0..x1, y0..y1) 안에 두 턱 말고 다른 발판이 걸리지 않나 — 지름길 판이 지붕을 뚫으면 둘 다 못 읽는다
static func _clear(plats: Array, a: Dictionary, b: Dictionary, x0: float, x1: float, y0: float, y1: float) -> bool:
	for pv in plats:
		var p: Dictionary = pv
		if p["id"] == a["id"] or p["id"] == b["id"]: continue
		var py := float(p["y"])
		if py <= y0 or py >= y1: continue
		if float(p["x"]) + float(p["w"]) > x0 and float(p["x"]) < x1: return false
	return true

## 다른 팩의 조각(taken: x, w, y, 있으면 len·b_y·floor·hp·y0·y1 까지 — 추는 y..hp, 다리는 y0..y1, 버섯은 점)이 집 상자와 겹치지 않나(공중그네의 _free 와 같은 식)
static func _free(taken: Array, x0: float, x1: float, ylo: float, yhi: float) -> bool:
	for tv in taken:
		var q: Dictionary = tv
		var qx0 := float(q.get("x", 0.0)) - 6.0; var qx1 := float(q.get("x", 0.0)) + float(q.get("w", 0.0)) + 6.0
		var qy := float(q.get("y", 0.0))
		var ys: Array = [qy, qy + float(q.get("len", 0.0)), float(q.get("b_y", qy)), float(q.get("floor", qy)), float(q.get("hp", qy)), float(q.get("y0", qy)), float(q.get("y1", qy))]
		var qy0 := float(ys.min()) - 6.0; var qy1 := float(ys.max()) + 6.0
		if x1 > qx0 and x0 < qx1 and yhi > qy0 and ylo < qy1: return false
	return true

## 로더의 착지 판정과 같은 규칙(HW·HZ) — 이 틱에 나와 있는 널빤지의 윗면을 지나 떨어지는 몸만 받고 발판 사전(새 사전: 로더의 on 이 된다)을 돌려준다; 들어간 널빤지는 없는 것
func land(x: float, y: float, ny: float, z: float) -> Dictionary:
	for sv in hatches:
		var s: Dictionary = sv
		if not is_out(s, t): continue
		var d := depth(s, t); var sz := z_of(s, t)
		var px := float(s["hx"]) - float(s["pw"]) / 2.0; var py := float(s["y"])
		if x + C.HW > px and x - C.HW < px + float(s["pw"]) and y >= py and ny <= py and absf(z - sz) < d / 2.0 + C.HZ:
			return { "id": String(s["id"]) + "p", "kind": "perch", "x": px, "y": py, "w": float(s["pw"]), "z": sz, "d": d, "hatch": String(s["id"]) }
	return {}

## 서 있는 매 틱(x 는 몸의 자리) — {x, y, inside, ext}: on 의 z·d 를 다시 적어 로더의 가장자리 검사가 몸을 붙들게 한다(들어가는 널빤지 위의 몸은 같이 들어간다 — 집 안에선 몸의 z 그대로·reach 깊이로, 밖에선 지금 기하로);
## 안에선 x 가 집 벽 사이(널빤지 끝 − HW)에 갇힌다. fig 가 있으면 자세의 메타를 적는다: perch_in 들어간 정도 0..1(1 − ext), perch_call 문이 열린 뒤 call_s 동안 1 → 0 (뻐꾸기처럼 고개를 내민다)
func stand(on: Dictionary, x: float, dt: float, fig: Stick3D = null) -> Dictionary:
	var s := _find(String(on.get("hatch", "")))
	if s.is_empty(): return { "x": x, "y": float(on.get("y", 0.0)), "inside": false, "ext": 0.0 }
	var e := ext(s, t); var ins := inside(s, t)
	if ins or not is_out(s, t): on["z"] = C.PLAYER_Z; on["d"] = reach()
	else: on["z"] = z_of(s, t); on["d"] = depth(s, t)
	s["rode"] = t
	if fig:
		fig.set_meta("perch_in", 1.0 - e)
		fig.set_meta("perch_call", clampf(1.0 - (t - float(s["opened"])) / maxf(0.05, float(kind.get("call_s", 0.5))), 0.0, 1.0) if float(s["opened"]) > -9.0 else 0.0)
	var px := float(on["x"]); var pw := float(on["w"])
	return { "x": clampf(x, px + C.HW, px + pw - C.HW) if ins else x, "y": float(on["y"]), "inside": ins, "ext": e }

## 안에서 두드리기(SPACE) — 문이 바로 열려 knock_hold_s 머문다; 돌려주는 값은 두드려졌나(밖이면 아무 일 없음)
func knock(on: Dictionary) -> bool:
	var s := _find(String(on.get("hatch", "")))
	if s.is_empty() or not inside(s, t): return false
	s["knock"] = t
	return true

func _find(id: String) -> Dictionary:
	for sv in hatches:
		if String((sv as Dictionary)["id"]) == id: return sv
	return {}

## 집을 짓는다 — root 는 그 층의 노드. 노드 원점은 (hx, 바닥 y, 절벽 z); 나무 집·어두운 문간·경첩 문짝 둘·맞배지붕 둘·널빤지(끝에 뻐꾸기)·벽의 놋쇠 톱니·울음
func build(root: Node3D, planned: Array) -> void:
	var K := C.K
	var hw := house_w() * K; var hh := float(kind.get("house_h", 64.0)) * K; var hd := float(kind.get("house_d", 30.0)) * K
	var dw := float(kind.get("door_w", 56.0)) * K; var dh := float(kind.get("door_h", 52.0)) * K; var rh := float(kind.get("roof_h", 22.0)) * K
	var pw := plank_w() * K; var pth := float(kind.get("plank_th", 5.0)) * K; var gr := float(kind.get("gear_r", 9.0)) * K
	for sv in planned:
		var s: Dictionary = (sv as Dictionary).duplicate()
		var node := Node3D.new(); node.position = C.to3(float(s["hx"]), float(s["y"]), C.WALL_Z * K); root.add_child(node)
		var wood := _mat(Color("8a6a4a")); var dark := _mat(Color("2a2226")); var leaf := _mat(Color("c9a07a")); var brass := _mat(Color("e08a2a")); var ink := _mat(Color("2f2a4e")); var plate := _mat(Color("ad7096"))
		_box(node, Vector3(hw, hh, hd), wood).position = Vector3(0, hh / 2.0, hd / 2.0)   # 집 몸체 — 절벽에서 hd 만큼 나와 있다
		_box(node, Vector3(dw, dh, 0.02), dark).position = Vector3(0, dh / 2.0, hd + 0.01)   # 어두운 문간
		var leaves: Array = []
		for k in [-1.0, 1.0]:
			var hinge := Node3D.new(); hinge.position = Vector3((k as float) * dw / 2.0, 0, hd + 0.02); node.add_child(hinge)   # 경첩은 문간 양옆, 문 면
			_box(hinge, Vector3(dw / 2.0, dh, 0.03), leaf).position = Vector3(-(k as float) * dw / 4.0, dh / 2.0, 0)
			leaves.append(hinge)
		for k in [-1.0, 1.0]:   # 맞배지붕 — 두 널이 가운데서 만난다
			var r := _box(node, Vector3(hw * 0.6, 0.04, hd + 0.1), ink)
			r.position = Vector3((k as float) * hw * 0.25, hh + rh / 2.0, hd / 2.0); r.rotation.z = -(k as float) * atan2(rh, hw / 2.0)
		var plank := _box(node, Vector3(pw, pth, reach() * K), wood); plank.position = Vector3(0, -pth / 2.0, 0)   # 널빤지 — z 로 미끄러진다(_pose_house)
		_box(plank, Vector3(0.1, 0.09, 0.14), ink).position = Vector3(pw / 2.0 - 0.08, pth / 2.0 + 0.05, reach() * K / 2.0 - 0.1)   # 뻐꾸기 — 널빤지 끝에 앉아 같이 나온다
		_box(plank, Vector3(0.03, 0.03, 0.05), plate).position = Vector3(pw / 2.0 - 0.08, pth / 2.0 + 0.06, reach() * K / 2.0 + 0.0)   # 부리 — 강조색만
		var gear := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = gr; cm.bottom_radius = gr; cm.height = 0.04; cm.radial_segments = 10; gear.mesh = cm
		gear.material_override = brass; gear.rotation.z = PI / 2.0; gear.position = Vector3(hw / 2.0 + 0.02, hh * 0.65, hd / 2.0); gear.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; node.add_child(gear)   # 벽의 놋쇠 톱니 — 박자대로 돈다
		var call := AudioStreamPlayer3D.new(); call.stream = _call_wav(float(kind.get("call_hz", 740))); call.volume_db = -9.0; call.unit_size = 6.0; call.max_distance = 30.0; node.add_child(call)
		s["node"] = node; s["plank"] = plank; s["leaves"] = leaves; s["gear"] = gear; s["call"] = call
		s["knock"] = -9.0; s["opened"] = -9.0; s["was"] = ext(s, t); s["rode"] = -9.0
		hatches.append(s)
		_pose_house(s, ext(s, t))

## 문짝은 바깥(+z)으로 door_open × e, 널빤지는 절벽 안에서 e × reach 만큼 나와(들어가 있으면 절벽 뒤에 숨는다), 톱니는 박자 안의 자리대로 돈다
func _pose_house(s: Dictionary, e: float) -> void:
	var op := float(kind.get("door_open", 1.3)) * e
	var leaves: Array = s["leaves"]
	(leaves[0] as Node3D).rotation.y = -op; (leaves[1] as Node3D).rotation.y = op
	(s["plank"] as Node3D).position.z = (e * reach() - reach() / 2.0) * C.K
	(s["gear"] as Node3D).rotation.x = fposmod(t + float(s.get("phase", 0.0)), beat()) / beat() * TAU

func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.albedo_color = c; m.roughness = 1.0
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON; m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return m

func _box(parent: Node3D, size: Vector3, m: StandardMaterial3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = size; mi.mesh = bm; mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF   # 발판과 같은 규칙 — 그림자는 사람만
	parent.add_child(mi); return mi

## 뻐꾸기 — 두 음(기음, 그 아래 단3도) 0.22초씩, 각각 빠르게 잦아든다(한 번 재생, 반복 없음)
static func _call_wav(hz: float) -> AudioStreamWAV:
	var rate := 22050; var note := int(rate * 0.22); var count := note * 2
	var data := PackedByteArray(); data.resize(count * 2)
	for i in count:
		var j := i % note; var k := float(j) / note
		var f := hz if i < note else hz * 0.8409   # 2^(−3/12)
		var ph := float(j) * f * TAU / rate
		var v := (sin(ph) * 0.55 + sin(ph * 2.0) * 0.15) * exp(-k * 5.0) * minf(1.0, k * 30.0)
		data.encode_s16(i * 2, int(v * 22000.0))
	var w := AudioStreamWAV.new(); w.format = AudioStreamWAV.FORMAT_16_BITS; w.mix_rate = rate; w.stereo = false; w.data = data
	return w
