extends Node3D
## 3D 마을 시제품 — 오메가루비 식 3/4 시점(운영자 2026-09-28: "최소한 오메가루비 같은 퀄리티"). 전부 코드로 만든 기하:
## 속이 빈 집(벽 네 장, 창은 기하, 경첩 달린 문짝 — 열고 들어간다), 기둥+구 나무, 타일 바닥과 자갈길, 벤치·가로등·울타리,
## 방향광 하나와 그림자, 툰 확산, 입체 졸라맨(Stick3D). 상호작용은 C 하나: 들고 있으면 내려놓기, 아니면 가까운 것부터 — 물건 집기 · 문 열닫기 · 벤치 앉기.

const TILE := 2.0
const WALK := 2.6
const G := 22.0
## 점프는 짧은 홉(Climb 의 힘 모으기는 마을에 안 맞는다) — 벤치(0.45m)·계단·낮은 담 위에 올라설 만큼, 집 벽은 못 넘는다
const HOP := 5.4
const WALL := 0.16

var player: Stick3D
var body: CharacterBody3D
var cam: Camera3D
var last_tap := ""
var last_tap_at := -1.0
var dash_until := -1.0
var action_until := 0.0
var seat: Dictionary = {}       # 앉아 있는 벤치 {pos, yaw}
var items: Array[Node3D] = []   # 바닥에 있는 집을 수 있는 것
var benches: Array = []         # {pos: Vector3, yaw: float}
var doors: Array = []           # {hinge: Node3D, open: bool, pos: Vector3}

func _ready() -> void:
	_light()
	_ground()
	_solid_floor()
	_path(Vector3(-14, 0, 2), Vector3(14, 0, 2), 2.4)
	_path(Vector3(0, 0, 2), Vector3(0, 0, -10), 2.0)
	_house(Vector3(-7, 0, -4), Vector3(4.0, 2.6, 3.4), Color("dfe6ea"), "accent-deep")
	_house(Vector3(0.5, 0, -6), Vector3(3.4, 3.1, 3.2), Color("f7f4ef"), "brick")
	_house(Vector3(7, 0, -4), Vector3(5.0, 2.4, 3.8), Color("e6d3a5"), "iron")
	_house(Vector3(-12, 0, -8), Vector3(3.6, 2.8, 3.2), Color("b56a5a"), "wood")
	for p in [Vector3(-11, 0, -1), Vector3(-3.5, 0, -1.5), Vector3(4, 0, -1), Vector3(11, 0, -1.5), Vector3(-9, 0, 5), Vector3(9, 0, 5.5), Vector3(13, 0, -7)]:
		_tree(p, 1.0 + fmod(absf(p.x) * 0.37, 0.5))
	_bench(Vector3(-4, 0, 4.2)); _bench(Vector3(4, 0, 4.2))
	_lamp(Vector3(-1.6, 0, 3.6)); _lamp(Vector3(1.6, 0, 3.6)); _lamp(Vector3(-8, 0, 0.6)); _lamp(Vector3(8, 0, 0.6))
	_fence(Vector3(-13, 0, 7), 6.0); _fence(Vector3(9, 0, 7.5), 5.0)
	_item("apple", Vector3(-2.2, 0, 3.0)); _item("cup", Vector3(3.2, 0, 2.6)); _item("paper", Vector3(-5.5, 0, 1.2)); _item("apple", Vector3(6.4, 0, 3.4))
	# 플레이어 = 충돌체(캡슐) + 그 안의 입체 졸라맨
	body = CharacterBody3D.new()
	body.position = Vector3(0, 0.02, 4)
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new(); cap.radius = 0.18; cap.height = 0.95
	col.shape = cap; col.position.y = 0.5
	body.add_child(col)
	player = Stick3D.new()
	body.add_child(player)
	add_child(body)
	cam = $Camera3D

# ── 재료 ──
func _mat(color: Color, tex: Texture2D = null, uv := Vector3.ONE) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	if tex:
		m.albedo_texture = tex
		m.uv1_scale = uv
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	m.roughness = 1.0
	return m

func _tex(id: String) -> Texture2D:
	var p := "res://assets/svg/%s.svg" % id
	return load(p) if ResourceLoader.exists(p) else null

# ── 세계 ──
func _light() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, 28, 0)
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 60.0
	sun.shadow_blur = 1.6
	add_child(sun)

## 상자 하나 — at 은 바닥 중심. solid 면 StaticBody 를 메시의 자식으로 붙여 회전·이동을 같이 따른다
func _box(size: Vector3, at: Vector3, mat: Material, solid := true, parent: Node3D = self) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new(); bm.size = size
	mi.mesh = bm; mi.material_override = mat
	mi.position = at + Vector3(0, size.y / 2.0, 0)
	if solid:
		var sb := StaticBody3D.new()
		var cs := CollisionShape3D.new(); var bs := BoxShape3D.new(); bs.size = size; cs.shape = bs
		sb.add_child(cs); mi.add_child(sb)
	parent.add_child(mi)
	return mi

func _solid_floor() -> void:
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new(); var bs := BoxShape3D.new(); bs.size = Vector3(80, 1, 80); cs.shape = bs
	sb.add_child(cs); sb.position.y = -0.5
	add_child(sb)

func _ground() -> void:
	var g := MeshInstance3D.new()
	var pm := PlaneMesh.new(); pm.size = Vector2(40, 32)
	g.mesh = pm
	g.material_override = _mat(Color.WHITE, _tex("ground/grass"), Vector3(40.0 / TILE, 32.0 / TILE, 1))
	g.position = Vector3(0, 0, -3)
	add_child(g)

## 자갈길 — 바닥보다 2cm 높은 납작한 상자(가장자리가 선으로 읽혀 길이 된다)
func _path(a: Vector3, b: Vector3, w: float) -> void:
	var d := b - a
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	var along := d.length()
	bm.size = Vector3(along, 0.04, w)
	mi.mesh = bm
	mi.material_override = _mat(Color.WHITE, _tex("ground/cobble"), Vector3(along / 1.6, w / 1.6, 1))
	mi.position = (a + b) / 2.0 + Vector3(0, 0.02, 0)
	mi.rotation.y = -atan2(d.z, d.x)
	add_child(mi)

## 속이 빈 집 — 벽 네 장(정면은 문틀 양쪽 + 상인방), 창은 기하(틀+유리), 경첩 달린 문짝(C 로 연다), 지붕은 기와 텍스처 삼각기둥, 굴뚝, 계단
func _house(at: Vector3, size: Vector3, wall: Color, roof: String) -> void:
	var wm := _mat(wall)
	var trim := _mat(Color("efe9e2"))
	var hw := size.x / 2.0; var hd := size.z / 2.0
	var door_w := 0.9; var door_h := 1.9
	# 정면(문 좌우 + 상인방)
	var seg := (size.x - door_w) / 2.0
	_box(Vector3(seg, size.y, WALL), at + Vector3(-hw + seg / 2.0, 0, hd - WALL / 2.0), wm)
	_box(Vector3(seg, size.y, WALL), at + Vector3(hw - seg / 2.0, 0, hd - WALL / 2.0), wm)
	_box(Vector3(door_w + 0.02, size.y - door_h, WALL), at + Vector3(0, door_h, hd - WALL / 2.0), wm)
	# 뒷벽·옆벽
	_box(Vector3(size.x, size.y, WALL), at + Vector3(0, 0, -hd + WALL / 2.0), wm)
	_box(Vector3(WALL, size.y, size.z - WALL * 2.0), at + Vector3(-hw + WALL / 2.0, 0, 0), wm)
	_box(Vector3(WALL, size.y, size.z - WALL * 2.0), at + Vector3(hw - WALL / 2.0, 0, 0), wm)
	# 창: 정면 좌우 하나씩, 옆벽 하나씩 — 틀(밝은) + 유리(하늘) + 창턱
	for wx in [-hw + seg / 2.0, hw - seg / 2.0]:
		_window(at + Vector3(wx, 1.1, hd), 0.0)
	_window(at + Vector3(-hw, 1.1, 0), PI / 2.0)
	_window(at + Vector3(hw, 1.1, 0), -PI / 2.0)
	# 문틀 + 경첩 + 문짝(손잡이 포함). 경첩은 문 왼쪽 기둥, 문짝은 경첩의 자식이라 열면 같이 돈다
	_box(Vector3(0.08, door_h, WALL + 0.04), at + Vector3(-door_w / 2.0 - 0.04, 0, hd - WALL / 2.0), trim)
	_box(Vector3(0.08, door_h, WALL + 0.04), at + Vector3(door_w / 2.0 + 0.04, 0, hd - WALL / 2.0), trim)
	var hinge := Node3D.new()
	hinge.position = at + Vector3(-door_w / 2.0, 0, hd - WALL / 2.0)
	add_child(hinge)
	var leaf := _box(Vector3(door_w, door_h - 0.02, 0.07), Vector3(door_w / 2.0, 0, 0), _mat(Color("7b526c")), true, hinge)
	var knob := MeshInstance3D.new(); var ks := SphereMesh.new(); ks.radius = 0.035; ks.height = 0.07; knob.mesh = ks
	knob.material_override = _mat(Color("e8c766")); knob.position = Vector3(door_w * 0.38, 0.0, 0.06); leaf.add_child(knob)
	doors.append({ "hinge": hinge, "open": false, "pos": hinge.position + Vector3(door_w / 2.0, 0, 0) })
	# 지붕: PrismMesh 는 XY 삼각형을 Z 로 뽑는다 → 용마루가 x 방향이 되게 y 로 90° 돌린다. 처마는 벽보다 0.35 더 나온다
	var r := MeshInstance3D.new()
	var pr := PrismMesh.new(); pr.size = Vector3(size.z + 0.7, size.y * 0.42, size.x + 0.7)
	r.mesh = pr; r.material_override = _mat(Color.WHITE, _tex("faces/roof-%s" % roof), Vector3(2.0, 1.5, 1))
	r.material_override.uv1_triplanar = true
	r.position = at + Vector3(0, size.y + pr.size.y / 2.0, 0)
	r.rotation.y = PI / 2.0
	add_child(r)
	# 천장(안에서 하늘이 안 보이게) · 굴뚝 · 문 앞 계단
	_box(Vector3(size.x, 0.06, size.z), at + Vector3(0, size.y - 0.06, 0), trim, false)
	_box(Vector3(0.36, 0.7, 0.36), at + Vector3(size.x * 0.28, size.y + pr.size.y * 0.55, -0.3), _mat(Color("b56a5a")), false)
	_box(Vector3(1.3, 0.12, 0.5), at + Vector3(0, 0, hd + 0.25), _mat(Color("cfc7c2")))

func _window(at: Vector3, yaw: float) -> void:
	var n := Node3D.new(); n.position = at; n.rotation.y = yaw; add_child(n)
	_box(Vector3(0.74, 0.84, 0.06), Vector3(0, 0, 0), _mat(Color("efe9e2")), false, n)
	_box(Vector3(0.6, 0.7, 0.08), Vector3(0, 0.07, 0), _mat(Color("dfe6ea")), false, n)
	_box(Vector3(0.04, 0.7, 0.09), Vector3(0, 0.07, 0), _mat(Color("efe9e2")), false, n)
	_box(Vector3(0.6, 0.04, 0.09), Vector3(0, 0.40, 0), _mat(Color("efe9e2")), false, n)
	_box(Vector3(0.84, 0.06, 0.16), Vector3(0, -0.04, 0.02), _mat(Color("cfc7c2")), false, n)

## 나무 — 기둥 + 구 셋(잎 두 톤). 크기 k 로 서로 다르게. 줄기만 막힌다
func _tree(at: Vector3, k: float) -> void:
	var trunk := MeshInstance3D.new()
	var cm := CylinderMesh.new(); cm.top_radius = 0.09 * k; cm.bottom_radius = 0.14 * k; cm.height = 1.0 * k
	trunk.mesh = cm; trunk.material_override = _mat(Color("8a6a4a"))
	trunk.position = at + Vector3(0, 0.5 * k, 0)
	var sb := StaticBody3D.new(); var cs := CollisionShape3D.new(); var sh := CylinderShape3D.new(); sh.radius = 0.16 * k; sh.height = 1.0 * k; cs.shape = sh; sb.add_child(cs); trunk.add_child(sb)
	add_child(trunk)
	for i in 3:
		var s := MeshInstance3D.new()
		var sm := SphereMesh.new(); var rr := (0.75 - i * 0.12) * k
		sm.radius = rr; sm.height = rr * 2.0; sm.radial_segments = 14; sm.rings = 8
		s.mesh = sm; s.material_override = _mat(Color("7a9b4e") if i % 2 == 0 else Color("5f8a3e"))
		s.position = at + Vector3((i - 1) * 0.28 * k, (1.25 + i * 0.32) * k, (i - 1) * 0.12 * k)
		add_child(s)

func _bench(at: Vector3) -> void:
	var wood := _mat(Color("8a6a4a")); var iron := _mat(Color("4a4a52"))
	_box(Vector3(1.5, 0.06, 0.45), at + Vector3(0, 0.42, 0), wood)
	var back := _box(Vector3(1.5, 0.06, 0.4), at + Vector3(0, 0.62, -0.2), wood)
	back.rotation.x = -1.35
	for sx in [-0.6, 0.6]:
		_box(Vector3(0.06, 0.42, 0.06), at + Vector3(sx, 0, 0.15), iron)
		_box(Vector3(0.06, 0.42, 0.06), at + Vector3(sx, 0, -0.15), iron)
	benches.append({ "pos": at, "yaw": 0.0 })

func _lamp(at: Vector3) -> void:
	var post := MeshInstance3D.new()
	var cm := CylinderMesh.new(); cm.top_radius = 0.035; cm.bottom_radius = 0.05; cm.height = 2.2
	post.mesh = cm; post.material_override = _mat(Color("4a4a52"))
	post.position = at + Vector3(0, 1.1, 0)
	add_child(post)
	_box(Vector3(0.26, 0.3, 0.26), at + Vector3(0, 2.2, 0), _mat(Color("e8c766")), false)
	var l := OmniLight3D.new(); l.light_color = Color("e8c766"); l.light_energy = 0.6; l.omni_range = 4.0
	l.position = at + Vector3(0, 2.3, 0)
	add_child(l)

func _fence(at: Vector3, len: float) -> void:
	var paper := _mat(Color("efe9e2"))
	var n := int(len / 0.5)
	for i in n + 1:
		_box(Vector3(0.08, 0.7, 0.05), at + Vector3(i * 0.5, 0, 0), paper)
	_box(Vector3(len + 0.08, 0.06, 0.04), at + Vector3(len / 2.0, 0.25, 0), paper)
	_box(Vector3(len + 0.08, 0.06, 0.04), at + Vector3(len / 2.0, 0.5, 0), paper)

## 집을 수 있는 것 — 작은 기하 하나씩(사과 = 구, 컵 = 원기둥, 신문 = 납작한 상자). 손에 들면 hand_r 의 자식이 된다
func _item(kind: String, at: Vector3) -> void:
	var mi := MeshInstance3D.new()
	match kind:
		"apple":
			var s := SphereMesh.new(); s.radius = 0.07; s.height = 0.14; mi.mesh = s; mi.material_override = _mat(Color("ff2d55"))
			mi.position = at + Vector3(0, 0.07, 0)
		"cup":
			var c := CylinderMesh.new(); c.top_radius = 0.06; c.bottom_radius = 0.05; c.height = 0.13; mi.mesh = c; mi.material_override = _mat(Color("f7f4ef"))
			mi.position = at + Vector3(0, 0.065, 0)
		_:
			var b := BoxMesh.new(); b.size = Vector3(0.22, 0.02, 0.16); mi.mesh = b; mi.material_override = _mat(Color("efe9e2"))
			mi.position = at + Vector3(0, 0.01, 0)
	mi.set_meta("kind", kind)
	add_child(mi)
	items.append(mi)

# ── 조작 ──
func _physics_process(delta: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var grounded := body.is_on_floor()
	var dir := Vector3(Input.get_axis("move_left", "move_right"), 0, Input.get_axis("move_up", "move_down"))
	if dir.length() > 1.0:
		dir = dir.normalized()
	# 앉아 있으면 아무 방향키로 일어난다
	if not seat.is_empty():
		if dir != Vector3.ZERO or Input.is_action_just_pressed("jump"):
			seat = {}; player.seated = false
			body.position = Vector3(body.position.x, 0.02, body.position.z + 0.45)
		else:
			_interact_check(now)
			return
	for a in ["move_left", "move_right", "move_up", "move_down"]:
		if Input.is_action_just_pressed(a):
			if a == last_tap and now - last_tap_at < 0.25 and grounded:
				dash_until = now + 0.18
			last_tap = a; last_tap_at = now
	var speed := WALK * (2.2 if now < dash_until else 1.0)
	var can_move := action_until < now
	var v := body.velocity
	if can_move and dir != Vector3.ZERO:
		v.x = dir.x * speed; v.z = dir.z * speed
		player.move_dir = dir; player.speed = speed
	else:
		var k := 1.0 if grounded else 0.98
		v.x = lerpf(v.x, 0.0, k); v.z = lerpf(v.z, 0.0, k)
		player.move_dir = Vector3.ZERO; player.speed = 0.0
	if not grounded:
		v.y -= G * delta
	elif Input.is_action_just_pressed("jump"):
		v.y = HOP
	body.velocity = v
	body.move_and_slide()
	body.position.x = clampf(body.position.x, -15.0, 15.0)
	body.position.z = clampf(body.position.z, -9.0, 9.0)
	player.crouch = 0.0
	player.airborne = not body.is_on_floor()
	player.vertical = body.velocity.y
	if grounded and action_until < now:
		if Input.is_action_just_pressed("hit"):
			player.action = "punch"; action_until = now + 0.28
		elif Input.is_action_just_pressed("kick"):
			player.action = "kick"; action_until = now + 0.32
	if action_until >= now:
		var dur := 0.28 if player.action == "punch" else (0.32 if player.action == "kick" else 0.4)
		player.action_t = 1.0 - (action_until - now) / dur
	else:
		player.action = ""; player.action_t = 0.0
	_interact_check(now)

## C — 들고 있으면 앞에 내려놓기; 아니면 가장 가까운 것: 물건(0.8m) · 문(1.3m) · 벤치(1.0m)
func _interact_check(now: float) -> void:
	if not Input.is_action_just_pressed("act") or action_until >= now:
		return
	var p := body.global_position
	var fwd := Vector3(sin(player.rotation.y), 0, cos(player.rotation.y))
	if player.carrying:
		var item := player.release(self, p + fwd * 0.5 + Vector3(0, 0.08, 0))
		items.append(item)
		player.action = "grab"; action_until = now + 0.4
		return
	var best: Dictionary = {}; var best_d := 9.0
	for it in items:
		var d := p.distance_to(it.global_position)
		if d < 0.8 and d < best_d: best = { "kind": "item", "node": it }; best_d = d
	for dr in doors:
		var d := p.distance_to(dr["pos"])
		if d < 1.3 and d < best_d: best = { "kind": "door", "door": dr }; best_d = d
	for b in benches:
		var d := p.distance_to(b["pos"])
		if d < 1.0 and d < best_d: best = { "kind": "bench", "bench": b }; best_d = d
	if best.is_empty():
		return
	match best["kind"]:
		"item":
			var it: Node3D = best["node"]
			items.erase(it)
			player.hold(it)
			player.action = "grab"; action_until = now + 0.4
		"door":
			var dr: Dictionary = best["door"]
			dr["open"] = not dr["open"]
			var tw := create_tween(); tw.set_ease(Tween.EASE_OUT); tw.set_trans(Tween.TRANS_CUBIC)
			tw.tween_property(dr["hinge"], "rotation:y", -1.85 if dr["open"] else 0.0, 0.45)
		"bench":
			var b: Dictionary = best["bench"]
			seat = b
			player.seated = true
			player.move_dir = Vector3.ZERO; player.speed = 0.0
			body.velocity = Vector3.ZERO
			body.position = b["pos"] + Vector3(0, 0.03, 0.02)
			player.rotation.y = b["yaw"]

func _process(delta: float) -> void:
	# 3/4 시점: 플레이어 뒤·위에서 내려다본다. 부드럽게 따라오고 세계 끝에서 멈춘다
	var want := Vector3(clampf(body.position.x, -9.0, 9.0), 0, clampf(body.position.z, -5.0, 6.0)) + Vector3(0, 8.5, 7.5)
	cam.position = cam.position.lerp(want, minf(1.0, delta * 4.0))
	cam.look_at(Vector3(cam.position.x, 0.6, cam.position.z - 7.5), Vector3.UP)
