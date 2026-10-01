class_name Water3D
extends Node3D
## 물 — 하나의 애셋(운영자 2026-09-28: "'물' 자체도 애셋으로 있어야"). 강 띠(band)와 연못 원(disc)을 만들면 수면 셰이더·돌 가장자리·
## 물결 조각·물 판정(contains)이 따라온다. 입수 물보라(splash)·헤엄 자국(wake)·나올 때 물 뚝뚝(drip)도 여기. 사람·주민·물건이 같은 함수를 쓴다.
## 새 물(웅덩이·호수)은 band/disc 하나 더 부르면 된다 — 마을 코드에 상자를 직접 놓지 않는다.

const SHADER := preload("res://shaders/water.gdshader")
const SURFACE_Y := 0.04   # 수면 높이(m) — 바닥(0)보다 살짝 위

var bodies: Array = []     # {kind: "band"|"disc", c: Vector3, hx, hz (band) | r (disc), flow: float}
var _flecks: Array = []    # {node, body}
var _wake_t: Dictionary = {}

## 수면 재질 — 모든 물이 같은 것을 쓴다
static func surface() -> ShaderMaterial:
	var m := ShaderMaterial.new(); m.shader = SHADER
	return m

static func _flat(c: Color, a := 1.0, unshaded := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.albedo_color = Color(c.r, c.g, c.b, a)
	if a < 1.0: m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if unshaded: m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	else: m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON; m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED; m.roughness = 1.0
	return m

func _mesh(mesh: Mesh, mat: Material, at: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); mi.mesh = mesh; mi.material_override = mat; mi.position = at; add_child(mi); return mi

## 강 띠 — 중심 c, 길이 length(x), 폭 width(z), +x 로 flow m/s 흐른다. 양쪽에 돌 둑, 흐르는 물결 조각
func band(c: Vector3, length: float, width: float, flow := 0.35, flecks := true) -> void:
	var bm := BoxMesh.new(); bm.size = Vector3(length, SURFACE_Y, width); bm.subdivide_width = int(length / (1.0 if flecks else 4.0))   # 정점이 있어야 셰이더가 수면을 찰랑이게 한다
	_mesh(bm, surface(), Vector3(c.x, SURFACE_Y / 2.0, c.z))
	for zs in [-1.0, 1.0]:
		var k := BoxMesh.new(); k.size = Vector3(length, 0.07, 0.3)
		_mesh(k, _flat(Color("bfb6b0")), Vector3(c.x, 0.035, c.z + zs * (width / 2.0 + 0.1)))
	var body := { "kind": "band", "c": c, "hx": length / 2.0, "hz": width / 2.0, "flow": flow }
	bodies.append(body)
	if not flecks: return
	var rr := RandomNumberGenerator.new(); rr.seed = int(c.x * 3.0 + c.z * 7.0) + 11
	for i in int(length / 2.5):
		_fleck(body, Vector3(c.x + rr.randf_range(-length / 2.0, length / 2.0), SURFACE_Y + 0.005, c.z + rr.randf_range(-width * 0.37, width * 0.37)), rr.randf_range(0.3, 0.7))

## 연못 원 — 중심 c, 반지름 r. 돌 테두리, 제자리에서 흔들리는 물결 조각 몇 개
func disc(c: Vector3, r: float) -> void:
	var cm := CylinderMesh.new(); cm.top_radius = r; cm.bottom_radius = r; cm.height = SURFACE_Y; cm.radial_segments = 48
	_mesh(cm, surface(), Vector3(c.x, SURFACE_Y / 2.0, c.z))
	var rm := CylinderMesh.new(); rm.top_radius = r + 0.3; rm.bottom_radius = r + 0.3; rm.height = 0.03; rm.radial_segments = 48
	_mesh(rm, _flat(Color("bfb6b0")), Vector3(c.x, 0.015, c.z))
	var body := { "kind": "disc", "c": c, "r": r, "flow": 0.0 }
	bodies.append(body)
	for i in 6:
		var a := i * TAU / 6.0 + 0.4
		_fleck(body, c + Vector3(cos(a) * r * 0.55, SURFACE_Y + 0.005, sin(a) * r * 0.55), 0.35)

func _fleck(body: Dictionary, at: Vector3, len: float) -> void:
	var b := BoxMesh.new(); b.size = Vector3(len, 0.01, 0.05)
	_flecks.append({ "node": _mesh(b, _flat(Color("c9dde6")), at), "body": body, "z0": at.z })

## 이 점이 물 안인가 — 띠·원 모두. 다리 같은 예외는 부르는 쪽(town_base.in_water)이 뺀다
func contains(p: Vector3, margin := 0.08) -> bool:
	if p.y > 0.3: return false
	for b in bodies:
		if b["kind"] == "band":
			if absf(p.x - b["c"].x) < b["hx"] and absf(p.z - b["c"].z) < b["hz"] - margin: return true
		elif Vector2(p.x - b["c"].x, p.z - b["c"].z).length() < b["r"] - margin: return true
	return false

## 원 모양 물을 지나는 직선 구간이면 옆으로 돌아가는 경유지 하나 — 주민은 옷 입고 연못을 가로지르지 않는다
func detour(from: Vector3, to: Vector3) -> Array:
	for b in bodies:
		if b["kind"] != "disc": continue
		var c: Vector3 = b["c"]; var r: float = b["r"] + 0.6
		var ab := Vector2(to.x - from.x, to.z - from.z); var ac := Vector2(c.x - from.x, c.z - from.z)
		if ab.length_squared() < 0.01: continue
		var t := clampf(ac.dot(ab) / ab.length_squared(), 0.0, 1.0)
		var q := Vector2(from.x, from.z) + ab * t
		var away := q - Vector2(c.x, c.z)
		if away.length() < r and t > 0.02 and t < 0.98:
			if away.length() < 0.01: away = Vector2(-ab.y, ab.x)
			var w := Vector2(c.x, c.z) + away.normalized() * (r + 0.4)
			return [{ "pos": Vector3(w.x, 0, w.y), "act": "" }]
	return []

func _process(delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	for f in _flecks:
		var n: Node3D = f["node"]; var b: Dictionary = f["body"]
		if b["flow"] > 0.0:
			n.position.x += b["flow"] * delta
			if n.position.x > b["c"].x + b["hx"] + 2.0: n.position.x = b["c"].x - b["hx"] - 2.0
		n.position.z = f["z0"] + sin(t * 1.3 + n.position.x) * 0.06

# ── 물보라·자국·물방울 ──
func _drops(at: Vector3, amount: int, up: float, spread: float) -> void:
	var p := CPUParticles3D.new()
	p.amount = amount; p.lifetime = 0.7; p.one_shot = true; p.explosiveness = 0.95
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE; p.emission_sphere_radius = spread
	p.direction = Vector3.UP; p.spread = 55.0; p.initial_velocity_min = up * 0.5; p.initial_velocity_max = up; p.gravity = Vector3(0, -9.0, 0)
	var sm := SphereMesh.new(); sm.radius = 0.025; sm.height = 0.05; sm.radial_segments = 6; sm.rings = 3; p.mesh = sm
	p.material_override = _flat(Color(0.75, 0.86, 0.92), 0.9, true); p.position = at
	add_child(p); p.emitting = true
	get_tree().create_timer(1.2).timeout.connect(p.queue_free)

## 수면에 퍼지는 고리 — 커지며 옅어져 사라진다
func _ring(at: Vector3, r0: float, r1: float, secs: float, a0: float) -> void:
	var mi := MeshInstance3D.new()
	var t := TorusMesh.new(); t.inner_radius = r0 * 0.82; t.outer_radius = r0; t.rings = 24; t.ring_segments = 6
	mi.mesh = t; mi.scale = Vector3(1, 0.15, 1)
	var m := _flat(Color(0.8, 0.9, 0.95), a0, true); mi.material_override = m
	mi.position = Vector3(at.x, SURFACE_Y + 0.01, at.z); add_child(mi)
	var tw := create_tween(); tw.set_parallel(true); tw.set_ease(Tween.EASE_OUT); tw.set_trans(Tween.TRANS_QUAD)
	tw.tween_property(mi, "scale", Vector3(r1 / r0, 0.15, r1 / r0), secs)
	tw.tween_property(m, "albedo_color:a", 0.0, secs)
	tw.chain().tween_callback(mi.queue_free)

## 입수 — 큰 물보라와 고리 둘
func splash(at: Vector3, big := true) -> void:
	_drops(Vector3(at.x, SURFACE_Y, at.z), 36 if big else 14, 3.2 if big else 1.8, 0.25)
	_ring(at, 0.25, 1.4 if big else 0.9, 0.9, 0.7)
	_ring(at, 0.15, 0.7, 0.5, 0.5)

## 헤엄 자국 — 매 프레임 부른다. 움직이면 0.3초마다 고리를 남기고 팔에서 물방울, 서 있으면 느리게 고리만
func wake(who: Node3D, moving: bool, delta: float) -> void:
	var left: float = _wake_t.get(who, 0.0) - delta
	if left <= 0.0:
		var p := who.global_position
		_ring(p, 0.2, 0.9 if moving else 0.6, 0.9, 0.45 if moving else 0.3)
		if moving: _drops(Vector3(p.x, SURFACE_Y + 0.04, p.z) + Vector3(sin(who.rotation.y), 0, cos(who.rotation.y)) * 0.3, 6, 1.4, 0.2)
		left = 0.3 if moving else 1.1
	_wake_t[who] = left

## 나올 때 — 몸에서 1.5초 동안 물이 뚝뚝(몸을 따라간다)
func drip(body: Node3D) -> void:
	_wake_t.erase(body)
	var p := CPUParticles3D.new()
	p.amount = 18; p.lifetime = 0.6; p.one_shot = true; p.explosiveness = 0.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX; p.emission_box_extents = Vector3(0.12, 0.35, 0.12)
	p.direction = Vector3.DOWN; p.spread = 10.0; p.initial_velocity_min = 0.1; p.initial_velocity_max = 0.4; p.gravity = Vector3(0, -6.0, 0)
	var sm := SphereMesh.new(); sm.radius = 0.02; sm.height = 0.04; sm.radial_segments = 6; sm.rings = 3; p.mesh = sm
	p.material_override = _flat(Color(0.75, 0.86, 0.92), 0.9, true); p.position = Vector3(0, 0.6, 0)
	body.add_child(p); p.emitting = true
	get_tree().create_timer(2.2).timeout.connect(p.queue_free)
