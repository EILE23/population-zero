class_name Player
extends Figure
## 조작되는 졸라맨 — 무대 좌표(x, d)와 높이 z. 물리 상수는 웹 Climb(site/src/lib/tower.ts)와 같다:
## 걷기 260px/s, 중력 2400, 점프 430~860(0.7초 완충). 화면 위치·크기는 Stage 가 정한다.

const WALK := 260.0
const G := 2400.0
const JUMP_V := 860.0
const JUMP_MIN := 430.0
const CHARGE := 0.7
const DEPTH_SPEED := 0.9  # d/s — 앞뒤 이동은 400px 환산이라 천천히

var x: float = 1500.0
var d: float = 0.5
var z: float = 0.0
var vz: float = 0.0
var charging: float = -1.0
var world_w: float = 3200.0
var moving := false
## 잠깐의 동작(주먹·발차기·던지기) — 끝날 때까지 자세를 덮는다
var act_pose := ""
var act_until := 0.0

func _physics_process(delta: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var grounded := z <= 0.0
	var dir := Input.get_axis("move_left", "move_right")
	var dd := Input.get_axis("move_up", "move_down")
	moving = false
	if charging < 0.0 or not grounded:
		if dir != 0.0:
			x = clampf(x + dir * WALK * delta, 30.0, world_w - 30.0)
			face = 1 if dir > 0.0 else -1
			moving = grounded
		if dd != 0.0 and grounded:
			d = clampf(d + dd * DEPTH_SPEED * delta, 0.05, 1.0)
			moving = true
	# 점프 — 누르는 동안 힘을 모으고 떼면 뛴다(웹 Climb 과 같은 손맛)
	if grounded and Input.is_action_just_pressed("jump"):
		charging = 0.0
	if charging >= 0.0:
		charging = minf(CHARGE, charging + delta)
		if Input.is_action_just_released("jump"):
			vz = lerpf(JUMP_MIN, JUMP_V, charging / CHARGE)
			z = 0.001
			charging = -1.0
	if not grounded or vz > 0.0:
		vz -= G * delta
		z = maxf(0.0, z + vz * delta)
		if z <= 0.0:
			vz = 0.0
	# 순간 동작
	if grounded and act_until < now:
		if Input.is_action_just_pressed("hit"):
			act_pose = "punch"; act_until = now + 0.22
		elif Input.is_action_just_pressed("kick"):
			act_pose = "kick"; act_until = now + 0.26
	# 자세 고르기 — 웹 SquareGame 의 myPose() 순서
	if act_until >= now:
		pose = act_pose
	elif charging >= 0.0:
		pose = "charge"
	elif not grounded:
		pose = "jump" if vz > 0.0 else "fall"
	elif moving:
		pose = "run"
	else:
		pose = "stand"
	# 무대 → 화면
	var s := Stage.ds(d)
	scale = Vector2(s, s)
	position = Vector2(x, Stage.dy(d) - z * s)
	z_index = int(d * 100.0)
