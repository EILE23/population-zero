class_name Stick3D
extends Node3D
## 입체 졸라맨 — 관절은 구, 뼈는 캡슐, 어깨와 골반엔 가로대. 코드로 조립하고 코드로 움직인다(운영자 2026-09-28: "졸라맨 자체도 입체화되서 움직임이 자연스러워져야").
## 2D figure.gd 와 같은 관절 논리를 3D 각도로 옮겼다: 걸음 위상은 이동 거리에 걸려 발이 미끄러지지 않고, 팔은 다리와 반대 위상,
## 무릎은 뒤로 갈 때 접히고, 상체는 달릴 때 앞으로 기울고, 엉덩이는 보폭마다 살짝 뜬다. 몸은 이동 방향으로 부드럽게 돈다.
## 회전 부호 약속(2026-09-28 수정 — 처음엔 팔꿈치가 뒤로, 무릎이 앞으로 꺾여 "팔이 따로 놀았다"):
##   피벗의 rotation.x 가 +면 매달린 뼈 끝이 앞(+z, 얼굴 방향)으로 간다. 다리·팔 앞으로 = +, 무릎 접힘 = −(정강이가 뒤로), 팔꿈치 접힘 = +(손이 앞·위로).
## 크기: 키 1.0m(2D 의 42px). 발끝이 원점. 두께는 3/4 카메라 거리에서 읽히게 2D 보다 굵다.

@export var color: Color = Color("1b0c15")
@export var head_color: Color = Color("1b0c15")

const HIP_Y := 0.42
const SHOULDER_Y := 0.84
const HEAD_Y := 1.0
const THIGH := 0.26
const SHIN := 0.24
const UPPER := 0.22
const FORE := 0.21
const R := 0.042          # 뼈 두께 — 2D 의 2.4px/42px 보다 굵게(멀리서 선으로 읽히게)
const SHOULDER_W := 0.115 # 어깨 반폭
const HIP_W := 0.075      # 골반 반폭
const STRIDE := 1.35      # 한 걸음(위상 2π)에 나아가는 거리 — 발 미끄러짐 없음

## 바깥에서 매 프레임 채워 준다
var move_dir := Vector3.ZERO   # 수평 이동 방향(단위) — ZERO 면 서 있음
var speed := 0.0               # m/s
var airborne := false
var vertical := 0.0            # 공중 속도(+ 위)
var crouch := 0.0              # 0..1 웅크림
var seated := false            # 벤치에 앉음
var action := ""               # "punch" | "kick" | "grab" | "" — 잠깐의 동작
var action_t := 0.0            # 동작 진행 0..1
var carrying: Node3D = null    # 오른손에 든 것(hand_r 의 자식)

var _phase := 0.0
var _t := 0.0
var _yaw := 0.0
var _mat: StandardMaterial3D
var _head_mat: StandardMaterial3D
var pelvis: Node3D
var torso: Node3D
var neck: Node3D
var hand_r: Node3D
var hand_l: Node3D
var socket_hat: Node3D
var socket_face: Node3D
var socket_back: Node3D
var socket_belt: Node3D
var hips := {}     # side → Node3D (thigh pivot)
var knees := {}
var shoulders := {}
var elbows := {}

func _ready() -> void:
	_mat = _material(color)
	_head_mat = _material(head_color)
	pelvis = _pivot(self, Vector3(0, HIP_Y, 0))
	_bar(pelvis, HIP_W)                                  # 골반대
	torso = _pivot(pelvis, Vector3.ZERO)
	_bone(torso, SHOULDER_Y - HIP_Y, _mat)
	neck = _pivot(torso, Vector3(0, SHOULDER_Y - HIP_Y, 0))
	_bar(neck, SHOULDER_W)                               # 쇄골
	_joint(neck, 1.0)
	var head := MeshInstance3D.new()
	var sm := SphereMesh.new(); sm.radius = 0.16; sm.height = 0.32; sm.radial_segments = 24; sm.rings = 12
	head.mesh = sm; head.material_override = _head_mat
	head.position = Vector3(0, HEAD_Y - SHOULDER_Y + 0.02, 0)
	neck.add_child(head)
	for side in [-1.0, 1.0]:
		var hip := _pivot(pelvis, Vector3(side * HIP_W, 0, 0))
		_joint(hip, 1.1)
		_bone(hip, -THIGH, _mat)
		var knee := _pivot(hip, Vector3(0, -THIGH, 0))
		_bone(knee, -SHIN, _mat)
		_joint(knee, 1.05)
		hips[side] = hip; knees[side] = knee
		var sh := _pivot(neck, Vector3(side * SHOULDER_W, 0, 0))
		_joint(sh, 1.1)
		_bone(sh, -UPPER, _mat)
		var el := _pivot(sh, Vector3(0, -UPPER, 0))
		_bone(el, -FORE, _mat)
		_joint(el, 1.05)
		shoulders[side] = sh; elbows[side] = el
	hand_r = _pivot(elbows[1.0], Vector3(0, -FORE, 0))
	_joint(hand_r, 1.0)
	hand_l = _pivot(elbows[-1.0], Vector3(0, -FORE, 0))
	_joint(hand_l, 1.0)
	# 꾸미기용 소켓(운영자 2026-09-28: 캐릭터 꾸미기) — 모자·안경·가방·벨트는 여기에 자식으로 붙인다. 위치는 리그 기준이라 자세와 함께 움직인다
	socket_hat = _pivot(neck, Vector3(0, HEAD_Y - SHOULDER_Y + 0.02 + 0.15, 0))
	socket_face = _pivot(neck, Vector3(0, HEAD_Y - SHOULDER_Y + 0.02, 0.15))
	socket_back = _pivot(torso, Vector3(0, (SHOULDER_Y - HIP_Y) * 0.7, -R * 1.6))
	socket_belt = _pivot(pelvis, Vector3(0, 0.02, 0))

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

## 가로대 — 어깨(쇄골)와 골반: 팔다리가 몸통에 붙어 보이게 한다
func _bar(pivot: Node3D, half: float) -> void:
	var mi := MeshInstance3D.new()
	var cm := CapsuleMesh.new(); cm.radius = R * 0.9; cm.height = half * 2.0 + R * 1.8; cm.radial_segments = 10; cm.rings = 4
	mi.mesh = cm; mi.material_override = _mat
	mi.rotation.z = PI / 2.0
	pivot.add_child(mi)

func _joint(pivot: Node3D, k: float) -> void:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new(); sm.radius = R * k * 1.15; sm.height = R * k * 2.3; sm.radial_segments = 10; sm.rings = 5
	mi.mesh = sm; mi.material_override = _mat
	pivot.add_child(mi)

## 손에 들기 — item 은 hand_r 의 자식이 되고, 놓으면 다시 세계로
func hold(item: Node3D) -> void:
	if carrying:
		return
	item.get_parent().remove_child(item)
	hand_r.add_child(item)
	item.position = Vector3(0, -0.06, 0.06)
	item.rotation = Vector3.ZERO
	carrying = item

func release(into: Node3D, at: Vector3) -> Node3D:
	var item := carrying
	if item == null:
		return null
	hand_r.remove_child(item)
	into.add_child(item)
	item.global_position = at
	carrying = null
	return item

func _process(delta: float) -> void:
	_t += delta
	var moving := move_dir.length_squared() > 0.0001 and speed > 0.05 and not seated
	# 몸 방향 — 이동 방향으로 부드럽게(초당 약 10rad 로 수렴). 서 있으면 마지막 방향 유지
	if moving:
		var want := atan2(move_dir.x, move_dir.z)
		_yaw = lerp_angle(_yaw, want, minf(1.0, delta * 10.0))
	rotation.y = _yaw
	# 걸음 위상은 거리로 — 빠르면 빨리, 멈추면 멈춘다
	if moving and not airborne:
		_phase += speed * delta / STRIDE * TAU
	else:
		_phase = lerp_angle(_phase, 0.0, minf(1.0, delta * 8.0))
	var sw := sin(_phase)
	var cw := cos(_phase)
	var run_k := clampf(speed / 3.0, 0.0, 1.4)  # 걷기 1.0 근처, 대시 1.4
	var breathe := sin(_t * 2.0) * 0.006
	var bob := absf(cw) * 0.035 * run_k if moving and not airborne else 0.0
	pelvis.position.y = HIP_Y + bob + breathe - crouch * 0.16
	# 상체: 달리면 앞으로 기울고 골반과 반대로 살짝 비틀림; 웅크리면 더 숙임; 공중이면 뒤로 살짝; 앉으면 곧게
	var lean := 0.28 * run_k if moving and not airborne else 0.0
	lean += crouch * 0.35
	if airborne:
		lean = -0.08 if vertical > 0.0 else 0.12
	if seated:
		lean = -0.05
	torso.rotation.x = lean
	torso.rotation.y = -sw * 0.10 * run_k if moving else 0.0
	neck.rotation.x = -lean * 0.6  # 고개는 앞을 본다
	for side in [-1.0, 1.0]:
		var s: float = side
		var hip: Node3D = hips[s]; var knee: Node3D = knees[s]
		var sh: Node3D = shoulders[s]; var el: Node3D = elbows[s]
		if seated:
			# 벤치: 허벅지 앞으로 수평, 정강이 아래로, 손은 무릎 위
			hip.rotation.x = 1.5; knee.rotation.x = -1.45
			sh.rotation.x = 0.55; sh.rotation.z = -s * 0.1; el.rotation.x = 0.9
		elif airborne:
			# 점프: 오를 땐 무릎을 당기고 팔을 위로, 내릴 땐 다리를 내리고 팔을 벌린다
			var up := vertical > 0.0
			hip.rotation.x = 0.9 if up else 0.2
			knee.rotation.x = -1.4 if up else -0.5
			sh.rotation.x = 2.4 if up else 1.0
			sh.rotation.z = -s * (0.25 if up else 0.9)
			el.rotation.x = 0.3 if up else 0.6
		elif crouch > 0.0:
			hip.rotation.x = 1.0 * crouch
			knee.rotation.x = -1.7 * crouch
			sh.rotation.x = -0.5 * crouch
			sh.rotation.z = -s * 0.15
			el.rotation.x = 1.0 * crouch
		elif moving:
			# 다리: 허벅지 ±43°·뒤로 갈 때 무릎 접힘(2D 와 같은 규칙)
			var a := s * sw * 0.75 * run_k
			hip.rotation.x = a
			knee.rotation.x = -(1.35 if a < 0.0 else 0.15) * run_k
			# 팔: 다리와 반대 위상, 팔꿈치 90° 근처로 접혀 손이 앞·위로
			sh.rotation.x = -a * 1.1
			sh.rotation.z = -s * 0.10
			el.rotation.x = 1.25 * run_k
		else:
			# 서 있음: 팔은 늘어뜨리고 숨 쉬듯 미세하게
			hip.rotation.x = 0.0
			knee.rotation.x = -0.05
			sh.rotation.x = sin(_t * 2.0 + s) * 0.03
			sh.rotation.z = -s * 0.10
			el.rotation.x = 0.12
	# 들고 있으면 오른팔은 앞으로 반쯤 들어 물건을 보인다(걸음 스윙 대신)
	if carrying and not airborne:
		shoulders[1.0].rotation.x = 0.55
		elbows[1.0].rotation.x = 1.15
	# 잠깐의 동작 — 오른팔 주먹 / 오른다리 발차기 / 허리 숙여 집기(진행 0→1: 나갔다 돌아온다)
	if action != "":
		var k := sin(clampf(action_t, 0.0, 1.0) * PI)
		if action == "punch":
			shoulders[1.0].rotation.x = 1.55 * k
			elbows[1.0].rotation.x = 1.2 * (1.0 - k) + 0.05 * k
			torso.rotation.y = -0.35 * k
		elif action == "kick":
			hips[1.0].rotation.x = 1.4 * k
			knees[1.0].rotation.x = -0.2 * k
			torso.rotation.x = -0.25 * k
		elif action == "grab":
			torso.rotation.x = 0.9 * k
			hips[1.0].rotation.x = 0.35 * k; hips[-1.0].rotation.x = 0.35 * k
			knees[1.0].rotation.x = -0.7 * k; knees[-1.0].rotation.x = -0.7 * k
			shoulders[1.0].rotation.x = 1.3 * k
			elbows[1.0].rotation.x = 0.2 * k
