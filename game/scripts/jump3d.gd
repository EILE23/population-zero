class_name Jump3D
extends RefCounted
## 점프 손맛(운영자 2026-09-29: "점프도 뭔가 어색해서 재미가 없을 것 — 역동적으로"). Climb 같은 점프맵 미니게임이 그대로 쓰는 재사용 부품.
## - 코요테 타임: 발판을 막 벗어난 0.1초 안에도 뛴다(떨어지는 줄 알고 눌렀는데 안 뛰던 억울함)
## - 입력 버퍼: 착지 0.12초 전에 눌러도 닿는 순간 뛴다
## - 중력 세 단: 오를 땐 보통, 꼭대기 근처는 절반(잠깐 떠 있는 맛), 내려올 땐 1.6배(묵직하게), 낙하 속도 상한
## - 짧게 누르면 상승을 끊어 낮은 홉(가변 점프)
## - 몸이 뛸 때 늘어나고 닿을 때 찌그러진다(squash), 세게 닿으면 흙먼지

const G_UP := 22.0
const G_APEX := 11.0       # |vy| < APEX_V 일 때
const APEX_V := 1.6
const G_FALL := 36.0
const FALL_MAX := 16.0
const COYOTE := 0.1
const BUFFER := 0.12
const CUT_V := 2.4         # 일찍 떼면 이 속도로 끊는다

var _coyote_until := -1.0
var _buffer_until := -1.0
var cut_ok := false

## 매 물리 프레임 처음에 — 땅에 있는지·점프를 막 눌렀는지를 기억한다
func tick(grounded: bool, pressed: bool, now: float) -> void:
	if grounded: _coyote_until = now + COYOTE
	if pressed: _buffer_until = now + BUFFER

## 지금 뛸 수 있나(버퍼된 입력 + 땅이거나 코요테 안). 뛰면 둘 다 소모한다
func consume(now: float) -> bool:
	if _buffer_until >= now and _coyote_until >= now:
		_buffer_until = -1.0; _coyote_until = -1.0; cut_ok = true
		return true
	return false

## 이번 프레임 중력 — 오름·꼭대기·낙하
static func gravity(vy: float) -> float:
	if absf(vy) < APEX_V: return G_APEX
	return G_UP if vy > 0.0 else G_FALL

## 공중 속도 적분 + 일찍 뗐을 때 끊기 + 낙하 상한
func air(vy: float, released: bool, delta: float) -> float:
	if cut_ok and released and vy > CUT_V:
		vy = CUT_V; cut_ok = false
	vy -= gravity(vy) * delta
	return maxf(vy, -FALL_MAX)

## 착지 먼지 — 떨어진 속도만큼 크게
static func dust(parent: Node3D, at: Vector3, strength: float) -> void:
	if strength < 0.25: return
	var p := CPUParticles3D.new()
	p.amount = int(8 + 18 * strength); p.lifetime = 0.5; p.one_shot = true; p.explosiveness = 0.95
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING; p.emission_ring_axis = Vector3.UP; p.emission_ring_radius = 0.2; p.emission_ring_inner_radius = 0.1; p.emission_ring_height = 0.02
	p.direction = Vector3(0, 0.3, 0); p.spread = 90.0; p.flatness = 0.8
	p.initial_velocity_min = 0.8 * strength; p.initial_velocity_max = 2.0 * strength; p.gravity = Vector3(0, -1.0, 0); p.damping_min = 2.0; p.damping_max = 3.0
	p.scale_amount_min = 0.6; p.scale_amount_max = 1.4
	var sm := SphereMesh.new(); sm.radius = 0.05; sm.height = 0.1; sm.radial_segments = 6; sm.rings = 3; p.mesh = sm
	var m := StandardMaterial3D.new(); m.albedo_color = Color(0.85, 0.8, 0.72, 0.6); m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	p.material_override = m; p.position = at + Vector3(0, 0.03, 0)
	parent.add_child(p); p.emitting = true
	parent.get_tree().create_timer(1.0).timeout.connect(p.queue_free)
