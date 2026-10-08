class_name ClimbPendulum
extends Node3D
## Climb 콘텐츠 팩 '추'(운영자 2026-10-06 밤: "Climb는 컨텐츠 자체의 질과 양을 늘리는 거" — 팩은 data/climb/*.json 자료, 로더는 운영자 세션이 잇는다; climb.gd 는 CI 가 안 건드린다).
## 태엽(Clockwork) 층의 잇단 두 std 발판 사이 틈 — 절벽의 받침대에서 쇠 막대가 내려와 놋쇠 가로대와 시계추(놋쇠 추)가 매달려 흔들린다. 공중에서 ↑ 로 가로대를 붙잡으면(홀드와 같은 손 범위) 매달린 채 반대편으로 실려 간다(dangle);
## 매달려서 SPACE 로 모았다 놓으면 추의 속도를 얹어 뛰고(홀드와 같은 0.9), ↓ 면 추의 속도만 안고 떨어진다. 추의 끝(양쪽 극점)은 멈춘 순간이라 그때 잡기 쉽다 — 그 순간 시계 tock 이 울린다.
## 막대 길이는 기하로 정한다: 받침대는 위 발판보다 rise 위, 흔들림의 바닥에서 가로대는 두 발판 높이의 평균보다 hang 위(매달린 몸의 발이 그 평균 높이), 진폭은 추의 바깥이 두 턱 끝에서 clear 만큼 떨어지게.
## 추는 그 층의 다른 틈 팩이 가져가는 가장 긴 틈 하나(다리 bridge·유령 판 ghost)나 둘(버섯 mushroom)을 건너뛴 다음 틈에만 — 같은 틈을 두 팩이 쓰지 않는다. 빈 틈의 흔들리는 추는 공중의 몸을 밀어낸다(sweep — 가는 쪽·위로, 아래로는 절대; 양 끝의 멈춘 추는 안 민다).
## 로더가 할 일(climb.gd, 운영자 세션): `var cp := ClimbPendulum.new(); add_child(cp)`; 층을 지을 때 `cp.build(root, cp.plan(n, plats))`; 매 틱 `cp.sync(_t)`;
## 공중에서 ↑(dirz < 0)이고 홀드를 못 잡았으면 `var g := cp.grab(x, y, z); if not g.is_empty(): swinging = g; on = {}; vx = 0.0; vy = 0.0; charge = 0.0` (swinging 은 로더의 새 사전 — holding 처럼);
## 매달린 매 틱(`_hold` 와 같은 자리): `var r := cp.hang_on(swinging, fig); x = r["x"]; y = r["y"]; apex = y; fig.pose_request = "dangle"; stamina -= dt * 0.09`, `r["lost"]` 면 놓는다;
## SPACE 를 놓으면 `var v := cp.let_go(swinging); vy = (JUMP_MIN + (JUMP_V - JUMP_MIN) * (charge / CHARGE)) * 0.9 + maxf(0.0, v["vy"]); vx = dir * RUN * 0.9 + v["vx"]; swinging = {}; 자세 ""`; ↓ 나 힘이 다하면 `vx = v["vx"]; vy = v["vy"]; swinging = {}`;
## 공중(on 이 빈 틱, 매달리지 않은)이면 `var sh := cp.sweep(x, y, z); if not sh.is_empty(): vx = sh["vx"]; vy = sh["vy"]; hurt = 0.4; fig.squash = -0.4`. 단위는 climb.gd 와 같은 px(36px = 1m, +y 위). 자세는 stick3d_dangle.gd, 점검은 tools/probe_pendulum.gd

const PACK := "res://data/climb/pendulum.json"
const C = preload("res://scripts/games/climb.gd")

var pack: Dictionary = {}
var kind: Dictionary = {}       # kinds.weight
var bobs: Array = []            # 지은 추 {id, kind "pendulum", x, y, w, z, d, hx, hp, len, amax, low_y, a_y, b_y, phase, node, arm, tock, held}
var t := 0.0                    # 로더의 _t 와 같이 간다(sync)

func _ready() -> void:
	var f := FileAccess.open(PACK, FileAccess.READ)
	if f: pack = JSON.parse_string(f.get_as_text()) as Dictionary
	kind = (pack.get("kinds", {}) as Dictionary).get("weight", {})

func sync(now: float) -> void:
	t = now

func period() -> float:
	return maxf(0.5, float(kind.get("period_s", 2.4)))

func hang() -> float:
	return float(kind.get("hang", 58.0))

## 흔들림의 위상 — sin 이 각의 비(−1..1), cos 이 속도의 비. 같은 시각엔 누구에게나 같다
func phase(s: Dictionary, at: float) -> float:
	return TAU * at / period() + float(s.get("phase", 0.0))

## 막대의 각(라디안; +면 +x 쪽으로 기울었다)
func ang(s: Dictionary, at: float) -> float:
	return float(s["amax"]) * sin(phase(s, at))

## 가로대 가운데의 자리(px) — 손이 잡는 곳
func bar(s: Dictionary, at: float) -> Vector2:
	var a := ang(s, at)
	return Vector2(float(s["hx"]) + float(s["len"]) * sin(a), float(s["hp"]) - float(s["len"]) * cos(a))

## 가로대의 속도 방향 −1..1(최고 속도를 1 로) — x 는 +x 로 가면 양수, y 는 오르면 양수 (d/dt (sin a, −cos a) = a'·(cos a, sin a))
func vel(s: Dictionary, at: float) -> Vector2:
	var a := ang(s, at)
	return Vector2(cos(a), sin(a)) * cos(phase(s, at))

## 가로대의 속도 px/s
func speed(s: Dictionary, at: float) -> Vector2:
	return vel(s, at) * float(s["len"]) * float(s["amax"]) * TAU / period()

## 막대를 돌리고, 속도의 부호가 바뀌는 틱(양 끝)에 tock — 빈 추도 흔들린다(시계니까)
func _process(delta: float) -> void:
	t += delta
	bobs = bobs.filter(func(s: Dictionary) -> bool: return is_instance_valid(s["node"]))   # 지운 층의 것은 뺀다(climb_windmill 과 같은 식)
	for sv in bobs:
		var s: Dictionary = sv
		_turn(s)
		if cos(phase(s, t - delta)) * cos(phase(s, t)) <= 0.0:
			var tk: AudioStreamPlayer3D = s["tock"]
			if tk.playing: tk.stop()
			tk.play()

## 층 n(테마 층만, 조각의 'only' 층만·'not' 층은 뺀다)의 잇단 두 std 발판 사이 틈 중 min_gap..max_gap 에 들고 높이차가 max_dy 안인 것들을 긴 순서로 세워 조각의 skip 개(그 층의 다른 팩 몫)를 버리고 그다음 것 하나 — 틈 한가운데에 받침대. 같은 층은 늘 같은 답
func plan(n: int, plats: Array) -> Array:
	var out: Array = []
	if not (String(C.theme(n)[0]) in (pack.get("themes", []) as Array)): return out
	for pv in (pack.get("pieces", []) as Array):
		var piece: Dictionary = pv
		var nt: Dictionary = piece.get("not", {})
		if not nt.is_empty() and _on(n, nt): continue
		var only: Dictionary = piece.get("only", {})
		if not only.is_empty() and not _on(n, only): continue
		var kinds: Array = piece.get("on", ["std"])
		var min_gap := float(kind.get("min_gap", 80.0)); var max_gap := float(kind.get("max_gap", 200.0)); var max_dy := float(kind.get("max_dy", 150.0))
		var rise := float(kind.get("rise", 150.0)); var clear := float(kind.get("clear", 8.0)); var br := float(kind.get("bob_r", 12.0))
		var hops := plats.filter(func(p: Dictionary) -> bool: return not (String(p["kind"]) in ["rest", "short", "ledge"]))
		var spans: Array = []
		for i in range(1, hops.size()):
			var a: Dictionary = hops[i - 1]; var b: Dictionary = hops[i]   # a 가 아래 발판(band() 는 오르는 순서로 쌓는다)
			if not (String(a["kind"]) in kinds and String(b["kind"]) in kinds): continue
			if absf(float(b["y"]) - float(a["y"])) > max_dy: continue
			var ax0 := float(a["x"]); var ax1 := ax0 + float(a["w"]); var bx0 := float(b["x"]); var bx1 := bx0 + float(b["w"])
			var right := bx0 >= ax1   # 위 발판이 오른쪽에
			var gap := bx0 - ax1 if right else ax0 - bx1
			if gap < min_gap or gap > max_gap: continue
			var hx := (ax1 + bx0) / 2.0 if right else (bx1 + ax0) / 2.0
			var mean := (float(a["y"]) + float(b["y"])) / 2.0
			var low_y := mean + hang()   # 흔들림의 바닥에서 가로대 높이 — 매달린 발이 두 발판 높이의 평균
			var hp := maxf(float(a["y"]), float(b["y"])) + rise
			var len := hp - low_y
			var reach := gap / 2.0 - clear - br   # 극점에서 가로대 가운데가 받침대 x 에서 떨어진 거리
			if reach < float(kind.get("min_reach", 14.0)) or reach > len * 0.7: continue
			if not _clear(plats, a, b, hx, reach, br, len, mean - 10.0, hp): continue
			var d := minf(float(a.get("d", C.DEPTH_HALF * 2.0)), float(b.get("d", C.DEPTH_HALF * 2.0)))
			spans.append({ "gap": gap, "hx": hx, "hp": hp, "len": len, "amax": asin(reach / len), "low_y": low_y, "d": d, "a_y": float(a["y"]), "b_y": float(b["y"]), "half": reach + br })
		spans.sort_custom(func(p: Dictionary, q: Dictionary) -> bool: return float(p["gap"]) > float(q["gap"]))
		var skip := int(piece.get("skip", kind.get("skip_longest", 2)))
		for i in range(skip, mini(skip + int(piece.get("max", 1)), spans.size())):
			var g: Dictionary = spans[i]
			out.append({ "id": "%d.p%d" % [n, i - skip], "kind": "pendulum", "x": float(g["hx"]) - float(g["half"]), "y": float(g["low_y"]) - hang(), "w": float(g["half"]) * 2.0, "z": C.WALL_Z + float(g["d"]) / 2.0, "d": float(g["d"]),
				"hx": float(g["hx"]), "hp": float(g["hp"]), "len": float(g["len"]), "amax": float(g["amax"]), "low_y": float(g["low_y"]), "a_y": float(g["a_y"]), "b_y": float(g["b_y"]), "phase": float(piece.get("phase", 0.0)) })
	return out

## 층 n 이 {from, every} 에 드나
static func _on(n: int, rule: Dictionary) -> bool:
	var from := int(rule.get("from", 0))
	return n >= from and (n - from) % maxi(1, int(rule.get("every", 1))) == 0

## 추가 쓸 쐐기(받침대에서 아래로 벌어지는 — 가로대 위 높이에선 그 높이에서 막대가 닿는 x 만, 가로대 아래에선 추 반지름과 몸 반폭까지; 매달린 발 높이..받침대) 안에 두 턱 말고 다른 발판이 걸리지 않나 — 받침대 바로 위의 다음 턱은 막대가 안 닿으니 괜찮고, 지름길 판을 추가 가르며 지나면 둘 다 못 읽는다
static func _clear(plats: Array, a: Dictionary, b: Dictionary, hx: float, reach: float, br: float, len: float, y0: float, y1: float) -> bool:
	for pv in plats:
		var p: Dictionary = pv
		if p["id"] == a["id"] or p["id"] == b["id"]: continue
		var px0 := float(p["x"]); var px1 := px0 + float(p["w"]); var py := float(p["y"])
		if py <= y0 or py >= y1: continue
		var depth := y1 - py
		var half := depth / len * reach + 6.0 if depth < len else reach + br + C.HW   # 가로대 위는 가는 막대만, 가로대 아래는 추와 매달린 몸까지
		if px1 > hx - half and px0 < hx + half: return false
	return true

## 공중에서 ↑ — 손(발 + hang)이 가로대의 reach_x·reach_y 안이면 잡는다: 돌려주는 사전의 x·y 가 몸의 자리(가로대 밑 hang). 아니면 빈 사전
func grab(x: float, y: float, z: float) -> Dictionary:
	var rx := float(kind.get("reach_x", 26.0)); var ry := float(kind.get("reach_y", 22.0))
	for sv in bobs:
		var s: Dictionary = sv
		if absf(z - float(s["z"])) >= float(s["d"]) / 2.0 + C.HZ: continue
		var h := bar(s, t)
		if absf(x - h.x) < rx and absf(y + hang() - h.y) < ry:
			var hit := s.duplicate(); hit["x"] = h.x; hit["y"] = h.y - hang()
			s["held"] = t
			return hit
	return {}

## 매달린 매 틱 — 가로대 밑의 몸 자리 {x, y, lost}; fig 가 있으면 자세가 읽을 속도(dangle_v)와 막대 각(dangle_a)을 적어 준다. 추가 사라졌으면 lost
func hang_on(on: Dictionary, fig: Stick3D = null) -> Dictionary:
	var s := _find(String(on.get("id", "")))
	if s.is_empty(): return { "x": float(on.get("x", 0.0)), "y": float(on.get("y", 0.0)), "lost": true }
	var h := bar(s, t); var v := vel(s, t)
	if fig:
		fig.set_meta("dangle_v", v.x)
		fig.set_meta("dangle_a", ang(s, t))
	s["held"] = t
	return { "x": h.x, "y": h.y - hang(), "lost": false }

## 놓는 순간 가로대의 속도 {vx, vy} px/s — 뛰면 얹고, 떨어지면 안고 간다
func let_go(on: Dictionary) -> Dictionary:
	var s := _find(String(on.get("id", "")))
	if s.is_empty(): return { "vx": 0.0, "vy": 0.0 }
	var v := speed(s, t)
	s["held"] = t
	return { "vx": v.x, "vy": v.y }

## 공중의 몸(x±HW, y..y+body_h)에 달리는 추(원)가 닿았나 — 닿았으면 가는 쪽·위로 밀어내는 속도 {vx, vy}, 아니면 빈 사전. 끝에서 멈춘 추(|속도| < shove_min)와 방금 놓은 추(grace_s)는 안 민다
func sweep(x: float, y: float, z: float) -> Dictionary:
	var bh := float(kind.get("body_h", 40.0)); var br := float(kind.get("bob_r", 12.0))
	var drop := float(kind.get("bar_gap", 6.0)) + float(kind.get("bob_h", 30.0)) / 2.0
	for sv in bobs:
		var s: Dictionary = sv
		if absf(z - float(s["z"])) >= float(s["d"]) / 2.0 + C.HZ: continue
		if t - float(s.get("held", -9.0)) < float(kind.get("grace_s", 0.3)): continue
		var v := vel(s, t)
		if absf(cos(phase(s, t))) < float(kind.get("shove_min", 0.35)): continue
		var h := bar(s, t); var cx := h.x; var cy := h.y - drop
		var qx := clampf(cx, x - C.HW, x + C.HW); var qy := clampf(cy, y, y + bh)   # 상자에서 원 중심에 가장 가까운 점
		if (qx - cx) * (qx - cx) + (qy - cy) * (qy - cy) < br * br:
			return { "vx": signf(v.x) * float(kind.get("shove_vx", 220.0)), "vy": float(kind.get("shove_vy", 240.0)) }
	return {}

func _find(id: String) -> Dictionary:
	for sv in bobs:
		if String((sv as Dictionary)["id"]) == id: return sv
	return {}

## 추를 짓는다 — root 는 그 층의 노드. 노드 원점은 받침대(hx, hp, z); 절벽에서 나온 나무 받침대, 쇠 핀, 막대 노드(핀에서 도는) 안에 쇠 막대·놋쇠 가로대·놋쇠 추·잉크 띠
func build(root: Node3D, planned: Array) -> void:
	var br := float(kind.get("bob_r", 12.0)) * C.K; var bh := float(kind.get("bob_h", 30.0)) * C.K
	var bw := float(kind.get("bar_w", 24.0)) * C.K; var bg := float(kind.get("bar_gap", 6.0)) * C.K
	for sv in planned:
		var s: Dictionary = (sv as Dictionary).duplicate()
		var dep := float(s["d"]) * C.K * 0.5
		var node := Node3D.new(); node.position = C.to3(float(s["hx"]), float(s["hp"]), float(s["z"]) * C.K); root.add_child(node)
		var wood := _mat(Color("8a6a4a")); var iron := _mat(Color("3a3640")); var brass := _mat(Color("c9a24a")); var ink := _mat(Color("2f2a4e"))
		var beam_len := (float(s["z"]) - C.WALL_Z) * C.K + 0.3
		_box(node, Vector3(0.1, 0.1, beam_len), wood).position = Vector3(0, 0.05, -beam_len / 2.0 + 0.1)   # 절벽에서 나온 받침대
		var pin := MeshInstance3D.new(); var pm := CylinderMesh.new(); pm.top_radius = 0.035; pm.bottom_radius = 0.035; pm.height = dep + 0.06; pm.radial_segments = 8; pin.mesh = pm
		pin.material_override = iron; pin.rotation.x = PI / 2.0; pin.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; node.add_child(pin)
		var len := float(s["len"]) * C.K
		var arm := Node3D.new(); node.add_child(arm)
		_box(arm, Vector3(0.04, len, 0.04), iron).position = Vector3(0, -len / 2.0, 0)   # 쇠 막대 — 핀에서 가로대까지
		_box(arm, Vector3(bw, 0.05, dep * 0.6), brass).position = Vector3(0, -len, 0)   # 손이 잡는 가로대
		var weight := MeshInstance3D.new(); var wm := CylinderMesh.new(); wm.top_radius = br; wm.bottom_radius = br; wm.height = bh; wm.radial_segments = 12; weight.mesh = wm
		weight.material_override = brass; weight.position = Vector3(0, -len - bg - bh / 2.0, 0); weight.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; arm.add_child(weight)
		var ring := MeshInstance3D.new(); var rm := CylinderMesh.new(); rm.top_radius = br + 0.006; rm.bottom_radius = br + 0.006; rm.height = 0.025; rm.radial_segments = 12; ring.mesh = rm
		ring.material_override = ink; ring.position = Vector3(0, -len - bg - bh * 0.35, 0); ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; arm.add_child(ring)   # 추 허리의 잉크 띠
		var tock := AudioStreamPlayer3D.new(); tock.stream = _tock_wav(float(kind.get("tock_hz", 110))); tock.volume_db = -8.0; tock.unit_size = 6.0; tock.max_distance = 30.0; node.add_child(tock)
		s["node"] = node; s["arm"] = arm; s["tock"] = tock; s["held"] = -9.0
		bobs.append(s)
		_turn(s)

## 막대를 지금 각으로 — +z 돌림이면 끝이 +x 로 간다(bar 와 같은 식)
func _turn(s: Dictionary) -> void:
	(s["arm"] as Node3D).rotation.z = ang(s, t)

func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.albedo_color = c; m.roughness = 1.0
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON; m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return m

func _box(parent: Node3D, size: Vector3, m: StandardMaterial3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = size; mi.mesh = bm; mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF   # 발판과 같은 규칙 — 그림자는 사람만
	parent.add_child(mi); return mi

## 시계의 tock — 0.1초, 낮은 기음에 둔한 배음이 빠르게 잦아든다(풍차의 clack 보다 무겁다; 한 번 재생, 반복 없음)
static func _tock_wav(hz: float) -> AudioStreamWAV:
	var rate := 22050; var count := int(rate * 0.1)
	var data := PackedByteArray(); data.resize(count * 2)
	for i in count:
		var k := float(i) / count
		var ph := float(i) * hz * TAU / rate
		var v := (sin(ph) * 0.6 + sin(ph * 1.5) * 0.25) * exp(-k * 9.0)
		data.encode_s16(i * 2, int(v * 22000.0))
	var w := AudioStreamWAV.new(); w.format = AudioStreamWAV.FORMAT_16_BITS; w.mix_rate = rate; w.stereo = false; w.data = data
	return w
