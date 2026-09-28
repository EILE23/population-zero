class_name Quad3D
extends Node3D
## 네발 동물 공용 리그 — 개·고양이·담비·다람쥐가 같은 뼈대를 크기·비율만 달리해 쓴다(운영자 2026-09-28: 동물이 생기면 최소한 이 동작들은 있어야).
## 척추 두 마디(가슴·엉덩이), 머리(귀·눈·주둥이), 다리 4개(위·아래), 꼬리 두 마디. 전부 캡슐·구. 코드로 움직인다.
## 상태: idle(숨·눈 깜빡·귀 움찔) · walk(4박자) · run(바운드: 앞다리 짝·뒷다리 짝, 척추가 늘었다 줄었다) · sit · lie · stretch(기지개)
##       · bow(놀자, 개) · roll(구르기, 개) · groom(그루밍, 고양이) · yawn · look(플레이어 보기) · arch(등 세우기, 고양이) · stalk(살금살금) · bite(물기)
## 다리 부호: 매달린 뼈는 rotation.x 가 + 면 발끝이 뒤(−z), − 면 앞(+z). 무릎 + 는 발이 뒤로 접힘. 앉기·엎드리기는 뒷다리를 앞으로 접어 몸 밑에 둔다.

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
		"fox": L = 0.58; H = 0.32; leg = 0.27; head_r = 0.11
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

func _mesh(parent: Node3D, mesh: Mesh, at: Vector3, rot: Vector3, c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); mi.mesh = mesh; mi.material_override = _mat(c); mi.position = at; mi.rotation = rot; parent.add_child(mi); return mi

func _sphere(parent: Node3D, r: float, at: Vector3, c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); var sm := SphereMesh.new(); sm.radius = r; sm.height = r * 2.0; sm.radial_segments = 12; sm.rings = 6
	mi.mesh = sm; mi.material_override = _mat(c); mi.position = at; parent.add_child(mi); return mi

func _build() -> void:
	# 2026-09-28 스크린샷 검토(운영자: "동물 퀄리티 이상") — 몸통이 소시지처럼 굵고 목이 없어 양처럼 보였다. 굵기 0.24→0.19, 목 마디, 종별 주둥이·귀, 개 목걸이, 눈 하이라이트
	var thick := L * 0.19
	rump = Node3D.new(); rump.position = Vector3(0, H, -L * 0.25); add_child(rump)
	_capsule(rump, thick, L * 0.45, Vector3(0, 0, 0), Vector3(PI / 2.0, 0, 0), color)
	spine = Node3D.new(); spine.position = Vector3(0, 0, L * 0.22); rump.add_child(spine)
	chest = Node3D.new(); chest.position = Vector3(0, 0, L * 0.22); spine.add_child(chest)
	_capsule(chest, thick * 1.05, L * 0.45, Vector3.ZERO, Vector3(PI / 2.0, 0, 0), color)
	# 목: 가슴 앞·위에서 머리로 비스듬히(위로 뻗는 뼈는 rotation.x + 가 앞). 여우·고양이는 길고 개는 짧다
	var neck_l := L * (0.3 if kind in ["cat", "fox", "marten"] else 0.22)
	_capsule(chest, thick * 0.6, neck_l, Vector3(0, thick * 0.35, L * 0.24) + Vector3(0, cos(0.85), sin(0.85)) * neck_l * 0.5, Vector3(0.85, 0, 0), color)
	head = Node3D.new(); head.position = Vector3(0, thick * 0.35, L * 0.24) + Vector3(0, cos(0.85), sin(0.85)) * neck_l; chest.add_child(head)
	_sphere(head, head_r, Vector3.ZERO, color)
	# 주둥이: 개·여우는 길고, 고양이는 짧고 둥글게. 코는 잉크 점
	var mz := 1.0 if kind in ["dog", "fox"] else (0.75 if kind == "marten" else 0.55)
	var mz_c := Color("f7f4ef") if kind == "fox" else color
	_capsule(head, head_r * 0.42, head_r * mz, Vector3(0, -head_r * 0.3, head_r * (0.6 + mz * 0.35)), Vector3(PI / 2.0, 0, 0), mz_c)
	_sphere(head, head_r * 0.16, Vector3(0, -head_r * 0.25, head_r * (0.6 + mz * 0.85)), Color("1b0c15"))  # 코
	for ex in [-1.0, 1.0]:
		var e := Node3D.new(); e.position = Vector3(ex * head_r * 0.48, head_r * 0.28, head_r * 0.72); head.add_child(e)
		_sphere(e, head_r * 0.17, Vector3.ZERO, Color("1b0c15")); eyes.append(e)
		_sphere(e, head_r * 0.06, Vector3(ex * head_r * 0.04, head_r * 0.06, head_r * 0.13), Color("f7f4ef"))  # 눈 하이라이트
		var ear := Node3D.new(); head.add_child(ear); ears.append(ear)
		if kind == "dog":
			# 처진 귀: 머리 옆에서 아래로 늘어진 납작한 캡슐
			ear.position = Vector3(ex * head_r * 0.8, head_r * 0.45, -head_r * 0.05)
			var er := _capsule(ear, head_r * 0.24, head_r * 0.85, Vector3(ex * head_r * 0.12, -head_r * 0.35, 0), Vector3(0, 0, ex * 0.35), dark)
			er.scale = Vector3(1.0, 1.0, 0.45)
		else:
			# 뾰족 귀: 원뿔. 여우는 크게
			var big := 1.35 if kind == "fox" else 1.0
			ear.position = Vector3(ex * head_r * 0.55, head_r * 0.8, -head_r * 0.05)
			var cone := CylinderMesh.new(); cone.top_radius = 0.0; cone.bottom_radius = head_r * 0.26 * big; cone.height = head_r * 0.62 * big; cone.radial_segments = 8
			_mesh(ear, cone, Vector3(0, head_r * 0.25 * big, 0), Vector3(0.15, 0, ex * -0.25), dark if kind != "fox" else Color("3a2f36"))
	if kind == "dog":
		# 목걸이 — 반려견으로 읽히게(운영자: AC 느낌)
		var ring := TorusMesh.new(); ring.inner_radius = thick * 0.62; ring.outer_radius = thick * 0.78
		_mesh(chest, ring, Vector3(0, thick * 0.35, L * 0.24) + Vector3(0, cos(0.85), sin(0.85)) * neck_l * 0.35, Vector3(0.85, 0, 0), Color("ff2d55"))
	# 다리: 어깨·엉덩이에서 아래로. 위·아래 두 마디, 한 색, 발만 어둡게(전엔 아랫마디가 어두워 장화처럼 보였다)
	for key in ["fl", "fr", "bl", "br"]:
		var front: bool = key.begins_with("f"); var side := -1.0 if key.ends_with("l") else 1.0
		var parent := chest if front else rump
		var hip := Node3D.new(); hip.position = Vector3(side * thick * 0.72, -thick * 0.3, (L * 0.12 if front else -L * 0.12)); parent.add_child(hip)
		_capsule(hip, thick * 0.3, leg * 0.5, Vector3(0, -leg * 0.25, 0), Vector3.ZERO, color)
		var knee := Node3D.new(); knee.position = Vector3(0, -leg * 0.5, 0); hip.add_child(knee)
		_capsule(knee, thick * 0.26, leg * 0.5, Vector3(0, -leg * 0.25, 0), Vector3.ZERO, color if kind != "fox" else Color("3a2f36"))
		_sphere(knee, thick * 0.3, Vector3(0, -leg * 0.5, thick * 0.1), dark if kind != "fox" else Color("3a2f36"))  # 발
		legs[key] = { "hip": hip, "knee": knee }
	# 꼬리 두 마디 — 여우·다람쥐는 굵고 끝이 다른 색
	tail1 = Node3D.new(); tail1.position = Vector3(0, thick * 0.4, -L * 0.28); rump.add_child(tail1)
	var tl := L * (0.55 if kind in ["cat", "marten", "fox"] else 0.35)
	var bushy := kind in ["squirrel", "fox"]
	_capsule(tail1, thick * (0.4 if bushy else 0.22), tl * 0.5, Vector3(0, 0, -tl * 0.25), Vector3(PI / 2.0, 0, 0), color)
	tail2 = Node3D.new(); tail2.position = Vector3(0, 0, -tl * 0.5); tail1.add_child(tail2)
	_capsule(tail2, thick * (0.42 if bushy else 0.18), tl * 0.5, Vector3(0, 0, -tl * 0.25), Vector3(PI / 2.0, 0, 0), color if not bushy else (dark if kind == "squirrel" else Color("f7f4ef")))
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
			# 바운드: 앞다리 짝, 뒷다리 짝(반대 위상). 뻗는 순간(앞) 곧고, 돌아올 때(뒤) 발이 뒤로 접힌다
			var ph := _phase + (0.0 if front else PI) + (0.15 if left else 0.0)
			target_hip = -sin(ph) * 0.9; target_knee = 0.3 + maxf(0.0, sin(ph)) * 1.1
		elif moving:
			# 4박자 걷기: 대각선 짝(왼앞·오른뒤). 앞으로 나갈 땐 곧고 뒤로 갈 땐 발이 살짝 접혀 들린다
			var ph := _phase + (0.0 if (front == left) else PI)
			target_hip = -sin(ph) * 0.55; target_knee = 0.1 + maxf(0.0, sin(ph)) * 0.8
		elif state == "stalk":
			# 살금살금: 무릎 굽혀 낮게, 느린 걷기
			var ph := _phase + (0.0 if (front == left) else PI)
			target_hip = -sin(ph) * 0.35 + 0.2; target_knee = 0.9 + maxf(0.0, sin(ph)) * 0.4
		match state:
			"sit":
				# 앉기: 앞다리 곧게, 뒷다리는 앞으로 접어 몸 밑에
				target_hip = 0.0 if front else -1.25; target_knee = 0.0 if front else 1.9
			"lie", "groom":
				# 엎드리기(스핑크스): 네 다리 다 앞으로 접어 몸 밑에
				target_hip = -1.3 if front else -1.35; target_knee = 1.9 if front else 2.1
			"stretch":
				# 기지개: 앞다리 앞으로 쭉 뻗어 가슴을 낮추고, 뒷다리는 곧게 서서 엉덩이를 올린다
				var k := sin(minf(_act_t, 1.6) / 1.6 * PI)
				target_hip = (-1.3 * k) if front else (0.15 * k); target_knee = 0.05 if front else 0.05
			"bow":
				# 놀자(개): 기지개와 같은 골격, 팔꿈치를 바닥에
				var k := minf(_act_t / 0.4, 1.0)
				target_hip = (-1.2 * k) if front else 0.1; target_knee = (0.9 * k) if front else 0.05
			"roll":
				# 구르기: 다리는 몸에 붙여 접고 살짝 허우적
				target_hip = -0.8 + sin(_act_t * 9.0) * 0.2; target_knee = 1.2
			"arch":
				target_hip = 0.0; target_knee = 0.1
			"bite":
				target_hip = (-0.6) if front else 0.4; target_knee = 0.4
		hip.rotation.x = lerp_angle(hip.rotation.x, target_hip, delta * 14.0)
		knee.rotation.x = lerp_angle(knee.rotation.x, target_knee, delta * 14.0)
	# 몸통 자세(앉기·엎드리기·기지개·놀자·구르기·등 세우기)
	var thick := L * 0.24
	var body_y := H; var body_pitch := 0.0; var roll := 0.0
	match state:
		"sit":
			# 엉덩이는 낮게(몸통 반지름), 가슴은 앞다리 길이만큼 위 — 파묻히지 않게 다리 길이에서 계산
			body_y = thick + 0.02; body_pitch = -atan2(H - thick, L * 0.44)
		"lie", "groom":
			body_y = thick + 0.02; body_pitch = 0.0
			if state == "groom" and _act_t > 2.2: state = "idle"
		"stretch":
			var k := sin(minf(_act_t, 1.6) / 1.6 * PI); body_y = H + 0.06 * k; body_pitch = 0.45 * k
			if _act_t > 1.7: state = "idle"
		"bow":
			var k := minf(_act_t / 0.4, 1.0); body_y = H + 0.04 * k; body_pitch = 0.5 * k
			if _act_t > 1.6: state = "idle"
		"roll":
			roll = sin(minf(_act_t, 1.4) / 1.4 * PI) * PI; body_y = thick + 0.05
			if _act_t > 1.5: state = "idle"
		"arch":
			body_y = H * 1.05; spine.rotation.x = 0.55; rump.rotation.x = -0.3
			if _act_t > 1.2: state = "idle"
		"stalk":
			body_y = H * 0.75
		"bite":
			var k := sin(minf(_act_t, 0.5) / 0.5 * PI); body_y = H + 0.05 * k; body_pitch = 0.35 * k
			if _act_t > 0.55: state = "idle"
		"yawn":
			if _act_t > 1.0: state = "idle"
	if not moving and state != "run" and state != "walk":
		rump.position.y = lerpf(rump.position.y, body_y + sin(_t * 2.0) * 0.006, delta * 8.0)   # 숨
		if state != "arch": rump.rotation.x = lerpf(rump.rotation.x, body_pitch, delta * 8.0)
	rump.rotation.z = lerp_angle(rump.rotation.z, roll, delta * 10.0)   # 몸통 축으로 구른다 — 루트(원점 = 발끝)를 돌리면 몸이 땅 밑으로 들어갔다(운영자 지적 2026-09-28)
	# 머리: 플레이어 보기, 그루밍(고개 옆구리로), 하품(입 대신 고개 젖힘), 걸을 때 까딱
	var hp := 0.0; var hy := 0.0
	if look:
		var to := head.global_transform.affine_inverse() * look_at_pos
		hy = clampf(atan2(to.x, to.z), -1.0, 1.0); hp = clampf(-atan2(to.y, Vector2(to.x, to.z).length()), -0.6, 0.5)
	if state == "groom": hy = 1.4; hp = 0.7
	elif state == "yawn": hp = -0.6
	elif state == "stalk": hp = 0.35
	elif state == "bite": hp = 0.5 * sin(minf(_act_t, 0.5) / 0.5 * PI) - 0.3
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
		"cat", "marten", "fox":
			# 여우가 다람쥐 가지(꼬리 세움)로 떨어지던 버그 — 고양이처럼 낮게 휜다
			tail1.rotation.y = sin(_t * 1.3) * 0.4; tail2.rotation.y = sin(_t * 1.3 - 1.0) * 0.6; tail1.rotation.x = (-0.2 if kind != "fox" else 0.1) + (0.8 if state == "arch" else 0.0)
		_:
			tail1.rotation.x = -1.3 + sin(_t * 10.0) * 0.08; tail2.rotation.x = -0.5
