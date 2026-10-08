class_name ClimbIcicle
extends Node3D
## Climb 콘텐츠 팩 '떨어지는 고드름'(운영자 2026-10-06 밤: "Climb는 컨텐츠 자체의 질과 양을 늘리는 거" — 팩은 data/climb/*.json 자료, 로더는 운영자 세션이 잇는다; climb.gd 는 CI 가 안 건드린다).
## 바람 절벽(Wind cliffs)·별빛(Starlit) 테마 층에서만: 앞 발판을 향한 턱 끝 밑에 고드름 둘이 grow 초에 걸쳐 자라고, tremble 초 떨다가(경고), 탑의 중력으로 떨어져 아래 발판에서 깨진다(유리 소리, 조각 넷) — 밑에 발판이 없으면 fall_px 아래서 사라진다 — 그리고 regrow 초 뒤 다시 자란다.
## 떠는·떨어지는 고드름 밑에 선 몸은 duck(머리를 감싸는 반사 — stick3d_duck.gd); 떨어지는 고드름에 맞은 공중의 몸은 아래로 밀리며 lurch, 선 몸은 감싼 채 hurt 만 받는다. 맞으면 그 고드름은 그 자리에서 깨진다(두 번 맞지 않는다).
## 평범한 결과가 늘 남는다: 한 주기 ≈ 8 초 중 떨어지는 때는 0.3~0.5 초 — 경고를 못 봐도 뜀의 아홉에 여덟은 그냥 지나간다. 같은 층은 누구에게나 같은 자리·같은 박자(plan 은 결정적, 시계는 로더의 _t).
## 로더가 할 일(climb.gd, 운영자 세션): `var ic := ClimbIcicle.new(); add_child(ic)`; 층을 지을 때 `ic.build(root, ic.plan(n, plats))`; 매 틱 `ic.sync(_t)`;
## 착지·서기 판정 뒤 `var hit := ic.strike(x, y, z, on.is_empty()); if not hit.is_empty(): vy = minf(vy, hit["vy"]); hurt = hit["hurt"]; fig.squash = -0.4; if on.is_empty(): fig.pose_request = "lurch"` (착지 뒤 `LurchPoses.done(fig)` 면 비운다);
## 서 있고 lurch 가 아니면 `if ic.near(x, y, z): fig.pose_request = "duck"; DuckPoses.hold(fig)` / `elif fig.pose_request == "duck" and DuckPoses.done(fig): fig.pose_request = ""`.
## 단위는 climb.gd 와 같은 px(36px = 1m, +y 위, G 2400). 점검은 tools/probe_icicle.gd

const PACK := "res://data/climb/icicle.json"
const C = preload("res://scripts/games/climb.gd")

var pack: Dictionary = {}
var kind: Dictionary = {}       # kinds.icicle
var pins: Array = []            # 지은 고드름 {id, kind "icicle", x, y(턱 밑), floor, z, d, t0, node, stem, glass, was}
var shards: Array = []          # 깨진 조각 {node, v, born}
var t := 0.0                    # 로더의 _t 와 같이 간다(sync)

func _ready() -> void:
	var f := FileAccess.open(PACK, FileAccess.READ)
	if f: pack = JSON.parse_string(f.get_as_text()) as Dictionary
	kind = (pack.get("kinds", {}) as Dictionary).get("icicle", {})

func sync(now: float) -> void:
	t = now

func grow_t() -> float:
	return float(kind.get("grow", 6.0))

func tremble_t() -> float:
	return float(kind.get("tremble", 0.5))

func len_px() -> float:
	return float(kind.get("len", 34.0))

## 떨어지는 데 걸리는 초 — 끝이 아래 발판에 닿을 때까지(자유 낙하, 탑의 G)
func fall_t(s: Dictionary) -> float:
	return sqrt(2.0 * maxf(1.0, float(s["y"]) - len_px() - float(s["floor"])) / C.G)

## 한 주기(자람 → 떨림 → 낙하 → 빈 턱) 초
func cycle(s: Dictionary) -> float:
	return grow_t() + tremble_t() + fall_t(s) + float(kind.get("regrow", 1.0))

## 주기 안의 나이 0..cycle
func age(s: Dictionary) -> float:
	return fposmod(t - float(s["t0"]), cycle(s))

## "grow" | "tremble" | "fall" | "gone"
func state(s: Dictionary) -> String:
	var a := age(s)
	if a < grow_t(): return "grow"
	if a < grow_t() + tremble_t(): return "tremble"
	if a < grow_t() + tremble_t() + fall_t(s): return "fall"
	return "gone"

## 지금 길이(px) — 자라는 동안 0 → len, 그 뒤 len, 빈 턱이면 0
func length(s: Dictionary) -> float:
	match state(s):
		"grow": return len_px() * clampf(age(s) / grow_t(), 0.0, 1.0)
		"gone": return 0.0
		_: return len_px()

## 끝(아래쪽 뾰족한 데)의 높이(px) — 빈 턱이면 NAN
func tip_y(s: Dictionary) -> float:
	var st := state(s)
	if st == "gone": return NAN
	var root := float(s["y"])
	if st == "fall":
		var tau := age(s) - grow_t() - tremble_t()
		return root - len_px() - 0.5 * C.G * tau * tau
	return root - length(s)

## 층 n 의 턱들 — 테마가 맞는 층만. 앞 발판(a)을 향한 b 의 가장자리 밑에 per_hop 개, 밑에 발판이 있는 턱(깨지는 게 보인다)부터 max 개. 같은 층은 늘 같은 답
func plan(n: int, plats: Array) -> Array:
	var out: Array = []
	if not (String(C.theme(n)[0]) in (pack.get("themes", []) as Array)): return out
	var r := float(kind.get("r", 5.0)); var inset := float(kind.get("inset", 10.0)); var spacing := float(kind.get("spacing", 14.0))
	var per := maxi(1, int(kind.get("per_hop", 2))); var fall_px := float(kind.get("fall_px", 280.0))
	for pv in (pack.get("pieces", []) as Array):
		var piece: Dictionary = pv
		var from := int(piece.get("from", 0)); var every := maxi(1, int(piece.get("every", 1)))
		if n < from or (n - from) % every != 0: continue
		var kinds: Array = piece.get("on", ["std"])
		var hops := plats.filter(func(p: Dictionary) -> bool: return not (String(p["kind"]) in ["rest", "short", "ledge"]))
		var lips: Array = []
		for i in range(1, hops.size()):
			var a: Dictionary = hops[i - 1]; var b: Dictionary = hops[i]   # a 가 아래 발판(band() 는 오르는 순서로 쌓는다)
			if not (String(b["kind"]) in kinds): continue
			var right := float(b["x"]) >= float(a["x"]) + float(a["w"])   # b 가 오른쪽이면 a 를 향한 턱은 b 의 왼 끝
			var xs: Array = []
			for j in per:
				var off := inset + j * spacing
				if off + r > float(b["w"]): break
				xs.append(float(b["x"]) + off if right else float(b["x"]) + float(b["w"]) - off)
			if xs.is_empty(): continue
			var fy := _floor(plats, b, (float(xs[0]) + float(xs[xs.size() - 1])) / 2.0)
			var below := not is_nan(fy)
			if not below: fy = float(b["y"]) - fall_px
			if float(b["y"]) - len_px() - fy < 20.0: continue   # 밑이 너무 가까우면 떨어질 데가 없다
			lips.append({ "below": below, "i": i, "xs": xs, "y": float(b["y"]), "floor": fy, "z": float(b.get("z", 0.0)), "d": float(b.get("d", C.DEPTH_HALF * 2.0)) })
		lips.sort_custom(func(p: Dictionary, q: Dictionary) -> bool: return (bool(p["below"]) and not bool(q["below"])) or (bool(p["below"]) == bool(q["below"]) and int(p["i"]) < int(q["i"])))
		var stagger := float(piece.get("stagger", 0.37)); var k := 0
		for li in mini(int(piece.get("max", 2)), lips.size()):
			var lip: Dictionary = lips[li]
			for j in (lip["xs"] as Array).size():
				out.append({ "id": "%d.i%d.%d" % [n, int(lip["i"]), j], "kind": "icicle", "x": float(lip["xs"][j]), "y": float(lip["y"]), "floor": float(lip["floor"]), "z": float(lip["z"]), "d": float(lip["d"]), "phase": fposmod(k * stagger, 1.0) })
				k += 1
	return out

## x 바로 밑의 가장 높은 발판 윗면(px) — 없으면 NAN. 움직이는 발판은 안 센다(박자가 결정적이어야 한다)
static func _floor(plats: Array, b: Dictionary, x: float) -> float:
	var best := NAN
	for pv in plats:
		var p: Dictionary = pv
		if p["id"] == b["id"] or String(p["kind"]) == "move" or float(p["y"]) >= float(b["y"]): continue
		if x < float(p["x"]) or x > float(p["x"]) + float(p["w"]): continue
		if is_nan(best) or float(p["y"]) > best: best = float(p["y"])
	return best

## 떠는·떨어지는 고드름이 선 몸 위 가까이 있나 — 로더가 duck 으로 바꾼다
func near(x: float, y: float, z: float) -> bool:
	var nx := float(kind.get("near_x", 30.0)); var ny := float(kind.get("near_y", 220.0))
	for sv in pins:
		var s: Dictionary = sv
		if absf(z - float(s["z"])) >= float(s["d"]) / 2.0 + C.HZ or absf(x - float(s["x"])) >= nx: continue
		var st := state(s)
		if st != "tremble" and st != "fall": continue
		var ty := tip_y(s)
		if ty > y and ty - y < ny: return true
	return false

## 떨어지는 고드름이 이 틱에 몸(x±HW, y..y+body_h)에 닿았나 — 닿았으면 그 고드름을 깨고 {vy, hurt, pose}: 공중이면 아래로 밀려 lurch, 서 있으면 감싼 채 hurt. 아니면 빈 사전
func strike(x: float, y: float, z: float, airborne: bool) -> Dictionary:
	var bh := float(kind.get("body_h", 40.0)); var r := float(kind.get("r", 5.0))
	for sv in pins:
		var s: Dictionary = sv
		if state(s) != "fall" or absf(z - float(s["z"])) >= float(s["d"]) / 2.0 + C.HZ or absf(x - float(s["x"])) >= C.HW + r: continue
		var ty := tip_y(s)
		if ty > y + bh or ty + len_px() < y: continue
		_shatter(s, ty)
		if airborne: return { "vy": -float(kind.get("shove_vy", 320.0)), "hurt": float(kind.get("hurt_air", 0.4)), "pose": "lurch" }
		return { "vy": 0.0, "hurt": float(kind.get("hurt_ground", 0.6)), "pose": "duck" }
	return {}

## 그 자리에서 깨진다 — 시계를 낙하 끝으로 돌려 빈 턱(regrow)으로, 유리 소리, 조각 넷
func _shatter(s: Dictionary, at_y: float) -> void:
	s["t0"] = t - (grow_t() + tremble_t() + fall_t(s))
	var g: AudioStreamPlayer3D = s["glass"]
	if g.playing: g.stop()
	g.play()
	var node: Node3D = s["node"]
	if not is_instance_valid(node) or node.get_parent() == null: return
	var at := C.to3(float(s["x"]), at_y, float(s["z"]) * C.K)
	for i in 4:
		var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3(0.05, 0.05, 0.05); mi.mesh = bm; mi.material_override = _mat(Color("e4f1f8", 0.9))
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; mi.position = at; node.get_parent().add_child(mi)
		shards.append({ "node": mi, "v": Vector3((i - 1.5) * 1.1, 1.6 + 0.4 * (i % 2), 0.3), "born": t })

## 매 틱 — 길이·떨림·낙하를 그림에, 저절로 깨지는 순간엔 소리와 조각, 조각은 날아가 0.5초에 사라진다
func _process(delta: float) -> void:
	t += delta
	pins = pins.filter(func(s: Dictionary) -> bool: return is_instance_valid(s["node"]))   # 지운 층의 것은 뺀다(climb_ghost 와 같은 식)
	for sv in pins:
		var s: Dictionary = sv
		var st := state(s)
		if st == "gone" and String(s["was"]) == "fall": _shatter(s, float(s["floor"]))
		s["was"] = st
		var node: Node3D = s["node"]; var stem: Node3D = s["stem"]
		var g := clampf(length(s) / len_px(), 0.02, 1.0)
		stem.scale.y = g; stem.position.y = -len_px() * C.K * g / 2.0
		stem.visible = st != "gone"
		var jitter := 0.6 * C.K * sin(t * 40.0 * TAU) if st == "tremble" else 0.0
		var root_y := float(s["y"]) if st != "fall" else tip_y(s) + len_px()
		node.position = C.to3(float(s["x"]), root_y, float(s["z"]) * C.K) + Vector3(jitter, 0, 0)
	shards = shards.filter(func(sh: Dictionary) -> bool: return is_instance_valid(sh["node"]))
	for shv in shards:
		var sh: Dictionary = shv
		var mi: MeshInstance3D = sh["node"]
		var v: Vector3 = sh["v"]; v.y -= C.G * C.K * delta; sh["v"] = v
		mi.position += v * delta; mi.rotation.x += delta * 9.0
		if t - float(sh["born"]) > 0.5: mi.queue_free()

## 고드름을 짓는다 — root 는 그 층의 노드. 노드 원점은 턱 밑(x, y, z); stem 이 자라는 몸(아래로 뾰족한 원뿔 + 앞면의 흰 빛줄기), 유리 소리
func build(root: Node3D, planned: Array) -> void:
	var r := float(kind.get("r", 5.0)) * C.K; var ln := len_px() * C.K
	for sv in planned:
		var s: Dictionary = (sv as Dictionary).duplicate()
		var node := Node3D.new(); node.position = C.to3(float(s["x"]), float(s["y"]), float(s["z"]) * C.K); root.add_child(node)
		var stem := Node3D.new(); node.add_child(stem)
		var cone := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = r; cm.bottom_radius = 0.0; cm.height = ln; cm.radial_segments = 7
		cone.mesh = cm; cone.material_override = _mat(Color("cfe6f2", 0.85)); cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; stem.add_child(cone)
		var hi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3(0.015, ln * 0.55, 0.01); hi.mesh = bm; hi.material_override = _mat(Color("ffffff", 0.9))
		hi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; hi.position = Vector3(-r * 0.35, ln * 0.12, r * 0.6); stem.add_child(hi)   # 빛줄기 — 뿌리 쪽 앞면
		var glass := AudioStreamPlayer3D.new(); glass.stream = _glass_wav(float(kind.get("glass_hz", 1800))); glass.volume_db = -12.0; glass.unit_size = 6.0; glass.max_distance = 30.0; node.add_child(glass)
		s["t0"] = -float(s.get("phase", 0.0)) * cycle(s)
		s["node"] = node; s["stem"] = stem; s["glass"] = glass; s["was"] = state(s)
		pins.append(s)

func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.albedo_color = c; m.roughness = 0.4
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA   # 얼음은 비친다 — 호환 렌더러에서도 되는 알파
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON; m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return m

## 유리 깨지는 소리 — 0.18초, 높은 기음에 어긋난 배음과 잡음이 빠르게 잦아든다(한 번 재생, 반복 없음)
static func _glass_wav(hz: float) -> AudioStreamWAV:
	var rate := 22050; var count := int(rate * 0.18)
	var data := PackedByteArray(); data.resize(count * 2)
	var rg := RandomNumberGenerator.new(); rg.seed = 0x1ce
	for i in count:
		var k := float(i) / count
		var ph := float(i) * hz * TAU / rate
		var v := (sin(ph) * 0.35 + sin(ph * 2.41) * 0.25 + (rg.randf() - 0.5) * 0.5) * exp(-k * 9.0)
		data.encode_s16(i * 2, int(v * 20000.0))
	var w := AudioStreamWAV.new(); w.format = AudioStreamWAV.FORMAT_16_BITS; w.mix_rate = rate; w.stereo = false; w.data = data
	return w
