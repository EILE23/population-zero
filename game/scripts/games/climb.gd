extends Node3D
## Climb — 첫 미니게임(운영자 2026-10-01: "Climb 는 점프맵", 2026-10-06: "climb 를 먼저 잘 만들고"). 마을의 Climb 탑 문(gate "climb")으로 들어온다.
## 탑을 감아 오르는 발판 48개를 네 구간(12개씩)으로 — 구간마다 재질·색·장치가 다르다:
##   0 돌 기단: 넓은 발판, 가끔 좁은 것 — 몸풀기
##   1 나무 비계: 좁은 들보, 좌우로 미끄러지는 발판(올라타면 같이 간다)
##   2 바람 난간: 밟으면 0.55초 흔들리다 떨어지는 발판(3초 뒤 제자리), 6초마다 뒤로 미는 돌풍(나뭇잎이 날린다)
##   3 구름 꼭대기: 밟으면 높이 튕겨 주는 구름, 오르내리는 승강 발판
## 구간 첫 발판은 체크포인트(깃발 — 닿으면 색이 바뀐다), 10m 마다 탑에 높이 표시, 구간마다 길에서 살짝 벗어난 별 하나(먹으면 결과에 남는다).
## 몸·점프는 마을과 같은 부품(Stick3D, Jump3D) — "엔진이 곧 Square". 떨어지면 마지막 체크포인트로(낙하 수를 센다). 꼭대기에 닿으면 결과(시간·낙하·별)를 들고 마을로.
## 카메라는 탑 둘레를 사람 쪽으로 따라 돈다 — 방향키는 화면 기준, → 가 오르막(발판은 각이 줄어드는 쪽으로 감는다, run 88)

signal finished(result: Dictionary)

var best := 0.0
const N := 48
const SECTION := 12
const RISE := 0.95       # 발판 사이 높이 — 꽉 찬 점프(약 1.25m) 안
const STEP_A := 0.6      # 발판 사이 각(rad) — 반지름 R 에서 약 2.5m 간격
const R := 4.3
const SPEED := 3.2
const JUMP_V := 8.0
const BOUNCE_V := 12.5   # 구름이 튕겨 주는 속도 — 발판 하나를 건너뛸 만큼
const CRUMBLE_T := 0.55
const GUST_EVERY := 6.0
const SECTION_NAMES := ["Stone base", "Scaffolding", "Windy ledges", "Cloud top"]
const SECTION_COLS := [Color("9a8f86"), Color("b48a5a"), Color("8fb8cc"), Color("f7f4ef")]

var body: CharacterBody3D
var fig: Stick3D
var cam: Camera3D
var jump := Jump3D.new()
var plats: Array = []      # {node, base, tang, kind, swing, phase, crumble_at, down_until}
var checks: Array[Vector3] = []
var flags: Array = []      # 체크포인트 깃발 천(닿으면 색)
var stars: Array = []      # {node, got}
var check := 0
var top := 0.0
var falls := 0
var t0 := 0.0
var done_at := -1.0
var hud: Label
var banner: Label
var _banner_until := 0.0
var _was_air := false
var _t := 0.0
var _gust_until := -1.0
var _leaves: CPUParticles3D
var _section := -1

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

func _mat(c: Color, unshaded := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.albedo_color = c; m.roughness = 1.0
	if unshaded: m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	else: m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON; m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return m

func _solid(mesh: Mesh, shape: Shape3D, at: Vector3, mat: Material, moving := false) -> Node3D:
	var b: Node3D = AnimatableBody3D.new() if moving else StaticBody3D.new()
	if moving: (b as AnimatableBody3D).sync_to_physics = true
	var mi := MeshInstance3D.new(); mi.mesh = mesh; mi.material_override = mat; mi.name = "mesh"; b.add_child(mi)
	var cs := CollisionShape3D.new(); cs.shape = shape; cs.name = "shape"; b.add_child(cs)
	b.position = at; add_child(b)
	return b

func _mesh(mesh: Mesh, mat: Material, at: Vector3, parent: Node3D = self) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); mi.mesh = mesh; mi.material_override = mat; mi.position = at; parent.add_child(mi); return mi

func _ready() -> void:
	t0 = _now()
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-55, 35, 0); sun.light_energy = 0.8; sun.shadow_enabled = true; add_child(sun)
	_scenery()
	for i in N: _platform(i)
	_top()
	body = CharacterBody3D.new()
	var col := CollisionShape3D.new(); var cap := CapsuleShape3D.new(); cap.radius = 0.18; cap.height = 0.95; col.shape = cap; col.position.y = 0.5; body.add_child(col)
	fig = Stick3D.new(); body.add_child(fig)
	add_child(body)
	body.position = Vector3(R + 2.5, 0.05, 1.2)   # 첫 발판(각 0)의 왼쪽 — → 한 번에 발판 0 쪽으로 간다
	checks.insert(0, body.position)
	cam = Camera3D.new(); cam.fov = 50.0; add_child(cam); cam.current = true
	cam.global_position = body.position + Vector3(10, 5, 0)
	_leaves = CPUParticles3D.new(); _leaves.amount = 40; _leaves.lifetime = 1.2; _leaves.emitting = false
	_leaves.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX; _leaves.emission_box_extents = Vector3(3, 2, 3); _leaves.gravity = Vector3.ZERO
	_leaves.initial_velocity_min = 4.0; _leaves.initial_velocity_max = 7.0; _leaves.spread = 15.0
	var lm := BoxMesh.new(); lm.size = Vector3(0.12, 0.02, 0.08); _leaves.mesh = lm; _leaves.material_override = _mat(Color("7fb05a"), true)
	add_child(_leaves)
	var ui := CanvasLayer.new(); add_child(ui)
	hud = Label.new(); hud.position = Vector2(14, 10); hud.add_theme_color_override("font_color", Color("1b0c15")); ui.add_child(hud)
	banner = Label.new(); banner.position = Vector2(14, 70); banner.add_theme_font_size_override("font_size", 28); banner.add_theme_color_override("font_color", Color("7b526c")); ui.add_child(banner)

## 탑 기둥(구간마다 색이 다른 띠·창), 10m 높이 표시, 바닥 풀밭과 둘레 나무, 먼 구름
func _scenery() -> void:
	var h := 0.6 + N * RISE   # 기둥 꼭대기 = 꼭대기 원판 바닥(더 높으면 원판을 덮었다)
	var core := CylinderMesh.new(); core.top_radius = 3.0; core.bottom_radius = 3.3; core.height = h; core.radial_segments = 28
	var cc := CylinderShape3D.new(); cc.radius = 3.1; cc.height = h
	_solid(core, cc, Vector3(0, h / 2.0, 0), _mat(Color("d8d2cc")))
	for i in int(h / 4.0):   # 4m 마다 띠(그 높이 구간의 색), 띠 사이 창 넷 — 높이가 눈에 읽힌다
		var y := 4.0 * (i + 1)
		var ry := 3.3 - 0.3 * y / h + 0.05   # 기둥이 위로 가늘어지니 그 높이의 반지름 바깥에
		var rm := CylinderMesh.new(); rm.top_radius = ry; rm.bottom_radius = ry; rm.height = 0.35; rm.radial_segments = 28
		var sec := clampi(int((y - 0.6) / RISE) / SECTION, 0, 3)
		_mesh(rm, _mat(SECTION_COLS[sec].darkened(0.15)), Vector3(0, y, 0))
		for w in 4:
			var a := w * PI / 2.0 + i * 0.4
			var wr := 3.3 - 0.3 * (y - 2.0) / h + 0.02
			var win := _mesh(BoxMesh.new(), _mat(Color("3a2f36")), Vector3(cos(a) * wr, y - 2.0, sin(a) * wr)); win.scale = Vector3(0.5, 0.8, 0.1); win.rotation.y = -a + PI / 2.0
	for m in range(10, int(h), 10):   # 높이 표시 — 탑에 크게 "10 m"
		var lb := Label3D.new(); lb.text = "%d m" % m; lb.font_size = 96; lb.pixel_size = 0.006; lb.modulate = Color("7b526c"); lb.outline_size = 12; lb.outline_modulate = Color("f7f4ef")
		var a := -((m - 0.6) / RISE) * STEP_A + 0.3
		lb.position = Vector3(cos(a) * 3.35, float(m), sin(a) * 3.35); lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED; add_child(lb)
	var ground := CylinderMesh.new(); ground.top_radius = 14.0; ground.bottom_radius = 14.0; ground.height = 0.2; ground.radial_segments = 40
	var gs := BoxShape3D.new(); gs.size = Vector3(28, 0.2, 28)
	_solid(ground, gs, Vector3(0, -0.1, 0), _mat(Color("9cc86a")))
	for i in 10:   # 둘레 나무
		var a := i * TAU / 10.0 + 0.2
		var tc := CylinderMesh.new(); tc.top_radius = 0.18; tc.bottom_radius = 0.25; tc.height = 1.6
		_mesh(tc, _mat(Color("7a5640")), Vector3(cos(a) * 11.5, 0.8, sin(a) * 11.5))
		var ls := SphereMesh.new(); ls.radius = 1.3; ls.height = 2.2
		_mesh(ls, _mat(Color("6aa04c") if i % 2 == 0 else Color("7fb05a")), Vector3(cos(a) * 11.5, 2.4, sin(a) * 11.5))
	for i in 18:   # 먼 구름 — 납작한 공 셋씩
		var a := i * TAU / 18.0; var ch := 8.0 + (i % 5) * 9.0
		for k in 3:
			var cs := SphereMesh.new(); cs.radius = 2.2 - k * 0.4; cs.height = 1.6 - k * 0.3
			_mesh(cs, _mat(Color("f7f4ef"), true), Vector3(cos(a) * 40.0 + k * 1.8, ch + k * 0.3, sin(a) * 40.0))

## 발판 하나 — 구간과 번호로 종류가 정해진다(같은 탑은 언제나 같다)
func _platform(i: int) -> void:
	var sec := i / SECTION; var k := i % SECTION
	var a := -i * STEP_A
	var at := Vector3(cos(a) * R, 0.6 + i * RISE, sin(a) * R)
	var kind := "plain"
	match sec:
		0: kind = "narrow" if k % 4 == 3 else "plain"
		1: kind = "slide" if k % 3 == 2 else "beam"
		2: kind = "crumble" if k % 2 == 1 else "plain"
		3: kind = "cloud" if k % 3 == 1 else ("lift" if k == 6 else "plain")
	if k == 0: kind = "check"
	var size := Vector3(1.6, 0.3, 1.35)
	match kind:
		"narrow": size = Vector3(0.95, 0.3, 0.95)
		"beam": size = Vector3(1.7, 0.22, 0.7)
		"slide": size = Vector3(1.6, 0.3, 1.6)
		"cloud": size = Vector3(1.8, 0.4, 1.6)
		"check": size = Vector3(1.8, 0.3, 1.6)
	var moving := kind in ["slide", "lift", "crumble"]
	var bm: Mesh = BoxMesh.new(); (bm as BoxMesh).size = size
	if kind == "cloud":
		var sm := SphereMesh.new(); sm.radius = size.x * 0.55; sm.height = size.y * 1.6; bm = sm
	var bs := BoxShape3D.new(); bs.size = size
	var col: Color = SECTION_COLS[sec]
	match kind:
		"check": col = Color("ad7096")
		"slide", "lift": col = Color("e3c46a")
		"crumble": col = Color("c9a07a")
		"narrow": col = col.darkened(0.2)
	var p := _solid(bm, bs, at, _mat(col, kind == "cloud"), moving)
	p.rotation.y = -a
	p.set_meta("idx", i)
	if kind == "crumble":   # 금 간 표시 — 위에 어두운 선 둘
		for s in [-0.3, 0.3]:
			var crack := _mesh(BoxMesh.new(), _mat(Color("5a3d2b")), Vector3(s, 0.16, 0), p); crack.scale = Vector3(0.05, 0.01, 1.1); crack.rotation.y = 0.4 * s
	if kind == "check":
		var pole := CylinderMesh.new(); pole.top_radius = 0.03; pole.bottom_radius = 0.03; pole.height = 1.4
		_mesh(pole, _mat(Color("4a4a52")), Vector3(0.6, 0.85, 0), p)
		var cloth := _mesh(BoxMesh.new(), _mat(Color("bfb6b0")), Vector3(0.82, 1.35, 0), p); cloth.scale = Vector3(0.45, 0.28, 0.03)
		flags.append(cloth)
		checks.append(at + Vector3(0, 0.6, 0))
	plats.append({ "node": p, "base": at, "tang": Vector3(-sin(a), 0, cos(a)), "kind": kind, "swing": 0.7 if kind == "slide" else 0.0, "phase": i * 0.7, "crumble_at": -1.0, "down_until": -1.0 })
	if k == 7:   # 구간마다 별 하나 — 길에서 바깥으로 1.8m, 한 칸 위(살짝 벗어나 뛰어야 먹는다)
		var st := MeshInstance3D.new(); var sm := SphereMesh.new(); sm.radius = 0.22; sm.height = 0.44; sm.radial_segments = 8; sm.rings = 4; st.mesh = sm
		st.material_override = _mat(Color("f2c84b"), true)
		st.position = at + Vector3(cos(a), 0, sin(a)) * 1.8 + Vector3(0, 1.1, 0); add_child(st)
		stars.append({ "node": st, "got": false })

func _top() -> void:
	var top_y := 0.6 + N * RISE
	var tm := CylinderMesh.new(); tm.top_radius = 3.6; tm.bottom_radius = 3.6; tm.height = 0.3; tm.radial_segments = 28
	var ts := CylinderShape3D.new(); ts.radius = 3.6; ts.height = 0.3
	var goal := _solid(tm, ts, Vector3(0, top_y + 0.2, 0), _mat(Color("efe9e2")))
	goal.set_meta("goal", true)
	var pm := CylinderMesh.new(); pm.top_radius = 0.05; pm.bottom_radius = 0.05; pm.height = 2.4
	_mesh(pm, _mat(Color("4a4a52")), Vector3(0, top_y + 1.5, 0))
	_mesh(BoxMesh.new(), _mat(Color("ad7096")), Vector3(0.5, top_y + 2.4, 0)).scale = Vector3(1.0, 0.55, 0.04)

func _say(t: String, secs := 1.6) -> void:
	banner.text = t; _banner_until = _now() + secs

## 발판 장치 — 미끄러짐·승강·무너짐(흔들림 → 떨어짐 → 3초 뒤 제자리)
func _devices(now: float) -> void:
	for p in plats:
		var n: Node3D = p["node"]
		match String(p["kind"]):
			"slide": n.position = p["base"] + p["tang"] * sin(_t * 1.3 + p["phase"]) * p["swing"]
			"lift": n.position = p["base"] + Vector3(0, (sin(_t * 0.9) * 0.5 + 0.5) * 1.6, 0)
			"crumble":
				var ca: float = p["crumble_at"]
				if float(p["down_until"]) > 0.0:
					if now >= float(p["down_until"]):
						p["down_until"] = -1.0; p["crumble_at"] = -1.0; n.position = p["base"]; n.get_node("shape").set_deferred("disabled", false); n.visible = true
				elif ca > 0.0:
					var k := (now - ca) / CRUMBLE_T
					if k < 1.0: n.position = p["base"] + Vector3(sin(now * 60.0) * 0.04, 0, 0)   # 흔들림
					else:
						n.position = p["base"] - Vector3(0, minf((k - 1.0) * 6.0, 8.0), 0)   # 떨어진다
						if k > 1.05: n.get_node("shape").set_deferred("disabled", true)
						if k > 2.2: n.visible = false; p["down_until"] = now + 3.0

func _physics_process(delta: float) -> void:
	var now := _now(); _t += delta
	_devices(now)
	var grounded := body.is_on_floor()
	var ix := Input.get_axis("move_left", "move_right"); var iz := Input.get_axis("move_up", "move_down")
	var right := cam.global_transform.basis.x; right.y = 0.0; right = right.normalized()
	var fwd := -cam.global_transform.basis.z; fwd.y = 0.0; fwd = fwd.normalized()
	var dir := right * ix + fwd * -iz
	if dir.length() > 1.0: dir = dir.normalized()
	var v := body.velocity
	var hv := Vector3(v.x, 0, v.z).move_toward(dir * SPEED, (26.0 if grounded else 15.0) * delta)
	# 돌풍(바람 난간 구간): 6초마다 1.2초 동안 오르막 반대쪽으로 민다 — 들보 위에선 버텨야 하고 공중에선 밀린다
	var pos := body.global_position
	var sec := clampi(int((pos.y - 0.6) / RISE) / SECTION, 0, 3)
	if sec == 2 and fmod(_t, GUST_EVERY) < 0.05 and now > _gust_until: _gust_until = now + 1.2; _say("Wind!", 1.0)
	if now < _gust_until:
		var back := Vector3(-sin(atan2(pos.z, pos.x)), 0, cos(atan2(pos.z, pos.x)))   # 각이 늘어나는 쪽 = 내려가는 쪽
		hv += back * (1.6 if grounded else 3.2) * delta * 3.0
		_leaves.global_position = pos + Vector3(0, 1.0, 0) - back * 3.0; _leaves.direction = back; _leaves.emitting = true
	else: _leaves.emitting = false
	v.x = hv.x; v.z = hv.z
	jump.tick(grounded, Input.is_action_just_pressed("jump"), now)
	if jump.consume(now): v.y = JUMP_V; fig.squash = 1.0
	elif not grounded: v.y = jump.air(v.y, Input.is_action_just_released("jump"), delta)
	body.velocity = v
	body.move_and_slide()
	var landed := _was_air and body.is_on_floor()
	if landed: fig.squash = -0.6; Jump3D.dust(self, body.global_position, 0.4)
	_was_air = not body.is_on_floor()
	fig.move_dir = dir if dir.length() > 0.05 else Vector3.ZERO; fig.speed = hv.length(); fig.airborne = not body.is_on_floor(); fig.vertical = body.velocity.y
	top = maxf(top, body.global_position.y)
	if body.is_on_floor(): _stand_on(now, landed)
	for s in stars:
		var sn: Node3D = s["node"]
		if not s["got"]:
			sn.rotation.y += delta * 2.0
			if sn.global_position.distance_to(body.global_position + Vector3(0, 0.5, 0)) < 0.7: s["got"] = true; sn.visible = false; _say("Star!", 1.2)
	if body.global_position.y < checks[check].y - 7.0:   # 떨어짐 — 마지막 체크포인트로
		body.global_position = checks[check]; body.velocity = Vector3.ZERO; falls += 1; _say("Again.", 1.0)
	if sec != _section:
		_section = sec; _say(SECTION_NAMES[sec], 2.0)
	_camera(delta)
	_hud(now)

## 밟은 것 — 꼭대기, 체크포인트(깃발 색), 무너지는 발판(흔들기 시작), 구름(튕김)
func _stand_on(now: float, landed: bool) -> void:
	for i in body.get_slide_collision_count():
		var c := body.get_slide_collision(i).get_collider() as Node
		if c == null: continue
		if c.has_meta("goal") and done_at < 0.0: done_at = now; _say("Top!", 3.0)
		if not c.has_meta("idx"): continue
		var p: Dictionary = plats[int(c.get_meta("idx"))]
		match String(p["kind"]):
			"crumble": if float(p["crumble_at"]) < 0.0: p["crumble_at"] = now
			"cloud":
				if landed or body.velocity.y <= 0.1:
					body.velocity.y = BOUNCE_V; fig.squash = 1.0; Jump3D.dust(self, body.global_position, 0.8)
	for k in checks.size():
		if k > check and body.global_position.distance_to(checks[k]) < 1.3:
			check = k
			if k - 1 < flags.size() and k >= 1: (flags[k - 1] as MeshInstance3D).material_override = _mat(Color("ad7096"))
			_say("Checkpoint", 1.2)

## 카메라: 탑 중심에서 사람 쪽으로 바깥 10m, 위 4.8m — 사람과 그 위 발판 둘이 보이게, 오르막 쪽으로 살짝 앞을 본다
func _camera(delta: float) -> void:
	var p := body.global_position
	var out := Vector3(p.x, 0, p.z)
	out = out.normalized() if out.length() > 0.1 else Vector3(1, 0, 0)
	var want := Vector3(out.x * (R + 10.5), p.y + 4.8, out.z * (R + 10.5))
	cam.global_position = cam.global_position.lerp(want, minf(1.0, delta * 5.0))
	cam.look_at(p + Vector3(0, 1.9, 0) - out * 1.0, Vector3.UP)

func _hud(now: float) -> void:
	var el := now - t0
	var got := stars.filter(func(s): return s["got"]).size()
	hud.text = "CLIMB   %d m   best %d m   %s   falls %d   stars %d/%d\n← → around · SPACE jump (hold: higher) · Esc leave" % [int(top), int(maxf(best, top)), _clock(el), falls, got, stars.size()]
	if now > _banner_until: banner.text = ""
	if done_at > 0.0:
		banner.text = "Top!  %s · %d falls · %d/%d stars" % [_clock(done_at - t0), falls, got, stars.size()]
		if now - done_at > 3.0: _leave()
	elif Input.is_action_just_pressed("ui_cancel") or (Input.is_action_just_pressed("act") and body.global_position.y < 1.0):
		_leave()

static func _clock(s: float) -> String:
	return "%d:%04.1f" % [int(s) / 60, fmod(s, 60.0)]

func _leave() -> void:
	set_physics_process(false)
	finished.emit({ "score": top, "time": (done_at if done_at > 0.0 else _now()) - t0, "top": done_at > 0.0, "falls": falls, "stars": stars.filter(func(s): return s["got"]).size() })
