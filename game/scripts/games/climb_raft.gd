class_name ClimbRaft
extends Node3D
## Climb 콘텐츠 팩 '구름 뗏목'(운영자 2026-10-06 밤: "Climb는 컨텐츠 자체의 질과 양을 늘리는 거" — 팩은 data/climb/*.json 자료, 로더는 운영자 세션이 잇는다; climb.gd 는 CI 가 안 건드린다).
## 구름바다(Cloud sea) 층의 잇단 두 선 발판 사이 틈 — 두 발판 높이의 중간에 솜구름 판 하나가 떠서 틈 안을 좌우로 느리게 흘러 다닌다(drift_s 주기, 로더의 시계 — 같은 시각엔 누구에게나 같은 자리).
## 올라서면 무게에 눌려 가라앉고(sink_s 에 걸쳐 sink_max 까지, 솜처럼 처음엔 빨리 끝엔 천천히), 내려오면 도로 떠오른다(rise_s). 가라앉은 만큼 위 발판이 멀어지니 머뭇거리면 뛰기 어렵다 — 그게 이 판의 전부: 떨어뜨리지도, 밀지도, 사라지지도 않는다.
## 서 있는 동안 자세는 wade(발이 솜에 잠긴 몸 — 가라앉을수록 골반이 내려가고 팔이 올라가며, 걸으면 무릎 높이 걸음; stick3d_wade.gd). 발이 닿는 순간 솜이 눌리며 푹 소리(puff).
## 뗏목은 그 층의 다른 틈 팩이 가져가는 가장 긴 틈 하나(다리 bridge·유령 판 ghost)나 둘(버섯 mushroom)을 건너뛴 다음 틈에만 — 같은 틈을 두 팩이 쓰지 않는다(추 팩과 같은 식). 통풍구 층엔 없다.
## 로더가 할 일(climb.gd, 운영자 세션): `var cr := ClimbRaft.new(); add_child(cr)`; 층을 지을 때 `cr.build(root, cr.plan(n, plats))`; 매 틱 `cr.sync(_t)`;
## 착지 판정에서 landed 가 비었고 vy <= 0 이면 `landed = cr.land(x, y, ny, z)` (돌려준 사전의 x·w 가 지금 뗏목의 자리, y 가 지금 윗면);
## 서 있을 때 `on["kind"] == "raft"` 면 'move' 발판이 실어 가는 자리에서 `var r := cr.stand(on, x, dt, fig, dir); x = r["x"]; y = r["y"]; fig.pose_request = "wade"; if r["off"]: on = {}` (on 이 비면 자세도 비운다 — 로더 자신의 턱 밖 판정은 뗏목이 움직이니 쓰지 않는다).
## 단위는 climb.gd 와 같은 px(36px = 1m, +y 위). 점검은 tools/probe_raft.gd

const PACK := "res://data/climb/raft.json"
const C = preload("res://scripts/games/climb.gd")

var pack: Dictionary = {}
var kind: Dictionary = {}       # kinds.raft
var rafts: Array = []           # 지은 뗏목 {id, kind "raft", x, y, w, z, d, hx, amp, phase, a_y, b_y, node, puff, load, stood, was}
var t := 0.0                    # 로더의 _t 와 같이 간다(sync)

func _ready() -> void:
	var f := FileAccess.open(PACK, FileAccess.READ)
	if f: pack = JSON.parse_string(f.get_as_text()) as Dictionary
	kind = (pack.get("kinds", {}) as Dictionary).get("raft", {})

func sync(now: float) -> void:
	t = now

func drift_s() -> float:
	return maxf(1.0, float(kind.get("drift_s", 6.0)))

func sink_max() -> float:
	return float(kind.get("sink_max", 36.0))

## 뗏목 가운데의 x(px) — 틈 안을 sin 으로 오간다(위상 0 은 틈 한가운데, 1/4 주기 뒤 +x 끝)
func cx(s: Dictionary, at: float) -> float:
	return float(s["hx"]) + float(s["amp"]) * sin(TAU * at / drift_s() + float(s.get("phase", 0.0)))

## 흐르는 속도 px/s (+x 로 가면 양수)
func vx(s: Dictionary, at: float) -> float:
	return float(s["amp"]) * TAU / drift_s() * cos(TAU * at / drift_s() + float(s.get("phase", 0.0)))

## 지금 윗면 높이(px) — 뜬 높이 y 에서 가라앉은 만큼(load 0..1, 솜처럼 처음엔 빨리 끝엔 천천히) 내려앉는다
func top(s: Dictionary) -> float:
	var k := float(s.get("load", 0.0))
	return float(s["y"]) - sink_max() * k * (2.0 - k)

## 무게에 가라앉고 비면 떠오른다; 발이 닿는 틱에 푹 — 빈 뗏목도 흘러 다닌다(구름이니까)
func _process(delta: float) -> void:
	t += delta
	rafts = rafts.filter(func(s: Dictionary) -> bool: return is_instance_valid(s["node"]))   # 지운 층의 것은 뺀다(climb_pendulum 과 같은 식)
	for sv in rafts:
		var s: Dictionary = sv
		var on := t - float(s.get("stood", -9.0)) < float(kind.get("settle_s", 0.12))
		var k := float(s.get("load", 0.0))
		s["load"] = minf(1.0, k + delta / maxf(0.05, float(kind.get("sink_s", 1.5)))) if on else maxf(0.0, k - delta / maxf(0.05, float(kind.get("rise_s", 2.0))))
		if on and not bool(s["was"]):
			var pf: AudioStreamPlayer3D = s["puff"]
			if pf.playing: pf.stop()
			pf.play()
		s["was"] = on
		_float(s)

## 층 n(테마 층만, 조각의 'only' 층만)의 잇단 두 선 발판 사이 틈 중 min_gap..max_gap 에 들고 높이차가 max_dy 안인 것들을 긴 순서로 세워 조각의 skip 개(그 층의 다른 팩 몫)를 버리고 그다음 것 하나 — 틈 한가운데 높이에 뗏목. 같은 층은 늘 같은 답
func plan(n: int, plats: Array) -> Array:
	var out: Array = []
	if not (String(C.theme(n)[0]) in (pack.get("themes", []) as Array)): return out
	for pv in (pack.get("pieces", []) as Array):
		var piece: Dictionary = pv
		var only: Dictionary = piece.get("only", {})
		if not only.is_empty() and not _on(n, only): continue
		var kinds: Array = piece.get("on", ["std"])
		var min_gap := float(kind.get("min_gap", 90.0)); var max_gap := float(kind.get("max_gap", 220.0)); var max_dy := float(kind.get("max_dy", 150.0))
		var margin := float(kind.get("margin", 10.0)); var w_min := float(kind.get("w_min", 50.0)); var w_max := float(kind.get("w_max", 110.0))
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
			var w := clampf(gap * float(kind.get("w_frac", 0.45)), w_min, w_max)
			if w > gap - 2.0 * margin: continue   # 뗏목이 틈에 안 들어간다
			var amp := (gap - w) / 2.0 - margin
			if amp < float(kind.get("min_amp", 4.0)): amp = 0.0   # 너무 좁으면 제자리에 뜬다
			var y := (float(a["y"]) + float(b["y"])) / 2.0
			var ylo := y - sink_max() - float(kind.get("thick", 22.0)) - 10.0
			if not _clear(plats, a, b, hx - amp - w / 2.0, hx + amp + w / 2.0, ylo, y + 60.0): continue
			var d := minf(float(a.get("d", C.DEPTH_HALF * 2.0)), float(b.get("d", C.DEPTH_HALF * 2.0)))
			spans.append({ "gap": gap, "hx": hx, "w": w, "amp": amp, "y": y, "d": d, "a_y": float(a["y"]), "b_y": float(b["y"]) })
		spans.sort_custom(func(p: Dictionary, q: Dictionary) -> bool: return float(p["gap"]) > float(q["gap"]))
		var skip := int(piece.get("skip", kind.get("skip_longest", 2)))
		for i in range(skip, mini(skip + int(piece.get("max", 1)), spans.size())):
			var g: Dictionary = spans[i]
			out.append({ "id": "%d.c%d" % [n, i - skip], "kind": "raft", "x": float(g["hx"]) - float(g["w"]) / 2.0, "y": float(g["y"]), "w": float(g["w"]), "z": C.WALL_Z + float(g["d"]) / 2.0, "d": float(g["d"]),
				"hx": float(g["hx"]), "amp": float(g["amp"]), "a_y": float(g["a_y"]), "b_y": float(g["b_y"]), "phase": float(piece.get("phase", 0.0)) })
	return out

## 층 n 이 {from, every} 에 드나
static func _on(n: int, rule: Dictionary) -> bool:
	var from := int(rule.get("from", 0))
	return n >= from and (n - from) % maxi(1, int(rule.get("every", 1))) == 0

## 뗏목이 흘러 다닐 상자(가라앉은 솜 밑..선 몸의 머리, 흐름의 양 끝)에 두 턱 말고 다른 발판이 걸리지 않나 — 지름길 판을 뗏목이 가르며 지나면 둘 다 못 읽는다
static func _clear(plats: Array, a: Dictionary, b: Dictionary, x0: float, x1: float, ylo: float, yhi: float) -> bool:
	for pv in plats:
		var p: Dictionary = pv
		if p["id"] == a["id"] or p["id"] == b["id"]: continue
		var py := float(p["y"])
		if py < ylo or py > yhi: continue
		var px0 := float(p["x"]) - 10.0; var px1 := float(p["x"]) + float(p["w"]) + 10.0
		if x1 > px0 and x0 < px1: return false
	return true

## 로더의 착지 판정과 같은 규칙(HW·HZ) — 이 틱에 뗏목의 지금 윗면을 지나 떨어지는 몸만 받고 그 뗏목(발판 모양 사전, x·w 는 지금 자리, y 는 지금 윗면)을 돌려준다
func land(x: float, y: float, ny: float, z: float) -> Dictionary:
	for sv in rafts:
		var s: Dictionary = sv
		if absf(z - float(s["z"])) >= float(s["d"]) / 2.0 + C.HZ: continue
		var c := cx(s, t); var half := float(s["w"]) / 2.0; var sy := top(s)
		if x + C.HW > c - half and x - C.HW < c + half and y >= sy and ny <= sy:
			var hit := s.duplicate(); hit["x"] = c - half; hit["y"] = sy
			s["stood"] = t
			return hit
	return {}

## 서 있는 매 틱 — {x, y, off}: x 는 이 틱에 흘러간 만큼 실려 간 자리, y 는 지금 윗면, off 는 몸이 뗏목 밖으로 나갔나. fig 가 있으면 자세의 메타를 적는다: wade_k 가라앉은 정도 0..1, wade_w 걷기 −1..1(로더의 dir). 뗏목이 사라졌으면 off
func stand(on: Dictionary, x: float, dt: float, fig: Stick3D = null, walk := 0.0) -> Dictionary:
	var s := _find(String(on.get("id", "")))
	if s.is_empty(): return { "x": x, "y": float(on.get("y", 0.0)), "off": true }
	var c := cx(s, t); var half := float(s["w"]) / 2.0
	var nx := x + c - cx(s, t - dt)
	var off := nx + C.HW <= c - half or nx - C.HW >= c + half
	s["stood"] = t
	if fig:
		fig.set_meta("wade_k", float(s.get("load", 0.0)))
		fig.set_meta("wade_w", clampf(walk, -1.0, 1.0))
	return { "x": nx, "y": top(s), "off": off }

func _find(id: String) -> Dictionary:
	for sv in rafts:
		if String((sv as Dictionary)["id"]) == id: return sv
	return {}

## 뗏목을 짓는다 — root 는 그 층의 노드. 노드 원점은 윗면 가운데(cx, top, z); 종이빛 솜 다섯 덩이가 윗줄에(크기·높이가 조금씩 다르다 — 픽셀까지 대칭인 건 없다), 그 밑에 하늘빛 그늘 솜 셋, 푹 소리
func build(root: Node3D, planned: Array) -> void:
	var th := float(kind.get("thick", 22.0)) * C.K
	var puffs := maxi(2, int(kind.get("puffs", 5)))
	for sv in planned:
		var s: Dictionary = (sv as Dictionary).duplicate()
		var w := float(s["w"]) * C.K; var dep := float(s["d"]) * C.K * 0.7
		var node := Node3D.new(); node.position = C.to3(float(s["hx"]), float(s["y"]), float(s["z"]) * C.K); root.add_child(node)
		var paper := _mat(Color("f7f4ef")); var shade := _mat(Color("c9dde6"))
		var r := th * 0.62
		for i in puffs:
			var rr := r * (1.0 + 0.12 * float((i * 7) % 3) - 0.1)
			var px := (float(i) / (puffs - 1) - 0.5) * (w - rr)
			_ball(node, rr, rr * 1.3, paper).position = Vector3(px, -rr * 0.55 - 0.02 * float((i * 5) % 3), 0.03 * float((i * 3) % 2))
		for i in 3:
			var rr := r * (0.8 + 0.1 * float(i % 2))
			_ball(node, rr, rr * 1.1, shade).position = Vector3((float(i) - 1.0) * w * 0.3, -th + rr * 0.35, -dep * 0.08 + 0.05 * float(i % 2))
		var puff := AudioStreamPlayer3D.new(); puff.stream = _puff_wav(); puff.volume_db = -14.0; puff.unit_size = 6.0; puff.max_distance = 30.0; node.add_child(puff)
		s["node"] = node; s["puff"] = puff; s["load"] = 0.0; s["stood"] = -9.0; s["was"] = false
		rafts.append(s)
		_float(s)

## 노드를 지금 자리로 — 흐른 x, 가라앉은 윗면; 눌린 만큼 납작해지고 옆으로 퍼진다(윗면은 원점이라 그대로)
func _float(s: Dictionary) -> void:
	var k := float(s.get("load", 0.0))
	var node: Node3D = s["node"]
	node.position = C.to3(cx(s, t), top(s), float(s["z"]) * C.K)
	node.scale = Vector3(1.0 + 0.12 * k, 1.0 - 0.22 * k, 1.0)

func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.albedo_color = c; m.roughness = 1.0
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON; m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return m

## 납작한 구 — 솜 한 덩이(가로 지름 2r, 높이 h)
func _ball(parent: Node3D, r: float, h: float, m: StandardMaterial3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); var sm := SphereMesh.new(); sm.radius = r; sm.height = h; sm.radial_segments = 10; sm.rings = 6; mi.mesh = sm; mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF   # 발판과 같은 규칙 — 그림자는 사람만
	parent.add_child(mi); return mi

## 푹 — 0.18초, 저역만 남긴 잡음이 빠르게 잦아든다(솜이 눌리는 소리; 한 번 재생, 반복 없음). 씨앗을 박아 늘 같은 소리
static func _puff_wav() -> AudioStreamWAV:
	var rate := 22050; var count := int(rate * 0.18)
	var data := PackedByteArray(); data.resize(count * 2)
	var rng := RandomNumberGenerator.new(); rng.seed = 7
	var lp := 0.0
	for i in count:
		var k := float(i) / count
		lp += (rng.randf() * 2.0 - 1.0 - lp) * 0.18   # 한 극 저역 — 쉭 소리가 아니라 푹 소리
		data.encode_s16(i * 2, clampi(int(lp * exp(-k * 5.0) * 26000.0), -32000, 32000))
	var w := AudioStreamWAV.new(); w.format = AudioStreamWAV.FORMAT_16_BITS; w.mix_rate = rate; w.stereo = false; w.data = data
	return w
