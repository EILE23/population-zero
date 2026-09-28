class_name Quad3D
extends Node3D
## 네발 동물 공용 리그 — 개·고양이·담비·다람쥐가 같은 뼈대를 크기·비율만 달리해 쓴다(운영자 2026-09-28: 동물이 생기면 최소한 이 동작들은 있어야).
## 척추 두 마디(가슴·엉덩이), 머리(귀·눈·주둥이), 다리 4개(위·아래), 꼬리 두 마디. 전부 캡슐·구. 코드로 움직인다.
## 상태: idle(숨·눈 깜빡·귀 움찔) · walk(4박자) · run(바운드: 앞다리 짝·뒷다리 짝, 척추가 늘었다 줄었다) · sit · lie · stretch(기지개)
##       · bow(놀자, 개) · roll(구르기, 개) · groom(그루밍, 고양이) · yawn · look(플레이어 보기) · arch(등 세우기, 고양이)

var kind := "dog"
var color := Color("c9a27a")
var dark := Color("9a6a3f")
var state := "idle"
var speed := 0.0            # m/s — walk/run 위상에 쓴다
var look_at_pos := Vector3.ZERO
var look := false
var _t := 0.0
var _phase := 0.0
var _act_t := 0.0
var _blink := 0.0

# 비율(개 기준, 몸통 길이 L)
var L := 0.62
var H := 0.36     # 어깨 높이
var leg := 0.3
var head_r := 0.13

var chest: Node3D
var rump: Node3D
var spine: Node3D
var head: Node3D
var tail1: Node3D
var tail2: Node3D
var legs := {}    # "fl","fr","bl","br" → {hip, knee}
var eyes: Array[Node3D] = []
var ears: Array[Node3D] = []

func setup(k: String, c: Color, d: Color, scale_k := 1.0) -> void:
	kind = k; color = c; dark = d
	match k:
		"cat": L = 0.5; H = 0.28; leg = 0.24; head_r = 0.11
		"marten": L = 0.52; H = 0.2; leg = 0.16; head_r = 0.085
		"squirrel": L = 0.24; H = 0.12; leg = 0.09; head_r = 0.06
		_: L = 0.62; H = 0.36; leg = 0.3; head_r = 0.13
	scale = Vector3.ONE * scale_k
	_build()

func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.albedo_color = c
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON; m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED; m.roughness = 1.0
	return m

func _capsule(parent: Node3D, r: float, h: float, at: Vector3, rot: Vector3, c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); var cm := CapsuleMesh.new(); cm.radius = r; cm.height = maxf(h, r * 2.0); cm.radial_segments = 10; cm.rings = 4
	mi.mesh = cm; mi.material_override = _mat(c); mi.position = at; mi.rotation = rot; parent.add_child(mi); return mi

func _sphere(parent: Node3D, r: float, at: Vector3, c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); var sm := SphereMesh.new(); sm.radius = r; sm.height = r * 2.0; sm.radial_segments = 12; sm.rings = 6
	mi.mesh = sm; mi.material_override = _mat(c); mi.position = at; parent.add_child(mi); return mi

func _build() -> void:
	var thick := L * 0.24
	rump = Node3D.new(); rump.position = Vector3(0, H, -L * 0.25); add_child(rump)
	_capsule(rump, thick, L * 0.45, Vector3(0, 0, 0), Vector3(PI / 2.0, 0, 0), color)
	spine = Node3D.new(); spine.position = Vector3(0, 0, L * 0.22); rump.add_child(spine)
	chest = Node3D.new(); chest.position = Vector3(0, 0, L * 0.22); spine.add_child(chest)
	_capsule(chest, thick * 1.05, L * 0.45, Vector3.ZERO, Vector3(PI / 2.0, 0, 0), color)
	# 머리: 가슴 앞·위. 귀 둘, 눈 둘, 주둥이
	head = Node3D.new(); head.position = Vector3(0, thick * 0.9, L * 0.3); chest.add_child(head)
	_sphere(head, head_r, Vector3.ZERO, color)
	_capsule(head, head_r * 0.45, head_r * 0.8, Vector3(0, -head_r * 0.25, head_r * 0.9), Vector3(PI / 2.0, 0, 0), color)  # 주둥이
	_sphere(head, head_r * 0.16, Vector3(0, -head_r * 0.2, head_r * 1.35), Color("1b0c15"))  # 코
	for ex in [-1.0, 1.0]:
		var e := Node3D.new(); e.position = Vector3(ex * head_r * 0.45, head_r * 0.25, head_r * 0.75); head.add_child(e)
		_sphere(e, head_r * 0.16, Vector3.ZERO, Color("1b0c15")); eyes.append(e)
		var ear := Node3D.new(); ear.position = Vector3(ex * head_r * 0.6, head_r * 0.75, -head_r * 0.1); head.add_child(ear)
		var er := _capsule(ear, head_r * 0.22, head_r * 0.7, Vector3(0, head_r * 0.3, 0), Vector3(0.2, 0, -ex * 0.35), dark)
		if kind == "cat" or kind == "marten": er.scale = Vector3(0.8, 0.8, 0.5)
		ears.append(ear)
	# 다리: 어깨·엉덩이에서 아래로. 위·아래 두 마디
	for key in ["fl", "fr", "bl", "br"]:
		var front: bool = key.begins_with("f"); var side := -1.0 if key.ends_with("l") else 1.0
		var parent := chest if front else rump
		var hip := Node3D.new(); hip.position = Vector3(side * thick * 0.7, -thick * 0.3, (L * 0.12 if front else -L * 0.12)); parent.add_child(hip)
		_capsule(hip, thick * 0.34, leg * 0.5, Vector3(0, -leg * 0.25, 0), Vector3.ZERO, color)
		var knee := Node3D.new(); knee.position = Vector3(0, -leg * 0.5, 0); hip.add_child(knee)
		_capsule(knee, thick * 0.3, leg * 0.5, Vector3(0, -leg * 0.25, 0), Vector3.ZERO, dark)
		_sphere(knee, thick * 0.32, Vector3(0, -leg * 0.5, thick * 0.1), dark)  # 발
		legs[key] = { "hip": hip, "knee": knee }
	# 꼬리 두 마디
	tail1 = Node3D.new(); tail1.position = Vector3(0, thick * 0.4, -L * 0.28); rump.add_child(tail1)
	var tl := L * (0.5 if kind == "cat" or kind == "marten" else 0.35)
	_capsule(tail1, thick * 0.22, tl * 0.5, Vector3(0, 0, -tl * 0.25), Vector3(PI / 2.0, 0, 0), color)
	tail2 = Node3D.new(); tail2.position = Vector3(0, 0, -tl * 0.5); tail1.add_child(tail2)
	_capsule(tail2, thick * (0.4 if kind == "squirrel" else 0.18), tl * 0.5, Vector3(0, 0, -tl * 0.25), Vector3(PI / 2.0, 0, 0), color if kind != "squirrel" else dark)
	tail1.rotation.x = -0.9 if kind == "dog" else (-1.3 if kind == "squirrel" else -0.2)

## 잠깐의 동작 시작(stretch·bow·roll·groom·yawn·arch)
func act(name: String) -> void:
	state = name; _act_t = 0.0

func _process(delta: float) -> void:
	_t += delta; _act_t += delta
	_blink -= delta
	if _blink <= 0.0:
		_blink = randf_range(2.0, 5.0)
	var blink_k := 1.0 if _blink > 0.12 else 0.15   # 0.12초 눈 감음
	for e in eyes: e.scale = Vector3(1.0, blink_k, 1.0)
	var moving := speed > 0.05 and (state == "walk" or state == "run")
	if moving:
		_phase += speed * delta / (L * 1.6) * TAU
	var sw := sin(_phase); var cw := cos(_phase)
	var run := state == "run"
	# 척추: 달리면(바운드) 늘었다 줄었다 — 시트의 고양이·담비 사이클. 걸으면 살짝 흔들림
	if run:
		spine.rotation.x = -sw * 0.35; rump.position.y = H + absf(cw) * 0.08 * (L / 0.6); rump.rotation.x = sw * 0.25
	elif moving:
		spine.rotation.x = sin(_phase * 2.0) * 0.05; rump.position.y = H + absf(cw) * 0.02; rump.rotation.x = 0.0
	else:
		spine.rotation.x = lerpf(spine.rotation.x, 0.0, delta * 6.0); rump.rotation.x = lerpf(rump.rotation.x, 0.0, delta * 6.0)
	# 다리
	for key in legs.keys():
		var hip: Node3D = legs[key]["hip"]; var knee: Node3D = legs[key]["knee"]
		var front: bool = key.begins_with("f"); var left: bool = key.ends_with("l")
		var target_hip := 0.0; var target_knee := 0.0
		if run:
			# 바운드: 앞다리 짝, 뒷다리 짝(반대 위상), 뻗을 때 곧고 모을 때 접힘
			var ph := _phase + (0.0 if front else PI) + (0.15 if left else 0.0)
			target_hip = sin(ph) * 0.9; target_knee = -(0.4 + maxf(0.0, -sin(ph)) * 1.2)
		elif moving:
			# 4박자 걷기: 왼앞·오른뒤 / 오른앞·왼뒤 짝, 대각선
			var ph := _phase + (0.0 if (front == left) else PI)
			target_hip = sin(ph) * 0.55; target_knee = -(0.15 + maxf(0.0, -sin(ph)) * 0.8)
		match state:
			"sit":
				target_hip = 0.0 if front else 1.4; target_knee = 0.0 if front else -1.9
			"lie":
				target_hip = 1.4 if front else 1.5; target_knee = -1.6 if front else -2.0
			"stretch":
				# 기지개: 앞다리 앞으로 쭉 뻗고 엉덩이 들기
				var k := sin(minf(_act_t, 1.6) / 1.6 * PI)
				target_hip = (1.5 * k) if front else (-0.2 * k); target_knee = (0.1) if front else (-0.2)
			"bow":
				# 놀자(개): 앞다리 접어 가슴을 바닥에, 엉덩이 높이
				var k := minf(_act_t / 0.4, 1.0)
				target_hip = (1.3 * k) if front else 0.0; target_knee = (-1.9 * k) if front else -0.1
			"roll":
				target_hip = 1.0; target_knee = -1.2
			"groom":
				target_hip = 0.0 if front else 1.4; target_knee = 0.0 if front else -1.9
			"arch":
				target_hip = -0.3; target_knee = -0.3
		hip.rotation.x = lerp_angle(hip.rotation.x, target_hip, delta * 14.0)
		knee.rotation.x = lerp_angle(knee.rotation.x, target_knee, delta * 14.0)
	# 몸통 자세(앉기·엎드리기·기지개·놀자·구르기·등 세우기)
	var body_y := H; var body_pitch := 0.0; var roll := 0.0
	match state:
		"sit": body_y = H * 0.75; body_pitch = -0.45
		"lie": body_y = H * 0.42
		"stretch":
			var k := sin(minf(_act_t, 1.6) / 1.6 * PI); body_y = H * (1.0 - 0.35 * k); body_pitch = 0.5 * k
			if _act_t > 1.7: state = "idle"
		"bow":
			var k := minf(_act_t / 0.4, 1.0); body_y = H * (1.0 - 0.3 * k); body_pitch = 0.55 * k
			if _act_t > 1.6: state = "idle"
		"roll":
			roll = sin(minf(_act_t, 1.4) / 1.4 * PI) * PI; body_y = H * 0.55
			if _act_t > 1.5: state = "idle"
		"groom":
			body_y = H * 0.75; body_pitch = -0.4
			if _act_t > 2.2: state = "idle"
		"arch":
			body_y = H * 1.1; spine.rotation.x = 0.55; rump.rotation.x = -0.3
			if _act_t > 1.2: state = "idle"
		"yawn":
			if _act_t > 1.0: state = "idle"
	if not moving and state != "run" and state != "walk":
		rump.position.y = lerpf(rump.position.y, body_y + sin(_t * 2.0) * 0.006, delta * 8.0)   # 숨
		if state != "arch": rump.rotation.x = lerpf(rump.rotation.x, body_pitch, delta * 8.0)
	rotation.z = lerp_angle(rotation.z, roll, delta * 10.0)
	# 머리: 플레이어 보기, 그루밍(고개 옆구리로), 하품(입 대신 고개 젖힘), 걸을 때 까딱
	var hp := 0.0; var hy := 0.0
	if look:
		var to := head.global_transform.affine_inverse() * look_at_pos
		hy = clampf(atan2(to.x, to.z), -1.0, 1.0); hp = clampf(-atan2(to.y, Vector2(to.x, to.z).length()), -0.6, 0.5)
	if state == "groom": hy = 1.4; hp = 0.7
	elif state == "yawn": hp = -0.6
	elif moving: hp = sin(_phase) * 0.08
	elif state == "sit": hp = -0.1
	head.rotation.x = lerp_angle(head.rotation.x, hp, delta * 8.0)
	head.rotation.y = lerp_angle(head.rotation.y, hy, delta * 8.0)
	# 귀: 가끔 움찔, 플레이어 보면 세움
	for i in ears.size():
		var flick := 0.3 if fmod(_t * 0.7 + i, 4.0) < 0.15 else 0.0
		(ears[i] as Node3D).rotation.x = lerpf((ears[i] as Node3D).rotation.x, -0.25 * (1.0 if look else 0.0) + flick, delta * 10.0)
	# 꼬리: 개는 흔들고(기쁘면 빨리), 고양이는 느리게 휘고, 다람쥐는 세워서 떨림
	match kind:
		"dog":
			var wag := 8.0 if (look or state == "bow") else 3.0
			tail1.rotation.y = sin(_t * wag) * (0.7 if wag > 5.0 else 0.35); tail2.rotation.y = sin(_t * wag - 0.6) * 0.5
		"cat", "marten":
			tail1.rotation.y = sin(_t * 1.3) * 0.4; tail2.rotation.y = sin(_t * 1.3 - 1.0) * 0.6; tail1.rotation.x = -0.2 + (0.8 if state == "arch" else 0.0)
		_:
			tail1.rotation.x = -1.3 + sin(_t * 10.0) * 0.08; tail2.rotation.x = -0.5
