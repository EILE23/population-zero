class_name ClimbBridge
extends Node3D
## Climb 콘텐츠 팩 '밧줄 다리'(운영자 2026-10-06 밤: "Climb는 컨텐츠 자체의 질과 양을 늘리는 거" — 팩은 data/climb/*.json 자료, 로더는 운영자 세션이 잇는다; climb.gd 는 CI 가 안 건드린다).
## 한 층의 잇단 두 std 발판 사이 가장 긴 틈(min_gap..max_gap)에 마주 보는 두 턱 끝을 잇는 다리 — 판자가 현수선(sag)으로 처지고 양쪽에 손잡이 밧줄·말뚝. 뛰지 않고 걸어 건너는 길이지만 발밑이 흔들린다:
## 몸이 올라서면 바닥이 dip 만큼 더 처지고(load_t 에 걸쳐) 앞뒤(z)로 period 주기로 흔들리며 삐걱(creak)인다. 서 있는 동안 자세는 sway(무릎 느슨, 팔 벌림, 골반이 흔들림을 따른다 — stick3d_sway.gd).
## 로더가 할 일(climb.gd, 운영자 세션): `var br := ClimbBridge.new(); add_child(br)`; 층을 지을 때 `br.build(root, br.plan(n, plats))`; 매 틱 `br.sync(_t)`;
## 착지 판정에서 landed 가 비었고 vy <= 0 이면 `landed = br.land(x, y, ny, z)` (돌려준 사전의 "y" 가 그 x 의 바닥 높이; "step" 이 참이면 발판에서 내려선 걸음이라 vx 를 0 으로 안 해도 된다);
## 서 있을 때 `on["kind"] == "bridge"` 면 `y = br.stand(on, x, dt, fig); fig.pose_request = "sway"`, 다리를 떠나면 비운다. 단위는 climb.gd 와 같은 px(36px = 1m, +y 위). 점검은 tools/probe_bridge.gd

const PACK := "res://data/climb/bridge.json"
const C = preload("res://scripts/games/climb.gd")

var pack: Dictionary = {}
var kind: Dictionary = {}       # kinds.bridge
var bridges: Array = []         # 지은 다리 {id, x, y, w, kind "bridge", z, d, x0, y0, x1, y1, node, planks, rails, threads, creak, load, stood, was}
var t := 0.0                    # 로더의 _t 와 같이 간다(sync)

func _ready() -> void:
	var f := FileAccess.open(PACK, FileAccess.READ)
	if f: pack = JSON.parse_string(f.get_as_text()) as Dictionary
	kind = (pack.get("kinds", {}) as Dictionary).get("bridge", {})

func sync(now: float) -> void:
	t = now

## 짐(load)을 따라 처짐·흔들림을 그림에 — 몸이 올라선 다리만 움직인다(빈 다리는 지은 모양 그대로)
func _process(delta: float) -> void:
	t += delta
	bridges = bridges.filter(func(s: Dictionary) -> bool: return is_instance_valid(s["node"]))   # 지운 층의 것은 뺀다(climb_ghost 와 같은 식)
	for sv in bridges:
		var s: Dictionary = sv
		var want := 1.0 if t - float(s["stood"]) < 0.1 else 0.0
		var load := move_toward(float(s["load"]), want, delta / float(kind.get("load_t", 0.25)))
		if load >= 0.5 and float(s["load"]) < 0.5:
			var ck: AudioStreamPlayer3D = s["creak"]
			if ck.playing: ck.stop()
			ck.play()
		if load == 0.0 and float(s["load"]) == 0.0: continue
		s["load"] = load
		_lay(s)

## 층 n 의 잇단 두 발판(둘 다 on 종류) 사이 틈 중 min_gap..max_gap 에 드는 가장 긴 것 하나 — 아래 턱의 마주 보는 끝에서 위 턱의 마주 보는 끝으로. 같은 층은 늘 같은 답
func plan(n: int, plats: Array) -> Array:
	var out: Array = []
	for pv in (pack.get("pieces", []) as Array):
		var piece: Dictionary = pv
		var from := int(piece.get("from", 0)); var every := maxi(1, int(piece.get("every", 1)))
		if n < from or (n - from) % every != 0: continue
		var kinds: Array = piece.get("on", ["std"])
		var min_gap := float(kind.get("min_gap", 90.0)); var max_gap := float(kind.get("max_gap", 320.0)); var max_dy := float(kind.get("max_dy", 150.0))
		var hops := plats.filter(func(p: Dictionary) -> bool: return not (String(p["kind"]) in ["rest", "short", "ledge"]))
		var spans: Array = []
		for i in range(1, hops.size()):
			var a: Dictionary = hops[i - 1]; var b: Dictionary = hops[i]   # a 가 아래 발판
			if not (String(a["kind"]) in kinds and String(b["kind"]) in kinds): continue
			if absf(float(a["y"]) - float(b["y"])) > max_dy: continue
			var ax0 := float(a["x"]); var ax1 := ax0 + float(a["w"]); var bx0 := float(b["x"]); var bx1 := bx0 + float(b["w"])
			var right := bx0 >= ax1   # b 가 오른쪽에
			var gap := bx0 - ax1 if right else ax0 - bx1
			if gap < min_gap or gap > max_gap: continue
			var x0 := ax1 if right else bx1; var x1 := bx0 if right else ax0
			var y0 := float(a["y"]) if right else float(b["y"]); var y1 := float(b["y"]) if right else float(a["y"])
			if not _clear(plats, a, b, x0, x1, minf(y0, y1), maxf(y0, y1)): continue
			var d := minf(float(a.get("d", C.DEPTH_HALF * 2.0)), float(b.get("d", C.DEPTH_HALF * 2.0)))
			spans.append({ "gap": gap, "x0": x0, "y0": y0, "x1": x1, "y1": y1, "d": d })
		spans.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["gap"]) > float(b["gap"]))
		for i in mini(int(piece.get("max", 1)), spans.size()):
			var g: Dictionary = spans[i]
			var s := { "id": "%d.b%d" % [n, i], "kind": "bridge", "x": float(g["x0"]), "w": float(g["x1"]) - float(g["x0"]), "x0": float(g["x0"]), "y0": float(g["y0"]), "x1": float(g["x1"]), "y1": float(g["y1"]),
				"z": C.WALL_Z + float(g["d"]) / 2.0, "d": float(g["d"]), "load": 0.0, "stood": -9.0 }
			s["y"] = surf(s, (float(g["x0"]) + float(g["x1"])) / 2.0)   # 한가운데 바닥 — 로더의 일반 코드가 읽을 대표 높이(착지·서기는 surf 로)
			out.append(s)
	return out

## 이 폭(x0..x1) 안에 두 턱 말고 다른 발판이 다리 높이띠(ylo-40..yhi+40)에 걸리지 않나 — 지름길 판이 판자 사이로 솟으면 둘 다 못 읽는다
static func _clear(plats: Array, a: Dictionary, b: Dictionary, x0: float, x1: float, ylo: float, yhi: float) -> bool:
	for pv in plats:
		var p: Dictionary = pv
		if p["id"] == a["id"] or p["id"] == b["id"]: continue
		var px0 := float(p["x"]); var px1 := px0 + float(p["w"])
		if px1 > x0 and px0 < x1 and float(p["y"]) > ylo - 40.0 and float(p["y"]) < yhi + 40.0: return false
	return true

## 바닥 높이(px) — 두 끝을 잇는 현에서 현수선만큼 처진다(빈 다리 sag, 몸이 실리면 dip 이 load 만큼 더). 폭 밖은 가까운 끝의 높이
func surf(s: Dictionary, x: float) -> float:
	var u := clampf((x - float(s["x0"])) / maxf(1.0, float(s["x1"]) - float(s["x0"])), 0.0, 1.0)
	var hang := float(kind.get("sag", 28.0)) + float(kind.get("dip", 11.0)) * float(s.get("load", 0.0))
	return lerpf(float(s["y0"]), float(s["y1"]), u) - hang * 4.0 * u * (1.0 - u)

## 흔들림 −1..1 — 짐이 실린 만큼, period 주기로
func swing_of(s: Dictionary) -> float:
	return float(s.get("load", 0.0)) * sin(TAU * t / float(kind.get("period", 1.2)))

## 로더의 착지 판정 뒤에 — 이 틱에 바닥을 지나 떨어지는 몸, 또는 바닥 위 catch px 안에서 내려서는 몸(턱에서 판자로 걸어 내려가는 걸음)을 받는다. 돌려준 사전의 "y" 가 그 x 의 바닥
func land(x: float, y: float, ny: float, z: float) -> Dictionary:
	var catch := float(kind.get("catch", 14.0))
	for sv in bridges:
		var s: Dictionary = sv
		if x < float(s["x0"]) or x > float(s["x1"]) or absf(z - float(s["z"])) >= float(s["d"]) / 2.0 + C.HZ: continue
		var sy := surf(s, x)
		var cross := y >= sy and ny <= sy
		var step := not cross and ny < y and y > sy and y - sy <= catch
		if not (cross or step): continue
		var hit := s.duplicate(); hit["y"] = sy; hit["step"] = step
		return hit
	return {}

## 서 있는 매 틱 — 짐을 적고(처짐·흔들림·삐걱이 따라온다) 발밑 바닥 높이를 돌려준다; fig 가 있으면 자세가 읽을 흔들림을 적어 준다(sway_k)
func stand(on: Dictionary, x: float, _dt: float, fig: Stick3D = null) -> float:
	var s := _find(String(on.get("id", "")))
	if s.is_empty(): return float(on.get("y", 0.0))
	s["stood"] = t
	if fig: fig.set_meta("sway_k", swing_of(s))
	return surf(s, x)

func _find(id: String) -> Dictionary:
	for sv in bridges:
		if String((sv as Dictionary)["id"]) == id: return sv
	return {}

## 다리를 짓는다 — root 는 그 층의 노드. 노드 원점은 아래 끝(x0, y0, z); 판자·손잡이 밧줄·실·말뚝은 _lay 가 현수선을 따라 놓는다
func build(root: Node3D, planned: Array) -> void:
	var pitch := float(kind.get("plank_w", 14.0)) + float(kind.get("plank_gap", 4.0))
	for sv in planned:
		var s: Dictionary = (sv as Dictionary).duplicate()
		var dep := float(s["d"]) * C.K * 0.9
		var node := Node3D.new(); node.position = C.to3(float(s["x0"]), float(s["y0"]), float(s["z"]) * C.K); root.add_child(node)
		var wood := _mat(Color("8a6a4a")); var rope := _mat(Color("6b5a48")); var post := _mat(Color("4a4a52"))
		var count := maxi(2, int(float(s["w"]) / pitch))
		var planks: Array = []; var rails: Array = []; var threads: Array = []
		for i in count:
			planks.append(_box(node, Vector3(float(kind.get("plank_w", 14.0)) * C.K, float(kind.get("thick", 6.0)) * C.K, dep), wood))
			for _k in 2: rails.append(_box(node, Vector3(pitch * C.K + 0.01, 0.035, 0.035), rope))
			if i % 3 == 1:
				for _k in 2: threads.append(_box(node, Vector3(0.02, 1.0, 0.02), rope))
		var ph := float(kind.get("post_h", 36.0)) * C.K
		for exv in [0.0, float(s["w"]) * C.K]:
			var ex: float = exv
			for k in 2:
				var p := _box(node, Vector3(0.09, ph, 0.09), post); p.position = Vector3(ex, surf_m(s, ex) + ph / 2.0 - 0.05, (k - 0.5) * dep)
		var creak := AudioStreamPlayer3D.new(); creak.stream = _creak_wav(float(kind.get("creak_hz", 110))); creak.volume_db = -8.0; creak.unit_size = 6.0; creak.max_distance = 30.0; node.add_child(creak)
		s["node"] = node; s["planks"] = planks; s["rails"] = rails; s["threads"] = threads; s["creak"] = creak; s["load"] = 0.0; s["stood"] = -9.0
		bridges.append(s)
		_lay(s)

## 노드 기준 높이(m) — x 는 노드 원점에서 m
func surf_m(s: Dictionary, xm: float) -> float:
	return (surf(s, float(s["x0"]) + xm / C.K) - float(s["y0"])) * C.K

## 판자·밧줄·실을 지금의 처짐에 맞춰 놓고, 흔들림만큼 앞뒤로 밀고 기울인다
func _lay(s: Dictionary) -> void:
	var pitch := (float(kind.get("plank_w", 14.0)) + float(kind.get("plank_gap", 4.0))) * C.K
	var rh := float(kind.get("rope_h", 32.0)) * C.K
	var dep := float(s["d"]) * C.K * 0.9
	var planks: Array = s["planks"]; var rails: Array = s["rails"]; var threads: Array = s["threads"]
	var ti := 0
	for i in planks.size():
		var xm := (i + 0.5) * pitch
		var y := surf_m(s, xm); var slope := atan2(surf_m(s, xm + 0.05) - surf_m(s, xm - 0.05), 0.1)
		var pl: MeshInstance3D = planks[i]; pl.position = Vector3(xm, y, 0.0); pl.rotation.z = slope
		for k in 2:
			var r: MeshInstance3D = rails[i * 2 + k]; r.position = Vector3(xm, y + rh, (k - 0.5) * dep); r.rotation.z = slope
		if i % 3 == 1:
			for k in 2:
				var th: MeshInstance3D = threads[ti]; th.position = Vector3(xm, y + rh / 2.0, (k - 0.5) * dep); th.scale.y = rh; ti += 1
	var sw := swing_of(s)
	var node: Node3D = s["node"]
	node.position.z = float(s["z"]) * C.K + float(kind.get("swing", 6.0)) * C.K * sw
	node.rotation.x = float(kind.get("roll", 0.05)) * sw

func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.albedo_color = c; m.roughness = 1.0
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON; m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return m

func _box(parent: Node3D, size: Vector3, m: StandardMaterial3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = size; mi.mesh = bm; mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF   # 발판과 같은 규칙 — 그림자는 사람만
	parent.add_child(mi); return mi

## 삐걱 — 기음이 0.3초 동안 1.3배에서 제자리로 미끄러지며 잦아든다(한 번 재생, 반복 없음)
static func _creak_wav(hz: float) -> AudioStreamWAV:
	var rate := 22050; var count := int(rate * 0.3)
	var data := PackedByteArray(); data.resize(count * 2)
	var ph := 0.0
	for i in count:
		var k := float(i) / count
		ph += hz * (1.3 - 0.3 * k) * TAU / rate
		var v := (sin(ph) * 0.5 + sin(ph * 2.0) * 0.25 + sin(ph * 3.0) * 0.1) * sin(k * PI) * (1.0 - k * 0.5)
		data.encode_s16(i * 2, int(v * 20000.0))
	var w := AudioStreamWAV.new(); w.format = AudioStreamWAV.FORMAT_16_BITS; w.mix_rate = rate; w.stereo = false; w.data = data
	return w
