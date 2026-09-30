class_name Quad3D
extends Node3D
## 네발 동물 공용 리그 — 개·고양이·담비·다람쥐가 같은 뼈대를 크기·비율만 달리해 쓴다(운영자 2026-09-28: 동물이 생기면 최소한 이 동작들은 있어야).
## 척추 두 마디(가슴·엉덩이), 머리(귀·눈·주둥이), 다리 4개(위·아래), 꼬리 두 마디. 전부 캡슐·구. 코드로 움직인다.
## 상태: idle(숨·눈 깜빡·귀 움찔) · walk(4박자) · run(바운드: 앞다리 짝·뒷다리 짝, 척추가 늘었다 줄었다) · sit · lie · stretch(기지개)
##       · bow(놀자, 개) · roll(구르기, 개) · groom(그루밍, 고양이) · yawn · look(플레이어 보기) · arch(등 세우기, 고양이) · stalk(살금살금) · bite(물기)
##       · sniff(킁킁, 개) · scratch(뒷발로 귀 긁기) · shake(몸 털기, 개) · hurt(깨갱) · pet(쓰다듬어짐: 앉아서 손에 머리를 민다)
## 2026-09-28 동작 시트 검토: 무릎이 디딤 구간에 접혀 인형처럼 보이던 부호를 고치고(_leg_cycle), 걸음에 몸통 구름·고개 까딱·귀·꼬리가 따라오게, 앉기·엎드리기는 엉덩이부터 0.55초
## 다리 부호: 매달린 뼈는 rotation.x 가 + 면 발끝이 뒤(−z), − 면 앞(+z). 무릎 + 는 발이 뒤로 접힘. 앉기·엎드리기는 뒷다리를 앞으로 접어 몸 밑에 둔다.

var kind := "dog"
var color := Color("c9a27a")
var dark := Color("9a6a3f")
var state := "idle"
var speed := 0.0            # m/s — walk/run 위상에 쓴다
var look_at_pos := Vector3.ZERO
var look := false
var sulk := false            # 맞은 뒤: 꼬리 내림(town 이 켜고 끈다)
var _bang: Label3D
var _bang_until := -1.0
var carry := false          # 입에 뭔가 물고 간다(여우의 노획) — 고개를 들고 귀를 뒤로: 뛰는 사이클은 그대로, 머리만 다르다
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

## 로프트 튜브 — z 축을 따라 (z, 반지름, y 오프셋) 고리들을 잇는 한 덩어리 매끈한 메시. 몸통·목이 구슬을 이어 붙인 것처럼 보이던 것을 고친다(운영자 2026-09-28: "푸들마냥")
func _tube(parent: Node3D, rings: Array, c: Color, segs := 14) -> MeshInstance3D:
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts: Array = []
	for r in rings:
		var ring: Array = []
		for i in segs:
			var a := i * TAU / segs
			ring.append(Vector3(cos(a) * r[1], sin(a) * r[1] * (r[3] if r.size() > 3 else 1.0) + r[2], r[0]))
		pts.append(ring)
	for k in pts.size() - 1:
		for i in segs:
			var j := (i + 1) % segs
			var a: Vector3 = pts[k][i]; var b: Vector3 = pts[k][j]; var cc: Vector3 = pts[k + 1][i]; var d: Vector3 = pts[k + 1][j]
			st.add_vertex(a); st.add_vertex(cc); st.add_vertex(b)
			st.add_vertex(b); st.add_vertex(cc); st.add_vertex(d)
	# 양 끝 막기
	for end in [0, pts.size() - 1]:
		var ring: Array = pts[end]; var centre := Vector3(0, rings[end][2], rings[end][0])
		for i in segs:
			var j := (i + 1) % segs
			if end == 0: st.add_vertex(centre); st.add_vertex(ring[i]); st.add_vertex(ring[j])
			else: st.add_vertex(centre); st.add_vertex(ring[j]); st.add_vertex(ring[i])
	st.generate_normals(); st.index()
	var mi := MeshInstance3D.new(); mi.mesh = st.commit(); mi.material_override = _mat(c); parent.add_child(mi); return mi

## 다리 한 마디 — 위가 굵고 아래가 가는 원기둥(캡슐 구슬 대신)
func _leg_seg(parent: Node3D, r_top: float, r_bot: float, len: float, c: Color) -> MeshInstance3D:
	var cy := CylinderMesh.new(); cy.top_radius = r_top; cy.bottom_radius = r_bot; cy.height = len; cy.radial_segments = 10; cy.rings = 1
	return _mesh(parent, cy, Vector3(0, -len / 2.0, 0), Vector3.ZERO, c)

func _sphere(parent: Node3D, r: float, at: Vector3, c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); var sm := SphereMesh.new(); sm.radius = r; sm.height = r * 2.0; sm.radial_segments = 12; sm.rings = 6
	mi.mesh = sm; mi.material_override = _mat(c); mi.position = at; parent.add_child(mi); return mi

func _build() -> void:
	# 2026-09-28 스크린샷 검토(운영자: "동물 퀄리티 이상") — 몸통이 소시지처럼 굵고 목이 없어 양처럼 보였다. 굵기 0.24→0.19, 목 마디, 종별 주둥이·귀, 개 목걸이, 눈 하이라이트
	var thick := L * 0.19
	var t := thick
	rump = Node3D.new(); rump.position = Vector3(0, H, -L * 0.25); add_child(rump)
	# 몸통 전체를 엉덩이 노드 하나에 한 덩어리 로프트로(운영자 2026-09-29: "몸통 분해되잖아" — 두 토막이면 척추가 휠 때 갈라졌다). 가슴이 제일 깊고 목으로 좁아진다
	_tube(rump, [[-L * 0.5, t * 0.35, 0.05 * t], [-L * 0.42, t * 0.8, 0.0], [-L * 0.25, t * 1.0, -0.05 * t], [0.0, t * 1.02, -0.08 * t], [L * 0.22, t * 1.02, -0.07 * t], [L * 0.34, t * 1.08, -0.1 * t, 1.12], [L * 0.52, t * 1.02, -0.02 * t, 1.1], [L * 0.64, t * 0.8, 0.12 * t], [L * 0.72, t * 0.45, 0.35 * t]], color)
	spine = Node3D.new(); spine.position = Vector3(0, 0, L * 0.22); rump.add_child(spine)
	chest = Node3D.new(); chest.position = Vector3(0, 0, L * 0.22); spine.add_child(chest)
	var neck_l := L * (0.3 if kind in ["cat", "fox", "marten"] else 0.22)
	# 목: 가슴 앞·위에서 머리로 비스듬히 — 튜브가 몸에서 머리 속까지 이어진다(위로 뻗는 축은 rotation.x + 가 앞)
	var neck := Node3D.new(); neck.position = Vector3(0, thick * 0.35, L * 0.24); neck.rotation.x = 0.85; chest.add_child(neck)
	_tube(neck, [[-t * 0.3, t * 0.62, 0.0], [neck_l * 0.5, t * 0.58, 0.0], [neck_l + head_r * 0.5, t * 0.5, 0.0]], color, 12)
	head = Node3D.new(); head.position = Vector3(0, thick * 0.35, L * 0.24) + Vector3(0, cos(0.85), sin(0.85)) * neck_l; chest.add_child(head)
	var hs := SphereMesh.new(); hs.radius = head_r; hs.height = head_r * 2.0; hs.radial_segments = 16; hs.rings = 8
	_mesh(head, hs, Vector3.ZERO, Vector3.ZERO, color).scale = Vector3(1.0, 0.92, 1.12)   # 살짝 길쭉한 머리(구 그대로면 구슬)
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
		var hip := Node3D.new(); hip.position = Vector3(side * thick * 0.66, -thick * 0.3, (L * 0.12 if front else -L * 0.12)); parent.add_child(hip)
		_sphere(hip, thick * 0.42, Vector3(0, 0, 0), color)   # 허벅지 덩어리(몸에 묻힌다)
		_leg_seg(hip, thick * 0.36, thick * 0.26, leg * 0.5, color)
		var knee := Node3D.new(); knee.position = Vector3(0, -leg * 0.5, 0); hip.add_child(knee)
		_sphere(knee, thick * 0.26, Vector3.ZERO, color)
		_leg_seg(knee, thick * 0.25, thick * 0.2, leg * 0.5, color if kind != "fox" else Color("3a2f36"))
		var paw := _sphere(knee, thick * 0.28, Vector3(0, -leg * 0.5, thick * 0.08), dark if kind != "fox" else Color("3a2f36"))  # 발
		paw.scale = Vector3(1.0, 0.7, 1.25)
		legs[key] = { "hip": hip, "knee": knee }
	# 꼬리 두 마디 — 여우·다람쥐는 굵고 끝이 다른 색
	tail1 = Node3D.new(); tail1.position = Vector3(0, thick * 0.4, -L * 0.28); rump.add_child(tail1)
	var tl := L * (0.55 if kind in ["cat", "marten", "fox"] else 0.35)
	var bushy := kind in ["squirrel", "fox"]
	_capsule(tail1, thick * (0.4 if bushy else 0.22), tl * 0.5, Vector3(0, 0, -tl * 0.25), Vector3(PI / 2.0, 0, 0), color)
	tail2 = Node3D.new(); tail2.position = Vector3(0, 0, -tl * 0.5); tail1.add_child(tail2)
	_capsule(tail2, thick * (0.42 if bushy else 0.18), tl * 0.5, Vector3(0, 0, -tl * 0.25), Vector3(PI / 2.0, 0, 0), color if not bushy else (dark if kind == "squirrel" else Color("f7f4ef")))
	tail1.rotation.x = -0.9 if kind == "dog" else (-1.3 if kind == "squirrel" else -0.2)
	# 아플 때 머리 위 "!"
	_bang = Label3D.new(); _bang.text = "!"; _bang.font_size = 64; _bang.pixel_size = 0.003; _bang.modulate = Color("ff2d55")
	_bang.outline_size = 10; _bang.outline_modulate = Color("f7f4ef"); _bang.billboard = BaseMaterial3D.BILLBOARD_ENABLED; _bang.no_depth_test = true
	_bang.position = Vector3(0, H + head_r * 2.0 + 0.3, L * 0.3); _bang.visible = false; add_child(_bang)

## 잠깐의 동작 시작(stretch·bow·roll·groom·yawn·arch·sniff·scratch·shake·hurt·pet)
func act(name: String) -> void:
	state = name; _act_t = 0.0
	if name == "hurt": _bang.visible = true; _bang_until = _t + 0.8

var _idle_yaw := 0.0        # 둘러보기 목표(플레이어를 안 볼 때)
var _idle_next := 2.0
var _sway := 0.0            # 서 있을 때 무게 옮기기

## 걸음 한 다리 — 디딤(발이 뒤로 밀림, 곧게)과 휘두름(앞으로, 무릎 접혀 발이 든다). ph: 0 = 발이 가장 뒤에서 앞으로 나가기 시작
static func _leg_cycle(ph: float, reach: float, fold: float) -> Vector2:
	var swing := maxf(0.0, cos(ph))   # 앞으로 나가는 반 바퀴에만 접힌다(전엔 sin — 디딤 구간에 접혀 인형처럼 보였다)
	return Vector2(-sin(ph) * reach, 0.05 + swing * fold)

func _process(delta: float) -> void:
	_t += delta; _act_t += delta
	_blink -= delta
	if _blink <= 0.0:
		_blink = randf_range(2.0, 5.0)
	var blink_k := 1.0 if _blink > 0.12 else 0.15   # 0.12초 눈 감음
	if _bang.visible and _t > _bang_until: _bang.visible = false
	for e in eyes: e.scale = Vector3(1.0, blink_k, 1.0)
	var moving := speed > 0.05 and (state == "walk" or state == "run")
	if moving:
		_phase += speed * delta / (L * 1.6) * TAU
	var sw := sin(_phase); var cw := cos(_phase)
	var run := state == "run"
	var thick := L * 0.19
	# 척추·몸통: 달리면(바운드) 늘었다 줄었다, 걸으면 대각선 짝에 맞춰 살짝 구르고(z) 비틀린다(y)
	if run:
		spine.rotation.x = -sw * 0.12; rump.position.y = H + absf(cw) * 0.08 * (L / 0.6); rump.rotation.x = sw * 0.25   # 척추 휨은 작게 — 몸통이 한 덩어리라 앞다리·머리만 따라간다
		rump.rotation.y = 0.0; rump.rotation.z = lerp_angle(rump.rotation.z, 0.0, delta * 10.0)
	elif moving:
		spine.rotation.x = sin(_phase * 2.0) * 0.05; rump.position.y = H + absf(cw) * 0.02; rump.rotation.x = 0.0
		rump.rotation.y = sw * 0.06; rump.rotation.z = lerp_angle(rump.rotation.z, cw * 0.05, delta * 12.0)
	else:
		spine.rotation.x = lerpf(spine.rotation.x, 0.0, delta * 6.0)
		rump.rotation.y = lerpf(rump.rotation.y, 0.0, delta * 6.0)
	# 다리
	var sit_k := smoothstep(0.0, 1.0, _act_t / 0.55)          # 앉기·엎드리기는 0.55초에 걸쳐(전엔 스냅)
	var rear_k := smoothstep(0.0, 1.0, _act_t / 0.4)          # 엉덩이가 먼저 내려앉고
	var front_k := smoothstep(0.0, 1.0, (_act_t - 0.15) / 0.4)  # 앞다리는 조금 뒤에
	for key in legs.keys():
		var hip: Node3D = legs[key]["hip"]; var knee: Node3D = legs[key]["knee"]
		var front: bool = key.begins_with("f"); var left: bool = key.ends_with("l")
		var target_hip := 0.0; var target_knee := 0.05
		var rate := 14.0
		if run:
			# 바운드: 앞다리 짝, 뒷다리 짝(반대 위상), 왼오른은 살짝 어긋나게
			var lc := _leg_cycle(_phase + (0.0 if front else PI) + (0.15 if left else 0.0), 0.9, 1.1)
			target_hip = lc.x; target_knee = lc.y
		elif moving:
			# 4박자 걷기: 대각선 짝(왼앞·오른뒤)
			var lc := _leg_cycle(_phase + (0.0 if (front == left) else PI), 0.55, 0.85)
			target_hip = lc.x; target_knee = lc.y
		elif state == "stalk":
			var lc := _leg_cycle(_phase + (0.0 if (front == left) else PI), 0.35, 0.4)
			target_hip = lc.x + 0.2; target_knee = 0.9 + lc.y
		match state:
			"sit", "pet", "scratch":
				# 앉기: 앞다리 곧게, 뒷다리는 앞으로 접어 몸 밑에 — 엉덩이부터
				target_hip = 0.0 if front else -1.25 * rear_k; target_knee = 0.05 if front else 1.9 * rear_k; rate = 9.0
				if state == "scratch" and key == "bl":
					target_hip = -1.0 + sin(_act_t * 26.0) * 0.35; target_knee = 1.2; rate = 30.0   # 뒷발로 귀 긁기
			"lie", "groom":
				target_hip = -1.3 * front_k if front else -1.35 * rear_k; target_knee = 1.9 * front_k if front else 2.1 * rear_k; rate = 8.0
			"stretch":
				var k := sin(minf(_act_t, 1.6) / 1.6 * PI)
				target_hip = (-1.3 * k) if front else (0.15 * k); target_knee = 0.05
			"bow":
				var k := minf(_act_t / 0.4, 1.0)
				target_hip = (-1.2 * k) if front else 0.1; target_knee = (0.9 * k) if front else 0.05
			"roll":
				target_hip = -0.8 + sin(_act_t * 9.0) * 0.2; target_knee = 1.2
			"arch":
				target_hip = 0.0; target_knee = 0.1
			"bite":
				target_hip = (-0.6) if front else 0.4; target_knee = 0.4
			"hurt":
				# 깨갱: 움츠러들며 네 다리를 굽힌다
				target_hip = 0.3 if front else -0.25; target_knee = 0.6; rate = 20.0
			"shake":
				target_hip = 0.1 if front else -0.1; target_knee = 0.3
			"idle":
				# 무게 옮기기: 한쪽 다리에 힘을 뺀다
				target_hip = _sway * (0.08 if left else -0.08); target_knee = 0.05 + maxf(0.0, _sway * (1.0 if left else -1.0)) * 0.12; rate = 4.0
		hip.rotation.x = lerp_angle(hip.rotation.x, target_hip, delta * rate)
		knee.rotation.x = lerp_angle(knee.rotation.x, target_knee, delta * rate)
	# 몸통 자세
	var body_y := H; var body_pitch := 0.0; var roll := 0.0; var body_rate := 8.0
	match state:
		"sit", "pet", "scratch":
			# 엉덩이는 낮게(몸통 반지름), 가슴은 앞다리 길이만큼 위 — 파묻히지 않게 다리 길이에서 계산
			body_y = lerpf(H, thick + 0.02, sit_k); body_pitch = -atan2(H - thick, L * 0.44) * sit_k; body_rate = 12.0
			if state == "scratch":
				roll = 0.12; if _act_t > 1.6: state = "idle"
		"lie", "groom":
			body_y = lerpf(H, thick + 0.02, sit_k); body_pitch = 0.0; body_rate = 12.0
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
			body_y = H * 1.05; spine.rotation.x = 0.2; rump.rotation.x = -0.3
			if _act_t > 1.2: state = "idle"
		"stalk":
			body_y = H * 0.75
		"bite":
			var k := sin(minf(_act_t, 0.5) / 0.5 * PI); body_y = H + 0.05 * k; body_pitch = 0.35 * k
			if _act_t > 0.55: state = "idle"
		"yawn":
			if _act_t > 1.0: state = "idle"
		"sniff":
			# 킁킁: 코를 땅에 대고 좌우로
			body_y = H * 0.92; body_pitch = 0.12
			if _act_t > 1.8: state = "idle"
		"shake":
			# 몸 털기: 몸통이 좌우로 빠르게 비틀린다(0.7초), 귀가 펄럭인다
			roll = sin(_act_t * 40.0) * 0.3 * (1.0 if _act_t < 0.7 else 0.0)
			if _act_t > 0.8: state = "idle"
		"hurt":
			# 깨갱(운영자: 아파해야): 0.12초 움찔 뛰어오른 뒤 0.5초 웅크린다 — 엉덩이는 내려가고 고개는 든다
			var k := sin(minf(_act_t, 0.6) / 0.6 * PI); var hop := maxf(0.0, sin(_act_t / 0.24 * PI)) * (1.0 if _act_t < 0.24 else 0.0)
			body_y = H - 0.3 * H * k + hop * 0.12; body_pitch = -0.35 * k; body_rate = 30.0
			if _act_t > 0.6: state = "idle"
	if not moving and state != "run" and state != "walk":
		rump.position.y = lerpf(rump.position.y, body_y + sin(_t * 2.0) * 0.006, delta * body_rate)   # 숨
		if state != "arch": rump.rotation.x = lerpf(rump.rotation.x, body_pitch, delta * body_rate)
	if not moving: rump.rotation.z = lerp_angle(rump.rotation.z, roll, delta * 10.0)   # 몸통 축으로 구른다(루트를 돌리면 땅 밑으로 들어갔다)
	# 서 있을 때 살아 있기: 무게를 천천히 옮기고, 플레이어를 안 볼 땐 가끔 둘러본다
	if state == "idle":
		_sway = lerpf(_sway, sin(_t * 0.6), delta * 2.0)
		_idle_next -= delta
		if _idle_next <= 0.0: _idle_next = randf_range(2.0, 5.0); _idle_yaw = randf_range(-0.8, 0.8) if randf() < 0.6 else 0.0
	else:
		_sway = lerpf(_sway, 0.0, delta * 4.0)
	# 머리: 플레이어 보기, 그루밍(고개 옆구리로), 하품(고개 젖힘), 킁킁(땅), 쓰다듬으면 손에 머리를 밀어 올리며 갸웃, 걸을 때 까딱
	var hp := 0.0; var hy := 0.0; var hz := 0.0
	if look:
		var to := head.global_transform.affine_inverse() * look_at_pos
		hy = clampf(atan2(to.x, to.z), -1.0, 1.0); hp = clampf(-atan2(to.y, Vector2(to.x, to.z).length()), -0.6, 0.5)
	elif state == "idle":
		hy = _idle_yaw
	match state:
		"groom": hy = 1.4; hp = 0.7
		"yawn": hp = -0.6
		"hurt": hp = -0.7
		"stalk": hp = 0.35
		"sniff": hp = 0.75; hy = sin(_t * 5.0) * 0.35
		"scratch": hz = -0.3; hy = -0.5
		"pet": hz = 0.35; hp = -0.35 + sin(_t * 4.0) * 0.15
		"bite": hp = 0.5 * sin(minf(_act_t, 0.5) / 0.5 * PI) - 0.3
		"lie": hp = 0.45 if _act_t > 2.5 else 0.0   # 한참 엎드리면 턱을 앞발에 얹는다
		"sit": hp = -0.1
	if carry: hp = -0.3   # 입에 문 채(여우 노획, CI run 69): 고개를 든다
	if moving: hp += cw * 0.06 * (1.0 if not run else 2.0); hy += sw * 0.04   # 걸음에 맞춰 고개가 까딱이고 살짝 좌우로
	head.rotation.x = lerp_angle(head.rotation.x, hp, delta * 8.0)
	head.rotation.y = lerp_angle(head.rotation.y, hy, delta * 8.0)
	head.rotation.z = lerp_angle(head.rotation.z, hz, delta * 6.0)
	# 귀: 가끔 움찔, 플레이어 보면 세움, 걸으면 까딱, 털면 펄럭, 아프면·삐치면 눕힌다
	for i in ears.size():
		var flick := 0.3 if fmod(_t * 0.7 + i, 4.0) < 0.15 else 0.0
		var bounce := (absf(cw) * 0.12 if moving else 0.0) + (sin(_act_t * 40.0 + i * PI) * 0.4 if state == "shake" else 0.0)
		(ears[i] as Node3D).rotation.x = lerpf((ears[i] as Node3D).rotation.x, -0.25 * (1.0 if look else 0.0) + flick + bounce + (0.4 if carry else 0.0) + (0.8 if (state == "hurt" or sulk) else 0.0), delta * 10.0)
	# 꼬리: 개는 흔들고(기쁘면 빨리, 걸으면 느슨하게 좌우), 고양이는 세워 끝을 말고, 여우는 낮게 곧게, 다람쥐는 세워서 떨림
	match kind:
		"dog":
			var wag := 8.0 if (look or state == "bow" or state == "pet") else (3.0 if not moving else 4.0)
			if sulk or state == "hurt": wag = 0.0
			tail1.rotation.y = sin(_t * wag) * (0.7 if wag > 5.0 else 0.35) + (sw * 0.2 if moving else 0.0); tail2.rotation.y = sin(_t * wag - 0.6) * 0.5
			tail1.rotation.x = lerpf(tail1.rotation.x, 0.5 if (sulk or state == "hurt") else -0.9, delta * 6.0)   # 꼬리를 다리 사이로
		"cat":
			tail1.rotation.y = sin(_t * 1.3) * 0.3; tail2.rotation.y = sin(_t * 2.1 - 1.0) * 0.5
			tail1.rotation.x = lerpf(tail1.rotation.x, (-1.0 if state != "arch" else -0.3) + (0.6 if (sulk or state == "hurt") else 0.0), delta * 4.0)   # 세운 꼬리
			tail2.rotation.x = lerpf(tail2.rotation.x, 0.8 + sin(_t * 1.7) * 0.25, delta * 4.0)   # 끝이 말린다
		"marten", "fox":
			tail1.rotation.y = sin(_t * 1.3) * 0.4; tail2.rotation.y = sin(_t * 1.3 - 1.0) * 0.6
			tail1.rotation.x = (-0.2 if kind != "fox" else 0.1) + (0.8 if state == "arch" else 0.0) + (0.5 if (sulk or state == "hurt") else 0.0)
		_:
			tail1.rotation.x = -1.3 + sin(_t * 10.0) * 0.08; tail2.rotation.x = -0.5
