extends Node3D
## 디오라마의 플레이어 — 종이 판 하나(figures/stand · figures/run)가 3D 바닥 위를 걷고 뛴다. 물리 숫자는 Player(2D)와 같고 PIXEL 로 미터로 바꾼다.

const PIXEL := 0.02
const WALK := 260.0 * PIXEL
const DEPTH := 180.0 * PIXEL
const G := 2400.0 * PIXEL
const JUMP_V := 860.0 * PIXEL
const JUMP_MIN := 430.0 * PIXEL
const CHARGE := 0.7

var vy := 0.0
var y := 0.0
var charging := -1.0
var sprite: Sprite3D
var shadow: MeshInstance3D
var tex_stand: Texture2D = preload("res://assets/svg/figures/stand.svg")
var tex_run: Texture2D = preload("res://assets/svg/figures/run.svg")
var run_t := 0.0
var last_tap := ""
var last_tap_at := -1.0
var dash_until := -1.0

func _ready() -> void:
	sprite = Sprite3D.new()
	sprite.texture = tex_stand
	sprite.pixel_size = PIXEL
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.shaded = false
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite.position.y = 25.0 * PIXEL
	add_child(sprite)
	shadow = MeshInstance3D.new()
	var q := QuadMesh.new(); q.size = Vector2(0.5, 0.18)
	shadow.mesh = q
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.1, 0.05, 0.08, 0.18)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shadow.material_override = mat
	shadow.rotation_degrees.x = -90.0
	shadow.position.y = 0.006
	add_child(shadow)

func _physics_process(delta: float) -> void:
	var grounded := y <= 0.0
	var dir := Input.get_axis("move_left", "move_right")
	var dz := Input.get_axis("move_up", "move_down")
	var moving := false
	# 벨트스크롤 손맛(운영자: 핵앤슬래시 같은 이동) — 8방향, 대각선은 정규화, 좌/우 더블탭이면 0.18초 대시
	var now := Time.get_ticks_msec() / 1000.0
	for a in ["move_left", "move_right"]:
		if Input.is_action_just_pressed(a):
			if a == last_tap and now - last_tap_at < 0.25 and grounded:
				dash_until = now + 0.18
			last_tap = a
			last_tap_at = now
	var speed_mul := 2.2 if now < dash_until else 1.0
	if charging < 0.0 or not grounded:
		var v := Vector2(dir * WALK, dz * DEPTH)
		if dir != 0.0 and dz != 0.0:
			v *= 0.7071
		if dir != 0.0:
			sprite.flip_h = dir < 0.0
		if v != Vector2.ZERO:
			position.x = clampf(position.x + v.x * speed_mul * delta, -16.0, 16.0)
			if grounded:
				position.z = clampf(position.z + v.y * speed_mul * delta, -7.5, 2.5)
			moving = grounded
	if grounded and Input.is_action_just_pressed("jump"):
		charging = 0.0
	if charging >= 0.0:
		charging = minf(CHARGE, charging + delta)
		if Input.is_action_just_released("jump"):
			vy = lerpf(JUMP_MIN, JUMP_V, charging / CHARGE)
			y = 0.001
			charging = -1.0
	if not grounded or vy > 0.0:
		vy -= G * delta
		y = maxf(0.0, y + vy * delta)
		if y <= 0.0:
			vy = 0.0
	# 판 그림 — 달릴 땐 두 장을 번갈아(4장짜리 걸음은 에셋 백로그에), 웅크림은 살짝 낮춰 흉내
	run_t += delta
	var squat := 0.0
	if charging >= 0.0:
		squat = 0.12
	sprite.texture = tex_run if moving and fmod(run_t, 0.24) < 0.12 else tex_stand
	sprite.position.y = 25.0 * PIXEL + y - squat
	sprite.scale = Vector3(1.0 + squat * 0.4, 1.0 - squat * 0.4, 1.0)
	# 뛰어오르면 그림자는 바닥에 남고 옅어진다 — 붕 떠 보이지 않는 가장 싼 방법
	var sm := shadow.material_override as StandardMaterial3D
	sm.albedo_color.a = maxf(0.05, 0.18 - y * 0.06)
	shadow.scale = Vector3(1.0 - minf(0.5, y * 0.25), 1.0 - minf(0.5, y * 0.25), 1.0)
