class_name Stick3D
extends Node3D
## 입체 졸라맨 — 관절은 작은 구, 뼈는 캡슐. 코드로 조립하고 코드로 움직인다(운영자 2026-09-28: "졸라맨 자체도 입체화되서 움직임이 자연스러워져야").
## 2D figure.gd 와 같은 관절 논리를 3D 각도로 옮겼다: 걸음 위상은 이동 거리에 걸려 발이 미끄러지지 않고, 팔은 다리와 반대 위상,
## 무릎은 뒤로 갈 때 접히고, 상체는 달릴 때 앞으로 기울고, 엉덩이는 보폭마다 살짝 뜬다. 몸은 이동 방향으로 부드럽게 돈다.
## 크기: 키 1.0m(2D 의 42px). 발끝이 원점.

@export var color: Color = Color("1b0c15")
@export var head_color: Color = Color("1b0c15")

const HIP_Y := 0.42
const SHOULDER_Y := 0.84
const HEAD_Y := 1.0
const THIGH := 0.26
const SHIN := 0.24
const UPPER := 0.22
const FORE := 0.21
const R := 0.032          # 뼈 두께
const STRIDE := 1.35      # 한 걸음(위상 2π)에 나아가는 거리 — 발 미끄러짐 없음

## 바깥에서 매 프레임 채워 준다
var move_dir := Vector3.ZERO   # 수평 이동 방향(단위) — ZERO 면 서 있음
var speed := 0.0               # m/s
var airborne := false
var vertical := 0.0            # 공중 속도(+ 위)
var crouch := 0.0              # 0..1 웅크림(점프 힘 모으기)
var action := ""               # "punch" | "kick" | "" — 잠깐의 동작
var action_t := 0.0            # 동작 진행 0..1

var _phase := 0.0
var _t := 0.0
var _yaw := 0.0
var _mat: StandardMaterial3D
var _head_mat: StandardMaterial3D
var pelvis: Node3D
var torso: Node3D
var neck: Node3D
var hips := {}     # side → Node3D (thigh pivot)
var knees := {}
var shoulders := {}
var elbows := {}

func _ready() -> void:
	_mat = _material(color)
	_head_mat = _material(head_color)
	pelvis = _pivot(self, Vector3(0, HIP_Y, 0))
	torso = _pivot(pelvis, Vector3.ZERO)
	_bone(torso, SHOULDER_Y - HIP_Y, _mat)
	neck = _pivot(torso, Vector3(0, SHOULDER_Y - HIP_Y, 0))
	var head := MeshInstance3D.new()
	var sm := SphereMesh.new(); sm.radius = 0.155; sm.height = 0.31; sm.radial_segments = 24; sm.rings = 12
	head.mesh = sm; head.material_override = _head_mat
	head.position = Vector3(0, HEAD_Y - SHOULDER_Y, 0)
	neck.add_child(head)
	for side in [-1.0, 1.0]:
		var hip := _pivot(pelvis, Vector3(side * 0.07, 0, 0))
		_bone(hip, -THIGH, _mat)
		var knee := _pivot(hip, Vector3(0, -THIGH, 0))
		_bone(knee, -SHIN, _mat)
		_joint(knee)
		hips[side] = hip; knees[side] = knee
		var sh := _pivot(neck, Vector3(side * 0.12, -0.02, 0))
		_bone(sh, -UPPER, _mat)
		var el := _pivot(sh, Vector3(0, -UPPER, 0))
		_bone(el, -FORE, _mat)
		_joint(el)
		shoulders[side] = sh; elbows[side] = el

func _material(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	m.roughness = 1.0
	return m

func _pivot(parent: Node3D, at: Vector3) -> Node3D:
	var n := Node3D.new(); n.position = at; parent.add_child(n); return n

## 피벗에서 아래(-y) 또는 위(+y)로 len 만큼 뻗는 캡슐
func _bone(pivot: Node3D, len: float, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var cm := CapsuleMesh.new(); cm.radius = R; cm.height = absf(len) + R * 2.0; cm.radial_segments = 10; cm.rings = 4
	mi.mesh = cm; mi.material_override = mat
	mi.position = Vector3(0, len / 2.0, 0)
	pivot.add_child(mi)

func _joint(pivot: Node3D) -> void:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new(); sm.radius = R * 1.15; sm.height = R * 2.3; sm.radial_segments = 10; sm.rings = 5
	mi.mesh = sm; mi.material_override = _mat
	pivot.add_child(mi)

func _process(delta: float) -> void:
	_t += delta
	var moving := move_dir.length_squared() > 0.0001 and speed > 0.05
	# 몸 방향 — 이동 방향으로 부드럽게(초당 약 10rad 로 수렴). 서 있으면 마지막 방향 유지
	if moving:
		var want := atan2(move_dir.x, move_dir.z)
		_yaw = lerp_angle(_yaw, want, minf(1.0, delta * 10.0))
	rotation.y = _yaw
	# 걸음 위상은 거리로 — 빠르면 빨리, 멈추면 멈춘다(2D 의 t*13 은 시간 위상이었다; 3D 에선 발 미끄러짐이 보여서 거리로 바꿨다)
	if moving and not airborne:
		_phase += speed * delta / STRIDE * TAU
	else:
		_phase = lerp_angle(_phase, 0.0, minf(1.0, delta * 8.0))
	var sw := sin(_phase)
	var cw := cos(_phase)
	var run_k := clampf(speed / 3.0, 0.0, 1.4)  # 걷기 1.0 근처, 대시 1.4
	var breathe := sin(_t * 2.0) * 0.006
	# 엉덩이: 보폭마다 살짝 뜸, 웅크리면 내려감, 공중이면 그대로
	var bob := absf(cw) * 0.035 * run_k if moving and not airborne else 0.0
	pelvis.position.y = HIP_Y + bob + breathe - crouch * 0.16
	# 상체: 달리면 앞으로 기울고 골반과 반대로 살짝 비틀림; 웅크리면 더 숙임; 공중이면 뒤로 살짝
	var lean := 0.28 * run_k if moving and not airborne else 0.0
	lean += crouch * 0.35
	if airborne:
		lean = -0.08 if vertical > 0.0 else 0.12
	torso.rotation.x = lean
	torso.rotation.y = -sw * 0.10 * run_k if moving else 0.0
	neck.rotation.x = -lean * 0.6  # 고개는 앞을 본다
	for side in [-1.0, 1.0]:
		var s: float = side
		var hip: Node3D = hips[s]; var knee: Node3D = knees[s]
		var sh: Node3D = shoulders[s]; var el: Node3D = elbows[s]
		if airborne:
			# 점프: 오를 땐 무릎을 당기고 팔을 위로, 내릴 땐 다리를 내리고 팔을 벌린다
			var up := vertical > 0.0
			hip.rotation.x = -0.9 if up else -0.2
			knee.rotation.x = 1.4 if up else 0.5
			sh.rotation.x = -2.6 if up else -1.2
			sh.rotation.z = -s * (0.2 if up else 0.9)
			el.rotation.x = -0.3 if up else -0.6
		elif crouch > 0.0:
			hip.rotation.x = -1.0 * crouch
			knee.rotation.x = 1.7 * crouch
			sh.rotation.x = 0.6 * crouch
			sh.rotation.z = -s * 0.15
			el.rotation.x = -1.2 * crouch
		elif moving:
			# 다리: 허벅지 ±40°·뒤로 갈 때 무릎 접힘(2D 와 같은 규칙). 앞으로(x 회전 음수)가 진행 방향
			var a := s * sw * 0.75 * run_k
			hip.rotation.x = -a
			knee.rotation.x = (1.35 if s * sw < 0.0 else 0.15) * run_k
			# 팔: 다리와 반대 위상, 팔꿈치 90° 근처
			sh.rotation.x = s * sw * 0.85 * run_k
			sh.rotation.z = -s * 0.12
			el.rotation.x = -1.3 * run_k
		else:
			# 서 있음: 팔은 늘어뜨리고 숨 쉬듯 미세하게
			hip.rotation.x = 0.0
			knee.rotation.x = 0.05
			sh.rotation.x = sin(_t * 2.0 + s) * 0.03
			sh.rotation.z = -s * 0.12
			el.rotation.x = -0.15
	# 잠깐의 동작 — 오른팔 주먹 / 오른다리 발차기(진행 0→1: 나갔다 돌아온다)
	if action != "":
		var k := sin(clampf(action_t, 0.0, 1.0) * PI)
		if action == "punch":
			shoulders[1.0].rotation.x = -1.55 * k
			elbows[1.0].rotation.x = -0.15 * k - 1.3 * (1.0 - k)
			torso.rotation.y = -0.35 * k
		elif action == "kick":
			hips[1.0].rotation.x = -1.4 * k
			knees[1.0].rotation.x = 0.2 * k
			torso.rotation.x = -0.25 * k
