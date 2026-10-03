class_name TownBuild
extends TownProps
## 세계를 짓는다 — 집(사양·실내·계단·문), 공원, 시장, 나무, 가구, 물건, 동물 몸, 주민 배치. 작은 소품(창·가로등·벤치·노점·창구·그네…)은 town_props.gd 에.
## 전부 원시 도형 + SVG 텍스처. 놓인 것은 base 의 목록(spots/doors/houses/...)에 등록된다.

## 명부(data/residents.json)에서 n 명 — 색은 웹과 같은 규칙, 자리는 무작위
func _residents(n: int) -> void:
	var f := FileAccess.open("res://data/residents.json", FileAccess.READ)
	if f == null:
		push_error("town3d: data/residents.json missing"); return
	var data: Dictionary = JSON.parse_string(f.get_as_text())
	var roster: Array = data.get("residents", [])
	var rng := RandomNumberGenerator.new(); rng.seed = 20260928
	for i in mini(n, roster.size()):
		var row: Dictionary = roster[(i * 7) % roster.size()]
		var r := Resident.new()
		add_child(r)
		r.setup(self, int(row["id"]), String(row["handle"]))
		r.home_door = doors[i % doors.size()] if not doors.is_empty() else {}
		r.job = String(r.home_door.get("job", ""))   # 문에 적힌 일자리(빵집 문 → "baker") — 일은 진짜 장소에 매인다(run 72)
		r.position = Vector3(rng.randf_range(-WORLD_X + 4.0, WORLD_X - 4.0), 0.02, rng.randf_range(-2.0, 7.0))
		residents.append(r)

## 운전사 — 주민이 차는 운전하는 차(ai)마다 한 명씩 운전석에 앉는다(운영자 2026-09-30: "주민들이 차 운전도 하나?" — 전엔 빈 차가 혼자 굴렀다)
func _hire_drivers() -> void:
	var k := 0
	for c in cars:
		if not c.ai: continue
		while k < residents.size() and (residents[k].job != "" or residents[k].uid % 6 == 0): k += 1   # 빵집 주인·수리공은 제 일이 있다
		if k >= residents.size(): return
		residents[k].drive(c); k += 1

func _light() -> void:
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-52, 28, 0)
	sun.light_energy = 0.72   # 1.15 였을 땐 해+앰비언트가 1.7배라 밝은 색이 전부 흰색으로 날아갔다(진갈색 벤치가 살구색, 연못이 흰색 — 2026-09-28 스크린샷)
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 60.0
	sun.shadow_blur = 1.6
	add_child(sun)

func _solid_floor() -> void:
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new(); var bs := BoxShape3D.new(); bs.size = Vector3(WORLD_X * 2.0 + 10.0, 1, WORLD_Z * 2.0 + 10.0); cs.shape = bs
	sb.add_child(cs); sb.position.y = -0.5
	add_child(sb)

func _ground() -> void:
	# 땅은 열린 세계(WorldGen)가 칸마다 짓는다 — 허브 안은 평지(y 0)의 같은 풀밭, 밖은 언덕·숲·호수. 전엔 400m 판 하나와 먼 언덕 실루엣이었다
	gen = WorldGen.new(); gen.name = "World"; add_child(gen); gen.setup(self)
	gen.fill(Vector3(0, 0, 4))
	# 안개: 하늘색으로 멀리가 녹아든다
	var env := ($WorldEnvironment as WorldEnvironment).environment
	env.fog_enabled = true; env.fog_light_color = Color(0.93, 0.94, 0.92); env.fog_density = 0.011; env.fog_sky_affect = 0.0

## 자갈길 — 바닥보다 2cm 높은 납작한 상자(가장자리가 선으로 읽혀 길이 된다)
func _path(a: Vector3, b: Vector3, w: float) -> void:
	var d := b - a
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	var along := d.length()
	bm.size = Vector3(along, 0.02, w)   # 0.04 는 옆면이 보여 단처럼 읽혔다
	mi.mesh = bm
	mi.material_override = _mat(Color("d8d2cc"), _tex("ground/cobble"), Vector3(along / 0.8, w / 0.8, 1))   # 돌 한 개 ≈ 19cm(1.6 이면 40cm)
	mi.position = (a + b) / 2.0 + Vector3(0, 0.01, 0)
	mi.rotation.y = -atan2(d.z, d.x)
	add_child(mi)

## 집 — 시드로 정하는 사양(진짜 집처럼, 운영자 2026-09-28): 층수 1~2, 박공/평지붕, 벽 재질(널빤지·벽돌·회벽·색벽), 트림 색, 창 배치와 덧문·창턱,
## 처마·홈통·굴뚝·현관 지붕·계단·화단·우체통. 속은 비어 있고(벽 네 장) 경첩 문으로 들어간다. 들어가면 지붕·앞벽·천장이 사라져 안이 보인다(컷어웨이).
func _house(at: Vector3, size: Vector3, wall: Color, roof: String, flat_roof := false, seed := 0, inside := "") -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = 1000 + seed + int(at.x * 7.0 + at.z * 13.0)
	var storeys := 2 if (rng.randf() < 0.35 and not flat_roof) else 1
	size.y = size.y * (1.7 if storeys == 2 else 1.0)
	var mats := ["plank", "brick", "stucco", "colour"]
	var material: String = mats[rng.randi() % mats.size()]
	var trim_c: Color = [Color("efe9e2"), Color("f7f4ef"), Color("cfc7c2")][rng.randi() % 3]
	var wm: StandardMaterial3D
	match material:
		"plank": wm = _mat(Color.WHITE, _tex("faces/wall-plank"), Vector3(2.8, 2.8, 1)); wm.uv1_triplanar = true
		"brick": wm = _mat(Color.WHITE, _tex("faces/wall-brick"), Vector3(2.4, 2.4, 1)); wm.uv1_triplanar = true   # 1.6 은 벽돌 한 장이 머리만 했다
		"stucco": wm = _mat(wall, _tex("faces/wall-stucco"), Vector3(1.4, 1.4, 1)); wm.uv1_triplanar = true
		_: wm = _mat(wall)
	var trim := _mat(trim_c)
	var hw := size.x / 2.0; var hd := size.z / 2.0
	var door_w := 0.9; var door_h := 1.9
	var parts: Array[Node3D] = []   # 컷어웨이 대상(지붕·앞벽·천장·차양·앞창)
	var shell: Array[Node3D] = []   # 뒷벽·옆벽·옆창 — 2.5D 옆시점에서 카메라와 나 사이에 이 집이 있으면 이것까지 감춘다(북쪽 골목이 가운데 집들에 가려졌다)
	var seg := (size.x - door_w) / 2.0
	parts.append(_box(Vector3(seg, size.y, WALL), at + Vector3(-hw + seg / 2.0, 0, hd - WALL / 2.0), wm))
	parts.append(_box(Vector3(seg, size.y, WALL), at + Vector3(hw - seg / 2.0, 0, hd - WALL / 2.0), wm))
	parts.append(_box(Vector3(door_w + 0.02, size.y - door_h, WALL), at + Vector3(0, door_h, hd - WALL / 2.0), wm))
	shell.append(_box(Vector3(size.x, size.y, WALL), at + Vector3(0, 0, -hd + WALL / 2.0), wm))
	shell.append(_box(Vector3(WALL, size.y, size.z - WALL * 2.0), at + Vector3(-hw + WALL / 2.0, 0, 0), wm))
	shell.append(_box(Vector3(WALL, size.y, size.z - WALL * 2.0), at + Vector3(hw - WALL / 2.0, 0, 0), wm))
	# 기단(돌 띠)과 모서리 트림 — 벽이 잔디에 그냥 꽂혀 보이던 것(2026-09-28 검토). 앞은 문을 비워 두 토막
	var plinth := _mat(Color("bfb6b0"))
	_box(Vector3(seg, 0.2, 0.07), at + Vector3(-hw + seg / 2.0, 0, hd + 0.035), plinth, false)
	_box(Vector3(seg, 0.2, 0.07), at + Vector3(hw - seg / 2.0, 0, hd + 0.035), plinth, false)
	shell.append(_box(Vector3(size.x + 0.14, 0.2, 0.07), at + Vector3(0, 0, -hd - 0.035), plinth, false))
	shell.append(_box(Vector3(0.07, 0.2, size.z + 0.14), at + Vector3(-hw - 0.035, 0, 0), plinth, false))
	shell.append(_box(Vector3(0.07, 0.2, size.z + 0.14), at + Vector3(hw + 0.035, 0, 0), plinth, false))
	for cx in [-1.0, 1.0]:
		for cz in [-1.0, 1.0]:
			var board := _box(Vector3(0.1, size.y, 0.1), at + Vector3(cx * hw, 0, cz * hd), trim, false)
			if cz < 0.0: shell.append(board)
			else: parts.append(board)
	# 창: 층마다 정면 좌우 + 옆벽. 덧문은 집마다 있거나 없다
	var shutters := rng.randf() < 0.5
	var shutter_c: Color = [Color("7b526c"), Color("3f6b2f"), Color("4a4a52"), Color("b56a5a")][rng.randi() % 4]
	for st in storeys:
		var wy := 1.1 + st * (size.y / storeys)
		for wx in [-hw + seg / 2.0, hw - seg / 2.0]:
			parts.append(_window(at + Vector3(wx, wy, hd), 0.0, shutters, shutter_c))
		shell.append(_window(at + Vector3(-hw, wy, 0), PI / 2.0, shutters, shutter_c))
		shell.append(_window(at + Vector3(hw, wy, 0), -PI / 2.0, shutters, shutter_c))
	# 문틀·경첩·문짝(손잡이)
	_box(Vector3(0.08, door_h, WALL + 0.04), at + Vector3(-door_w / 2.0 - 0.04, 0, hd - WALL / 2.0), trim)
	_box(Vector3(0.08, door_h, WALL + 0.04), at + Vector3(door_w / 2.0 + 0.04, 0, hd - WALL / 2.0), trim)
	var hinge := Node3D.new()
	hinge.position = at + Vector3(-door_w / 2.0, 0, hd - WALL / 2.0)
	add_child(hinge)
	var door_c: Color = [Color("7b526c"), Color("8a6a4a"), Color("3f6b2f"), Color("1b0c15")][rng.randi() % 4]
	var leaf := _box(Vector3(door_w, door_h - 0.02, 0.07), Vector3(door_w / 2.0, 0, 0), _mat(door_c), true, hinge)
	var knob := MeshInstance3D.new(); var ks := SphereMesh.new(); ks.radius = 0.035; ks.height = 0.07; knob.mesh = ks
	knob.material_override = _mat(Color("e8c766")); knob.position = Vector3(door_w * 0.38, 0.0, 0.06); leaf.add_child(knob)
	var door_pos := hinge.position + Vector3(door_w / 2.0, 0, 0)
	doors.append({ "hinge": hinge, "open": false, "pos": door_pos, "hw": hw, "hd": hd })
	spots.append({ "pos": door_pos + Vector3(0, 0, 0.9), "kind": "door", "yaw": PI })
	# 현관 차양 + 계단 + 화단/우체통
	if rng.randf() < 0.6:
		var awn := _box(Vector3(door_w + 0.6, 0.06, 0.55), at + Vector3(0, door_h + 0.12, hd + 0.25), _mat(door_c), false)
		awn.rotation.x = 0.18
		parts.append(awn)
	_box(Vector3(1.3, 0.12, 0.5), at + Vector3(0, 0, hd + 0.25), _mat(Color("cfc7c2")))
	_ramp(at + Vector3(0, 0, hd + 0.5), 1.3, 0.12, 0.45)   # 계단 앞 경사(보이지 않음) — 사람도 주민도 걸어 넘는다
	if rng.randf() < 0.5:
		_box(Vector3(0.9, 0.3, 0.3), at + Vector3(-hw + 0.7, 0, hd + 0.35), _mat(Color("8a6a4a")))
		_box(Vector3(0.8, 0.08, 0.2), at + Vector3(-hw + 0.7, 0.3, hd + 0.35), _mat(Color("5f8a3e")), false)
		for fx in [-0.28, -0.1, 0.1, 0.28]:
			_flower(at + Vector3(-hw + 0.7 + fx, 0.38, hd + 0.35), [Color("ff2d55"), Color("e8c766"), Color("ad7096")][rng.randi() % 3], seed)
	if rng.randf() < 0.5:
		_box(Vector3(0.06, 0.8, 0.06), at + Vector3(hw - 0.4, 0, hd + 0.9), _mat(Color("4a4a52")))
		_box(Vector3(0.22, 0.16, 0.14), at + Vector3(hw - 0.4, 0.8, hd + 0.9), _mat(Color("ad7096")), false)
	# 지붕: 평지붕(옥상) 또는 박공(처마 돌출 + 홈통 + 굴뚝)
	var ceiling_y := size.y
	var cap: Node3D = null   # 굴뚝 갓 — 박공지붕에만 있다; 연기(town_systems _smoke)가 이 위에 선다
	if flat_roof:
		parts.append(_box(Vector3(size.x + 0.2, 0.16, size.z + 0.2), at + Vector3(0, size.y, 0), _mat(Color("cfc7c2"))))
		parts.append(_box(Vector3(size.x + 0.2, 0.5, 0.12), at + Vector3(0, size.y + 0.16, hd + 0.04), trim))
		parts.append(_box(Vector3(size.x + 0.2, 0.5, 0.12), at + Vector3(0, size.y + 0.16, -hd - 0.04), trim))
		parts.append(_box(Vector3(0.12, 0.5, size.z + 0.2), at + Vector3(-hw - 0.04, size.y + 0.16, 0), trim))
		_stairs(at + Vector3(hw + 0.55, 0, hd + 0.4), size.y + 0.16, 0.9)  # 집 앞에서 시작해 옆벽을 따라 뒤로
	else:
		var r := MeshInstance3D.new()
		var pr := PrismMesh.new(); pr.size = Vector3(size.z + 0.7, size.y * (0.42 if storeys == 1 else 0.28), size.x + 0.7)
		var roof_tex := "faces/roof-%s" % roof if rng.randf() < 0.6 else "faces/roof-shingle"
		r.mesh = pr; r.material_override = _mat(Color.WHITE, _tex(roof_tex), Vector3(3.2, 2.4, 1))   # (2.0, 1.5) 는 벽지처럼 보였다
		r.material_override.uv1_triplanar = true
		r.position = at + Vector3(0, size.y + pr.size.y / 2.0, 0)
		r.rotation.y = PI / 2.0
		add_child(r); parts.append(r)
		parts.append(_box(Vector3(size.x + 0.7, 0.07, 0.09), at + Vector3(0, size.y - 0.02, hd + 0.33), _mat(Color("4a4a52")), false))
		_box(Vector3(size.x + 0.7, 0.07, 0.09), at + Vector3(0, size.y - 0.02, -hd - 0.33), _mat(Color("4a4a52")), false)
		var chim := _box(Vector3(0.36, 0.7, 0.36), at + Vector3(size.x * (0.28 if rng.randf() < 0.5 else -0.28), size.y + pr.size.y * 0.55, -0.3), _mat(Color("b56a5a")), false)
		cap = _box(Vector3(0.44, 0.06, 0.44), Vector3.ZERO, _mat(Color("cfc7c2")), false)
		cap.position = chim.position + Vector3(0, 0.35, 0)
		parts.append(chim); parts.append(cap)
	parts.append(_box(Vector3(size.x, 0.06, size.z), at + Vector3(0, ceiling_y - 0.06, 0), trim, false))
	var before := spots.size()
	if inside == "": _interior(at, size, rng)
	else: call(inside, at, size)   # 집마다 다른 실내(편지방 run 99, town_letters) — 윗층 빌더라 이름으로 부른다
	for k in range(before, spots.size()):
		if spots[k]["kind"] in ["chair", "bed", "shelf", "letters"]: spots[k]["door"] = doors[doors.size() - 1]   # 의자만 달아 줬더니 침대·선반은 문 없이 벽을 향해 곧장 걷다 포기했고, 밤엔 아무도 침대에서 못 잤다
	houses.append({ "min": at + Vector3(-hw, 0, -hd), "max": at + Vector3(hw, size.y, hd), "parts": parts, "inside": false, "shell": shell, "behind": false, "chim": cap, "door": doors[doors.size() - 1] })   # chim·door: 굴뚝 연기(run 77)가 이 집 자리의 taken 을 찾는 열쇠

## 옮길 수 있는 가구 — 의자(앉는 자리 포함)·화분·소형 램프. 들면 충돌을 끄고, 놓으면 다시 켠다
func _furniture(kind: String, at: Vector3, yaw := 0.0) -> Node3D:
	var n := Node3D.new(); n.position = at; n.rotation.y = yaw; add_child(n)
	match kind:
		"chair":
			_box(Vector3(0.4, 0.45, 0.4), Vector3.ZERO, _mat(Color("8a6a4a")), true, n)
			_box(Vector3(0.4, 0.5, 0.05), Vector3(0, 0.45, -0.18), _mat(Color("8a6a4a")), false, n)
		"pot":
			_box(Vector3(0.3, 0.3, 0.3), Vector3.ZERO, _mat(Color("b56a5a")), true, n)
			var fl := MeshInstance3D.new(); var fs := SphereMesh.new(); fs.radius = 0.16; fs.height = 0.32; fl.mesh = fs
			fl.material_override = _mat(Color("7a9b4e")); fl.position = Vector3(0, 0.42, 0); n.add_child(fl)
		_:
			_box(Vector3(0.05, 1.3, 0.05), Vector3.ZERO, _mat(Color("4a4a52")), true, n)
			_box(Vector3(0.3, 0.22, 0.3), Vector3(0, 1.3, 0), _mat(Color("e8c766")), false, n)
			var l := OmniLight3D.new(); l.light_color = Color("e8c766"); l.light_energy = 0.7; l.omni_range = 3.5; l.position = Vector3(0, 1.5, 0); n.add_child(l)
			n.set_meta("light", l)
	n.set_meta("kind", kind)
	var entry := { "node": n, "kind": kind, "spot": null }
	if kind == "chair":
		var sp := { "pos": at, "kind": "chair", "yaw": yaw, "node": n }
		spots.append(sp); entry["spot"] = sp
	movables.append(entry)
	return n

## 실내 가구 — 집마다 조금씩 다르게. 전부 원시 도형: 널빤지 바닥, 러그, 침대, 식탁+의자, 선반+책, 램프
func _interior(at: Vector3, size: Vector3, rng: RandomNumberGenerator) -> void:
	var hw := size.x / 2.0 - WALL; var hd := size.z / 2.0 - WALL
	var floor_m := _mat(Color.WHITE, _tex("faces/wall-plank"), Vector3(size.x / 1.2, size.z / 1.2, 1)); floor_m.uv1_triplanar = true
	_box(Vector3(hw * 2.0, 0.03, hd * 2.0), at, floor_m, false)
	var rug_c: Color = [Color("ad7096"), Color("8fb8cc"), Color("e6d3a5")][rng.randi() % 3]
	_box(Vector3(1.4, 0.02, 1.0), at + Vector3(0, 0.03, 0.2), _mat(rug_c), false)
	var bx := -hw + 0.55; var bz := -hd + 0.85
	_box(Vector3(0.9, 0.35, 1.6), at + Vector3(bx, 0, bz), _mat(Color("8a6a4a")))
	_box(Vector3(0.84, 0.12, 1.5), at + Vector3(bx, 0.35, bz), _mat([Color("f7f4ef"), Color("dfe6ea"), Color("e6d3a5")][rng.randi() % 3]), false)
	_box(Vector3(0.6, 0.1, 0.35), at + Vector3(bx, 0.47, bz - 0.5), _mat(Color("f7f4ef")), false)
	spots.append({ "pos": at + Vector3(bx, 0.47, bz + 0.1), "kind": "bed", "yaw": 0.0 })  # yaw 0: 누우면 머리가 −z(베개) 쪽 — PI 였을 땐 거꾸로 잤다
	var tx := hw - 0.9; var tz := -hd + 1.2
	_box(Vector3(0.9, 0.05, 0.7), at + Vector3(tx, 0.7, tz), _mat(Color("b48a5a")))
	for c in [Vector3(-0.35, 0, 0.2), Vector3(0.35, 0, 0.2), Vector3(-0.35, 0, -0.2), Vector3(0.35, 0, -0.2)]:
		_box(Vector3(0.05, 0.7, 0.05), at + Vector3(tx, 0, tz) + c, _mat(Color("8a6a4a")), false)
	for cx in [-0.75, 0.75]:
		_furniture("chair", at + Vector3(tx + cx, 0, tz), 0.0)
	_furniture("pot", at + Vector3(-hw + 0.3, 0, hd - 0.35))
	_box(Vector3(1.2, 0.05, 0.3), at + Vector3(0.2, 1.4, -hd + 0.16), _mat(Color("8a6a4a")), false)
	spots.append({ "pos": at + Vector3(0.2, 0, -hd + 0.5), "kind": "shelf", "yaw": PI })
	for i in 5:
		_box(Vector3(0.06, 0.24, 0.2), at + Vector3(-0.2 + i * 0.13, 1.45, -hd + 0.16), _mat([Color("ad7096"), Color("7a9b4e"), Color("d98a2a"), Color("4a4a52"), Color("8fb8cc")][i]), false)
	_furniture("lamp", at + Vector3(hw - 0.35, 0, hd - 0.4))

## 보이지 않는 경사면 — at 은 아래쪽 끝(앞), 뒤(−z)로 length 만큼 가며 height 만큼 오른다
func _ramp(at: Vector3, w: float, height: float, length: float) -> void:
	var ramp := StaticBody3D.new(); var rc := CollisionShape3D.new(); var rb := BoxShape3D.new()
	rb.size = Vector3(w, 0.06, sqrt(length * length + height * height)); rc.shape = rb; ramp.add_child(rc)
	ramp.position = at + Vector3(0, height / 2.0 - 0.02, -length / 2.0)
	ramp.rotation.x = atan2(height, length)
	_add(ramp)

## 계단 — 집 오른쪽 벽을 따라 뒤로(−z) 오른다. 한 단 18cm×30cm, 폭 w. 꼭대기에서 옥상으로 이어진다
func _stairs(at: Vector3, height: float, w: float) -> void:
	var n := int(ceil(height / 0.25))   # 한 단 25cm — 집 깊이 안에 꼭대기가 오게(0.18 이면 3.8m 집을 넘어가 지붕과 못 만났다)
	var rise := height / n
	var stone := _mat(Color("bfb6b0"))
	for i in n:
		_box(Vector3(w, rise * (i + 1), 0.3), at + Vector3(0, 0, -i * 0.3), stone)
	_box(Vector3(0.06, 0.9, n * 0.3), at + Vector3(w / 2.0 + 0.03, 0, -(n - 1) * 0.15), _mat(Color("4a4a52")), false)  # 난간 기둥 대신 얇은 판
	# 경사면 충돌체(보이지 않음): 첫 단 앞에서 꼭대기까지 31° 램프 — 단차를 한 칸씩 넘는 방식은 가끔 걸렸다(운영자 지적)
	var length := n * 0.3
	var ramp := StaticBody3D.new(); var rc := CollisionShape3D.new(); var rb := BoxShape3D.new()
	var slope := sqrt(length * length + height * height)
	rb.size = Vector3(w, 0.1, slope); rc.shape = rb; ramp.add_child(rc)
	ramp.position = at + Vector3(0, height / 2.0 - 0.02, 0.15 - length / 2.0)
	ramp.rotation.x = atan2(height, length)   # 뒤(−z)로 갈수록 높아진다
	add_child(ramp)
	# 랜딩: 꼭대기 단에서 지붕 가장자리까지, 지붕 윗면(height)과 같은 높이의 발판 — 계단이 지붕으로 이어진다
	_box(Vector3(w + 1.0, 0.12, 0.7), at + Vector3(-(w + 1.0) / 2.0 + w / 2.0, height - 0.12, -(n - 1) * 0.3), stone)

## 서쪽 공원 — 연못(납작한 원반, 밝은 테두리), 놀이터(미끄럼틀·시소·그네·모래밭), 나무·벤치·화단, 자갈 산책로
func _park(at: Vector3) -> void:
	_path(at + Vector3(0, 0, 2.8), at + Vector3(0, 0, -8), 1.6)   # 큰길 가장자리(z 0.8)에서 시작 — 겹치면 이음새가 보였다
	water.disc(at + Vector3(-6, 0, -3), 3.2)   # 연못 — 물 애셋(강과 같은 수면·판정: 걸어 들어가면 헤엄, 운영자 지적 2026-09-28)
	spots.append({ "pos": at + Vector3(-6, 0, 0.9), "kind": "door", "yaw": PI })  # 연못가에 서기
	for p in [Vector3(-10, 0, 1.4), Vector3(-9, 0, -7), Vector3(2, 0, -8), Vector3(6, 0, 1), Vector3(9, 0, -5), Vector3(-2, 0, 7)]:   # 큰길(z 0.2..3.8) 밖으로 — 둘이 길 위에 있었다
		_tree(at + p, 1.1 + fmod(absf(p.x) * 0.23, 0.6))
	_bench(at + Vector3(-2.5, 0, 1.4)); _bench(at + Vector3(5.5, 0, 1.4))   # 큰길(z 0.2..3.8) 밖 — 전엔 z 1 이라 도로 위에 있어 차가 부수고 다녔다(2026-10-01)
	_lamp(at + Vector3(0.9, 0, 1.6)); _lamp(at + Vector3(-0.9, 0, -8.5))
	# 놀이터: 미끄럼틀(사다리+경사), 시소, 그네(틀+줄+좌석), 모래밭
	var wood := _mat(Color("b48a5a")); var iron := _mat(Color("4a4a52"))
	_box(Vector3(3.6, 0.12, 3.0), at + Vector3(6, 0, -5), _mat(Color("e6d3a5")))                       # 모래밭
	var slide := _box(Vector3(0.6, 0.06, 2.2), at + Vector3(4.3, 1.0, -6.8), _mat(Color("ad7096")), true); slide.rotation.x = -0.55
	_box(Vector3(0.6, 1.6, 0.06), at + Vector3(4.3, 0, -5.4), iron); _box(Vector3(0.7, 0.06, 0.7), at + Vector3(4.3, 1.6, -5.6), wood)
	var ss := Seesaw3D.new(); ss.position = at + Vector3(8.5, 0, -7.5); _add(ss); ss.build(wood, iron); seesaws.append(ss)   # 시소 — 탈 수 있다
	spots.append({ "pos": ss.position, "kind": "seesaw", "yaw": 0.0, "ss": ss })
	_swing(at + Vector3(9.6, 0, -3.0))
	for fx in [-4.0, 4.0]:
		_box(Vector3(1.6, 0.25, 0.5), at + Vector3(fx, 0, 6.6), _mat(Color("8a6a4a")))
		for i in 7:
			_flower(at + Vector3(fx - 0.65 + i * 0.22, 0.25, 6.6 + (0.08 if i % 2 == 0 else -0.08)), [Color("ff2d55"), Color("e8c766"), Color("ad7096"), Color("f7f4ef")][i % 4], i)
	_fence(at + Vector3(-12, 0, 8), 24.0)
	for i in 4: _animal("duck", at + Vector3(-6, 0.03, -3) + Vector3(cos(i * 1.57) * 2.0, 0, sin(i * 1.57) * 2.0), { "center": at + Vector3(-6, 0.03, -3), "phase": i * 1.57 })
	_animal("dog", at + Vector3(2, 0, 1), { "home": at + Vector3(2, 0, 1) })
	_animal("marten", at + Vector3(-10, 0, -6), { "home": at + Vector3(-10, 0, -6) })
	_animal("fox", at + Vector3(12, 0, -8), { "home": at + Vector3(12, 0, -8) })   # 육식동물 — 새를 노리고, 건드리면 문다

## 동쪽 시장 거리 — 노점(기둥+차양+판매대+물건), 상점 정면 둘(빵집·카페: 집 생성기에 간판 색만 다르게), 쓰레기통, 가로등, 자갈 광장
func _market(at: Vector3) -> void:
	var sq := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3(22, 0.04, 12); sq.mesh = bm
	sq.material_override = _mat(Color("d8d2cc"), _tex("ground/cobble"), Vector3(22 / 0.8, 12 / 0.8, 1)); sq.position = at + Vector3(0, 0.02, 1); _add(sq)
	for i in 4:
		_stall(at + Vector3(-7.5 + i * 5.0, 0, -1.5), [Color("ad7096"), Color("7a9b4e"), Color("e8c766"), Color("8fb8cc")][i])
	_house(at + Vector3(-6, 0, -8), Vector3(5.0, 2.8, 3.6), Color("e6d3a5"), "wood", false, 11)  # 빵집(집 생성기) — 지붕에 브랜드 분홍은 대면적 금지
	doors[doors.size() - 1]["job"] = "baker"   # 이 문의 주민이 빵집 주인(_residents 가 읽는다) — 창구가 비면 화덕에서 반죽해 채운다(CI run 72)
	_house(at + Vector3(5, 0, -8), Vector3(4.2, 2.6, 3.4), Color("f7f4ef"), "brick", false, 12)      # 카페
	doors[doors.size() - 1]["job"] = "cutler"   # 이 문의 주민이 칼갈이 — 광장 동쪽 끝 숫돌(town_trades)이 낮 일터(run 81)
	_counter(at + Vector3(-7.6, 0, -6.1), "bread", Color("e6d3a5"), 3)   # 빵집 창구(정면 왼쪽) — 빵 셋, 팔리면 준다. 화덕은 town3d._ready 가 문 오른쪽에(places 층이라 여선 못 부른다)
	_counter(at + Vector3(6.4, 0, -6.2), "cup", Color("8a6a4a"))       # 카페 테이크아웃 창구
	_hatstand(at + Vector3(-11.5, 0, -3.5))   # 모자 거치대 — C 로 하나 집어 쓴다
	_lamp(at + Vector3(-10, 0, 1.6)); _lamp(at + Vector3(0, 0, 1.6)); _lamp(at + Vector3(10, 0, 1.6))   # 길 북쪽 가 — 전엔 z 2(큰길 한가운데)
	_bin(at + Vector3(-9.5, 0, -0.5)); _bin(at + Vector3(9.5, 0, -0.5))
	_bench(at + Vector3(0, 0, 6.6))
	_animal("cat", at + Vector3(8.5, 0, 6.0), { "home": at + Vector3(8.5, 0, 6.0) })
	for i in 5: _animal("pigeon", at + Vector3(-4 + i * 2.0, 0, 2.5 + (i % 2) * 1.2), { "home": at + Vector3(-4 + i * 2.0, 0, 2.5 + (i % 2) * 1.2) })
	_item("apple", at + Vector3(-7.5, 0.95, -1.3)); _item("cup", at + Vector3(2.5, 0.95, -1.3)); _item("paper", at + Vector3(7.5, 0.95, -1.3))

## 동물 — 원시 도형 몸 + 아주 단순한 습성. 전부 코드
func _animal(kind: String, at: Vector3, data: Dictionary) -> void:
	var n := Node3D.new(); n.position = at; _add(n)
	match kind:
		"duck", "pigeon":
			# 새는 절차 리그(bird3d.gd) — Gobkit 오리는 시트로 보니 우리 것보다 못했다(2026-09-29), CC0 대안은 아직 없다
			var bd := Bird3D.new()
			if kind == "duck": bd.setup("duck", Color("e6d3a5"), Color("b48a5a"))
			else: bd.setup("pigeon", Color("8a7f86"), Color("5b4f56"))
			n.add_child(bd); data["bird"] = bd
		"dog", "fox", "wolf", "deer":
			# 외부 모델(Quaternius Ultimate Animated Animals, CC0) — Quad3D 와 같은 상태 API(운영자 2026-09-28: 외부 에셋으로)
			var q := Animal3D.new(); q.setup(kind); n.add_child(q); data["quad"] = q
			if kind == "fox":
				# 굴(CI 2026-09-28, "쓰러진 사람 곁의 동물"): 집 자리 뒤에 흙 둔덕과 검은 입구 — 여우가 물어 간 것은 이 앞에 놓인다
				var mound := MeshInstance3D.new(); var ms := SphereMesh.new(); ms.radius = 0.7; ms.height = 0.5; mound.mesh = ms; mound.material_override = _mat(Color("8a6a4a")); mound.position = at + Vector3(0, -0.02, -0.8); _add(mound)
				var hole := MeshInstance3D.new(); var hs2 := SphereMesh.new(); hs2.radius = 0.24; hs2.height = 0.36; hole.mesh = hs2; hole.material_override = _mat(Color("1b0c15")); hole.position = at + Vector3(0, 0.1, -0.35); _add(hole)
		"cat", "squirrel", "marten":
			# 고양이·다람쥐·담비는 CC0 애니메이션 모델이 없어(Gobkit 마못은 너무 저품질) 절차 리그(quad3d.gd)
			var q := Quad3D.new()
			match kind:
				"cat": q.setup("cat", Color("4a4a52"), Color("3a2f36"), 1.0)
				"marten": q.setup("marten", Color("8a6a4a"), Color("5b4f56"), 1.0)
				_: q.setup("squirrel", Color("9a6a3f"), Color("8a6a4a"), 1.0)
			n.add_child(q); data["quad"] = q
	data["kind"] = kind; data["node"] = n; data["t"] = randf() * 10.0; data["fly"] = 0.0
	animals.append(data)

## 나무 — Quaternius Stylized Nature MegaKit(CC0, 텍스처·잎 포함) 모델. 시드로 종류를 고르고 2.8~3.8m 로 맞춘다(사람 1m). 운영자 2026-09-29: "나무들도 진짜 나무같아야".
## 루트(충돌체)는 고정하고 모델을 담은 자식(sway)만 바람에 기울인다 — 뿌리째 흔들리고 콜라이더까지 기울던 리뷰 버그
const TREE_KINDS := ["CommonTree_1", "CommonTree_2", "CommonTree_3", "CommonTree_4", "CommonTree_5", "CommonTree_2", "Pine_1", "Pine_3"]
func _tree(at: Vector3, k: float) -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = int(at.x * 13.0 + at.z * 7.0) + 5
	var which: String = TREE_KINDS[rng.randi() % TREE_KINDS.size()]
	var model := _model("nature/quaternius/" + which)
	var h := _model_height(model)
	var sc := (2.8 + 1.2 * (k - 0.9)) / maxf(h, 0.5)
	var base := Node3D.new(); base.position = at; base.rotation.y = rng.randf_range(0.0, TAU); _add(base)
	var sway := Node3D.new(); base.add_child(sway)
	model.scale = Vector3.ONE * sc; sway.add_child(model)
	var sb := StaticBody3D.new(); var cs := CollisionShape3D.new(); var sh := CylinderShape3D.new(); sh.radius = 0.22 * k; sh.height = 1.2; cs.shape = sh; cs.position.y = 0.6; sb.add_child(cs); base.add_child(sb)
	spots.append({ "pos": at, "kind": "tree", "yaw": 0.0 })
	var fruit: Array = []
	var top := h * sc
	if not which.begins_with("Pine"):
		for i in 3:
			var f := MeshInstance3D.new(); var fs := SphereMesh.new(); fs.radius = 0.08; fs.height = 0.16; f.mesh = fs; f.material_override = _mat(Color("ff2d55"))
			f.position = Vector3(cos(i * 2.1) * 0.9, top * (0.5 + (i % 2) * 0.12), sin(i * 2.1) * 0.9)
			sway.add_child(f); fruit.append(f)
	crowns.append({ "node": sway, "phase": at.x * 0.7 + at.z * 0.3, "k": k, "fruit": fruit, "at": at })

## 강과 돌다리와 남쪽 초원(비전 2단계, 2026-09-28 — 마을은 매달 눈에 띄게 넓어져야 한다): 물 띠(세계 끝까지), 돌 둑, 흐르는 물결 조각,
## x=0 에 아치 돌다리(얇은 상판 일곱 토막이 호를 그린다 — 턱은 step_up 이 넘는다, 난간은 안 막아서 뛰어들 수 있다), 다리 앞뒤 자갈길,
## 초원엔 나무 셋과 풀밭 자리 셋(누워 하늘 보기 `sky`), 강가 자리 둘(서서 물 보기), 뒤 울타리. 구역이 아니라 항상 켜져 있다(강은 전체 폭)
func _river() -> void:
	water.band(Vector3(0, 0, RIVER_Z), WORLD_X * 2.0 + 20.0, RIVER_HW * 2.0, 0.35)
	for xs in [-1.0, 1.0]: water.band(Vector3(xs * (OPEN + WORLD_X + 10.0) / 2.0, 0, RIVER_Z), OPEN - WORLD_X - 10.0, RIVER_HW * 2.0, 0.35, false)   # 허브 밖으로 세계 끝까지(물결 조각 없이)   # 물 애셋: 수면·둑·물결·판정
	var stone := _mat(Color("bfb6b0")); var dark := _mat(Color("8a7f86"))
	var n := 7; var bspan := RIVER_HW * 2.0 + 1.4; var seg := bspan / n
	for i in n:
		var h := 0.16 + 0.34 * sin(PI * (i + 0.5) / n)
		var z := RIVER_Z - bspan / 2.0 + seg * (i + 0.5)
		var slope := atan2(0.34 * PI / n * cos(PI * (i + 0.5) / n), seg)   # 토막을 호의 기울기로 눕혀 계단이 아니라 아치로 읽히게(충돌체도 같이 기울어 경사로가 된다)
		_box(Vector3(BRIDGE_HW * 2.0, 0.16, seg + 0.06), Vector3(0, h - 0.16, z), stone).rotation.x = -slope
		for xs in [-1.0, 1.0]:
			_box(Vector3(0.12, 0.34, seg + 0.06), Vector3(xs * (BRIDGE_HW - 0.06), h, z), dark, false).rotation.x = -slope   # 난간
	for zs in [-1.0, 1.0]:
		_box(Vector3(BRIDGE_HW * 2.0 + 0.3, 0.14, 0.5), Vector3(0, 0, RIVER_Z + zs * (bspan / 2.0 + 0.2)), dark)   # 교대(발치)
	_path(Vector3(0, 0, 3.2), Vector3(0, 0, RIVER_Z - bspan / 2.0 - 0.4), 2.0)
	_path(Vector3(0, 0, RIVER_Z + bspan / 2.0 + 0.4), Vector3(0, 0, RIVER_Z + bspan / 2.0 + 4.0), 2.0)
	_tree(Vector3(-9, 0, 17.5), 1.25); _tree(Vector3(10, 0, 18.5), 1.1); _tree(Vector3(3, 0, 21), 0.95)
	# 풀밭: 자리가 아니라 구역(반지름 r) — 그 안 아무 데서나 눕는다(운영자: 가운데로 걸어가 눕는 게 어색). 들꽃이 흩어져 있어 눈에 띈다
	var frng := RandomNumberGenerator.new(); frng.seed = 3
	for g in [Vector3(-3.5, 0, 16.5), Vector3(4.5, 0, 17.5), Vector3(-0.5, 0, 19.5)]:
		spots.append({ "pos": g, "kind": "grass", "yaw": PI, "r": 1.8 })
		for i in 9:
			_flower(g + Vector3(frng.randf_range(-1.9, 1.9), 0, frng.randf_range(-1.6, 1.6)), [Color("ff2d55"), Color("e8c766"), Color("ad7096"), Color("f7f4ef"), Color("8fb8cc")][frng.randi() % 5], i)
	var srng := RandomNumberGenerator.new(); srng.seed = 21
	for i in 26: _scatter(["Grass_Common_Short", "Grass_Wispy_Short", "Grass_Common_Tall", "Clover_1", "Clover_2"][i % 5], Vector3(srng.randf_range(-15, 15), 0, srng.randf_range(14.3, 22.2)), srng.randf_range(0.28, 0.42))
	for i in 5: _scatter(["Bush_Common", "Bush_Common_Flowers", "Bush_Common", "Bush_Common_Flowers", "Bush_Common"][i], Vector3(srng.randf_range(-14, 14), 0, srng.randf_range(19.5, 22)), srng.randf_range(0.45, 0.7))
	for i in 6: _scatter(["Rock_Medium_1", "Pebble_Round_1", "Rock_Medium_2", "Pebble_Round_3", "Rock_Medium_3", "Pebble_Round_5"][i], Vector3(srng.randf_range(-14, 14), 0, RIVER_Z + RIVER_HW + srng.randf_range(0.4, 1.2)), srng.randf_range(0.18, 0.32))
	for i in 3: _scatter("Mushroom_Common", Vector3(srng.randf_range(-12, 12), 0, srng.randf_range(15, 21)), 0.25)
	spots.append({ "pos": Vector3(-5, 0, RIVER_Z + RIVER_HW + 0.6), "kind": "bank", "yaw": PI })
	spots.append({ "pos": Vector3(6, 0, RIVER_Z - RIVER_HW - 0.6), "kind": "bank", "yaw": 0.0 })
	_fence(Vector3(-16, 0, 24.5), 32.0)   # 뒤 울타리 — 텃밭(z 19.6..23.4) 뒤로

## 언덕(운영자 2026-09-29: 오르막 내리막) — 코사인 봉우리 높이장. 메시와 HeightMapShape3D 충돌체가 같은 격자라 보이는 대로 딛고 달린다
func _hill(c: Vector3, r: float, h: float) -> void:
	var n := 33; var step := (r * 2.0) / (n - 1)
	var heights := PackedFloat32Array(); heights.resize(n * n)
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hf := func(ix: int, iz: int) -> float:
		var x := -r + ix * step; var z := -r + iz * step
		var d := sqrt(x * x + z * z) / r
		return h * (0.5 + 0.5 * cos(PI * d)) if d < 1.0 else 0.0
	for iz in n:
		for ix in n: heights[iz * n + ix] = hf.call(ix, iz)
	for iz in n - 1:
		for ix in n - 1:
			var p00 := Vector3(-r + ix * step, heights[iz * n + ix], -r + iz * step)
			var p10 := Vector3(-r + (ix + 1) * step, heights[iz * n + ix + 1], -r + iz * step)
			var p01 := Vector3(-r + ix * step, heights[(iz + 1) * n + ix], -r + (iz + 1) * step)
			var p11 := Vector3(-r + (ix + 1) * step, heights[(iz + 1) * n + ix + 1], -r + (iz + 1) * step)
			for v in [p00, p10, p01, p10, p11, p01]: st.set_uv(Vector2(v.x, v.z) / TILE); st.add_vertex(v)
	st.generate_normals()
	var mi := MeshInstance3D.new(); mi.mesh = st.commit()
	mi.material_override = _mat(Color.WHITE, _tex("ground/grass"), Vector3(1, 1, 1)); mi.position = c + Vector3(0, 0.005, 0); add_child(mi)
	var sb := StaticBody3D.new(); var cs := CollisionShape3D.new(); var hs := HeightMapShape3D.new()
	hs.map_width = n; hs.map_depth = n; hs.map_data = heights; cs.shape = hs; cs.scale = Vector3(step, 1.0, step)
	sb.add_child(cs); sb.position = c; add_child(sb)

## 집을 수 있는 것 — 작은 기하 하나씩(사과 = 구, 컵 = 원기둥, 신문 = 납작한 상자). 손에 들면 hand_r 의 자식이 된다
func _item(kind: String, at: Vector3) -> void:
	items.append(make_item(kind, at))
