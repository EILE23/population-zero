class_name Stick3D
extends Node3D
## 입체 졸라맨 — 관절은 구, 뼈는 캡슐, 어깨와 골반엔 가로대. 코드로 조립하고 코드로 움직인다(운영자 2026-09-28: "졸라맨 자체도 입체화되서 움직임이 자연스러워져야").
## 2D figure.gd 와 같은 관절 논리를 3D 각도로 옮겼다: 걸음 위상은 이동 거리에 걸려 발이 미끄러지지 않고, 팔은 다리와 반대 위상,
## 무릎은 뒤로 갈 때 접히고, 상체는 달릴 때 앞으로 기울고, 엉덩이는 보폭마다 살짝 뜬다. 몸은 이동 방향으로 부드럽게 돈다.
## 회전 부호 약속(2026-09-28 수정 — 처음엔 팔꿈치가 뒤로, 무릎이 앞으로 꺾여 "팔이 따로 놀았다"):
##   매달린 뼈(팔다리)는 rotation.x 가 −면 끝이 앞(+z, 얼굴 방향)으로 간다(Godot 오른손 좌표계). 코드는 '앞 = 양수' 로 읽히게 쓰고 대입에서 -( ) 로 뒤집는다.
##   2026-09-28 두 번째 수정: 처음엔 + 가 앞인 줄 알고 넣어서 다리가 진행 방향과 반대로 저었다(운영자: "지금 무슨 문워크 하냐"). 위로 뻗는 몸통(torso)은 + 가 앞이 맞다.
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
var jet := false               # 제트킥 비행 중(온몸이 앞으로 쏠린 자세)
var action := ""               # "punch" | "kick" | "grab" | "" — 잠깐의 동작
var action_t := 0.0            # 동작 진행 0..1
var carrying: Node3D = null    # 오른손에 든 것(hand_r 의 자식)

var _phase := 0.0
var _t := 0.0
var _yaw := 0.0
var _yaw_target := 0.0
var _pivots: Array[Node3D] = []   # 블렌딩 대상 관절 전부
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
	_pivots = [torso, neck, hips[-1.0], hips[1.0], knees[-1.0], knees[1.0], shoulders[-1.0], shoulders[1.0], elbows[-1.0], elbows[1.0]]
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
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED  # 잉크 선처럼 평평하게(운영자: 2D 느낌) — 툰 명암을 주면 튜브로 보였다
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
		_yaw_target = atan2(move_dir.x, move_dir.z)
	_yaw = lerp_angle(_yaw, _yaw_target, minf(1.0, delta * 10.0))
	rotation.y = _yaw
	# 자세 블렌딩 — 이 프레임의 목표 각도를 아래에서 곧장 대입한 뒤, 끝에서 이전 각도와 섞는다(앉기·일어서기가 딱딱하지 않게)
	var prev := {}
	for pv in _pivots:
		prev[pv] = pv.rotation
	var prev_pelvis_y := pelvis.position.y
	var prev_pelvis_rot := pelvis.rotation
	pelvis.rotation = Vector3.ZERO
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
		lean = 0.18 if vertical > 0.0 else 0.08  # 도약은 살짝 앞으로
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
			hip.rotation.x = -(1.5); knee.rotation.x = -(-1.45)
			sh.rotation.x = -(0.55); sh.rotation.z = -s * 0.1; el.rotation.x = -(0.9)
		elif airborne:
			# 점프: 오를 땐 무릎을 당기고 팔을 위로, 내릴 땐 다리를 내리고 팔을 벌린다
			# 보폭 도약(운영자 스케치 2026-09-28): 오른다리(s=1)가 앞, 왼다리가 뒤. 팔은 반대 — 왼팔 앞·위, 오른팔 뒤. 내려올수록 앞다리를 내려 착지 준비
			var down := clampf(-vertical / 6.0, 0.0, 1.0)
			if s > 0.0:
				hip.rotation.x = -(lerpf(1.05, 0.55, down)); knee.rotation.x = -(lerpf(-1.25, -0.35, down))
				sh.rotation.x = -(-0.95); sh.rotation.z = -0.25; el.rotation.x = -(0.35)
			else:
				hip.rotation.x = -(lerpf(-0.75, -0.3, down)); knee.rotation.x = -(lerpf(-0.9, -0.5, down))
				sh.rotation.x = -(1.45); sh.rotation.z = 0.15; el.rotation.x = -(0.5)
		elif crouch > 0.0:
			hip.rotation.x = -(1.0 * crouch)
			knee.rotation.x = -(-1.7 * crouch)
			sh.rotation.x = -(-0.5 * crouch)
			sh.rotation.z = -s * 0.15
			el.rotation.x = -(1.0 * crouch)
		elif moving:
			# 다리: 허벅지 ±43°·뒤로 갈 때 무릎 접힘(2D 와 같은 규칙)
			var a := s * sw * 0.9 * run_k
			hip.rotation.x = -(a)
			knee.rotation.x = -(-(1.4 if a < 0.0 else 0.2) * run_k)
			# 팔: 다리와 반대 위상(2D: 1.05), 팔꿈치는 2D 의 1.7 에 가깝게 접혀 손이 가슴 앞을 오간다
			sh.rotation.x = -(-s * sw * 1.05 * run_k)
			sh.rotation.z = -s * 0.10
			el.rotation.x = -(1.5 * run_k)
		else:
			# 서 있음: 팔은 늘어뜨리고 숨 쉬듯 미세하게
			hip.rotation.x = -(0.0)
			knee.rotation.x = -(-0.05)
			sh.rotation.x = -(sin(_t * 2.0 + s) * 0.03)
			sh.rotation.z = -s * 0.10
			el.rotation.x = -(0.12)
	# 들고 있으면 오른팔은 앞으로 반쯤 들어 물건을 보인다(걸음 스윙 대신)
	if carrying and not airborne:
		shoulders[1.0].rotation.x = -(0.55)
		elbows[1.0].rotation.x = -(1.15)
	# 잠깐의 동작 — 2D 자세를 그대로: 빨리 나갔다(35%) 천천히 돌아온다(65%). 공중에서도 된다(점프킥·점프 주먹)
	if action != "":
		var a := clampf(action_t, 0.0, 1.0)
		var k := smoothstep(0.0, 1.0, a / 0.35) if a < 0.35 else 1.0 - smoothstep(0.0, 1.0, (a - 0.35) / 0.65)
		if action == "punch":
			# 2D punch: 상체 앞으로, 뻗은 팔 수평으로 쭉, 뒷팔 당김, 다리 벌림
			shoulders[1.0].rotation.x = -(1.6 * k); elbows[1.0].rotation.x = -(0.05 * k + 0.12 * (1.0 - k)); shoulders[1.0].rotation.z = -0.05
			shoulders[-1.0].rotation.x = -(-0.7 * k); elbows[-1.0].rotation.x = -(0.9 * k)
			torso.rotation.y = -0.45 * k; torso.rotation.x = 0.15 * k
			if not airborne:
				hips[1.0].rotation.x = -(0.35 * k); hips[-1.0].rotation.x = -(-0.35 * k)
			else:
				# 점프 주먹: 다리 둘 다 당겨 올리고 상체를 더 숙여 비틀며 온몸으로 친다
				hips[1.0].rotation.x = -(0.9 * k); knees[1.0].rotation.x = -(-1.5 * k)
				hips[-1.0].rotation.x = -(0.5 * k); knees[-1.0].rotation.x = -(-1.2 * k)
				torso.rotation.x = 0.45 * k; torso.rotation.y = -0.7 * k; neck.rotation.x = -0.2 * k
		elif action == "kick":
			# 2D kick: 디딤발 하나, 찬 발이 앞으로 높이 쭉, 몸은 뒤로 기움, 팔은 균형
			hips[1.0].rotation.x = -(1.5 * k); knees[1.0].rotation.x = -(-0.1 * k)
			torso.rotation.x = -0.3 * k
			shoulders[1.0].rotation.x = -(-0.6 * k); shoulders[-1.0].rotation.x = -(0.8 * k); elbows[-1.0].rotation.x = -(0.6 * k)
			if not airborne:
				knees[-1.0].rotation.x = -(-0.25 * k)
			elif jet:
				# 제트킥(운영자 스케치): 몸 전체가 앞으로 쏠려 거의 수평 — 골반을 앞으로 70° 눕히고, 찬 다리는 몸 선을 따라 앞으로 쭉,
				# 반대 다리는 접어 뒤로, 팔은 몸 선을 따라 옆·뒤로, 고개는 들어 앞을 본다
				pelvis.rotation.x = 1.2 * k
				torso.rotation.x = 0.1 * k; torso.rotation.y = 0.15 * k; neck.rotation.x = -0.9 * k
				hips[1.0].rotation.x = -(2.35 * k); knees[1.0].rotation.x = -(0.0)
				hips[-1.0].rotation.x = -(-0.5 * k); knees[-1.0].rotation.x = -(-1.7 * k)
				shoulders[1.0].rotation.x = -(-1.6 * k); shoulders[1.0].rotation.z = -1.1 * k; elbows[1.0].rotation.x = -(0.1)
				shoulders[-1.0].rotation.x = -(-1.6 * k); shoulders[-1.0].rotation.z = 1.1 * k; elbows[-1.0].rotation.x = -(0.1)
			else:
				# 비행 킥: 찬 다리 앞으로 쭉, 반대 다리는 접어 뒤로, 상체는 뒤로 젖혀 비틀고, 양팔은 벌려 균형
				hips[1.0].rotation.x = -(1.75 * k); knees[1.0].rotation.x = -(0.0)
				hips[-1.0].rotation.x = -(-0.7 * k); knees[-1.0].rotation.x = -(-1.6 * k)
				torso.rotation.x = -0.5 * k; torso.rotation.y = 0.35 * k; neck.rotation.x = 0.3 * k
				shoulders[1.0].rotation.x = -(-1.1 * k); shoulders[1.0].rotation.z = -0.7 * k
				shoulders[-1.0].rotation.x = -(0.4 * k); shoulders[-1.0].rotation.z = 0.8 * k; elbows[-1.0].rotation.x = -(0.3 * k)
		elif action == "throw":
			# 2D throw: 앞 절반은 팔을 뒤로 높이 감고(뒷다리에 체중), 뒤 절반은 앞으로 쭉 뻗어 놓는다
			var back := a < 0.45
			var w := smoothstep(0.0, 1.0, a / 0.45) if back else smoothstep(0.0, 1.0, (a - 0.45) / 0.3)
			shoulders[1.0].rotation.x = -(-2.4 * w) if back else -(lerpf(-2.4, 1.3, w))
			elbows[1.0].rotation.x = -(1.0 * w) if back else -(lerpf(1.0, 0.1, w))
			torso.rotation.y = (0.5 * w) if back else lerpf(0.5, -0.4, w)
			torso.rotation.x = (-0.15 * w) if back else lerpf(-0.15, 0.3, w)
			if not airborne:
				hips[1.0].rotation.x = -(-0.3); hips[-1.0].rotation.x = -(0.3)
		elif action == "grab":
			torso.rotation.x = 0.9 * k
			hips[1.0].rotation.x = -(0.35 * k); hips[-1.0].rotation.x = -(0.35 * k)
			knees[1.0].rotation.x = -(-0.7 * k); knees[-1.0].rotation.x = -(-0.7 * k)
			shoulders[1.0].rotation.x = -(1.3 * k)
			elbows[1.0].rotation.x = -(0.2 * k)
	# 블렌딩 속도: 동작 중엔 아주 빠르게(주먹이 0.28초라 뭉개지면 안 된다), 앉기·웅크림은 느리게, 걷기는 중간
	var rate := 34.0 if action != "" else (9.0 if seated or crouch > 0.0 else 18.0)
	var k := minf(1.0, delta * rate)
	for pv in _pivots:
		var want: Vector3 = pv.rotation
		var was: Vector3 = prev[pv]
		pv.rotation = Vector3(lerp_angle(was.x, want.x, k), lerp_angle(was.y, want.y, k), lerp_angle(was.z, want.z, k))
	pelvis.position.y = lerpf(prev_pelvis_y, pelvis.position.y, k)
	pelvis.rotation.x = lerp_angle(prev_pelvis_rot.x, pelvis.rotation.x, k)

## 바깥에서 방향을 정한다(벤치에 앉을 때 등) — 부드럽게 돌아간다
func face(yaw: float) -> void:
	_yaw_target = yaw
