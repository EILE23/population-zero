extends Node3D
## Climb — 첫 미니게임(운영자 2026-10-01: "Climb 는 점프맵, 마을 입구로 들어가 다른 게임으로"). 마을의 Climb 탑 문(gate "climb")으로 들어온다.
## 탑을 감아 오르는 발판 48개: 보통 발판, 좁은 발판(11번째마다), 좌우로 미끄러지는 발판(7번째마다, AnimatableBody — 올라타면 같이 간다), 12번째마다 체크포인트(색 발판).
## 몸·점프는 마을과 같은 부품(Stick3D, Jump3D: 코요테·버퍼·꼭대기 체공·가변 높이) — "엔진이 곧 Square". 떨어지면 마지막 체크포인트로, 꼭대기에 닿으면 기록을 들고 돌아간다.
## 카메라는 탑 둘레를 사람 쪽으로 따라 돈다 — 방향키는 화면 기준. 바깥에서 기둥을 보는 카메라의 오른쪽은 각이 줄어드는 쪽이라
## 발판도 각이 줄어드는 쪽(-i·STEP_A)으로 감는다 → → 가 오르막(운영자 2026-10-01: 전엔 ← 가 올라갔다)

signal finished(result: Dictionary)

var best := 0.0
const N := 48
const RISE := 0.95       # 발판 사이 높이 — 꽉 찬 점프(약 1.25m) 안
const STEP_A := 0.6      # 발판 사이 각(rad) — 반지름 R 에서 약 2.5m 간격(가장자리 사이 1m 남짓)
const R := 4.3
const SPEED := 3.2
const JUMP_V := 8.0

var body: CharacterBody3D
var fig: Stick3D
var cam: Camera3D
var jump := Jump3D.new()
var plats: Array = []      # {node: AnimatableBody3D, base: Vector3, tang: Vector3, swing: float, phase: float}
var checks: Array[Vector3] = []
var check := 0
var top := 0.0
var t0 := 0.0
var done_at := -1.0
var hud: Label
var _was_air := false
var _t := 0.0

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.albedo_color = c; m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON; m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED; m.roughness = 1.0
	return m

func _solid(mesh: Mesh, shape: Shape3D, at: Vector3, mat: Material, moving := false) -> Node3D:
	var b: Node3D = AnimatableBody3D.new() if moving else StaticBody3D.new()
	if moving: (b as AnimatableBody3D).sync_to_physics = true
	var mi := MeshInstance3D.new(); mi.mesh = mesh; mi.material_override = mat; b.add_child(mi)
	var cs := CollisionShape3D.new(); cs.shape = shape; b.add_child(cs)
	b.position = at; add_child(b)
	return b

func _ready() -> void:
	t0 = _now()
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-55, 35, 0); sun.light_energy = 0.8; sun.shadow_enabled = true; add_child(sun)
	var h := 0.6 + N * RISE   # 기둥 꼭대기 = 꼭대기 원판 바닥(더 높으면 원판을 덮었다)
	var core := CylinderMesh.new(); core.top_radius = 3.0; core.bottom_radius = 3.3; core.height = h; core.radial_segments = 28
	var cc := CylinderShape3D.new(); cc.radius = 3.1; cc.height = h
	_solid(core, cc, Vector3(0, h / 2.0, 0), _mat(Color("d8d2cc")))
	for i in int(h / 4.0):   # 4m 마다 색 띠, 띠 사이엔 작은 창 넷 — 높이가 눈에 읽힌다
		var ring := MeshInstance3D.new(); var rm := CylinderMesh.new(); var ry := 3.3 - 0.3 * (4.0 * (i + 1)) / h + 0.05; rm.top_radius = ry; rm.bottom_radius = ry;   # 기둥이 위로 가늘어지니 그 높이의 반지름 바깥에 rm.height = 0.35; rm.radial_segments = 28
		ring.mesh = rm; ring.material_override = _mat([Color("ad7096"), Color("8fb8cc"), Color("e3c46a")][i % 3]); ring.position = Vector3(0, 4.0 * (i + 1), 0); add_child(ring)
		for w in 4:
			var a := w * PI / 2.0 + i * 0.4
			var win := MeshInstance3D.new(); var wb := BoxMesh.new(); wb.size = Vector3(0.5, 0.8, 0.1); win.mesh = wb; win.material_override = _mat(Color("3a2f36"))
			var wr := 3.3 - 0.3 * (4.0 * i + 2.0) / h + 0.02; win.position = Vector3(cos(a) * wr, 4.0 * i + 2.0, sin(a) * wr); win.rotation.y = -a + PI / 2.0; add_child(win)
	for i in 18:   # 먼 구름 — 납작한 공 셋씩
		var a := i * TAU / 18.0; var ch := 8.0 + (i % 5) * 9.0
		for k in 3:
			var cl := MeshInstance3D.new(); var cs := SphereMesh.new(); cs.radius = 2.2 - k * 0.4; cs.height = 1.6 - k * 0.3; cl.mesh = cs
			var cm := StandardMaterial3D.new(); cm.albedo_color = Color("f7f4ef"); cm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; cl.material_override = cm
			cl.position = Vector3(cos(a) * 40.0 + k * 1.8, ch + k * 0.3, sin(a) * 40.0); add_child(cl)
	for i in 10:   # 둘레 나무(공 모양 잎 + 줄기)
		var a := i * TAU / 10.0 + 0.2
		var tr := MeshInstance3D.new(); var tc := CylinderMesh.new(); tc.top_radius = 0.18; tc.bottom_radius = 0.25; tc.height = 1.6; tr.mesh = tc; tr.material_override = _mat(Color("7a5640")); tr.position = Vector3(cos(a) * 11.5, 0.8, sin(a) * 11.5); add_child(tr)
		var lf := MeshInstance3D.new(); var ls := SphereMesh.new(); ls.radius = 1.3; ls.height = 2.2; lf.mesh = ls; lf.material_override = _mat(Color("6aa04c") if i % 2 == 0 else Color("7fb05a")); lf.position = Vector3(cos(a) * 11.5, 2.4, sin(a) * 11.5); add_child(lf)
	var ground := CylinderMesh.new(); ground.top_radius = 14.0; ground.bottom_radius = 14.0; ground.height = 0.2; ground.radial_segments = 40
	var gs := BoxShape3D.new(); gs.size = Vector3(28, 0.2, 28)
	_solid(ground, gs, Vector3(0, -0.1, 0), _mat(Color("9cc86a")))
	for i in N:
		var a := -i * STEP_A
		var at := Vector3(cos(a) * R, 0.6 + i * RISE, sin(a) * R)
		var small := i % 11 == 10; var moving := i % 7 == 6 and i > 0; var cp := i % 12 == 0
		var size := Vector3(0.95, 0.3, 0.95) if small else (Vector3(1.6, 0.3, 1.6) if moving else Vector3(1.6, 0.3, 1.35))
		var bm := BoxMesh.new(); bm.size = size
		var bs := BoxShape3D.new(); bs.size = size
		var col := Color("ad7096") if cp else (Color("e3c46a") if moving else (Color("8a7f86") if small else Color("9a8f86")))
		var p := _solid(bm, bs, at, _mat(col), moving)
		p.rotation.y = -a
		var tang := Vector3(-sin(a), 0, cos(a))
		plats.append({ "node": p, "base": at, "tang": tang, "swing": 0.7 if moving else 0.0, "phase": i * 0.7 })
		if cp: checks.append(at + Vector3(0, 0.6, 0))
	# 꼭대기: 넓은 원판과 깃발
	var top_y := 0.6 + N * RISE
	var tm := CylinderMesh.new(); tm.top_radius = 3.6; tm.bottom_radius = 3.6; tm.height = 0.3; tm.radial_segments = 28
	var ts := CylinderShape3D.new(); ts.radius = 3.6; ts.height = 0.3
	var goal := _solid(tm, ts, Vector3(0, top_y + 0.2, 0), _mat(Color("efe9e2")))
	goal.set_meta("goal", true)
	var pole := MeshInstance3D.new(); var pm := CylinderMesh.new(); pm.top_radius = 0.05; pm.bottom_radius = 0.05; pm.height = 2.4; pole.mesh = pm; pole.material_override = _mat(Color("4a4a52")); pole.position = Vector3(0, top_y + 1.5, 0); add_child(pole)
	var fl := MeshInstance3D.new(); var fb := BoxMesh.new(); fb.size = Vector3(1.0, 0.55, 0.04); fl.mesh = fb; fl.material_override = _mat(Color("ad7096")); fl.position = Vector3(0.5, top_y + 2.4, 0); add_child(fl)
	# 사람
	body = CharacterBody3D.new()
	var col := CollisionShape3D.new(); var cap := CapsuleShape3D.new(); cap.radius = 0.18; cap.height = 0.95; col.shape = cap; col.position.y = 0.5; body.add_child(col)
	fig = Stick3D.new(); body.add_child(fig)
	add_child(body)
	body.position = Vector3(R + 2.5, 0.05, 1.2)   # 첫 발판(각 0)의 왼쪽 — → 한 번에 발판 0 쪽으로 간다
	checks.insert(0, body.position)
	cam = Camera3D.new(); cam.fov = 50.0; add_child(cam); cam.current = true
	var ui := CanvasLayer.new(); add_child(ui)
	hud = Label.new(); hud.position = Vector2(14, 10); hud.add_theme_color_override("font_color", Color("1b0c15")); ui.add_child(hud)

func _physics_process(delta: float) -> void:
	var now := _now(); _t += delta
	for p in plats:   # 미끄러지는 발판
		if p["swing"] > 0.0: (p["node"] as Node3D).position = p["base"] + p["tang"] * sin(_t * 1.3 + p["phase"]) * p["swing"]
	var grounded := body.is_on_floor()
	var ix := Input.get_axis("move_left", "move_right"); var iz := Input.get_axis("move_up", "move_down")
	var right := cam.global_transform.basis.x; right.y = 0.0; right = right.normalized()
	var fwd := -cam.global_transform.basis.z; fwd.y = 0.0; fwd = fwd.normalized()
	var dir := right * ix + fwd * -iz
	if dir.length() > 1.0: dir = dir.normalized()
	var v := body.velocity
	var hv := Vector3(v.x, 0, v.z).move_toward(dir * SPEED, (26.0 if grounded else 15.0) * delta)
	v.x = hv.x; v.z = hv.z
	jump.tick(grounded, Input.is_action_just_pressed("jump"), now)
	if jump.consume(now): v.y = JUMP_V; fig.squash = 1.0
	elif not grounded: v.y = jump.air(v.y, Input.is_action_just_released("jump"), delta)
	body.velocity = v
	body.move_and_slide()
	if _was_air and body.is_on_floor(): fig.squash = -0.6
	_was_air = not body.is_on_floor()
	fig.move_dir = dir if dir.length() > 0.05 else Vector3.ZERO; fig.speed = hv.length(); fig.airborne = not body.is_on_floor(); fig.vertical = body.velocity.y
	top = maxf(top, body.global_position.y)
	# 체크포인트·꼭대기: 밟은 발판으로 판단
	if body.is_on_floor():
		for i in body.get_slide_collision_count():
			var c := body.get_slide_collision(i).get_collider() as Node
			if c and c.has_meta("goal") and done_at < 0.0: done_at = now
		for k in checks.size():
			if k > check and body.global_position.distance_to(checks[k]) < 1.2: check = k
	if body.global_position.y < checks[check].y - 7.0:   # 떨어짐 — 마지막 체크포인트로
		body.global_position = checks[check]; body.velocity = Vector3.ZERO
	# 카메라: 탑 중심에서 사람 쪽으로 바깥 8m, 3.5m 위에서 사람을 본다
	var out := Vector3(body.global_position.x, 0, body.global_position.z)
	out = out.normalized() if out.length() > 0.1 else Vector3(1, 0, 0)
	var want := Vector3(out.x * (R + 10.5), body.global_position.y + 4.8, out.z * (R + 10.5))   # 멀리·높이 — 다음 발판 둘이 보이게(가까우면 기둥이 화면을 채웠다)
	cam.global_position = cam.global_position.lerp(want, minf(1.0, delta * 5.0))
	cam.look_at(body.global_position + Vector3(0, 1.6, 0) - out * 1.0, Vector3.UP)
	var el := now - t0
	hud.text = "CLIMB   %d m   best %d m   %.1f s\n← → around · SPACE jump (hold: higher) · Esc leave" % [int(top), int(maxf(best, top)), el]
	if done_at > 0.0:
		hud.text = "Top. %d m in %.1f s" % [int(top), done_at - t0]
		if now - done_at > 2.0: _leave()
	elif Input.is_action_just_pressed("ui_cancel") or (Input.is_action_just_pressed("act") and body.global_position.y < 1.0):
		_leave()

func _leave() -> void:
	set_physics_process(false)
	finished.emit({ "score": top, "time": _now() - t0, "top": done_at > 0.0 })
