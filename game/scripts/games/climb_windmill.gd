class_name ClimbWindmill
extends Node3D
## Climb 콘텐츠 팩 '풍차 날'(운영자 2026-10-06 밤: "Climb는 컨텐츠 자체의 질과 양을 늘리는 거" — 팩은 data/climb/*.json 자료, 로더는 운영자 세션이 잇는다; climb.gd 는 CI 가 안 건드린다).
## 한 층의 잇단 두 std 발판 사이 틈(min_gap..max_gap) 한가운데, 두 발판 높이의 중간에 절벽에서 나온 축과 바퀴 — 종이 날 셋이 rev_s 로 돌고, 날 끝마다 바람개비 접은 끝처럼 수평을 지키는 종이 컵이 달려 있다. 컵이 발판이다.
## 날 길이는 기하로 정한다: 컵이 아래 턱 끝을 그 높이에서(clear px 떨어져) 지나고, 반 바퀴 뒤 위 턱 끝을 그 높이에서 지난다. 아래 턱 쪽이 오르도록 돈다 — 턱 끝에서 올라오는 컵에 내려서면(catch) 반 바퀴(2.5초) 뒤 위 턱 앞에 서 있다;
## 놓치면 컵은 아래로 돌아 다시 올라온다(떨어지지 않는다 — 평범한 결과가 늘 남는다). 컵이 아래 턱 높이를 지나 오르는 순간 나무 딸깍(clack) — 지금 올라서라는 신호. 날(살)의 모서리가 공중의 몸에 닿으면 밀어낸다(sweep — 다른 등반자의 밀치기처럼 옆·위로, 아래로는 절대 아니다).
## 로더가 할 일(climb.gd, 운영자 세션): `var wm := ClimbWindmill.new(); add_child(wm)`; 층을 지을 때 `wm.build(root, wm.plan(n, plats))`; 매 틱 `wm.sync(_t)`;
## 'move' 발판을 옮기는 자리(ny 를 재기 전)에서 `on["kind"] == "windmill"` 이면 `var r := wm.ride(on, x, dt, fig); x = r["x"]; y = r["y"]; fig.pose_request = "ride"; if r["off"]: on = {}; apex = y` (컵 밖으로 걸어 나간 몸 — 떨어진다; 뛰어 내려서도 자세를 비운다);
## 착지 판정에서 landed 가 비었고 vy <= 0 이면 `landed = wm.land(x, y, ny, z)` (돌려준 사전의 "y" 가 컵 바닥, "arm" 이 어느 날인지, "step" 이 참이면 턱에서 내려선 걸음이라 vx 를 0 으로 안 해도 된다);
## 공중(on 이 빈 틱)이면 `var sh := wm.sweep(x, y, z); if not sh.is_empty(): vx = sh["vx"]; vy = sh["vy"]; hurt = 0.4; fig.squash = -0.4`.
## 컵 위에선 로더의 일반 '발판 밖으로 나갔나' 검사(x..x+w)를 그대로 둬도 된다 — x/w 가 바퀴의 좌우 폭이라 타는 동안 늘 안이다. 단위는 climb.gd 와 같은 px(36px = 1m, +y 위). 점검은 tools/probe_windmill.gd

const PACK := "res://data/climb/windmill.json"
const C = preload("res://scripts/games/climb.gd")

var pack: Dictionary = {}
var kind: Dictionary = {}       # kinds.wheel
var wheels: Array = []          # 지은 바퀴 {id, kind "windmill", x, y, w, z, d, hx, hy, len, dir, a_y, phase, node, arms, cups, clack, rode}
var t := 0.0                    # 로더의 _t 와 같이 간다(sync)

func _ready() -> void:
	var f := FileAccess.open(PACK, FileAccess.READ)
	if f: pack = JSON.parse_string(f.get_as_text()) as Dictionary
	kind = (pack.get("kinds", {}) as Dictionary).get("wheel", {})

func sync(now: float) -> void:
	t = now

func omega() -> float:
	return TAU * float(kind.get("rev_s", 0.2))

func blades() -> int:
	return maxi(2, int(kind.get("blades", 3)))

func cup_w() -> float:
	return float(kind.get("cup_w", 24.0))

## 날 k 의 각(라디안; +x 에서 반시계로, +y 위) — dir −1 이면 시계 방향으로 돈다. 같은 시각엔 누구에게나 같은 각
func ang(s: Dictionary, k: int, at: float) -> float:
	return float(s.get("phase", 0.0)) + float(s["dir"]) * omega() * at + k * TAU / blades()

## 날 k 끝(컵 바닥 가운데)의 자리(px)
func tip(s: Dictionary, k: int, at: float) -> Vector2:
	var a := ang(s, k, at)
	return Vector2(float(s["hx"]) + float(s["len"]) * cos(a), float(s["hy"]) + float(s["len"]) * sin(a))

## 컵의 속도 방향 −1..1 — x 는 +x 로 가면 양수, y 는 오르면 양수 (d/dt (cos a, sin a) = dir·ω·(−sin a, cos a))
func vel(s: Dictionary, k: int, at: float) -> Vector2:
	var a := ang(s, k, at)
	return Vector2(-sin(a), cos(a)) * float(s["dir"])

## 날을 돌리고(컵은 수평을 지킨다), 아래 턱 높이를 지나 오르는 컵이 있으면 딸깍 — 빈 바퀴도 돈다(풍차니까)
func _process(delta: float) -> void:
	t += delta
	wheels = wheels.filter(func(s: Dictionary) -> bool: return is_instance_valid(s["node"]))   # 지운 층의 것은 뺀다(climb_bridge 와 같은 식)
	for sv in wheels:
		var s: Dictionary = sv
		_turn(s)
		var a_y := float(s["a_y"])
		for k in blades():
			if tip(s, k, t - delta).y < a_y and tip(s, k, t).y >= a_y:
				var ck: AudioStreamPlayer3D = s["clack"]
				if ck.playing: ck.stop()
				ck.play()

## 층 n 의 잇단 두 발판(둘 다 on 종류) 사이 틈 중 min_gap..max_gap 에 들고 높이차가 dy_min..dy_max 인 가장 긴 것 하나 — 틈 한가운데·중간 높이에 축. 같은 층은 늘 같은 답
func plan(n: int, plats: Array) -> Array:
	var out: Array = []
	for pv in (pack.get("pieces", []) as Array):
		var piece: Dictionary = pv
		var from := int(piece.get("from", 0)); var every := maxi(1, int(piece.get("every", 1)))
		if n < from or (n - from) % every != 0: continue
		var kinds: Array = piece.get("on", ["std"])
		var min_gap := float(kind.get("min_gap", 150.0)); var max_gap := float(kind.get("max_gap", 260.0))
		var dy_min := float(kind.get("dy_min", 60.0)); var dy_max := float(kind.get("dy_max", 150.0))
		var hops := plats.filter(func(p: Dictionary) -> bool: return not (String(p["kind"]) in ["rest", "short", "ledge"]))
		var spans: Array = []
		for i in range(1, hops.size()):
			var a: Dictionary = hops[i - 1]; var b: Dictionary = hops[i]   # a 가 아래 발판(band() 는 오르는 순서로 쌓는다)
			if not (String(a["kind"]) in kinds and String(b["kind"]) in kinds): continue
			var dy := float(b["y"]) - float(a["y"])
			if dy < dy_min or dy > dy_max: continue
			var ax0 := float(a["x"]); var ax1 := ax0 + float(a["w"]); var bx0 := float(b["x"]); var bx1 := bx0 + float(b["w"])
			var right := bx0 >= ax1   # 위 발판이 오른쪽에 → 왼쪽(아래 발판 쪽)이 올라야 하니 시계 방향
			var gap := bx0 - ax1 if right else ax0 - bx1
			if gap < min_gap or gap > max_gap: continue
			var hx := (ax1 + bx0) / 2.0 if right else (bx1 + ax0) / 2.0
			var hy := (float(a["y"]) + float(b["y"])) / 2.0
			var reach := gap / 2.0 - cup_w() / 2.0 - float(kind.get("clear", 8.0))   # 턱 높이에서 컵 가운데가 축에서 떨어진 거리
			var len := sqrt(reach * reach + dy * dy / 4.0)   # 그 자리에 컵이 오게 하는 날 길이
			if not _clear(plats, a, b, hx, hy, len + cup_w() / 2.0): continue
			var d := minf(float(a.get("d", C.DEPTH_HALF * 2.0)), float(b.get("d", C.DEPTH_HALF * 2.0)))
			spans.append({ "gap": gap, "hx": hx, "hy": hy, "len": len, "dir": -1.0 if right else 1.0, "d": d, "a_y": float(a["y"]) })
		spans.sort_custom(func(p: Dictionary, q: Dictionary) -> bool: return float(p["gap"]) > float(q["gap"]))
		for i in mini(int(piece.get("max", 1)), spans.size()):
			var g: Dictionary = spans[i]
			var half := float(g["len"]) + cup_w() / 2.0
			out.append({ "id": "%d.w%d" % [n, i], "kind": "windmill", "x": float(g["hx"]) - half, "y": float(g["hy"]), "w": half * 2.0, "z": C.WALL_Z + float(g["d"]) / 2.0, "d": float(g["d"]),
				"hx": float(g["hx"]), "hy": float(g["hy"]), "len": float(g["len"]), "dir": float(g["dir"]), "a_y": float(g["a_y"]), "phase": float(piece.get("phase", 0.0)) })
	return out

## 바퀴가 쓸 원(축에서 r+10) 안에 두 턱 말고 다른 발판이 걸리지 않나 — 날이 지름길 판을 가르며 돌면 둘 다 못 읽는다
static func _clear(plats: Array, a: Dictionary, b: Dictionary, hx: float, hy: float, r: float) -> bool:
	var rr := r + 10.0
	for pv in plats:
		var p: Dictionary = pv
		if p["id"] == a["id"] or p["id"] == b["id"]: continue
		var px0 := float(p["x"]); var px1 := px0 + float(p["w"]); var py := float(p["y"])
		if px1 > hx - rr and px0 < hx + rr and py > hy - rr and py < hy + rr: return false
	return true

## 날 k 의 컵 바닥 높이(px) at 시각 — 컵이 그 x 를 덮지 않으면 NAN
func surf(s: Dictionary, k: int, x: float, at: float) -> float:
	var tp := tip(s, k, at)
	if absf(x - tp.x) > cup_w() / 2.0: return NAN
	return tp.y + float(kind.get("thick", 6.0)) / 2.0

## 로더의 착지 판정 뒤에 — 이 틱에 컵 바닥을 지나 떨어지는 몸, 또는 그 위 catch px 안에서 내려서는 몸(턱에서 컵으로 걸어 내려가는 걸음)을 받는다
func land(x: float, y: float, ny: float, z: float) -> Dictionary:
	var catch := float(kind.get("catch", 14.0))
	for sv in wheels:
		var s: Dictionary = sv
		if absf(z - float(s["z"])) >= float(s["d"]) / 2.0 + C.HZ: continue
		for k in blades():
			var sy := surf(s, k, x, t)
			if is_nan(sy): continue
			var cross := y >= sy and ny <= sy
			var step := not cross and ny < y and y > sy and y - sy <= catch
			if not (cross or step): continue
			var hit := s.duplicate(); hit["y"] = sy; hit["arm"] = k; hit["step"] = step
			return hit
	return {}

## 서 있는 매 틱 — 컵과 함께 돌아간 자리 {x, y, off}: 컵 안의 제자리(가운데에서의 치우침)를 지키며 x·y 가 바뀐다(걸으면 치우침이 바뀐다); 컵 밖으로 나가면 off. fig 가 있으면 자세가 읽을 컵의 속도를 적어 준다
func ride(on: Dictionary, x: float, dt: float, fig: Stick3D = null) -> Dictionary:
	var s := _find(String(on.get("id", "")))
	if s.is_empty(): return { "x": x, "y": float(on.get("y", 0.0)), "off": true }
	var k := int(on.get("arm", 0))
	var side := x - tip(s, k, t - dt).x
	var tp := tip(s, k, t); var v := vel(s, k, t)
	var off := absf(side) >= cup_w() / 2.0 + C.HW
	if fig:
		fig.set_meta("ride_k", v.x)
		fig.set_meta("ride_v", v.y)
	s["rode"] = t
	return { "x": tp.x + side, "y": tp.y + float(kind.get("thick", 6.0)) / 2.0, "off": off }

## 공중의 몸(x±HW, y..y+body_h)이 날의 살에 닿았나 — 닿았으면 날이 가는 쪽으로 밀어내는 속도 {vx, vy}, 아니면 빈 사전. 살은 축 밖 hub_r 에서 컵 앞(len − cup_w)까지만 센다 — 컵에 선 몸이 제 살에 맞지 않게
func sweep(x: float, y: float, z: float) -> Dictionary:
	var bh := float(kind.get("body_h", 40.0)); var th := float(kind.get("thick", 6.0))
	for sv in wheels:
		var s: Dictionary = sv
		if absf(z - float(s["z"])) >= float(s["d"]) / 2.0 + C.HZ: continue
		for k in blades():
			var a := ang(s, k, t)
			var u := float(kind.get("hub_r", 10.0))
			while u <= float(s["len"]) - cup_w():
				var px := float(s["hx"]) + u * cos(a); var py := float(s["hy"]) + u * sin(a)
				if absf(px - x) < C.HW + th / 2.0 and py > y - th / 2.0 and py < y + bh + th / 2.0:
					var v := vel(s, k, t)
					return { "vx": signf(v.x) * float(kind.get("shove_vx", 220.0)), "vy": float(kind.get("shove_vy", 240.0)) }
				u += 8.0
	return {}

func _find(id: String) -> Dictionary:
	for sv in wheels:
		if String((sv as Dictionary)["id"]) == id: return sv
	return {}

## 바퀴를 짓는다 — root 는 그 층의 노드. 노드 원점은 축(hx, hy, z); 절벽에서 나오는 축대, 나무 축, 날마다 종이 살(잉크 뼈대)과 끝의 수평 컵(바닥 + 두 턱)
func build(root: Node3D, planned: Array) -> void:
	var th := float(kind.get("thick", 6.0)) * C.K; var hr := float(kind.get("hub_r", 10.0)) * C.K; var cw := cup_w() * C.K
	for sv in planned:
		var s: Dictionary = (sv as Dictionary).duplicate()
		var dep := float(s["d"]) * C.K * 0.8
		var node := Node3D.new(); node.position = C.to3(float(s["hx"]), float(s["hy"]), float(s["z"]) * C.K); root.add_child(node)
		var paper := _mat(Color("efe7d9")); var ink := _mat(Color("2f2a4e")); var wood := _mat(Color("8a6a4a")); var tipc := _mat(Color("ad7096"))
		var axle_len := (float(s["z"]) - C.WALL_Z) * C.K + 0.3
		_box(node, Vector3(0.08, 0.08, axle_len), wood).position = Vector3(0, 0, -axle_len / 2.0 + 0.1)
		var hub := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = hr; cm.bottom_radius = hr; cm.height = dep + 0.08; cm.radial_segments = 10; hub.mesh = cm
		hub.material_override = wood; hub.rotation.x = PI / 2.0; hub.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; node.add_child(hub)
		var len := float(s["len"]) * C.K
		var arms: Array = []; var cups: Array = []
		for _k in blades():
			var arm := Node3D.new(); node.add_child(arm)
			_box(arm, Vector3(len * 0.8, th * 2.2, dep * 0.7), paper).position = Vector3(len * 0.45, 0, 0)   # 종이 살 — 축 가까이서 컵 앞까지
			_box(arm, Vector3(len, th * 0.5, 0.012), ink).position = Vector3(len / 2.0, 0, dep * 0.35 + 0.006)   # 앞면의 잉크 뼈대
			var cup := Node3D.new(); cup.position = Vector3(len, 0, 0); arm.add_child(cup)
			_box(cup, Vector3(cw, th, dep), paper)
			for e in [-1.0, 1.0]:
				var ex: float = e
				_box(cup, Vector3(0.03, th * 1.8, dep), tipc).position = Vector3(ex * (cw / 2.0 - 0.015), th * 0.4, 0)   # 컵의 두 턱 — 포도빛 접은 끝
			arms.append(arm); cups.append(cup)
		var clack := AudioStreamPlayer3D.new(); clack.stream = _clack_wav(float(kind.get("clack_hz", 180))); clack.volume_db = -9.0; clack.unit_size = 6.0; clack.max_distance = 30.0; node.add_child(clack)
		s["node"] = node; s["arms"] = arms; s["cups"] = cups; s["clack"] = clack; s["rode"] = -9.0
		wheels.append(s)
		_turn(s)

## 날을 지금 각으로, 컵은 그 반대로 돌려 수평을 지킨다
func _turn(s: Dictionary) -> void:
	var arms: Array = s["arms"]; var cups: Array = s["cups"]
	for k in arms.size():
		var a := ang(s, k, t)
		(arms[k] as Node3D).rotation.z = a
		(cups[k] as Node3D).rotation.z = -a

func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.albedo_color = c; m.roughness = 1.0
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON; m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return m

func _box(parent: Node3D, size: Vector3, m: StandardMaterial3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = size; mi.mesh = bm; mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF   # 발판과 같은 규칙 — 그림자는 사람만
	parent.add_child(mi); return mi

## 나무 딸깍 — 0.12초, 기음과 어긋난 배음이 빠르게 잦아든다(한 번 재생, 반복 없음)
static func _clack_wav(hz: float) -> AudioStreamWAV:
	var rate := 22050; var count := int(rate * 0.12)
	var data := PackedByteArray(); data.resize(count * 2)
	for i in count:
		var k := float(i) / count
		var ph := float(i) * hz * TAU / rate
		var v := (sin(ph) * 0.5 + sin(ph * 2.7) * 0.3) * exp(-k * 7.0)
		data.encode_s16(i * 2, int(v * 22000.0))
	var w := AudioStreamWAV.new(); w.format = AudioStreamWAV.FORMAT_16_BITS; w.mix_rate = rate; w.stereo = false; w.data = data
	return w
