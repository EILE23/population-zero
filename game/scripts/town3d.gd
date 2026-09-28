extends Node3D
## 3D 마을 시제품 — 오메가루비 식 3/4 시점(운영자 2026-09-28: "최소한 오메가루비 같은 퀄리티"). 전부 코드로 만든 기하:
## 상자 건물(벽면·지붕은 SVG 텍스처), 기둥+구 나무, 타일 바닥과 자갈길, 벤치·가로등·울타리는 원시 도형, 방향광 하나와 그림자,
## 그리고 입체 졸라맨(Stick3D). 조명은 툰 확산(면이 두 톤으로 갈라진다), 반사광 없음 — 팔레트가 그대로 보이게.

const TILE := 2.0  # 바닥 타일 한 장 = 2m

var player: Stick3D
var cam: Camera3D
var vel := Vector3.ZERO
var y := 0.0
var vy := 0.0
var charging := -1.0
var last_tap := ""
var last_tap_at := -1.0
var dash_until := -1.0
var action_until := 0.0

const WALK := 2.6
const G := 24.0
const JUMP_V := 8.6
const JUMP_MIN := 4.3
const CHARGE := 0.7

func _ready() -> void:
	_light()
	_ground()
	_path(Vector3(-14, 0, 2), Vector3(14, 0, 2), 2.4)
	_path(Vector3(0, 0, 2), Vector3(0, 0, -10), 2.0)
	_house(Vector3(-7, 0, -4), Vector3(4.0, 2.6, 3.2), "sky", "accent-deep")
	_house(Vector3(0.5, 0, -6), Vector3(3.2, 3.2, 3.0), "paper", "brick")
	_house(Vector3(7, 0, -4), Vector3(5.0, 2.4, 3.6), "sand", "iron")
	_house(Vector3(-12, 0, -8), Vector3(3.6, 2.8, 3.0), "brick", "wood")
	for p in [Vector3(-11, 0, -1), Vector3(-3.5, 0, -1.5), Vector3(4, 0, -1), Vector3(11, 0, -1.5), Vector3(-9, 0, 5), Vector3(9, 0, 5.5), Vector3(13, 0, -7)]:
		_tree(p, 1.0 + fmod(absf(p.x) * 0.37, 0.5))
	_bench(Vector3(-4, 0, 4.2), 0.0)
	_bench(Vector3(4, 0, 4.2), 0.0)
	_lamp(Vector3(-1.6, 0, 3.6)); _lamp(Vector3(1.6, 0, 3.6)); _lamp(Vector3(-8, 0, 0.6)); _lamp(Vector3(8, 0, 0.6))
	_fence(Vector3(-13, 0, 7), 6.0); _fence(Vector3(9, 0, 7.5), 5.0)
	player = Stick3D.new()
	player.position = Vector3(0, 0, 4)
	add_child(player)
	cam = $Camera3D

# ── 세계 ──
func _mat(color: Color, tex: Texture2D = null, uv := Vector3.ONE) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	if tex:
		m.albedo_texture = tex
		m.uv1_scale = uv
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	m.roughness = 1.0
	return m

func _tex(id: String) -> Texture2D:
	var p := "res://assets/svg/%s.svg" % id
	return load(p) if ResourceLoader.exists(p) else null

func _light() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, 28, 0)
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 60.0
	sun.shadow_blur = 1.6
	add_child(sun)

func _box(size: Vector3, at: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new(); bm.size = size
	mi.mesh = bm; mi.material_override = mat
	mi.position = at + Vector3(0, size.y / 2.0, 0)
	add_child(mi)
	return mi

func _ground() -> void:
	var g := MeshInstance3D.new()
	var pm := PlaneMesh.new(); pm.size = Vector2(40, 32)
	g.mesh = pm
	g.material_override = _mat(Color.WHITE, _tex("ground/grass"), Vector3(40.0 / TILE, 32.0 / TILE, 1))
	g.position = Vector3(0, 0, -3)
	add_child(g)

## 자갈길 — 바닥보다 2cm 높은 납작한 상자(가장자리가 선으로 읽혀 길이 된다)
func _path(a: Vector3, b: Vector3, w: float) -> void:
	var d := b - a
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	var along := d.length()
	bm.size = Vector3(along, 0.04, w)
	mi.mesh = bm
	mi.material_override = _mat(Color.WHITE, _tex("ground/cobble"), Vector3(along / 1.6, w / 1.6, 1))
	mi.position = (a + b) / 2.0 + Vector3(0, 0.02, 0)
	mi.rotation.y = -atan2(d.z, d.x)
	add_child(mi)

## 상자집 — 네 벽은 각각 텍스처 면(정면은 문·창 둘, 옆은 창 하나), 지붕은 삼각기둥 + 기와 텍스처, 굴뚝 하나
func _house(at: Vector3, size: Vector3, wall: String, roof: String) -> void:
	var front := _tex("faces/wall-front-%s" % wall)
	var side := _tex("faces/wall-side-%s" % wall)
	var body := _box(size, at, _mat(Color.WHITE, side, Vector3(size.x / 3.0, size.y / 2.8, 1)))
	body.material_override.uv1_triplanar = true  # 옆·뒷면에 옆벽 무늬
	# 정면만 따로 — 얇은 판을 앞에 1cm 띄워 붙인다
	var f := MeshInstance3D.new()
	var q := QuadMesh.new(); q.size = Vector2(size.x, size.y)
	f.mesh = q; f.material_override = _mat(Color.WHITE, front)
	f.position = at + Vector3(0, size.y / 2.0, size.z / 2.0 + 0.01)
	add_child(f)
	# 지붕: PrismMesh 는 XY 삼각형을 Z 로 뽑는다 → 용마루가 x 방향이 되게 y 로 90° 돌린다
	var r := MeshInstance3D.new()
	var pr := PrismMesh.new(); pr.size = Vector3(size.z + 0.5, size.y * 0.45, size.x + 0.5)
	r.mesh = pr; r.material_override = _mat(Color.WHITE, _tex("faces/roof-%s" % roof), Vector3(2.0, 1.5, 1))
	r.material_override.uv1_triplanar = true
	r.position = at + Vector3(0, size.y + pr.size.y / 2.0, 0)
	r.rotation.y = PI / 2.0
	add_child(r)
	_box(Vector3(0.36, 0.7, 0.36), at + Vector3(size.x * 0.28, size.y + pr.size.y * 0.55, -0.3), _mat(Color("b56a5a")))
	# 문 앞 계단 — 접지가 자연스러워진다
	_box(Vector3(1.1, 0.12, 0.5), at + Vector3(0, 0, size.z / 2.0 + 0.25), _mat(Color("cfc7c2")))

## 나무 — 기둥 + 구 셋(잎 두 톤). 크기 k 로 서로 다르게
func _tree(at: Vector3, k: float) -> void:
	var trunk := MeshInstance3D.new()
	var cm := CylinderMesh.new(); cm.top_radius = 0.09 * k; cm.bottom_radius = 0.14 * k; cm.height = 1.0 * k
	trunk.mesh = cm; trunk.material_override = _mat(Color("8a6a4a"))
	trunk.position = at + Vector3(0, 0.5 * k, 0)
	add_child(trunk)
	for i in 3:
		var s := MeshInstance3D.new()
		var sm := SphereMesh.new(); var rr := (0.75 - i * 0.12) * k
		sm.radius = rr; sm.height = rr * 2.0; sm.radial_segments = 14; sm.rings = 8
		s.mesh = sm; s.material_override = _mat(Color("7a9b4e") if i % 2 == 0 else Color("5f8a3e"))
		s.position = at + Vector3((i - 1) * 0.28 * k, (1.25 + i * 0.32) * k, (i - 1) * 0.12 * k)
		add_child(s)

func _bench(at: Vector3, yaw: float) -> void:
	var wood := _mat(Color("8a6a4a")); var iron := _mat(Color("4a4a52"))
	var seat := _box(Vector3(1.5, 0.06, 0.45), at + Vector3(0, 0.42, 0), wood)
	var back := _box(Vector3(1.5, 0.06, 0.4), at + Vector3(0, 0.62, -0.2), wood)
	back.rotation.x = -1.35
	for sx in [-0.6, 0.6]:
		_box(Vector3(0.06, 0.42, 0.06), at + Vector3(sx, 0, 0.15), iron)
		_box(Vector3(0.06, 0.42, 0.06), at + Vector3(sx, 0, -0.15), iron)
	seat.rotation.y = yaw

func _lamp(at: Vector3) -> void:
	var post := MeshInstance3D.new()
	var cm := CylinderMesh.new(); cm.top_radius = 0.035; cm.bottom_radius = 0.05; cm.height = 2.2
	post.mesh = cm; post.material_override = _mat(Color("4a4a52"))
	post.position = at + Vector3(0, 1.1, 0)
	add_child(post)
	_box(Vector3(0.26, 0.3, 0.26), at + Vector3(0, 2.2, 0), _mat(Color("e8c766")))
	var l := OmniLight3D.new(); l.light_color = Color("e8c766"); l.light_energy = 0.6; l.omni_range = 4.0
	l.position = at + Vector3(0, 2.3, 0)
	add_child(l)

func _fence(at: Vector3, len: float) -> void:
	var paper := _mat(Color("efe9e2"))
	var n := int(len / 0.5)
	for i in n + 1:
		_box(Vector3(0.08, 0.7, 0.05), at + Vector3(i * 0.5, 0, 0), paper)
	_box(Vector3(len + 0.08, 0.06, 0.04), at + Vector3(len / 2.0, 0.25, 0), paper)
	_box(Vector3(len + 0.08, 0.06, 0.04), at + Vector3(len / 2.0, 0.5, 0), paper)

# ── 조작과 카메라 ──
func _physics_process(delta: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var grounded := y <= 0.0
	var dir := Vector3(Input.get_axis("move_left", "move_right"), 0, Input.get_axis("move_up", "move_down"))
	if dir.length() > 1.0:
		dir = dir.normalized()
	for a in ["move_left", "move_right", "move_up", "move_down"]:
		if Input.is_action_just_pressed(a):
			if a == last_tap and now - last_tap_at < 0.25 and grounded:
				dash_until = now + 0.18
			last_tap = a; last_tap_at = now
	var speed := WALK * (2.2 if now < dash_until else 1.0)
	var can_move := charging < 0.0 and action_until < now
	if can_move and dir != Vector3.ZERO:
		player.position += dir * speed * delta
		player.position.x = clampf(player.position.x, -15.0, 15.0)
		player.position.z = clampf(player.position.z, -9.0, 9.0)
		player.move_dir = dir; player.speed = speed
	else:
		player.move_dir = Vector3.ZERO; player.speed = 0.0
	if grounded and Input.is_action_just_pressed("jump"):
		charging = 0.0
	if charging >= 0.0:
		charging = minf(CHARGE, charging + delta)
		if Input.is_action_just_released("jump"):
			vy = lerpf(JUMP_MIN, JUMP_V, charging / CHARGE)
			y = 0.001; charging = -1.0
	if not grounded or vy > 0.0:
		vy -= G * delta
		y = maxf(0.0, y + vy * delta)
		if y <= 0.0:
			vy = 0.0
	player.crouch = (charging / CHARGE) if charging >= 0.0 else 0.0
	player.airborne = y > 0.0
	player.vertical = vy
	player.position.y = y
	if grounded and action_until < now:
		if Input.is_action_just_pressed("hit"):
			player.action = "punch"; action_until = now + 0.28
		elif Input.is_action_just_pressed("kick"):
			player.action = "kick"; action_until = now + 0.32
	if action_until >= now:
		player.action_t = 1.0 - (action_until - now) / (0.28 if player.action == "punch" else 0.32)
	else:
		player.action = ""; player.action_t = 0.0

func _process(delta: float) -> void:
	# 3/4 시점: 플레이어 뒤·위에서 내려다본다. 부드럽게 따라오고 세계 끝에서 멈춘다
	var want := Vector3(clampf(player.position.x, -9.0, 9.0), 0, clampf(player.position.z, -5.0, 6.0)) + Vector3(0, 8.5, 7.5)
	cam.position = cam.position.lerp(want, minf(1.0, delta * 4.0))
	cam.look_at(Vector3(cam.position.x, 0.6, cam.position.z - 7.5), Vector3.UP)
