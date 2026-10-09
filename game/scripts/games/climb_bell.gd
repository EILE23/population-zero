class_name ClimbBell
extends Node3D
## Climb 콘텐츠 팩 '종 줄'(운영자 2026-10-06 밤: "Climb는 컨텐츠 자체의 질과 양을 늘리는 거" — 팩은 data/climb/*.json 자료, 로더는 운영자 세션이 잇는다; climb.gd 는 CI 가 안 건드린다).
## 옛 회관(Old hall) 층의 잇단 두 선 발판 사이 틈 — 절벽의 들보가 위 발판보다 rise 위에서 종머리·청동 종·종바퀴를 받치고, 바퀴에서 삼 줄이 내려와 털실 손잡이(sally)로 끝난다; 손잡이는 아래 발판에서 짧게 뛰면 손이 닿는 높이(hang + lift_in)에 쉰다.
## 공중에서 ↑ 로 손잡이를 붙잡으면(홀드와 같은 손 범위) 줄이 한 바퀴 돈다: 몸무게에 줄이 sag 만큼 내려앉고(종이 들린다) 종이 한 번 울리고(dong) 바퀴가 줄을 hoist_v 로 감아 몸을 위 발판보다 lift_out 높이까지 끌어올려(haul) hold_s 머문 뒤 drop_v 로 도로 내려 쉰다.
## 매달려서 SPACE 로 모았다 놓으면 줄의 오르는 속도를 얹어 뛰고(홀드와 같은 0.9), ↓ 나 힘이 다하면 줄의 내려가는 속도를 안고 떨어진다. 빈 줄도 한 바퀴를 마저 돈다(종이니까). 도는 중인 줄은 못 잡고, 방금 놓은 줄은 grace_s 동안 못 잡는다.
## 줄은 그 층의 다른 틈 팩이 가져가는 가장 긴 틈 하나(다리 bridge·유령 판 ghost)나 둘(버섯 mushroom)을 건너뛴 다음 틈에만 — 같은 틈을 두 팩이 쓰지 않는다(추·사다리 팩과 같은 식). 통풍구 층엔 없다. 밀지도, 떨어뜨리지도 않는다 — 느리고 확실한 길.
## 로더가 할 일(climb.gd, 운영자 세션): `var cb := ClimbBell.new(); add_child(cb)`; 층을 지을 때 `cb.build(root, cb.plan(n, plats))`; 매 틱 `cb.sync(_t)`;
## 공중에서 ↑(dirz < 0)이고 홀드를 못 잡았으면(`_try_grab` 다음): `var g := cb.grab(x, y, z); if not g.is_empty(): hauling = g; on = {}; vx = 0.0; vy = 0.0; charge = 0.0` (hauling 은 로더의 새 사전 — holding 처럼);
## 매달린 매 틱(`_hold` 와 같은 자리, 맨 앞): `var r := cb.hang_on(hauling, fig); x = r["x"]; y = r["y"]; apex = y; face = r["face"]; fig.pose_request = "haul"; stamina -= dt * 0.09`, `r["lost"]` 면 놓는다;
## SPACE 를 놓으면 `var v := cb.let_go(hauling); vy = (JUMP_MIN + (JUMP_V - JUMP_MIN) * (charge / CHARGE)) * 0.9 + maxf(0.0, v["vy"]); vx = dir * RUN * 0.9; hauling = {}; 자세 ""`; ↓ 나 힘이 다하면 `vy = minf(0.0, v["vy"]); hauling = {}`.
## 단위는 climb.gd 와 같은 px(36px = 1m, +y 위). 자세는 stick3d_haul.gd, 점검은 tools/probe_bell.gd

const PACK := "res://data/climb/bell.json"
const C = preload("res://scripts/games/climb.gd")

var pack: Dictionary = {}
var kind: Dictionary = {}       # kinds.rope
var ropes: Array = []           # 지은 줄 {id, kind "bell", x, y, w, z, d, hx, hp, rest, top, a_y, b_y, a_id, b_id, dirx, node, swing, rope, sally, dong, go, held, rider}
var t := 0.0                    # 로더의 _t 와 같이 간다(sync)

func _ready() -> void:
	var f := FileAccess.open(PACK, FileAccess.READ)
	if f: pack = JSON.parse_string(f.get_as_text()) as Dictionary
	kind = (pack.get("kinds", {}) as Dictionary).get("rope", {})

func sync(now: float) -> void:
	t = now

func hang() -> float:
	return float(kind.get("hang", 58.0))

func sag() -> float:
	return float(kind.get("sag", 14.0))

func sag_s() -> float:
	return maxf(0.05, float(kind.get("sag_s", 0.3)))

func hoist_v() -> float:
	return maxf(10.0, float(kind.get("hoist_v", 160.0)))

func hold_s() -> float:
	return maxf(0.0, float(kind.get("hold_s", 0.6)))

func drop_v() -> float:
	return maxf(10.0, float(kind.get("drop_v", 90.0)))

## 내려앉은 바닥(rest − sag)에서 꼭대기까지 감는 시간
func hoist_s(s: Dictionary) -> float:
	return (float(s["top"]) - (float(s["rest"]) - sag())) / hoist_v()

## 꼭대기에서 쉼 자리까지 도로 내리는 시간
func drop_s(s: Dictionary) -> float:
	return (float(s["top"]) - float(s["rest"])) / drop_v()

## 한 바퀴: 내려앉기 → 감기 → 머물기 → 내리기
func cycle_s(s: Dictionary) -> float:
	return sag_s() + hoist_s(s) + hold_s() + drop_s(s)

## 도는 중인가(잡은 뒤 한 바퀴가 아직 안 끝났다)
func busy(s: Dictionary, at: float) -> bool:
	var go := float(s.get("go", -9.0))
	return go > -1.0 and at >= go and at < go + cycle_s(s)

## 손잡이의 자리(px, y) — 쉬면 rest, 도는 중이면 바퀴의 단계대로. 같은 시각엔 누구에게나 같다
func grip_y(s: Dictionary, at: float) -> float:
	var rest := float(s["rest"]); var top := float(s["top"])
	if not busy(s, at): return rest
	var k := at - float(s["go"])
	var ss := sag_s(); var hs := hoist_s(s); var ds := hold_s()
	if k < ss: return rest - sag() * smoothstep(0.0, 1.0, k / ss)
	if k < ss + hs: return rest - sag() + hoist_v() * (k - ss)
	if k < ss + hs + ds: return top
	return maxf(rest, top - drop_v() * (k - ss - hs - ds))

## 손잡이의 속도 px/s (+ 위) — 내려앉을 땐 smoothstep 의 기울기, 감을 땐 hoist_v, 머물면 0, 내릴 땐 −drop_v
func grip_vy(s: Dictionary, at: float) -> float:
	if not busy(s, at): return 0.0
	var k := at - float(s["go"])
	var ss := sag_s(); var hs := hoist_s(s); var ds := hold_s()
	if k < ss:
		var u := k / ss
		return -sag() * 6.0 * u * (1.0 - u) / ss
	if k < ss + hs: return hoist_v()
	if k < ss + hs + ds: return 0.0
	return -drop_v()

## 당김 정도 — 쉬면 0, 꼭대기면 1, 내려앉은 바닥은 음수(종과 바퀴가 이만큼 돈다)
func pull(s: Dictionary, at: float) -> float:
	return (grip_y(s, at) - float(s["rest"])) / maxf(1.0, float(s["top"]) - float(s["rest"]))

## 바퀴를 돌리고 줄을 늘이고, 내려앉기가 끝나는 틱(종이 치는 순간)에 dong — 빈 줄도 한 바퀴를 마저 돈다
func _process(delta: float) -> void:
	t += delta
	ropes = ropes.filter(func(s: Dictionary) -> bool: return is_instance_valid(s["node"]))   # 지운 층의 것은 뺀다(climb_pendulum 과 같은 식)
	for sv in ropes:
		var s: Dictionary = sv
		var go := float(s.get("go", -9.0))
		if go > -1.0:
			if t - delta - go < sag_s() and t - go >= sag_s():
				var dg: AudioStreamPlayer3D = s["dong"]
				if dg.playing: dg.stop()
				dg.play()
			if t >= go + cycle_s(s): s["go"] = -9.0; s["rider"] = false
		_place(s)

## 층 n(테마 층만, 조각의 'only' 층만)의 잇단 두 선 발판 사이 틈 중 min_gap..max_gap 에 들고 위 발판이 min_dy..max_dy 높은 것들을 긴 순서로 세워 조각의 skip 개(그 층의 다른 팩 몫)를 버리고 그다음 것 하나 — 틈 한가운데에 줄. 같은 층은 늘 같은 답
func plan(n: int, plats: Array) -> Array:
	var out: Array = []
	if not (String(C.theme(n)[0]) in (pack.get("themes", []) as Array)): return out
	for pv in (pack.get("pieces", []) as Array):
		var piece: Dictionary = pv
		var only: Dictionary = piece.get("only", {})
		if not only.is_empty() and not _on(n, only): continue
		var kinds: Array = piece.get("on", ["std"])
		var min_gap := float(kind.get("min_gap", 80.0)); var max_gap := float(kind.get("max_gap", 200.0))
		var min_dy := float(kind.get("min_dy", 60.0)); var max_dy := float(kind.get("max_dy", 150.0))
		var rise := float(kind.get("rise", 150.0)); var sw := float(kind.get("sally_w", 10.0))
		var hops := plats.filter(func(p: Dictionary) -> bool: return not (String(p["kind"]) in ["rest", "short", "ledge"]))
		var spans: Array = []
		for i in range(1, hops.size()):
			var a: Dictionary = hops[i - 1]; var b: Dictionary = hops[i]   # a 가 아래 발판(band() 는 오르는 순서로 쌓는다)
			if not (String(a["kind"]) in kinds and String(b["kind"]) in kinds): continue
			var dy := float(b["y"]) - float(a["y"])
			if dy < min_dy or dy > max_dy: continue
			var ax0 := float(a["x"]); var ax1 := ax0 + float(a["w"]); var bx0 := float(b["x"]); var bx1 := bx0 + float(b["w"])
			var right := bx0 >= ax1   # 위 발판이 오른쪽에
			var gap := bx0 - ax1 if right else ax0 - bx1
			if gap < min_gap or gap > max_gap: continue
			var hx := (ax1 + bx0) / 2.0 if right else (bx1 + ax0) / 2.0
			var hp := float(b["y"]) + rise
			var half := C.HW + sw / 2.0 + 4.0
			if not _clear(plats, a, b, hx - half, hx + half, float(a["y"]) - 10.0, hp): continue
			var d := minf(float(a.get("d", C.DEPTH_HALF * 2.0)), float(b.get("d", C.DEPTH_HALF * 2.0)))
			spans.append({ "gap": gap, "hx": hx, "hp": hp, "dirx": 1.0 if right else -1.0, "d": d, "a_y": float(a["y"]), "b_y": float(b["y"]), "a_id": String(a["id"]), "b_id": String(b["id"]) })
		spans.sort_custom(func(p: Dictionary, q: Dictionary) -> bool: return float(p["gap"]) > float(q["gap"]))
		var skip := int(piece.get("skip", kind.get("skip_longest", 2)))
		for i in range(skip, mini(skip + int(piece.get("max", 1)), spans.size())):
			var g: Dictionary = spans[i]
			var rest := float(g["a_y"]) + hang() + float(kind.get("lift_in", 50.0))
			var top := float(g["b_y"]) + hang() + float(kind.get("lift_out", 30.0))
			out.append({ "id": "%d.b%d" % [n, i - skip], "kind": "bell", "x": float(g["hx"]) - sw / 2.0, "y": rest - hang(), "w": sw, "z": C.WALL_Z + float(g["d"]) / 2.0, "d": float(g["d"]),
				"hx": float(g["hx"]), "hp": float(g["hp"]), "rest": rest, "top": top, "dirx": float(g["dirx"]), "a_y": float(g["a_y"]), "b_y": float(g["b_y"]), "a_id": String(g["a_id"]), "b_id": String(g["b_id"]) })
	return out

## 층 n 이 {from, every} 에 드나
static func _on(n: int, rule: Dictionary) -> bool:
	var from := int(rule.get("from", 0))
	return n >= from and (n - from) % maxi(1, int(rule.get("every", 1))) == 0

## 줄 기둥(손잡이 폭 + 몸, 아래 발판..들보)에 두 턱 말고 다른 발판이 걸리지 않나 — 지름길 판이 줄을 가르면 둘 다 못 읽는다
static func _clear(plats: Array, a: Dictionary, b: Dictionary, x0: float, x1: float, ylo: float, yhi: float) -> bool:
	for pv in plats:
		var p: Dictionary = pv
		if p["id"] == a["id"] or p["id"] == b["id"]: continue
		var py := float(p["y"])
		if py < ylo or py > yhi: continue
		var px0 := float(p["x"]) - 10.0; var px1 := float(p["x"]) + float(p["w"]) + 10.0
		if x1 > px0 and x0 < px1: return false
	return true

## 공중에서 ↑ — 손(발 + hang)이 쉬는 손잡이의 reach_x·reach_y 안이면 잡는다: 돌려주는 사전의 x·y 가 몸의 자리(손잡이 밑 hang), 그 순간 줄이 돌기 시작한다. 도는 중인 줄·방금 놓은 줄(grace_s)은 빈 사전
func grab(x: float, y: float, z: float) -> Dictionary:
	var rx := float(kind.get("reach_x", 26.0)); var ry := float(kind.get("reach_y", 22.0))
	for sv in ropes:
		var s: Dictionary = sv
		if absf(z - float(s["z"])) >= float(s["d"]) / 2.0 + C.HZ: continue
		if busy(s, t) or t - float(s.get("held", -9.0)) < float(kind.get("grace_s", 0.4)): continue
		var gy := grip_y(s, t)
		if absf(x - float(s["hx"])) < rx and absf(y + hang() - gy) < ry:
			s["go"] = t; s["rider"] = true
			var hit := s.duplicate(); hit["x"] = float(s["hx"]); hit["y"] = gy - hang()
			return hit
	return {}

## 매달린 매 틱 — 손잡이 밑의 몸 자리 {x, y, face, lost}; fig 가 있으면 자세가 읽을 당김(haul_p 0..1 — 내려앉는 동안 1 로, 감기 시작 0.3초에 걸쳐 0 으로)과 오르내림(haul_v −1..1)을 적어 준다. 줄이 사라졌으면 lost
func hang_on(on: Dictionary, fig: Stick3D = null) -> Dictionary:
	var s := _find(String(on.get("id", "")))
	if s.is_empty(): return { "x": float(on.get("x", 0.0)), "y": float(on.get("y", 0.0)), "face": 1.0, "lost": true }
	var gy := grip_y(s, t)
	if fig:
		var p := 0.0
		if busy(s, t):
			var k := t - float(s["go"])
			p = smoothstep(0.0, 1.0, k / sag_s()) if k < sag_s() else 1.0 - smoothstep(0.0, 1.0, (k - sag_s()) / 0.3)
		fig.set_meta("haul_p", p)
		fig.set_meta("haul_v", clampf(grip_vy(s, t) / hoist_v(), -1.0, 1.0))
	return { "x": float(s["hx"]), "y": gy - hang(), "face": float(s["dirx"]), "lost": false }

## 놓는 순간 줄의 속도 {vy} px/s — 뛰면 오르는 만큼 얹고, 떨어지면 내리는 만큼 안고 간다; 줄은 빈 채 마저 돈다
func let_go(on: Dictionary) -> Dictionary:
	var s := _find(String(on.get("id", "")))
	if s.is_empty(): return { "vy": 0.0 }
	s["rider"] = false; s["held"] = t
	return { "vy": grip_vy(s, t) }

func _find(id: String) -> Dictionary:
	for sv in ropes:
		if String((sv as Dictionary)["id"]) == id: return sv
	return {}

## 줄을 짓는다 — root 는 그 층의 노드. 노드 원점은 들보 끝(hx, hp, z); 절벽에서 나온 나무 들보, 도는 종 노드(종머리·청동 종·테두리 띠·종바퀴) 안, 바퀴 밑에서 내려오는 삼 줄(길이를 매 틱 늘인다)과 털실 손잡이(종이빛에 잉크 띠), 종의 dong
func build(root: Node3D, planned: Array) -> void:
	var br := float(kind.get("bell_r", 14.0)) * C.K; var wr := float(kind.get("wheel_r", 16.0)) * C.K
	var sw := float(kind.get("sally_w", 10.0)) * C.K; var sh := float(kind.get("sally_h", 30.0)) * C.K
	for sv in planned:
		var s: Dictionary = (sv as Dictionary).duplicate()
		var node := Node3D.new(); node.position = C.to3(float(s["hx"]), float(s["hp"]), float(s["z"]) * C.K); root.add_child(node)
		var wood := _mat(Color("8a6a4a")); var bronze := _mat(Color("a8863c")); var hemp := _mat(Color("b89a6a")); var paper := _mat(Color("efe9e2")); var ink := _mat(Color("2f2a4e"))
		var beam_len := (float(s["z"]) - C.WALL_Z) * C.K + 0.3
		_box(node, Vector3(0.12, 0.12, beam_len), wood).position = Vector3(0, 0.06, -beam_len / 2.0 + 0.1)   # 절벽에서 나온 들보
		var rope_z := (C.PLAYER_Z - 6.0 - float(s["z"])) * C.K   # 줄은 몸 바로 뒤
		var swing := Node3D.new(); node.add_child(swing)   # 종머리·종·바퀴가 들보 축에서 함께 돈다
		_box(swing, Vector3(0.3, 0.1, 0.14), wood).position = Vector3(0, -0.05, 0)   # 종머리
		var bell := MeshInstance3D.new(); var bm := CylinderMesh.new(); bm.top_radius = br * 0.55; bm.bottom_radius = br; bm.height = br * 1.5; bm.radial_segments = 12; bell.mesh = bm
		bell.material_override = bronze; bell.position = Vector3(0, -0.1 - br * 0.75, 0); bell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; swing.add_child(bell)
		var lip := MeshInstance3D.new(); var lm := CylinderMesh.new(); lm.top_radius = br + 0.006; lm.bottom_radius = br + 0.006; lm.height = 0.025; lm.radial_segments = 12; lip.mesh = lm
		lip.material_override = ink; lip.position = Vector3(0, -0.1 - br * 1.4, 0); lip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; swing.add_child(lip)   # 종 입술의 잉크 띠
		var wheel := MeshInstance3D.new(); var wm := CylinderMesh.new(); wm.top_radius = wr; wm.bottom_radius = wr; wm.height = 0.03; wm.radial_segments = 14; wheel.mesh = wm
		wheel.material_override = wood; wheel.rotation.x = PI / 2.0; wheel.position = Vector3(0, 0, rope_z); wheel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; swing.add_child(wheel)   # 줄을 감는 바퀴
		var rope := Node3D.new(); rope.position = Vector3(0, -wr, rope_z); node.add_child(rope)   # 바퀴 밑에서 아래로 — y 로 늘인다
		_box(rope, Vector3(0.03, 1.0, 0.03), hemp).position = Vector3(0, -0.5, 0)
		var sally := Node3D.new(); sally.position = Vector3(0, 0, rope_z); node.add_child(sally)   # 털실 손잡이 — 원점이 잡는 자리
		_box(sally, Vector3(sw, sh, sw), paper)
		_box(sally, Vector3(sw + 0.012, sh * 0.2, sw + 0.012), ink)
		var dong := AudioStreamPlayer3D.new(); dong.stream = _dong_wav(float(kind.get("dong_hz", 220))); dong.volume_db = -6.0; dong.unit_size = 8.0; dong.max_distance = 40.0; node.add_child(dong)
		s["node"] = node; s["swing"] = swing; s["rope"] = rope; s["sally"] = sally; s["dong"] = dong; s["go"] = -9.0; s["held"] = -9.0; s["rider"] = false
		ropes.append(s)
		_place(s)

## 종·바퀴를 지금 각으로, 줄을 지금 길이로, 손잡이를 지금 자리로 — 노드 원점이 들보라 그만큼 뺀다
func _place(s: Dictionary) -> void:
	var gy := (grip_y(s, t) - float(s["hp"])) * C.K   # 손잡이의 y(노드 기준, 음수)
	var wr := float(kind.get("wheel_r", 16.0)) * C.K
	(s["swing"] as Node3D).rotation.z = float(kind.get("amax", 1.1)) * pull(s, t) * float(s["dirx"])
	(s["rope"] as Node3D).scale.y = maxf(0.05, -gy - wr)
	(s["sally"] as Node3D).position.y = gy

func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.albedo_color = c; m.roughness = 1.0
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON; m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return m

func _box(parent: Node3D, size: Vector3, m: StandardMaterial3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = size; mi.mesh = bm; mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF   # 발판과 같은 규칙 — 그림자는 사람만
	parent.add_child(mi); return mi

## 종의 dong — 0.7초, 기음에 웅(½)·3도(1.2)·명목(2) 배음이 천천히 잦아든다(추의 tock 보다 길고 울린다; 한 번 재생, 반복 없음)
static func _dong_wav(hz: float) -> AudioStreamWAV:
	var rate := 22050; var count := int(rate * 0.7)
	var data := PackedByteArray(); data.resize(count * 2)
	for i in count:
		var k := float(i) / count
		var ph := float(i) * hz * TAU / rate
		var v := (sin(ph * 0.5) * 0.35 + sin(ph) * 0.4 + sin(ph * 1.2) * 0.2 + sin(ph * 2.0) * 0.25 * exp(-k * 6.0)) * exp(-k * 4.5)
		data.encode_s16(i * 2, int(v * 16000.0))
	var w := AudioStreamWAV.new(); w.format = AudioStreamWAV.FORMAT_16_BITS; w.mix_rate = rate; w.stereo = false; w.data = data
	return w
