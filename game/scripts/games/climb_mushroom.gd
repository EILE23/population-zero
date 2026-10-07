class_name ClimbMushroom
extends Node3D
## Climb 콘텐츠 팩 '통통 버섯'(운영자 2026-10-06 밤: "Climb는 컨텐츠 자체의 질과 양을 늘리는 거" — 팩은 data/climb/*.json 자료, 로더는 운영자 세션이 잇는다; climb.gd 는 CI 가 안 건드린다).
## 발판 사이 틈의 절벽에서 자란 버섯 — 굵은 줄기 위에 포도빛 갓(크림색 점 셋, 밑엔 주름). 떨어지던 몸이 갓 윗면을 지나면 launch px/s 로 던져 올려진다(다음 발판보다 높이) —
## 갓은 납작하게 눌렸다 튀어 오르고(squash 초) '보잉' 소리가 난다. 갓은 아래 발판보다 sink px 낮게 자라서, 짧은 점프나 가장자리에서 헛디딘 몸이 떨어지는 길에 걸린다: 추락을 받아 주는 동시에 더 높이 가는 지름길.
## 로더가 할 일(climb.gd, 운영자 세션): `var mu := ClimbMushroom.new(); add_child(mu)`; 층을 지을 때 `mu.build(root, mu.plan(n, plats))`; 매 틱 `vy -= G * dt` 다음, 착지 판정 전에
## `vy = mu.step_vy(x, y, z, vy, dt)` — `mu.bounced` 가 참이면 발판을 떠나고(on = {}, apex = y) `fig.pose_request = "bounce"`; 착지 뒤 `BouncePoses.done(fig)` 면 비운다.
## 단위는 climb.gd 와 같은 px(36px = 1m, +y 위). 자세는 stick3d_bounce.gd, 점검은 tools/probe_mushroom.gd

const PACK := "res://data/climb/mushroom.json"
const C = preload("res://scripts/games/climb.gd")

var pack: Dictionary = {}
var kind: Dictionary = {}       # kinds.cap
var caps: Array = []            # 지은 버섯 {id, x, y, z, node, cap, boing}
var bounced := false            # 마지막 step_vy 가 갓을 밟았나 — 로더가 bounce 자세를 고른다

func _ready() -> void:
	var f := FileAccess.open(PACK, FileAccess.READ)
	if f: pack = JSON.parse_string(f.get_as_text()) as Dictionary
	kind = (pack.get("kinds", {}) as Dictionary).get("cap", {})

func _process(_delta: float) -> void:
	caps = caps.filter(func(c: Dictionary) -> bool: return is_instance_valid(c["node"]))   # 지운 층의 것은 뺀다(climb_updraft 와 같은 식)

## 층 n 의 발판 사이 틈 중 버섯이 자랄 곳 — 조각(pieces)마다 from 층부터 every 층마다, 종류 on 에 드는 잇단 두 발판의 틈(모서리끼리 min_gap 이상)을 넓은 순으로 max 개. 같은 층은 늘 같은 답(탑은 누구에게나 같다)
func plan(n: int, plats: Array) -> Array:
	var out: Array = []
	for pv in (pack.get("pieces", []) as Array):
		var piece: Dictionary = pv
		var from := int(piece.get("from", 0)); var every := maxi(1, int(piece.get("every", 1)))
		if n < from or (n - from) % every != 0: continue
		var kinds: Array = piece.get("on", ["std"]); var min_gap := float(piece.get("min_gap", 70.0))
		var hops := plats.filter(func(p: Dictionary) -> bool: return String(p["kind"]) in kinds)
		var gaps: Array = []
		for i in range(1, hops.size()):
			var a: Dictionary = hops[i - 1]; var b: Dictionary = hops[i]   # a 가 아래 발판(band() 는 오르는 순서로 쌓는다)
			var ax0 := float(a["x"]); var ax1 := ax0 + float(a["w"]); var bx0 := float(b["x"]); var bx1 := bx0 + float(b["w"])
			var gap := bx0 - ax1 if bx0 >= ax1 else ax0 - bx1
			if gap < min_gap: continue
			var mid := (ax1 + bx0) / 2.0 if bx0 >= ax1 else (bx1 + ax0) / 2.0
			gaps.append({ "gap": gap, "x": mid, "y": minf(float(a["y"]), float(b["y"])) - float(kind.get("sink", 60.0)) })
		gaps.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["gap"]) > float(b["gap"]))
		for i in mini(int(piece.get("max", 2)), gaps.size()):
			var g: Dictionary = gaps[i]
			out.append({ "id": "%d.m%d" % [n, i], "x": float(g["x"]), "y": float(g["y"]), "z": C.PLAYER_Z })
	return out

## 버섯을 짓는다 — root 는 그 층의 노드(층이 지워지면 같이 지워진다). 종이빛 줄기, 포도빛 갓(납작한 구), 크림색 점, 짙은 주름 테, 보잉 소리
func build(root: Node3D, planned: Array) -> void:
	var r := float(kind.get("radius", 30)) * C.K; var h := float(kind.get("height", 40)) * C.K
	for cv in planned:
		var c: Dictionary = cv
		var node := Node3D.new(); node.position = C.to3(float(c["x"]), float(c["y"]), float(c["z"]) * C.K); root.add_child(node)
		_mesh(node, _cyl(r * 0.36, h * 0.7), Vector3(0, h * 0.35, 0), Color("e9e2d6"))
		var cap := Node3D.new(); cap.position = Vector3(0, h * 0.62, 0); node.add_child(cap)   # 갓은 제 밑동에서 눌린다 — 줄기는 그대로
		var dome := _mesh(cap, _ball(r), Vector3(0, h * 0.2, 0), Color("ad7096")); dome.scale = Vector3(1.0, (h * 0.38) / r, 0.9)
		_mesh(cap, _cyl(r * 0.92, 0.03), Vector3(0, 0.0, 0), Color("7b526c"))
		for i in int(kind.get("spots", 3)):
			var ang := i * 2.1 + 0.4; var rr := r * (0.35 + 0.2 * (i % 2))
			var spot := _mesh(cap, _ball(r * 0.17), Vector3(cos(ang) * rr, h * 0.2 + (h * 0.38) * sqrt(maxf(0.0, 1.0 - (rr / r) * (rr / r))) - 0.01, sin(ang) * rr * 0.9), Color("f4ecdf"), true)
			spot.scale = Vector3(1.0, 0.45, 1.0)
		var boing := AudioStreamPlayer3D.new(); boing.stream = _boing_wav(float(kind.get("boing_hz", 220))); boing.volume_db = -8.0; boing.unit_size = 6.0; boing.max_distance = 30.0; node.add_child(boing)
		caps.append({ "id": c["id"], "x": float(c["x"]), "y": float(c["y"]), "z": float(c["z"]), "node": node, "cap": cap, "boing": boing })

func top(c: Dictionary) -> float:
	return float(c["y"]) + float(kind.get("height", 40.0))

func over(c: Dictionary, x: float, z: float) -> bool:
	return absf(x - float(c["x"])) < float(kind.get("radius", 30.0)) and absf(z - float(c["z"])) < float(kind.get("depth", 40.0))

## 로더가 `vy -= g * dt` 다음, 착지 판정 전에 부른다. 갓 위에서 떨어지는 몸이 이 틱에 윗면을 지나면(또는 한 틱 안에 지나쳤으면) launch 로 던진다 — 갓이 눌리고 소리가 난다. 아니면 그대로
func step_vy(x: float, y: float, z: float, vy: float, dt: float) -> float:
	bounced = false
	if vy >= 0.0: return vy
	for cv in caps:
		var c: Dictionary = cv
		if not over(c, x, z): continue
		var tp := top(c)
		if y < tp - 16.0 or y + vy * dt > tp: continue
		bounced = true; _squash(c)
		return float(kind.get("launch", 1100.0))
	return vy

## 갓이 납작해졌다 튀어 오른다 — squash 초 안에 0.45 → 1.15 → 1.0
func _squash(c: Dictionary) -> void:
	var cap: Node3D = c["cap"]; var s := float(kind.get("squash", 0.35))
	var tw := cap.create_tween()
	tw.tween_property(cap, "scale", Vector3(1.25, 0.45, 1.25), s * 0.22)
	tw.tween_property(cap, "scale", Vector3(0.92, 1.15, 0.92), s * 0.4)
	tw.tween_property(cap, "scale", Vector3.ONE, s * 0.38)
	var b: AudioStreamPlayer3D = c["boing"]
	if b.playing: b.stop()
	b.play()

func _mat(c: Color, unshaded := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.albedo_color = c; m.roughness = 1.0
	if unshaded: m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	else: m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON; m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return m

func _mesh(parent: Node3D, mesh: Mesh, at: Vector3, c: Color, unshaded := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); mi.mesh = mesh; mi.material_override = _mat(c, unshaded); mi.position = at
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF   # 발판과 같은 규칙 — 그림자는 사람만
	parent.add_child(mi); return mi

static func _cyl(r: float, h: float) -> CylinderMesh:
	var m := CylinderMesh.new(); m.top_radius = r * 0.85; m.bottom_radius = r; m.height = h; m.radial_segments = 10; m.rings = 1; return m

static func _ball(r: float) -> SphereMesh:
	var m := SphereMesh.new(); m.radius = r; m.height = r * 2.0; m.radial_segments = 14; m.rings = 7; return m

## 보잉 — 기음이 0.18초 동안 1.5배까지 미끄러져 오르며 잦아든다(한 번 재생, 반복 없음)
static func _boing_wav(hz: float) -> AudioStreamWAV:
	var rate := 22050; var count := int(rate * 0.18)
	var data := PackedByteArray(); data.resize(count * 2)
	var ph := 0.0
	for i in count:
		var k := float(i) / count
		ph += hz * (1.0 + 0.5 * k) * TAU / rate
		var v := (sin(ph) * 0.6 + sin(ph * 2.0) * 0.15) * (1.0 - k) * (1.0 - k)
		data.encode_s16(i * 2, int(v * 24000.0))
	var w := AudioStreamWAV.new(); w.format = AudioStreamWAV.FORMAT_16_BITS; w.mix_rate = rate; w.stereo = false; w.data = data
	return w
