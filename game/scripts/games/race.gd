extends Node3D
## Race — 두 번째 미니게임(운영자 2026-10-01: "호숫가 차고 문으로 들어가는 레이싱"). 마을의 호숫가 차고(gate "race")로 들어온다.
## 평지 위 닫힌 고리 트랙(길 조각 상자를 중심선을 따라 잇는다), 내 차는 마을과 같은 Car3D(같은 물리·드리프트 부스트), 주민 둘이 같은 더듬이 AI(_drive_ai)로
## 트랙 경유지를 route 삼아 달린다. 세 바퀴, 가장 빠른 바퀴가 차고 표지판의 기록. Car3D 는 마을(town)에 기대니 이 노드가 그 몫(body·cars·OPEN…)을 대신한다

signal finished(result: Dictionary)

var best := 0.0
var rivals: Array = []         # [{handle, color}] — 마을이 넣어 준다(성미 급한 주민 둘). 없으면(점검) 이름 없는 둘
const LAPS := 3
const N := 120                 # 중심선 점 — 약 2m 간격
const HALF := 4.5              # 길 반폭
const HALF_N := 60
const OPEN := 200.0            # Car3D 가 위치를 이 안으로 묶는다

# ── Car3D 가 읽는 마을 몫 ──
var body := Node3D.new()       # 내 차를 따라다니는 보이지 않는 점 — 더듬이의 '플레이어 가까이' 판단만 쓴다(안 보이니 밀리거나 치이지 않는다)
var player: Stick3D
var cars: Array[Car3D] = []
var residents: Array = []
var animals: Array = []
var wreckables: Array = []
var houses: Array = []
var flying: Array = []
var driving: Car3D = null
var down_until := -1.0
func _crack_wall(_d: Vector3, _at: Vector3) -> void: pass
func smash(_w: Dictionary, _p: Vector3) -> void: pass
func car_hits_player(_l: Vector3, _s: float) -> void: pass
func animal_hit(_a: Dictionary, _f: Vector3) -> void: pass

var pts: Array[Vector3] = []
var racers: Array = []         # {car, fig, idx, lap, lap_t0, done_at, name}
var cam: Camera3D
var hud: Label
var t0 := 0.0
var go_at := 0.0
var best_lap := 0.0
var last_lap := 0.0
var done_at := -1.0
var place := 0

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.albedo_color = c; m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON; m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED; m.roughness = 1.0
	return m

func _mesh_box(size: Vector3, at: Vector3, yaw: float, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = size; mi.mesh = bm; mi.material_override = mat
	mi.position = at; mi.rotation.y = yaw; add_child(mi)
	return mi

## 중심선 — 길쭉한 고리에 S 굽이 하나(sin 2t): 긴 직선 둘, 빠른 굽이 둘, 느린 머리핀 하나쯤으로 읽힌다
func _center(t: float) -> Vector3:
	return Vector3(48.0 * cos(t), 0, 24.0 * sin(t) + 7.0 * sin(2.0 * t))

func _ready() -> void:
	t0 = _now(); go_at = t0 + 3.0
	var env := WorldEnvironment.new(); var e := Environment.new()
	e.background_mode = Environment.BG_COLOR; e.background_color = Color("cfe3ee")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; e.ambient_light_color = Color("f7f4ef"); e.ambient_light_energy = 0.5
	env.environment = e; add_child(env)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-55, 35, 0); sun.light_energy = 0.9; sun.shadow_enabled = true; add_child(sun)
	var ground := StaticBody3D.new(); var gs := CollisionShape3D.new(); var gb := BoxShape3D.new(); gb.size = Vector3(400, 0.4, 400); gs.shape = gb; ground.add_child(gs)
	ground.position = Vector3(0, -0.2, 0); add_child(ground)
	_mesh_box(Vector3(400, 0.4, 400), Vector3(0, -0.2, 0), 0.0, _mat(Color("9cc86a")))
	for i in N: pts.append(_center(i * TAU / N))
	var road := _mat(Color("5b5560")); var red := _mat(Color("c4524a")); var white := _mat(Color("efe9e2"))
	for i in N:
		var a := pts[i]; var b := pts[(i + 1) % N]; var c := pts[(i + 2) % N]
		var d := b - a; var yaw := atan2(d.x, d.z)
		_mesh_box(Vector3(HALF * 2.0, 0.03, d.length() + 0.7), (a + b) / 2.0 + Vector3(0, 0.015, 0), yaw, road)
		var turn := absf(wrapf(atan2((c - b).x, (c - b).z) - yaw, -PI, PI))
		if turn > 0.05:   # 굽이에만 연석(빨강·하양 번갈아) — 어디서 꺾이는지 멀리서 읽힌다
			var side := Vector3(d.z, 0, -d.x).normalized()
			for s in [-1.0, 1.0]: _mesh_box(Vector3(0.6, 0.06, d.length() + 0.1), (a + b) / 2.0 + side * s * (HALF + 0.3) + Vector3(0, 0.03, 0), yaw, red if i % 2 == 0 else white)
	# 출발선: 체크무늬 띠, 양옆 기둥과 현수막
	var d0 := (pts[1] - pts[0]).normalized(); var s0 := Vector3(d0.z, 0, -d0.x)
	for k in 9:
		for r in 2: _mesh_box(Vector3(1.0, 0.04, 0.5), pts[0] + s0 * (k - 4.0) + d0 * (r * 0.5 - 0.25) + Vector3(0, 0.03, 0), atan2(d0.x, d0.z), white if (k + r) % 2 == 0 else _mat(Color("1b0c15")))
	for s in [-1.0, 1.0]: _mesh_box(Vector3(0.25, 4.2, 0.25), pts[0] + s0 * s * (HALF + 1.6) + Vector3(0, 2.1, 0), 0.0, _mat(Color("4a4a52")))
	var banner := _mesh_box(Vector3((HALF + 1.6) * 2.0, 0.7, 0.08), pts[0] + Vector3(0, 3.9, 0), atan2(d0.x, d0.z), _mat(Color("ad7096")))
	var bl := Label3D.new(); bl.text = "FINISH"; bl.font_size = 96; bl.pixel_size = 0.006; bl.modulate = Color("f7f4ef"); bl.outline_size = 0; bl.double_sided = true; banner.add_child(bl); bl.position = Vector3(0, 0, 0.06)
	for i in 26:   # 둘레 나무 — 트랙 밖 멀리(부딪힐 일 없게 충돌 없음)
		var a := i * TAU / 26.0; var p := Vector3(cos(a) * (70.0 + (i % 3) * 6.0), 0, sin(a) * (44.0 + (i % 4) * 5.0))
		_mesh_box(Vector3(0.4, 1.6, 0.4), p + Vector3(0, 0.8, 0), 0.0, _mat(Color("7a5640")))
		var lf := MeshInstance3D.new(); var ls := SphereMesh.new(); ls.radius = 1.6; ls.height = 2.6; lf.mesh = ls; lf.material_override = _mat(Color("6aa04c") if i % 2 == 0 else Color("7fb05a")); lf.position = p + Vector3(0, 2.6, 0); add_child(lf)
	body.visible = false; add_child(body)
	# 출발 격자: 나는 첫 줄 바깥, 주민 하나는 첫 줄 안, 하나는 둘째 줄 가운데
	var route: Array[Vector3] = []
	for i in range(0, N, 4): route.append(pts[i])
	var grid := [[N - 4, -2.2, "race", ""], [N - 4, 2.2, "hatchback", "a"], [N - 8, 0.0, "race", "b"]]
	for k in grid.size():
		var g: Array = grid[k]
		var at: Vector3 = pts[int(g[0])]; var dir := (pts[(int(g[0]) + 1) % N] - at).normalized(); var side := Vector3(dir.z, 0, -dir.x)
		var car := Car3D.new(); car.setup(String(g[2]), self); car.position = at + side * float(g[1]) + Vector3(0, 0.02, 0); car.rotation.y = atan2(-dir.x, -dir.z)
		add_child(car); cars.append(car)
		var fig := Stick3D.new(); fig.seated = true; fig.pose_request = "drive"; fig.base_scale = Vector3.ONE * 0.8
		var nm := "You"
		if k > 0:
			car.route = route; car.cruise = 10.0 if k == 1 else 11.5   # 주민 둘 — 하나는 조금 느리고, 하나는 드리프트 없는 내 차와 비슷하게
			var rv: Dictionary = rivals[k - 1] if rivals.size() >= k else { "handle": "driver " + String(g[3]), "color": Color("5b4f56") }
			nm = String(rv["handle"]); fig.color = rv["color"]; fig.head_color = rv["color"]
			var lb := Label3D.new(); lb.text = nm; lb.font_size = 44; lb.pixel_size = 0.004; lb.modulate = Color("5b4f56"); lb.outline_size = 8; lb.outline_modulate = Color("f7f4ef")
			lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED; lb.position = Vector3(0, 2.0, 0); car.add_child(lb)
			car._ri = ((int(g[0]) >> 2) + 1) % route.size()
		else:
			driving = car; player = fig
		add_child(fig); car.driver = fig   # 색을 정한 뒤에 넣는다(_ready 가 재질을 만든다)
		racers.append({ "car": car, "fig": fig, "idx": int(g[0]), "lap": 0, "lap_t0": 0.0, "done_at": -1.0, "name": nm })
	cam = Camera3D.new(); cam.fov = 62.0; add_child(cam); cam.current = true
	cam.global_position = driving.global_position + driving.global_transform.basis.z * 8.0 + Vector3(0, 3.5, 0)
	var ui := CanvasLayer.new(); add_child(ui)
	hud = Label.new(); hud.position = Vector2(14, 10); hud.add_theme_color_override("font_color", Color("1b0c15")); ui.add_child(hud)

## 바퀴 세기 — 지난 점에서 조금 뒤·앞(−2..+8) 중 가장 가까운 점으로만 옮긴다(트랙을 가로질러 건너뛰지 못한다). 0 을 앞으로 넘으면 한 바퀴, 뒤로 넘으면 무른다
func _progress(r: Dictionary, now: float) -> void:
	var p: Vector3 = (r["car"] as Car3D).global_position; p.y = 0.0
	var idx: int = r["idx"]; var bi := idx; var bd := INF
	for k in range(-2, 9):
		var j := (idx + k + N) % N; var dd := p.distance_squared_to(pts[j])
		if dd < bd: bd = dd; bi = j
	if bi < idx - HALF_N:
		r["lap"] = int(r["lap"]) + 1
		if bool(r.get("dirty", false)): r["dirty"] = false   # 뒤로 넘었다 다시 넘은 바퀴는 기록하지 않는다(리뷰: 선 앞뒤로 오가 몇 초짜리 최고 랩이 남았다)
		elif r["car"] == driving and int(r["lap"]) > 1:
			last_lap = now - float(r["lap_t0"])
			if best_lap <= 0.0 or last_lap < best_lap: best_lap = last_lap
		r["lap_t0"] = now
		if int(r["lap"]) > LAPS and float(r["done_at"]) < 0.0: r["done_at"] = now
	elif bi > idx + HALF_N: r["lap"] = int(r["lap"]) - 1; r["dirty"] = true
	r["idx"] = bi
	# 풀밭: 길 밖이면 6m/s 위로는 끌린다(사람이든 주민이든 같다)
	var car: Car3D = r["car"]
	if sqrt(bd) > HALF + 0.8 and car.v > 6.0: car.v = move_toward(car.v, 6.0, 9.0 * get_physics_process_delta_time())

func _physics_process(delta: float) -> void:
	var now := _now()
	var started := now >= go_at
	var dir := Vector3(Input.get_axis("move_left", "move_right"), 0, Input.get_axis("move_up", "move_down"))
	var mine := done_at < 0.0 and started
	driving.input = { "throttle": -dir.z if mine else 0.0, "steer": dir.x if mine else 0.0, "brake": Input.is_action_pressed("jump") if mine else false }
	for r in racers:
		var car: Car3D = r["car"]; var fig: Stick3D = r["fig"]
		if car != driving:
			if started: car._drive_ai()   # 마을 교통과 같은 더듬이 AI — 앞차·내 차를 보고 비켜 가고, 꺾을수록 늦춘다
			else: car.input = { "throttle": 0.0, "steer": 0.0, "brake": false }
		fig.global_position = car.seat_pos(); fig.face(car.rotation.y + PI)
		_progress(r, now)
	body.global_position = driving.global_position
	for f in flying.duplicate():   # 부딪힌 부품 — 날다 떨어져 1.5초 뒤 사라진다
		var n: Node3D = f["node"]
		if not is_instance_valid(n): flying.erase(f); continue
		f["vel"] = (f["vel"] as Vector3) + Vector3(0, -12.0, 0) * delta
		n.global_position += (f["vel"] as Vector3) * delta; n.rotation.x += float(f["spin"]) * delta
		if n.global_position.y < 0.05: flying.erase(f); get_tree().create_timer(1.5).timeout.connect(n.queue_free)
	# 카메라: 차 뒤 7m·3m 위에서 앞 4m 를 본다(드리프트 중엔 차체가 아니라 가는 쪽을 따라가게 천천히)
	var back := driving.global_transform.basis.z; back.y = 0.0; back = back.normalized()
	cam.global_position = cam.global_position.lerp(driving.global_position + back * 7.0 + Vector3(0, 3.0, 0), minf(1.0, delta * 4.0))
	cam.look_at(driving.global_position - back * 4.0 + Vector3(0, 0.8, 0), Vector3.UP)
	var me: Dictionary = racers[0]
	var pos := 1
	for r in racers.slice(1):
		var ahead: bool = float(r["done_at"]) > 0.0 and (done_at < 0.0 or float(r["done_at"]) < done_at)
		if ahead or (done_at < 0.0 and int(r["lap"]) * N + int(r["idx"]) > int(me["lap"]) * N + int(me["idx"])): pos += 1
	if float(me["done_at"]) > 0.0 and done_at < 0.0: done_at = float(me["done_at"]); place = pos
	if not started:
		hud.text = "RACE   %d\n↑ ↓ drive · ← → steer · SPACE drift · Esc leave" % int(ceil(go_at - now))
	elif done_at > 0.0:
		hud.text = "Finished %s.   best lap %s" % [["1st", "2nd", "3rd"][place - 1], _t(best_lap)]
		if now - done_at > 4.0: _leave()
	else:
		var lap_t := now - float(me["lap_t0"]) if int(me["lap"]) > 0 else 0.0
		hud.text = "RACE   lap %d/%d   P%d   %s   last %s   best %s\n↑ ↓ drive · ← → steer · SPACE drift · Esc leave" % [clampi(int(me["lap"]), 1, LAPS), LAPS, pos, _t(lap_t), _t(last_lap), _t(best_lap if best_lap > 0.0 and (best <= 0.0 or best_lap < best) else best)]
	if Input.is_action_just_pressed("ui_cancel"): _leave()

func _t(s: float) -> String:
	return "--" if s <= 0.0 else "%d:%04.1f" % [int(s / 60.0), fmod(s, 60.0)]

func _leave() -> void:
	set_physics_process(false)
	finished.emit({ "score": best_lap, "place": place })
