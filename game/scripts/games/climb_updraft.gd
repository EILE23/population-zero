class_name ClimbUpdraft
extends Node3D
## Climb 콘텐츠 팩 '상승기류'(운영자 2026-10-06 밤: "Climb는 컨텐츠 자체의 질과 양을 늘리는 거" — 팩은 data/climb/*.json 자료, 로더는 운영자 세션이 잇는다; climb.gd 는 CI 가 안 건드린다).
## 발판 위에 쇠살 바닥판 하나, 켜지면 먼지 줄기 넷이 솟고(CPUParticles3D) 살 사이가 환해지며 낮은 웅 소리가 난다. 기둥(반지름 radius px) 안의 몸은 중력이 ×gravity 가 되고
## lift px/s 로 꾸준히 떠올라 판 위 height px 까지 — 그 위로 나가면 보통대로 떨어져 꼭대기에서 떠돈다(위 발판에 내려설 수 있다). 둘이 짝으로 beat 초 박자에 번갈아 켜진다 — 뛰어드는 때를 맞춰야 한다.
## 로더가 할 일(climb.gd, 운영자 세션): `var up := ClimbUpdraft.new(); add_child(up)`; 층을 지을 때 `up.build(root, up.plan(n, plats))`; 매 틱 `vy -= G * dt` 다음에
## `vy = up.step_vy(x, y, z, vy, dt, G)` — 결과가 양수면 발판을 떠난다(on = {}); `up.lifting` 이면 `fig.pose_request = "glide"`, 착지 뒤 `GlidePoses.done(fig)` 면 비운다.
## 단위는 climb.gd 와 같은 px(36px = 1m, +y 위). 자세는 stick3d_glide.gd, 점검은 tools/probe_updraft.gd

const PACK := "res://data/climb/updraft.json"
const C = preload("res://scripts/games/climb.gd")
const LIFT_ACC := 2200.0   # 떨어지던 몸을 lift 로 끌어올리는 빠르기(px/s²) — 기둥 안 중력(×0.35 = 840)보다 넉넉히 커야 꼭대기에서 들어온 몸을 2/3 높이 안에서 받는다

var pack: Dictionary = {}
var kind: Dictionary = {}       # kinds.vent
var vents: Array = []           # 지은 통풍구 {id, x, y, z, phase, node, streaks, glow, hum}
var t := 0.0                    # 박자 시계 — 로더의 _t 와 같이 간다(sync)
var lifting := false            # 마지막 step_vy 가 켜진 기둥 안이었나 — 로더가 glide 자세를 고른다

func _ready() -> void:
	var f := FileAccess.open(PACK, FileAccess.READ)
	if f: pack = JSON.parse_string(f.get_as_text()) as Dictionary
	kind = (pack.get("kinds", {}) as Dictionary).get("vent", {})

func sync(now: float) -> void:
	t = now

func _process(delta: float) -> void:
	t += delta
	vents = vents.filter(func(v: Dictionary) -> bool: return is_instance_valid(v["node"]))   # 지운 층의 것은 뺀다(climb_signs 와 같은 식)
	for vv in vents:
		var v: Dictionary = vv
		var on := active(v)
		for p in v["streaks"]: (p as CPUParticles3D).emitting = on
		(v["glow"] as Node3D).visible = on
		var hum: AudioStreamPlayer3D = v["hum"]
		if on and not hum.playing: hum.play()
		elif not on and hum.playing: hum.stop()

## 층 n 의 발판 중 통풍구가 놓일 곳 — 조각(pieces)마다 from 층부터 every 층마다, 종류 on 에 드는 넓은(min_w) 발판을 넓은 순으로 pair 수만큼. 같은 층은 늘 같은 답(탑은 누구에게나 같다)
func plan(n: int, plats: Array) -> Array:
	var out: Array = []
	for pv in (pack.get("pieces", []) as Array):
		var piece: Dictionary = pv
		var from := int(piece.get("from", 0)); var every := maxi(1, int(piece.get("every", 1)))
		if n < from or (n - from) % every != 0: continue
		var kinds: Array = piece.get("on", ["std"]); var min_w := float(piece.get("min_w", 0.0))
		var cands := plats.filter(func(p: Dictionary) -> bool: return String(p["kind"]) in kinds and float(p["w"]) >= min_w)
		cands.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["w"]) > float(b["w"]))
		var pair: Array = piece.get("pair", [0.0])
		for i in mini(pair.size(), cands.size()):
			var p: Dictionary = cands[i]
			out.append({ "id": "%d.v%d" % [n, i], "x": float(p["x"]) + float(p["w"]) / 2.0, "y": float(p["y"]), "z": C.PLAYER_Z, "phase": float(pair[i]) })
	return out

## 통풍구를 짓는다 — root 는 그 층의 노드(층이 지워지면 같이 지워진다). 쇠살판(잉크 회색)에 포도빛 테두리 하나, 살 다섯, 켜질 때만 보이는 환한 틈, 네 귀의 먼지 줄기, 웅 소리
func build(root: Node3D, planned: Array) -> void:
	var tile := float(kind.get("tile", 48)) * C.K
	for vv in planned:
		var v: Dictionary = vv
		var node := Node3D.new(); node.position = C.to3(float(v["x"]), float(v["y"]), float(v["z"]) * C.K); root.add_child(node)
		_box(node, Vector3(tile + 0.12, 0.03, 0.96), Vector3(0, 0.015, 0), Color("ad7096"))
		_box(node, Vector3(tile, 0.08, 0.9), Vector3(0, 0.06, 0), Color("4a4a52"))
		for i in 5: _box(node, Vector3(0.05, 0.03, 0.8), Vector3((i - 2) * tile * 0.2, 0.11, 0), Color("2b2b31"))
		var glow := _box(node, Vector3(tile * 0.8, 0.02, 0.6), Vector3(0, 0.1, 0), Color("fff4d6"), true); glow.visible = false
		var streaks: Array = []
		for i in int(kind.get("streaks", 4)):
			var p := CPUParticles3D.new(); p.position = Vector3((-0.4 if i % 2 == 0 else 0.4) * tile, 0.12, -0.28 if i < 2 else 0.28)
			p.amount = 6; p.lifetime = float(kind.get("height", 216)) * C.K / 2.6; p.direction = Vector3.UP; p.spread = 4.0
			p.initial_velocity_min = 2.2; p.initial_velocity_max = 3.0; p.gravity = Vector3.ZERO; p.emitting = false
			var bm := BoxMesh.new(); bm.size = Vector3(0.04, 0.45, 0.04); p.mesh = bm; p.material_override = _mat(Color("e9e2d6"), true)
			node.add_child(p); streaks.append(p)
		var hum := AudioStreamPlayer3D.new(); hum.stream = _hum_wav(float(kind.get("hum_hz", 55))); hum.volume_db = -18.0; hum.unit_size = 6.0; hum.max_distance = 30.0; node.add_child(hum)
		vents.append({ "id": v["id"], "x": float(v["x"]), "y": float(v["y"]), "z": float(v["z"]), "phase": float(v["phase"]), "node": node, "streaks": streaks, "glow": glow, "hum": hum })

## 켜져 있나 — 박자 한 바퀴(beat)의 앞 반은 phase 0 이, 뒤 반은 phase 0.5 가
func active(v: Dictionary) -> bool:
	return fposmod(t / float(kind.get("beat", 4.0)) + float(v["phase"]), 1.0) < 0.5

func in_column(v: Dictionary, x: float, y: float, z: float) -> bool:
	var r := float(kind.get("radius", 32))
	return absf(x - float(v["x"])) < r and absf(z - float(v["z"])) < r and y >= float(v["y"]) - 4.0 and y <= float(v["y"]) + float(kind.get("height", 216))

## 로더가 `vy -= g * dt` 다음에 부른다. 켜진 기둥 안이면 중력의 (1 - gravity) 를 돌려주고, lift 보다 느리면 LIFT_ACC 로 lift 까지 끌어올린다(더 빠르면 — 기둥 안에서 뛴 몸 — 그대로 두어 더 높이 간다). 밖이면 그대로
func step_vy(x: float, y: float, z: float, vy: float, dt: float, g: float) -> float:
	lifting = false
	for vv in vents:
		var v: Dictionary = vv
		if not active(v) or not in_column(v, x, y, z): continue
		lifting = true
		var lift := float(kind.get("lift", 79.0))
		var vy2 := vy + g * (1.0 - float(kind.get("gravity", 0.35))) * dt
		return vy2 if vy2 >= lift else minf(lift, vy2 + LIFT_ACC * dt)
	return vy

func _mat(c: Color, unshaded := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.albedo_color = c; m.roughness = 1.0
	if unshaded: m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	else: m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON; m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return m

func _box(parent: Node3D, size: Vector3, at: Vector3, c: Color, unshaded := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = size; mi.mesh = bm; mi.material_override = _mat(c, unshaded); mi.position = at
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF   # 발판과 같은 규칙 — 그림자는 사람만
	parent.add_child(mi); return mi

## 송풍기 웅 소리 — 기음에 2·3배음, 정수 주기로 끊어 이음새 없이 돈다(town_cabin 의 _tone_wav 와 같은 방식, 사각파 대신 사인)
static func _hum_wav(hz: float) -> AudioStreamWAV:
	var rate := 22050; var per := int(rate / hz); var count := per * int(hz)
	var data := PackedByteArray(); data.resize(count * 2)
	for i in count:
		var ph := float(i) / per * TAU
		var v := sin(ph) * 0.5 + sin(ph * 2.0) * 0.2 + sin(ph * 3.0) * 0.1
		data.encode_s16(i * 2, int(v * 24000.0))
	var w := AudioStreamWAV.new(); w.format = AudioStreamWAV.FORMAT_16_BITS; w.mix_rate = rate; w.stereo = false; w.data = data
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD; w.loop_begin = 0; w.loop_end = count
	return w
