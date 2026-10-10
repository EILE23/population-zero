class_name ClimbDoor
extends Node3D
## Climb 콘텐츠 팩 '회전문'(운영자 2026-10-06 밤: "Climb는 컨텐츠 자체의 질과 양을 늘리는 거" — 팩은 data/climb/*.json 자료, 로더는 운영자 세션이 잇는다; climb.gd 는 CI 가 안 건드린다).
## 옛 회관(Old hall) 층의 넓은 still 발판(min_w 이상) 한가운데 — 둥근 바닥판(반지름 r) 위에 놋쇠 축, 종이·잉크 잎 넷(가슴 높이의 놋쇠 손잡이), 앞쪽 유리 벽 세 장, h 위에 테를 두른 지붕판. 드럼의 뒤는 절벽 그 자체.
## C 를 쥔 채 문 쪽으로 걸어 손(x + dir·HW)이 드럼 가까운 가장자리 reach 안에 들면 몸이 들어서고 문이 몸과 같이 돈다 — 잎은 ease_s 에 속도가 붙고 반 바퀴(π)에 turn_s; 몸은 축 뒤로 납작한 호를 걷는다(x = hx − dir·(r − HW − 2)·cos a, z = PLAYER_Z − swing_z·sin a) — 자세 turn(meta turn_v 잎의 속도 0..1); a 가 π 에 닿으면 건너편에 내려놓는다(done).
## C 를 놓거나 반대로 걸으면 문은 그 자리에 서고 몸은 걸어 나간다 — 잎은 C 가 있든 없든 걸음을 막지 않는다. 몸이 나간 뒤 빈 문은 제 관성으로 더 돈다(각속도가 spin_s 에 걸쳐 0 으로 — 속도·spin_s 의 반만큼; 도는 동안 whirr, 잎이 밀림을 받을 때 clack).
## 지붕판은 디딤 — 떨어지는 몸이 올라선다(land, kind "canopy"; 움직이지 않는 발판이라 로더 자신의 떠남 판정이 그대로 쓰인다): 발판 가운데서 다음 발판까지가 h px 가까워진다. 밀지도, 떨어뜨리지도, 거절하지도 않는다 — 맨 걸음과 맨 점프는 그대로.
## 타는 자세는 turn(stick3d_turn.gd — 운영자 보드의 '밀기' 가족 중 회전문: 오른손을 가슴 높이 손잡이에 대고 팔꿈치를 접은 채 왼팔은 뒤로 늘어뜨리고, 잰걸음으로 도는 쪽을 보며 돈다; 문이 서면 손을 댄 채 선다).
## 로더가 할 일(climb.gd, 운영자 세션): `var cr := ClimbDoor.new(); add_child(cr)`; 층을 지을 때 `cr.build(root, cr.plan(n, plats, cb.plan(n, plats)))` (종의 계획을 taken 으로 — 같은 층의 둘이 한 자리를 안 나눈다); 매 틱 `cr.sync(_t)`;
## 발판에 선 틱의 걷기 자리(`_physics_process` 의 `else:` — target 을 정하기 전): `var r := cr.push(on, x, z, dir, Input.is_action_pressed("act"), dt, fig); if r["riding"]: x = r["x"]; z = r["z"]; vx = 0.0; fig.pose_request = "turn"; elif fig.pose_request == "turn": fig.pose_request = ""` (`z = PLAYER_Z` 줄은 타는 틱엔 건너뛴다 — 호의 z 가 그 틱의 자리);
## 로더 자신의 착지 판정이 비면 `landed = cr.land(x, y, ny, z)` (kind "canopy" — 지붕판; 그 위에선 로더의 걷기·떠남·점프가 발판과 같다).
## 단위는 climb.gd 와 같은 px(36px = 1m, +y 위). 점검은 tools/probe_door.gd

const PACK := "res://data/climb/door.json"
const C = preload("res://scripts/games/climb.gd")
const LET_GO_T := 0.35    # 타는 틱이 이만큼 끊기면(뛰었다, 떠났다) 손을 뗀 것
const Z_OFF := 4.0        # 드럼 축의 z — 레인(PLAYER_Z)보다 이만큼 앞: 드럼 뒤끝이 절벽(WALL_Z)에 거의 붙는다

var pack: Dictionary = {}
var kind: Dictionary = {}       # kinds.door
var doors: Array = []           # 지은 문 {id, kind "door", x, y, w, z, d, a_id, a_y, hx, top_y, node, spin, whirr, clack, ang, a, spd, dir, riding, t0, last, rel, spd_rel, shown}
var t := 0.0                    # 로더의 _t 와 같이 간다(sync)

func _ready() -> void:
	var f := FileAccess.open(PACK, FileAccess.READ)
	if f: pack = JSON.parse_string(f.get_as_text()) as Dictionary
	kind = (pack.get("kinds", {}) as Dictionary).get("door", {})

func sync(now: float) -> void:
	t = now
	for sv in doors:   # 타는 틱이 끊겼으면(뛰었다, 떠났다) 손을 뗀 것
		var s: Dictionary = sv
		if bool(s["riding"]) and t - float(s["last"]) > LET_GO_T: _release(s)

func r() -> float:
	return float(kind.get("r", 28.0))

func h() -> float:
	return float(kind.get("h", 70.0))

## 몸이 도는 호의 x 반지름 — 드럼 벽 안쪽, 몸 반폭을 뺀 것
func path_r() -> float:
	return maxf(4.0, r() - C.HW - 2.0)

func swing_z() -> float:
	return float(kind.get("swing_z", 12.0))

func turn_s() -> float:
	return maxf(0.01, float(kind.get("turn_s", 0.9)))

func ease_s() -> float:
	return maxf(0.01, float(kind.get("ease_s", 0.15)))

func spin_s() -> float:
	return maxf(0.01, float(kind.get("spin_s", 2.0)))

## 잎의 최고 각속도 rad/s — 반 바퀴에 turn_s
func omega() -> float:
	return PI / turn_s()

## 잎의 각(rad, 누적, 미는 쪽으로 +): 타는 동안은 ang 그대로(push 가 더한다), 놓은 뒤엔 spin_s 에 걸쳐 각속도가 spd_rel 에서 0 으로 줄며 더 돈다
func angle_at(s: Dictionary, at: float) -> float:
	if bool(s["riding"]): return float(s["ang"])
	var rel := float(s["rel"])
	if rel < -1.0: return float(s["ang"])
	var k := clampf((at - rel) / spin_s(), 0.0, 1.0)
	return float(s["ang"]) + float(s["spd_rel"]) * spin_s() * (k - 0.5 * k * k)

## 돌아가는 잎을 지금 각으로
func _process(delta: float) -> void:
	t += delta
	doors = doors.filter(func(s: Dictionary) -> bool: return is_instance_valid(s["node"]))   # 지운 층의 것은 뺀다(climb_bookcase 와 같은 식)
	for sv in doors:
		var s: Dictionary = sv
		if bool(s["riding"]) and t - float(s["last"]) > LET_GO_T: _release(s)
		_place(s)

## 층 n(테마 층만)의 still 발판(조각의 on) 중 min_w 이상 넓고 드럼 상자(드럼 + 그 위의 몸)를 다른 발판이나 taken 조각이 가르지 않는 것들 중 가장 넓은 하나(같으면 낮은 쪽)에 문. 같은 층·같은 taken 은 늘 같은 답
func plan(n: int, plats: Array, taken: Array = []) -> Array:
	var out: Array = []
	if not (String(C.theme(n)[0]) in (pack.get("themes", []) as Array)): return out
	for pv in (pack.get("pieces", []) as Array):
		var piece: Dictionary = pv
		var only: Dictionary = piece.get("only", {})
		if not only.is_empty() and not _on(n, only): continue
		var kinds: Array = piece.get("on", ["std"])
		var min_w := float(kind.get("min_w", 120.0)); var rr := r(); var hh := h()
		var spots: Array = []
		for pv2 in plats:
			var a: Dictionary = pv2
			if not (String(a["kind"]) in kinds): continue
			var aw := float(a["w"])
			if aw < min_w: continue
			var hx := float(a["x"]) + aw / 2.0
			var x0 := hx - rr; var x1 := hx + rr
			var top := float(a["y"]) + hh
			if not _clear(plats, a, x0 - C.HW, x1 + C.HW, float(a["y"]) + 1.0, top + 50.0): continue
			if not _free(taken, x0, x1, float(a["y"]), top): continue
			var d := float(a.get("d", C.DEPTH_HALF * 2.0))
			spots.append({ "aw": aw, "hx": hx, "top_y": top, "a_id": String(a["id"]), "a_y": float(a["y"]), "d": d, "x": x0 })
		spots.sort_custom(func(p: Dictionary, q: Dictionary) -> bool: return float(p["aw"]) > float(q["aw"]) if float(p["aw"]) != float(q["aw"]) else float(p["a_y"]) < float(q["a_y"]))
		for i in range(0, mini(int(piece.get("max", 1)), spots.size())):
			var g: Dictionary = spots[i]
			var s: Dictionary = g.duplicate()
			s["id"] = "%d.R%d" % [n, i]; s["kind"] = "door"; s["y"] = float(g["a_y"]); s["w"] = rr * 2.0; s["z"] = C.PLAYER_Z + Z_OFF
			out.append(s)
	return out

## 층 n 이 {from, every} 에 드나
static func _on(n: int, rule: Dictionary) -> bool:
	var from := int(rule.get("from", 0))
	return n >= from and (n - from) % maxi(1, int(rule.get("every", 1))) == 0

## 드럼 상자(드럼의 x, 발판 윗면..지붕 위의 몸)에 그 발판 말고 다른 발판이 걸리지 않나 — 지름길 판이 가르면 문이 걸린다
static func _clear(plats: Array, a: Dictionary, x0: float, x1: float, ylo: float, yhi: float) -> bool:
	for pv in plats:
		var p: Dictionary = pv
		if p["id"] == a["id"]: continue
		var py := float(p["y"])
		if py < ylo or py > yhi: continue
		var px0 := float(p["x"]) - 10.0; var px1 := float(p["x"]) + float(p["w"]) + 10.0
		if x1 > px0 and x0 < px1: return false
	return true

## 다른 팩의 조각(taken: x, w, y, 있으면 b_y·beam_y 까지의 기둥)이 드럼 상자와 겹치지 않나 — 종의 줄
static func _free(taken: Array, x0: float, x1: float, ylo: float, yhi: float) -> bool:
	for tv in taken:
		var q: Dictionary = tv
		var qx0 := float(q.get("x", 0.0)) - 10.0; var qx1 := float(q.get("x", 0.0)) + float(q.get("w", 0.0)) + 10.0
		var qy0 := float(q.get("y", 0.0)) - 10.0
		var qy1 := maxf(maxf(float(q.get("y", 0.0)), float(q.get("b_y", -1e9))), float(q.get("beam_y", -1e9))) + 10.0
		if x1 > qx0 and x0 < qx1 and yhi > qy0 and ylo < qy1: return false
	return true

## 발판에 선 틱 — 타는 중이면(C 를 쥔 채, 반대로 걷지 않으면) 호를 따라 가고, 아니면 on 이 문의 발판이고 C 를 쥔 채 문 쪽(dir)으로 걸어 손(x + dir·HW)이 드럼 가장자리 reach 안이면 들어선다: {riding, x, z, done}. 아니면 {riding false}
## fig 가 있으면 자세의 메타를 적는다: turn_v 잎의 속도 0..1
func push(on: Dictionary, x: float, z: float, dir: float, held: bool, dt: float, fig: Stick3D = null) -> Dictionary:
	var s := _riding()
	if not s.is_empty() and (not held or dir == -float(s["dir"])): _release(s); s = {}   # 손을 뗐다, 되돌아 걷는다 — 문은 그 자리에 선다
	if s.is_empty() and held and dir != 0.0 and not on.is_empty(): s = _reached(on, x, z, dir)
	for sv in doors:   # 이 틱에 타지 않는 문은 손을 뗀 것
		if bool((sv as Dictionary)["riding"]) and sv != s: _release(sv)
	if s.is_empty(): return { "riding": false, "x": x, "z": z, "done": false }
	if not bool(s["riding"]):
		s["ang"] = angle_at(s, t); s["riding"] = true; s["t0"] = t; s["a"] = 0.0; s["dir"] = dir; s["rel"] = -9.0; s["spd"] = 0.0; _play(s["clack"])   # 돌던 문은 지금 각에서 다시 밀린다(ang 은 riding 을 세우기 전에 읽는다)
	s["last"] = t
	var d := float(s["dir"])
	var w := omega() * clampf((t - float(s["t0"])) / ease_s(), 0.0, 1.0)
	var na := minf(PI, float(s["a"]) + w * dt)
	s["ang"] = float(s["ang"]) + d * (na - float(s["a"])); s["a"] = na; s["spd"] = w
	var done := na >= PI - 0.001
	if fig: fig.set_meta("turn_v", w / omega())
	var out := { "riding": true, "x": float(s["hx"]) - d * path_r() * cos(na), "z": C.PLAYER_Z - swing_z() * sin(na), "done": done }
	if done: _release(s)   # 반 바퀴 — 건너편에 내려놓는다; 잎은 제 관성으로 더 돈다
	return out

## 지금 타는 문 — 없으면 빈 사전
func _riding() -> Dictionary:
	for sv in doors:
		if bool((sv as Dictionary)["riding"]): return sv
	return {}

## on 이 발판이고 손(x + dir·HW)이 드럼의 가까운 가장자리(hx − dir·r) reach 안인 문 — 없으면 빈 사전
func _reached(on: Dictionary, x: float, z: float, dir: float) -> Dictionary:
	var reach := float(kind.get("reach", 18.0))
	for sv in doors:
		var s: Dictionary = sv
		if String(on.get("id", "")) != String(s["a_id"]): continue
		if absf(z - C.PLAYER_Z) >= swing_z() + C.HZ: continue
		if absf((x + dir * C.HW) - (float(s["hx"]) - dir * r())) <= reach: return s
	return {}

## 로더 자신의 착지 판정이 빈 뒤 — 떨어지는 몸이 지붕판을 지나면 올라선다: {kind "canopy", id, x, y, w, z, d}. 아니면 빈 사전
func land(x: float, y: float, ny: float, z: float) -> Dictionary:
	for sv in doors:
		var s: Dictionary = sv
		var top := float(s["top_y"])
		if y < top or ny > top: continue
		if absf(z - float(s["z"])) >= r() + C.HZ: continue
		var hx := float(s["hx"])
		if x + C.HW <= hx - r() or x - C.HW >= hx + r(): continue
		return { "kind": "canopy", "id": String(s["id"]), "x": hx - r(), "y": top, "w": r() * 2.0, "z": float(s["z"]), "d": r() * 2.0 }
	return {}

## 손을 뗀다 — 지금 각에서 제 관성으로 spin_s 동안 더 돈다
func _release(s: Dictionary) -> void:
	s["riding"] = false; s["rel"] = t; s["spd_rel"] = float(s["spd"])

func _play(p: AudioStreamPlayer3D) -> void:
	if p.playing: p.stop()
	p.play()

## 문을 짓는다 — root 는 그 층의 노드. 노드 원점은 축의 발(hx, 발판 윗면, z); 바닥판·축·잎 묶음(spin: 잎마다 축 노드 + 잎판 + 손잡이)·지붕판·테·유리 벽(세 장)·whirr·clack
func build(root: Node3D, planned: Array) -> void:
	var rr := r() * C.K; var hh := h() * C.K
	var n_leaf := maxi(2, int(kind.get("leaves", 4)))
	for sv in planned:
		var s: Dictionary = (sv as Dictionary).duplicate()
		var node := Node3D.new(); node.position = C.to3(float(s["hx"]), float(s["a_y"]), float(s["z"]) * C.K); root.add_child(node)
		var stone := _mat(Color("8a7f86")); var brass := _mat(Color("c9a07a")); var paper := _mat(Color("efe9e2")); var ink := _mat(Color("2f2a4e")); var gold := _mat(Color("e3c46a"))
		var glass := _mat(Color("c9dde6", 0.35)); glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_disk(node, rr, 0.03, stone).position = Vector3(0, 0.015, 0)   # 바닥판
		_disk(node, 0.035, hh, brass).position = Vector3(0, hh / 2.0, 0)   # 축
		var spin := Node3D.new(); node.add_child(spin)
		for i in n_leaf:
			var pivot := Node3D.new(); pivot.rotation.y = TAU * float(i) / float(n_leaf); spin.add_child(pivot)
			var leaf := _box(pivot, Vector3(rr - 0.04, hh - 0.12, 0.02), paper if i % 2 == 0 else ink)
			leaf.position = Vector3((rr - 0.04) / 2.0 + 0.035, 0.06 + (hh - 0.12) / 2.0, 0)   # 잎판 — 축에서 드럼 벽까지
			var bar := _box(pivot, Vector3(rr * 0.5, 0.025, 0.025), brass)
			bar.position = Vector3(rr * 0.6, 0.95, 0.03)   # 손잡이 — 가슴 높이
		_disk(node, rr + 0.04, 0.06, stone).position = Vector3(0, hh - 0.03, 0)   # 지붕판 — 디딤
		_disk(node, rr + 0.07, 0.02, gold).position = Vector3(0, hh - 0.07, 0)   # 테
		var wall := Node3D.new(); node.add_child(wall)
		for k in 3:   # 앞 유리 벽 세 장 — 드럼의 앞 호를 따라(뒤는 절벽)
			var th := (float(k) - 1.0) * 0.62
			var pane := _box(wall, Vector3(2.0 * rr * sin(0.31) + 0.01, hh - 0.12, 0.012), glass)
			pane.position = Vector3(rr * sin(th), 0.06 + (hh - 0.12) / 2.0, rr * cos(th)); pane.rotation.y = -th
		var whirr := AudioStreamPlayer3D.new(); whirr.stream = _loop_wav(float(kind.get("whirr_hz", 60)), 0.3); whirr.volume_db = -18.0; whirr.unit_size = 6.0; whirr.max_distance = 30.0; node.add_child(whirr)
		var clack := AudioStreamPlayer3D.new(); clack.stream = _tick_wav(float(kind.get("clack_hz", 95)), 0.1); clack.volume_db = -8.0; clack.unit_size = 6.0; clack.max_distance = 30.0; node.add_child(clack)
		s["node"] = node; s["spin"] = spin; s["whirr"] = whirr; s["clack"] = clack
		s["ang"] = 0.0; s["a"] = 0.0; s["spd"] = 0.0; s["spd_rel"] = 0.0; s["dir"] = 1.0; s["riding"] = false; s["t0"] = -9.0; s["last"] = -9.0; s["rel"] = -9.0; s["shown"] = 0.0
		doors.append(s)
		_place(s)

## 잎을 지금 각으로 — 도는 동안 whirr 가 돈다(+y 회전은 +x 를 −z 로 보내니 미는 쪽(+)이면 −로: 들어선 쪽의 잎이 절벽 쪽으로 쓸려 간다)
func _place(s: Dictionary) -> void:
	var was := float(s.get("shown", 0.0))
	var ang := angle_at(s, t)
	var spin: Node3D = s["spin"]; spin.rotation.y = -ang
	var moving := absf(ang - was) > 0.0005 or bool(s["riding"])
	var whirr: AudioStreamPlayer3D = s["whirr"]
	if moving and not whirr.playing: whirr.play()
	elif not moving and whirr.playing: whirr.stop()
	s["shown"] = ang

func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.albedo_color = c; m.roughness = 1.0
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON; m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return m

func _box(parent: Node3D, size: Vector3, m: StandardMaterial3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = size; mi.mesh = bm; mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF   # 발판과 같은 규칙 — 그림자는 사람만
	parent.add_child(mi); return mi

func _disk(parent: Node3D, radius: float, height: float, m: StandardMaterial3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = radius; cm.bottom_radius = radius; cm.height = height; cm.radial_segments = 20; mi.mesh = cm; mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi); return mi

## 손잡이 소리 — 짧은 기음이 아주 빠르게 잦아든다(서가의 thud 와 같은 식). 한 번 재생, 반복 없음
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

## 축 소리 — 낮은 기음에 거친 결을 얹어 돌려 튼다(도는 동안만 play/stop)
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
