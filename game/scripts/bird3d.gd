class_name Bird3D
extends Node3D
## 새 공용 리그 — 비둘기·오리(·나중에 참새·까마귀)가 같은 뼈대를 크기·색만 달리해 쓴다(운영자 2026-09-28: 동물은 덩어리가 아니다).
## 몸(가로 캡슐)·목 위 머리(구+부리 원뿔+눈)·날개 둘(납작한 상자, 날면 퍼덕임)·꼬리(납작한 쐐기)·다리 둘(가는 캡슐+발).
## 상태는 바깥(town_systems)이 채운다: speed(걷기 위상), flying(날개), swimming(다리 숨김·물결 흔들림), feed(고개 숙여 먹기).
## 쪼기(peck)는 서 있을 때 리그가 스스로 한다 — 새는 가만히 있어도 고개를 까딱인다.

var kind := "pigeon"
var color := Color("8a7f86")
var dark := Color("5b4f56")
var speed := 0.0
var flying := false
var swimming := false
var feed := false
var _t := 0.0
var _phase := 0.0
var _peck_next := 1.0
var _peck_t := 9.0       # 쪼기 진행(초) — 9 = 쉼

# 비율(몸통 길이 L)
var L := 0.2
var H := 0.09     # 몸통 중심 높이(서 있을 때)

var body: Node3D
var head: Node3D
var tail: Node3D
var wings: Array[Node3D] = []
var legs: Array[Node3D] = []

func setup(k: String, c: Color, d: Color) -> void:
	kind = k; color = c; dark = d
	match k:
		"duck": L = 0.34; H = 0.14
		_: L = 0.2; H = 0.09
	_build()

func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.albedo_color = c
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON; m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED; m.roughness = 1.0
	return m

func _mesh(parent: Node3D, mesh: Mesh, at: Vector3, rot: Vector3, c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); mi.mesh = mesh; mi.material_override = _mat(c); mi.position = at; mi.rotation = rot; parent.add_child(mi); return mi

func _build() -> void:
	var r := L * 0.3
	body = Node3D.new(); body.position = Vector3(0, H, 0); add_child(body)
	var bc := CapsuleMesh.new(); bc.radius = r; bc.height = L; bc.radial_segments = 12; bc.rings = 5
	_mesh(body, bc, Vector3.ZERO, Vector3(PI / 2.0, 0, 0), color)
	# 머리: 몸 앞·위, 목 없이 붙어도 새는 그렇게 생겼다. 오리는 목이 길다
	head = Node3D.new(); head.position = Vector3(0, r * (1.6 if kind == "duck" else 1.1), L * 0.42); body.add_child(head)
	if kind == "duck":
		var nc := CapsuleMesh.new(); nc.radius = r * 0.45; nc.height = r * 1.8
		_mesh(body, nc, Vector3(0, r * 0.9, L * 0.4), Vector3(0.25, 0, 0), color)   # 목
	var hr := r * (0.7 if kind == "duck" else 0.75)
	var hs := SphereMesh.new(); hs.radius = hr; hs.height = hr * 2.0; hs.radial_segments = 12; hs.rings = 6
	_mesh(head, hs, Vector3.ZERO, Vector3.ZERO, color if kind != "duck" else color.darkened(0.08))
	# 부리: 원뿔(비둘기) 또는 납작한 상자(오리)
	if kind == "duck":
		var bk := BoxMesh.new(); bk.size = Vector3(hr * 0.9, hr * 0.3, hr * 1.3)
		_mesh(head, bk, Vector3(0, -hr * 0.15, hr * 1.2), Vector3.ZERO, Color("d98a2a"))
	else:
		var bk := CylinderMesh.new(); bk.top_radius = 0.0; bk.bottom_radius = hr * 0.28; bk.height = hr * 0.8; bk.radial_segments = 8
		_mesh(head, bk, Vector3(0, -hr * 0.1, hr * 1.1), Vector3(PI / 2.0, 0, 0), Color("d98a2a"))
	for ex in [-1.0, 1.0]:
		var es := SphereMesh.new(); es.radius = hr * 0.18; es.height = hr * 0.36; es.radial_segments = 8; es.rings = 4
		var e := _mesh(head, es, Vector3(ex * hr * 0.55, hr * 0.2, hr * 0.7), Vector3.ZERO, Color("1b0c15"))
		var ws := SphereMesh.new(); ws.radius = hr * 0.06; ws.height = hr * 0.12; ws.radial_segments = 6; ws.rings = 3
		_mesh(e, ws, Vector3(ex * hr * 0.04, hr * 0.06, hr * 0.14), Vector3.ZERO, Color("f7f4ef"))   # 눈 하이라이트(귀여움)
	# 날개: 몸 옆에 납작한 판, 어깨(앞·위)에 피벗 — 날면 퍼덕이고 접으면 몸에 붙는다
	for ex in [-1.0, 1.0]:
		var w := Node3D.new(); w.position = Vector3(ex * r * 0.75, r * 0.45, L * 0.1); body.add_child(w)
		var wb := BoxMesh.new(); wb.size = Vector3(r * 1.1, r * 0.18, L * 0.62)
		_mesh(w, wb, Vector3(ex * r * 0.4, -r * 0.1, -L * 0.18), Vector3(0.12, 0, ex * -0.25), dark)
		wings.append(w)
	# 꼬리: 뒤로 뻗은 납작한 쐐기(오리는 살짝 들려 있다)
	tail = Node3D.new(); tail.position = Vector3(0, r * 0.2, -L * 0.45); body.add_child(tail)
	var tb := BoxMesh.new(); tb.size = Vector3(r * 0.9, r * 0.15, L * 0.35)
	_mesh(tail, tb, Vector3(0, 0, -L * 0.15), Vector3.ZERO, dark)
	tail.rotation.x = -0.35 if kind == "duck" else -0.15
	# 다리: 가는 주황 캡슐 + 납작한 발
	for ex in [-1.0, 1.0]:
		var lg := Node3D.new(); lg.position = Vector3(ex * r * 0.4, -r * 0.6, L * 0.02); body.add_child(lg)
		var lc := CapsuleMesh.new(); lc.radius = r * 0.09; lc.height = H - r * 0.6 + r * 0.2
		_mesh(lg, lc, Vector3(0, -(H - r * 0.6) / 2.0, 0), Vector3.ZERO, Color("d98a2a"))
		var fb := BoxMesh.new(); fb.size = Vector3(r * 0.5, r * 0.08, r * 0.7)
		_mesh(lg, fb, Vector3(0, -(H - r * 0.6), r * 0.2), Vector3.ZERO, Color("d98a2a"))
		legs.append(lg)

func _process(delta: float) -> void:
	_t += delta
	var walking := speed > 0.05 and not flying and not swimming
	if walking:
		_phase += speed * delta / (L * 1.2) * TAU
	# 몸: 걸으면 좌우로 뒤뚱(오리답게), 헤엄치면 물결에 흔들, 날면 앞으로 기운다
	var waddle := sin(_phase) * (0.16 if kind == "duck" else 0.06) if walking else 0.0
	body.rotation.z = lerpf(body.rotation.z, waddle, minf(1.0, delta * 12.0))
	var pitch := -0.35 if flying else (sin(_t * 2.6) * 0.04 if swimming else 0.0)
	body.rotation.x = lerpf(body.rotation.x, pitch, minf(1.0, delta * 8.0))
	body.position.y = H + (absf(sin(_phase)) * 0.008 if walking else 0.0) - (0.06 if swimming else 0.0)
	# 날개: 날면 크게 퍼덕, 아니면 접힘
	var flap := sin(_t * 22.0) * 0.9 if flying else 0.0
	for i in wings.size():
		var w := wings[i]; var ex := -1.0 if i == 0 else 1.0
		w.rotation.z = lerpf(w.rotation.z, ex * flap, minf(1.0, delta * 30.0))
	# 다리: 걸으면 번갈아 앞뒤, 날면 뒤로 접힘, 헤엄치면 물속(숨김)
	for i in legs.size():
		var lg := legs[i]; var ph := _phase + (0.0 if i == 0 else PI)
		lg.visible = not swimming
		lg.rotation.x = lerpf(lg.rotation.x, (-sin(ph) * 0.6 if walking else (1.2 if flying else 0.0)), minf(1.0, delta * 14.0))
	# 머리: 걸으면 까딱(비둘기), 서 있으면 가끔 쪼기, 먹을 땐 물속으로 숙임, 날면 앞을 본다
	var hx := 0.0
	if feed:
		hx = 0.9 + sin(_t * 5.0) * 0.1
	elif flying:
		hx = 0.25
	elif walking:
		hx = absf(sin(_phase * 0.5)) * (0.35 if kind != "duck" else 0.12)
	else:
		_peck_next -= delta
		if _peck_next <= 0.0 and _peck_t >= 9.0:
			_peck_t = 0.0; _peck_next = randf_range(1.5, 4.0)
		if _peck_t < 0.5:
			_peck_t += delta; hx = sin(_peck_t / 0.5 * PI) * 0.8
		else:
			_peck_t = 9.0; hx = sin(_t * 1.8) * 0.05
	head.rotation.x = lerpf(head.rotation.x, hx, minf(1.0, delta * 16.0))
	# 꼬리: 오리는 흔들고, 비둘기는 가만
	tail.rotation.x = (-0.35 + sin(_t * 9.0) * 0.2) if (kind == "duck" and (swimming or walking)) else (-0.35 if kind == "duck" else -0.15)
