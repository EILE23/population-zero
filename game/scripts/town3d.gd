extends Node3D
## 3D 마을 시제품 — 오메가루비 식 3/4 시점(운영자 2026-09-28: "최소한 오메가루비 같은 퀄리티"). 전부 코드로 만든 기하:
## 속이 빈 집(벽 네 장, 창은 기하, 경첩 달린 문짝 — 열고 들어간다), 기둥+구 나무, 타일 바닥과 자갈길, 벤치·가로등·울타리,
## 방향광 하나와 그림자, 툰 확산, 입체 졸라맨(Stick3D). 상호작용은 C 하나: 들고 있으면 내려놓기, 아니면 가까운 것부터 — 물건 집기 · 문 열닫기 · 벤치 앉기.

const TILE := 2.0
const WALK := 2.6
const G := 22.0
## 점프는 짧은 홉(Climb 의 힘 모으기는 마을에 안 맞는다) — 벤치(0.45m)·계단·낮은 담 위에 올라설 만큼, 집 벽은 못 넘는다
const HOP := 5.4
const JUMP_HOLD := 0.28   # 점프 홀드 최대(초) — 누르는 동안 더 높이·멀리(가변 점프)
const WALL := 0.16
const WORLD_X := 46.0    # 세계 반폭(m): 서쪽 공원(-46..-16) · 마을(-16..16) · 동쪽 시장(16..46)
const WORLD_Z := 12.0
const DAY_LEN := 720.0   # 낮밤 한 바퀴(초) = 12분

var player: Stick3D
var body: CharacterBody3D
var cam: Camera3D
var last_tap := ""
var last_tap_at := -1.0
var dash_until := -1.0
var running := false        # 더블탭 뒤 방향키를 계속 누르는 동안 달린다
var idle_since := -1.0
var action_until := 0.0
var jump_at := -1.0
var jump_hold_until := -1.0
var jump_from_speed := 0.0
var dash_jump := false     # 대시 중에 뛴 점프인가 — 제트킥은 이때만
var was_airborne := false
var land_until := -1.0
var jet := false           # 제트킥 비행 중 — 착지까지 자세 유지, 조작 불가   # 착지 반동(무릎 꺾임) 끝나는 시각
var throw_at := -1.0
var throw_charge := -1.0   # X 를 누르기 시작한 시각(들고 있을 때) — 누르는 동안 감고, 떼면 던진다
const THROW_MAX := 0.8
var throw_power := 0.0
var push_at := -1.0
var push_amount := 0.0
var push_lift := 0.0
var flying: Array = []   # 던져진 것 {node, vel, spin} — 포물선으로 날다 바닥에 떨어져 다시 집을 수 있다
var seat: Dictionary = {}       # 앉아 있는 벤치 {pos, yaw}
var items: Array[Node3D] = []   # 바닥에 있는 집을 수 있는 것
var benches: Array = []         # {pos: Vector3, yaw: float}
var doors: Array = []           # {hinge: Node3D, open: bool, pos: Vector3}
var spots: Array = []           # 주민 일과 자리 {pos, kind: bench|lamp|tree|door, yaw}
var residents: Array = []
var combo := 0                  # 연속기 단계(0 왼 잽 → 1 오른 스트레이트 → 2 왼 훅)
var combo_open_until := -1.0    # 이 시각 안에 다시 누르면 다음 타
var hit_kind := ""              # 이번 타격의 종류(맞히기 판정용): punch | kick | jet | air
var my_hits := 0
var my_last_hit := -9.0
var down_until := -1.0          # 내가 넘어져 있는 동안
var getup_until := -1.0

func _ready() -> void:
	_light()
	_ground()
	_solid_floor()
	_path(Vector3(-WORLD_X, 0, 2), Vector3(WORLD_X, 0, 2), 2.4)  # 큰길: 공원 ↔ 마을 ↔ 시장
	_district("park", Vector3(-31, 0, -2), _park)
	_district("market", Vector3(31, 0, -2), _market)
	_sun = get_node_or_null("Sun")
	_path(Vector3(0, 0, 2), Vector3(0, 0, -10), 2.0)
	_house(Vector3(-7, 0, -4), Vector3(4.0, 2.6, 3.4), Color("dfe6ea"), "accent-deep", false, 1)
	_house(Vector3(0.5, 0, -6), Vector3(3.4, 3.1, 3.2), Color("f7f4ef"), "brick", false, 2)
	_house(Vector3(7, 0, -4), Vector3(5.0, 2.4, 3.8), Color("e6d3a5"), "iron", true, 3)  # 계단집 — 옥상까지 걸어 올라간다
	_house(Vector3(-12, 0, -8), Vector3(3.6, 2.8, 3.2), Color("b56a5a"), "wood", false, 4)
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
	_residents(24)

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
		r.position = Vector3(rng.randf_range(-WORLD_X + 4.0, WORLD_X - 4.0), 0.02, rng.randf_range(-2.0, 7.0))
		residents.append(r)

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
var _sun: DirectionalLight3D
var districts: Array = []   # {node, center, on}
var _build_parent: Node3D = null   # 구역을 지을 때 add_child 가 향하는 곳

## 구역 — 자기 노드 아래에 짓고 중심을 기억한다. _stream() 이 거리로 켜고 끈다
func _district(name: String, center: Vector3, builder: Callable) -> void:
	var n := Node3D.new(); n.name = "District_" + name; add_child(n)
	_build_parent = n
	builder.call(center)
	_build_parent = null
	districts.append({ "node": n, "center": center, "on": true })

## 스트리밍(첫 단계): 플레이어에서 34m 넘게 먼 구역은 끈다 — 그리기·물리·주민 처리 비용이 빠진다. 씬 단위 로딩은 맵이 더 커질 때
func _stream() -> void:
	var p := body.global_position
	for d in districts:
		var on: bool = absf(p.x - d["center"].x) < 34.0
		if on != d["on"]:
			d["on"] = on
			var n: Node3D = d["node"]
			n.visible = on
			n.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED
var lamps: Array = []   # 저녁에 켜지는 불 {light, bulb}
var clock := 0.3        # 0..1 하루 — 0.3 = 아침에서 시작

func _light() -> void:
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
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
	if parent == self:
		_add(mi)
	else:
		parent.add_child(mi)
	return mi

## 지을 때의 부모 — 구역 안이면 구역 노드, 아니면 마을
func _add(n: Node) -> void:
	if _build_parent != null:
		_build_parent.add_child(n)
	else:
		add_child(n)

func _solid_floor() -> void:
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new(); var bs := BoxShape3D.new(); bs.size = Vector3(WORLD_X * 2.0 + 10.0, 1, WORLD_Z * 2.0 + 10.0); cs.shape = bs
	sb.add_child(cs); sb.position.y = -0.5
	add_child(sb)

func _ground() -> void:
	var g := MeshInstance3D.new()
	var pm := PlaneMesh.new(); pm.size = Vector2(WORLD_X * 2.0, WORLD_Z * 2.0 + 8.0)
	g.mesh = pm
	g.material_override = _mat(Color.WHITE, _tex("ground/grass"), Vector3(WORLD_X * 2.0 / TILE, (WORLD_Z * 2.0 + 8.0) / TILE, 1))
	g.position = Vector3(0, 0, -2)
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

## 집 — 시드로 정하는 사양(진짜 집처럼, 운영자 2026-09-28): 층수 1~2, 박공/평지붕, 벽 재질(널빤지·벽돌·회벽·색벽), 트림 색, 창 배치와 덧문·창턱,
## 처마·홈통·굴뚝·현관 지붕·계단·화단·우체통. 속은 비어 있고(벽 네 장) 경첩 문으로 들어간다. 들어가면 지붕·앞벽·천장이 사라져 안이 보인다(컷어웨이).
func _house(at: Vector3, size: Vector3, wall: Color, roof: String, flat_roof := false, seed := 0) -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = 1000 + seed + int(at.x * 7.0 + at.z * 13.0)
	var storeys := 2 if (rng.randf() < 0.35 and not flat_roof) else 1
	size.y = size.y * (1.7 if storeys == 2 else 1.0)
	var mats := ["plank", "brick", "stucco", "colour"]
	var material: String = mats[rng.randi() % mats.size()]
	var trim_c: Color = [Color("efe9e2"), Color("f7f4ef"), Color("cfc7c2")][rng.randi() % 3]
	var wm: StandardMaterial3D
	match material:
		"plank": wm = _mat(Color.WHITE, _tex("faces/wall-plank"), Vector3(2.2, 2.2, 1)); wm.uv1_triplanar = true
		"brick": wm = _mat(Color.WHITE, _tex("faces/wall-brick"), Vector3(1.6, 1.6, 1)); wm.uv1_triplanar = true
		"stucco": wm = _mat(wall, _tex("faces/wall-stucco"), Vector3(1.4, 1.4, 1)); wm.uv1_triplanar = true
		_: wm = _mat(wall)
	var trim := _mat(trim_c)
	var hw := size.x / 2.0; var hd := size.z / 2.0
	var door_w := 0.9; var door_h := 1.9
	var parts: Array[Node3D] = []   # 컷어웨이 대상(지붕·앞벽·천장·차양·앞창)
	var seg := (size.x - door_w) / 2.0
	parts.append(_box(Vector3(seg, size.y, WALL), at + Vector3(-hw + seg / 2.0, 0, hd - WALL / 2.0), wm))
	parts.append(_box(Vector3(seg, size.y, WALL), at + Vector3(hw - seg / 2.0, 0, hd - WALL / 2.0), wm))
	parts.append(_box(Vector3(door_w + 0.02, size.y - door_h, WALL), at + Vector3(0, door_h, hd - WALL / 2.0), wm))
	_box(Vector3(size.x, size.y, WALL), at + Vector3(0, 0, -hd + WALL / 2.0), wm)
	_box(Vector3(WALL, size.y, size.z - WALL * 2.0), at + Vector3(-hw + WALL / 2.0, 0, 0), wm)
	_box(Vector3(WALL, size.y, size.z - WALL * 2.0), at + Vector3(hw - WALL / 2.0, 0, 0), wm)
	# 창: 층마다 정면 좌우 + 옆벽. 덧문은 집마다 있거나 없다
	var shutters := rng.randf() < 0.5
	var shutter_c: Color = [Color("7b526c"), Color("3f6b2f"), Color("4a4a52"), Color("b56a5a")][rng.randi() % 4]
	for st in storeys:
		var wy := 1.1 + st * (size.y / storeys)
		for wx in [-hw + seg / 2.0, hw - seg / 2.0]:
			parts.append(_window(at + Vector3(wx, wy, hd), 0.0, shutters, shutter_c))
		_window(at + Vector3(-hw, wy, 0), PI / 2.0, shutters, shutter_c)
		_window(at + Vector3(hw, wy, 0), -PI / 2.0, shutters, shutter_c)
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
	doors.append({ "hinge": hinge, "open": false, "pos": door_pos })
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
		for fx in [-0.25, 0.0, 0.25]:
			var fl := MeshInstance3D.new(); var fs := SphereMesh.new(); fs.radius = 0.05; fs.height = 0.1; fl.mesh = fs
			fl.material_override = _mat([Color("ff2d55"), Color("e8c766"), Color("ad7096")][rng.randi() % 3]); fl.position = at + Vector3(-hw + 0.7 + fx, 0.44, hd + 0.35); add_child(fl)
	if rng.randf() < 0.5:
		_box(Vector3(0.06, 0.8, 0.06), at + Vector3(hw - 0.4, 0, hd + 0.9), _mat(Color("4a4a52")))
		_box(Vector3(0.22, 0.16, 0.14), at + Vector3(hw - 0.4, 0.8, hd + 0.9), _mat(Color("ad7096")), false)
	# 지붕: 평지붕(옥상) 또는 박공(처마 돌출 + 홈통 + 굴뚝)
	var ceiling_y := size.y
	if flat_roof:
		parts.append(_box(Vector3(size.x + 0.2, 0.16, size.z + 0.2), at + Vector3(0, size.y, 0), _mat(Color("cfc7c2"))))
		parts.append(_box(Vector3(size.x + 0.2, 0.5, 0.12), at + Vector3(0, size.y + 0.16, hd + 0.04), trim))
		parts.append(_box(Vector3(size.x + 0.2, 0.5, 0.12), at + Vector3(0, size.y + 0.16, -hd - 0.04), trim))
		parts.append(_box(Vector3(0.12, 0.5, size.z + 0.2), at + Vector3(-hw - 0.04, size.y + 0.16, 0), trim))
		_stairs(at + Vector3(hw + 0.55, 0, hd - 0.4), size.y + 0.16, 0.9)
	else:
		var r := MeshInstance3D.new()
		var pr := PrismMesh.new(); pr.size = Vector3(size.z + 0.7, size.y * (0.42 if storeys == 1 else 0.28), size.x + 0.7)
		var roof_tex := "faces/roof-%s" % roof if rng.randf() < 0.6 else "faces/roof-shingle"
		r.mesh = pr; r.material_override = _mat(Color.WHITE, _tex(roof_tex), Vector3(2.0, 1.5, 1))
		r.material_override.uv1_triplanar = true
		r.position = at + Vector3(0, size.y + pr.size.y / 2.0, 0)
		r.rotation.y = PI / 2.0
		add_child(r); parts.append(r)
		parts.append(_box(Vector3(size.x + 0.7, 0.07, 0.09), at + Vector3(0, size.y - 0.02, hd + 0.33), _mat(Color("4a4a52")), false))
		_box(Vector3(size.x + 0.7, 0.07, 0.09), at + Vector3(0, size.y - 0.02, -hd - 0.33), _mat(Color("4a4a52")), false)
		var chim := _box(Vector3(0.36, 0.7, 0.36), at + Vector3(size.x * (0.28 if rng.randf() < 0.5 else -0.28), size.y + pr.size.y * 0.55, -0.3), _mat(Color("b56a5a")), false)
		var cap := _box(Vector3(0.44, 0.06, 0.44), Vector3.ZERO, _mat(Color("cfc7c2")), false)
		cap.position = chim.position + Vector3(0, 0.35, 0)
		parts.append(chim); parts.append(cap)
	parts.append(_box(Vector3(size.x, 0.06, size.z), at + Vector3(0, ceiling_y - 0.06, 0), trim, false))
	var before := spots.size()
	_interior(at, size, rng)
	for k in range(before, spots.size()):
		if spots[k]["kind"] == "chair": spots[k]["door"] = doors[doors.size() - 1]
	houses.append({ "min": at + Vector3(-hw, 0, -hd), "max": at + Vector3(hw, size.y, hd), "parts": parts, "inside": false })

var houses: Array = []
var movables: Array = []       # 옮길 수 있는 가구 {node, kind, spot}

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

func _set_solid(n: Node3D, solid: bool) -> void:
	for c in n.get_children():
		for cc in c.get_children():
			if cc is StaticBody3D:
				(cc as StaticBody3D).process_mode = Node.PROCESS_MODE_INHERIT if solid else Node.PROCESS_MODE_DISABLED
				for sh in cc.get_children():
					if sh is CollisionShape3D: (sh as CollisionShape3D).disabled = not solid

var carrying_big: Dictionary = {}   # 두 손에 든 가구(movables 항목)
var act_down_at := -1.0
var resting := false   # 침대에 누움

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
	spots.append({ "pos": at + Vector3(bx, 0.47, bz + 0.1), "kind": "bed", "yaw": PI })
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

## 컷어웨이 — 플레이어가 집 안에 있으면 지붕·앞벽·천장·차양·앞창을 감춘다(운영자: 들어가면 캐릭터가 가려져 안 보였다)
func _cutaway() -> void:
	var p := body.global_position
	for h in houses:
		var inside: bool = p.x > h["min"].x and p.x < h["max"].x and p.z > h["min"].z and p.z < h["max"].z and p.y < h["max"].y
		if inside != h["inside"]:
			h["inside"] = inside
			for n in h["parts"]:
				n.visible = not inside

## 계단 — 집 오른쪽 벽을 따라 뒤로(−z) 오른다. 한 단 18cm×30cm, 폭 w. 꼭대기에서 옥상으로 이어진다
func _stairs(at: Vector3, height: float, w: float) -> void:
	var n := int(ceil(height / 0.18))
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

func _window(at: Vector3, yaw: float, shutters := false, shutter_c := Color("7b526c")) -> Node3D:
	var n := Node3D.new(); n.position = at; n.rotation.y = yaw; add_child(n)
	_box(Vector3(0.74, 0.84, 0.06), Vector3(0, 0, 0), _mat(Color("efe9e2")), false, n)
	_box(Vector3(0.6, 0.7, 0.08), Vector3(0, 0.07, 0), _mat(Color("dfe6ea")), false, n)
	_box(Vector3(0.04, 0.7, 0.09), Vector3(0, 0.07, 0), _mat(Color("efe9e2")), false, n)
	_box(Vector3(0.6, 0.04, 0.09), Vector3(0, 0.40, 0), _mat(Color("efe9e2")), false, n)
	_box(Vector3(0.84, 0.06, 0.16), Vector3(0, -0.04, 0.02), _mat(Color("cfc7c2")), false, n)
	if shutters:
		_box(Vector3(0.22, 0.8, 0.05), Vector3(-0.5, 0.02, 0.0), _mat(shutter_c), false, n)
		_box(Vector3(0.22, 0.8, 0.05), Vector3(0.5, 0.02, 0.0), _mat(shutter_c), false, n)
	return n

## 서쪽 공원 — 연못(납작한 원반, 밝은 테두리), 놀이터(미끄럼틀·시소·그네·모래밭), 나무·벤치·화단, 자갈 산책로
func _park(at: Vector3) -> void:
	_path(at + Vector3(0, 0, 4), at + Vector3(0, 0, -8), 1.6)
	# 연못: 물 원반 + 테두리
	var pond := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = 3.2; cm.bottom_radius = 3.2; cm.height = 0.04
	pond.mesh = cm; pond.material_override = _mat(Color("8fb8cc")); pond.position = at + Vector3(-6, 0.02, -3); _add(pond)
	var rim := MeshInstance3D.new(); var rm := CylinderMesh.new(); rm.top_radius = 3.5; rm.bottom_radius = 3.5; rm.height = 0.03
	rim.mesh = rm; rim.material_override = _mat(Color("cfc7c2")); rim.position = at + Vector3(-6, 0.01, -3); _add(rim)
	spots.append({ "pos": at + Vector3(-6, 0, 0.9), "kind": "door", "yaw": PI })  # 연못가에 서기
	for p in [Vector3(-10, 0, 2), Vector3(-9, 0, -7), Vector3(2, 0, -8), Vector3(6, 0, 1), Vector3(9, 0, -5), Vector3(-2, 0, 5)]:
		_tree(at + p, 1.1 + fmod(absf(p.x) * 0.23, 0.6))
	_bench(at + Vector3(-2.5, 0, 3.0)); _bench(at + Vector3(5.5, 0, 3.0))
	_lamp(at + Vector3(0.9, 0, 3.6)); _lamp(at + Vector3(-0.9, 0, -8.5))
	# 놀이터: 미끄럼틀(사다리+경사), 시소, 그네(틀+줄+좌석), 모래밭
	var wood := _mat(Color("b48a5a")); var iron := _mat(Color("4a4a52"))
	_box(Vector3(3.6, 0.12, 3.0), at + Vector3(6, 0, -5), _mat(Color("e6d3a5")))                       # 모래밭
	var slide := _box(Vector3(0.6, 0.06, 2.2), at + Vector3(4.3, 1.0, -6.8), _mat(Color("ad7096")), true); slide.rotation.x = -0.55
	_box(Vector3(0.6, 1.6, 0.06), at + Vector3(4.3, 0, -5.4), iron); _box(Vector3(0.7, 0.06, 0.7), at + Vector3(4.3, 1.6, -5.6), wood)
	var plank := _box(Vector3(3.0, 0.08, 0.3), at + Vector3(8.5, 0.5, -7.5), wood); plank.rotation.z = 0.2   # 시소
	_box(Vector3(0.3, 0.5, 0.3), at + Vector3(8.5, 0, -7.5), iron)
	_box(Vector3(0.08, 2.2, 0.08), at + Vector3(8.6, 0, -3.0), iron); _box(Vector3(0.08, 2.2, 0.08), at + Vector3(10.6, 0, -3.0), iron)  # 그네
	_box(Vector3(2.2, 0.08, 0.08), at + Vector3(9.6, 2.2, -3.0), iron, false)
	_box(Vector3(0.02, 1.5, 0.02), at + Vector3(9.35, 0.7, -3.0), iron, false); _box(Vector3(0.02, 1.5, 0.02), at + Vector3(9.85, 0.7, -3.0), iron, false)
	_box(Vector3(0.6, 0.05, 0.25), at + Vector3(9.6, 0.66, -3.0), wood)
	benches.append({ "pos": at + Vector3(9.6, 0.24, -3.0), "yaw": 0.0 }); spots.append({ "pos": at + Vector3(9.6, 0.24, -3.0), "kind": "bench", "yaw": 0.0 })  # 그네 좌석에도 앉는다
	for fx in [-4.0, 4.0]:
		_box(Vector3(1.6, 0.25, 0.5), at + Vector3(fx, 0, 6), _mat(Color("8a6a4a")))
		for i in 4:
			var fl := MeshInstance3D.new(); var fs := SphereMesh.new(); fs.radius = 0.07; fs.height = 0.14; fl.mesh = fs
			fl.material_override = _mat([Color("ff2d55"), Color("e8c766"), Color("ad7096"), Color("ffffff")][i]); fl.position = at + Vector3(fx - 0.6 + i * 0.4, 0.35, 6); _add(fl)
	_fence(at + Vector3(-12, 0, 8), 24.0)
	for i in 4: _animal("duck", at + Vector3(-6, 0.03, -3) + Vector3(cos(i * 1.57) * 2.0, 0, sin(i * 1.57) * 2.0), { "center": at + Vector3(-6, 0.03, -3), "phase": i * 1.57 })
	_animal("dog", at + Vector3(2, 0, 1), { "home": at + Vector3(2, 0, 1) })

## 동쪽 시장 거리 — 노점(기둥+차양+판매대+물건), 상점 정면 둘(빵집·카페: 집 생성기에 간판 색만 다르게), 쓰레기통, 가로등, 자갈 광장
func _market(at: Vector3) -> void:
	var sq := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3(22, 0.04, 12); sq.mesh = bm
	sq.material_override = _mat(Color.WHITE, _tex("ground/cobble"), Vector3(22 / 1.6, 12 / 1.6, 1)); sq.position = at + Vector3(0, 0.02, 1); _add(sq)
	for i in 4:
		_stall(at + Vector3(-7.5 + i * 5.0, 0, -1.5), [Color("ad7096"), Color("7a9b4e"), Color("e8c766"), Color("8fb8cc")][i])
	_house(at + Vector3(-6, 0, -8), Vector3(5.0, 2.8, 3.6), Color("e6d3a5"), "accent-deep", false, 11)  # 빵집(집 생성기)
	_house(at + Vector3(5, 0, -8), Vector3(4.2, 2.6, 3.4), Color("f7f4ef"), "brick", false, 12)      # 카페
	_lamp(at + Vector3(-10, 0, 4)); _lamp(at + Vector3(0, 0, 4)); _lamp(at + Vector3(10, 0, 4))
	_bin(at + Vector3(-9.5, 0, -0.5)); _bin(at + Vector3(9.5, 0, -0.5))
	_bench(at + Vector3(0, 0, 5.5))
	for i in 5: _animal("pigeon", at + Vector3(-4 + i * 2.0, 0, 2.5 + (i % 2) * 1.2), { "home": at + Vector3(-4 + i * 2.0, 0, 2.5 + (i % 2) * 1.2) })
	_item("apple", at + Vector3(-7.5, 0.95, -1.3)); _item("cup", at + Vector3(2.5, 0.95, -1.3)); _item("paper", at + Vector3(7.5, 0.95, -1.3))

func _stall(at: Vector3, awning: Color) -> void:
	var wood := _mat(Color("8a6a4a"))
	_box(Vector3(2.2, 0.9, 0.9), at, wood)                                                     # 판매대
	for sx in [-1.0, 1.0]:
		_box(Vector3(0.08, 2.2, 0.08), at + Vector3(sx, 0, -0.4), wood, false)
	var awn := _box(Vector3(2.6, 0.06, 1.4), at + Vector3(0, 2.15, 0.1), _mat(awning), false); awn.rotation.x = 0.25
	for i in 3:
		var g := MeshInstance3D.new(); var gs := SphereMesh.new(); gs.radius = 0.09; gs.height = 0.18; g.mesh = gs
		g.material_override = _mat([Color("d98a2a"), Color("ff2d55"), Color("e8c766")][i]); g.position = at + Vector3(-0.6 + i * 0.6, 0.98, -0.1); _add(g)
	spots.append({ "pos": at + Vector3(0, 0, 1.0), "kind": "door", "yaw": PI })   # 손님 자리(서서 고른다)

func _bin(at: Vector3) -> void:
	var b := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = 0.28; cm.bottom_radius = 0.24; cm.height = 0.8
	b.mesh = cm; b.material_override = _mat(Color("4a4a52")); b.position = at + Vector3(0, 0.4, 0); _add(b)
	var sb := StaticBody3D.new(); var cs := CollisionShape3D.new(); var sh := CylinderShape3D.new(); sh.radius = 0.28; sh.height = 0.8; cs.shape = sh; sb.add_child(cs); b.add_child(sb)

var weather := "clear"      # clear | cloudy | rain
var weather_until := 90.0
var rain: CPUParticles3D
var wet: MeshInstance3D
var _wrng := RandomNumberGenerator.new()

func _weather(delta: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now >= weather_until:
		if _wrng.seed == 0: _wrng.seed = 20260928
		var r := _wrng.randf()
		weather = "rain" if (weather != "rain" and r < 0.35) else ("cloudy" if r < 0.6 else "clear")
		weather_until = now + _wrng.randf_range(150.0, 300.0)
		_apply_weather()
	if rain: rain.global_position = Vector3(body.global_position.x, 9.0, body.global_position.z)

func _apply_weather() -> void:
	if rain == null:
		rain = CPUParticles3D.new()
		rain.amount = 900; rain.lifetime = 1.4; rain.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX; rain.emission_box_extents = Vector3(14, 0.2, 10)
		rain.direction = Vector3(0.15, -1, 0); rain.spread = 3.0; rain.initial_velocity_min = 9.0; rain.initial_velocity_max = 11.0; rain.gravity = Vector3(0, -6, 0)
		rain.mesh = BoxMesh.new(); (rain.mesh as BoxMesh).size = Vector3(0.015, 0.22, 0.015)
		var rm := StandardMaterial3D.new(); rm.albedo_color = Color(0.62, 0.72, 0.8, 0.75); rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		rain.material_override = rm; rain.emitting = false; add_child(rain)
		wet = MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(WORLD_X * 2.0, WORLD_Z * 2.0 + 8.0); wet.mesh = pm
		var wm := StandardMaterial3D.new(); wm.albedo_color = Color(0.1, 0.12, 0.18, 0.0); wm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; wm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		wet.material_override = wm; wet.position = Vector3(0, 0.005, -2); add_child(wet)
	rain.emitting = weather == "rain"
	var tw := create_tween()
	tw.tween_property(wet.material_override, "albedo_color:a", 0.28 if weather == "rain" else (0.08 if weather == "cloudy" else 0.0), 2.0)
	for r in residents: r.on_weather(weather)

var animals: Array = []

## 동물 — 원시 도형 몸 + 아주 단순한 습성. 전부 코드
func _animal(kind: String, at: Vector3, data: Dictionary) -> void:
	var n := Node3D.new(); n.position = at; _add(n)
	match kind:
		"duck":
			var b := MeshInstance3D.new(); var bs := SphereMesh.new(); bs.radius = 0.16; bs.height = 0.22; b.mesh = bs; b.material_override = _mat(Color("e6d3a5")); b.position.y = 0.1; n.add_child(b)
			var h := MeshInstance3D.new(); var hs := SphereMesh.new(); hs.radius = 0.08; hs.height = 0.16; h.mesh = hs; h.material_override = _mat(Color("e6d3a5")); h.position = Vector3(0, 0.26, 0.14); n.add_child(h)
			var bk := _box(Vector3(0.04, 0.03, 0.1), Vector3(0, 0.24, 0.24), _mat(Color("d98a2a")), false, n)
			bk.position.y = 0.245
		"dog":
			var b := MeshInstance3D.new(); var bs := CapsuleMesh.new(); bs.radius = 0.16; bs.height = 0.7; b.mesh = bs; b.material_override = _mat(Color("c9a27a")); b.rotation.x = PI / 2.0; b.position.y = 0.32; n.add_child(b)
			var h := MeshInstance3D.new(); var hs := SphereMesh.new(); hs.radius = 0.13; hs.height = 0.26; h.mesh = hs; h.material_override = _mat(Color("c9a27a")); h.position = Vector3(0, 0.45, 0.4); n.add_child(h)
			for lx in [-0.09, 0.09]:
				for lz in [-0.22, 0.22]:
					_box(Vector3(0.06, 0.24, 0.06), Vector3(lx, 0, lz), _mat(Color("9a6a3f")), false, n)
			var t := _box(Vector3(0.05, 0.05, 0.28), Vector3(0, 0.36, -0.45), _mat(Color("9a6a3f")), false, n); t.rotation.x = -0.6
		_:
			var b := MeshInstance3D.new(); var bs := SphereMesh.new(); bs.radius = 0.09; bs.height = 0.14; b.mesh = bs; b.material_override = _mat(Color("8a7f86")); b.position.y = 0.09; n.add_child(b)
			var h := MeshInstance3D.new(); var hs := SphereMesh.new(); hs.radius = 0.045; hs.height = 0.09; h.mesh = hs; h.material_override = _mat(Color("5b4f56")); h.position = Vector3(0, 0.17, 0.08); n.add_child(h)
	data["kind"] = kind; data["node"] = n; data["t"] = randf() * 10.0; data["fly"] = 0.0
	animals.append(data)

func _animals(delta: float) -> void:
	var p := body.global_position
	for a in animals:
		var n: Node3D = a["node"]
		if not n.is_visible_in_tree(): continue
		a["t"] += delta
		var d := p.distance_to(n.global_position)
		match a["kind"]:
			"duck":
				# 연못을 빙빙, 사람이 2m 안이면 날갯짓(위아래로 들썩)하며 반대쪽으로
				var ph: float = a["phase"] + a["t"] * 0.35
				var c: Vector3 = a["center"]
				var want := c + Vector3(cos(ph) * 2.0, 0, sin(ph) * 2.0)
				if d < 2.0: want = c + (n.global_position - p).normalized() * 2.6; n.position.y = 0.03 + absf(sin(a["t"] * 18.0)) * 0.12
				else: n.position.y = 0.03 + sin(a["t"] * 3.0) * 0.015
				n.global_position = Vector3(lerpf(n.global_position.x, want.x, delta * 1.5), n.position.y, lerpf(n.global_position.z, want.z, delta * 1.5))
				if want.distance_to(n.global_position) > 0.05:
					n.look_at(Vector3(want.x, n.global_position.y, want.z), Vector3.UP, true)
			"dog":
				# 어슬렁(집 주변 4m), 사람이 3m 안이면 3초 따라오다 만다, 뛸 땐 몸이 들썩
				if d < 3.0 and a.get("follow_until", 0.0) < a["t"]: a["follow_until"] = a["t"] + 3.0
				var want: Vector3
				if a.get("follow_until", 0.0) > a["t"]: want = p + (n.global_position - p).normalized() * 1.1
				else:
					if a.get("wander_until", 0.0) < a["t"]: a["wander_until"] = a["t"] + randf_range(2.0, 5.0); a["wander"] = a["home"] + Vector3(randf_range(-4, 4), 0, randf_range(-3, 3))
					want = a.get("wander", a["home"])
				var to := want - n.global_position; to.y = 0.0
				if to.length() > 0.3:
					n.global_position += to.normalized() * 1.9 * delta
					n.look_at(n.global_position + to, Vector3.UP, true)
					n.position.y = absf(sin(a["t"] * 12.0)) * 0.06
				else: n.position.y = lerpf(n.position.y, 0.0, 0.2)
			_:
				# 비둘기: 바닥을 쫀다, 1.6m 안이면 날아올라 3m 옆으로 갔다 내려앉는다
				if d < 1.6 and a["fly"] <= 0.0:
					a["fly"] = 1.6; a["land"] = a["home"] + Vector3(randf_range(-3, 3), 0, randf_range(-2, 2))
				if a["fly"] > 0.0:
					a["fly"] -= delta
					var k: float = 1.0 - a["fly"] / 1.6
					var land: Vector3 = a["land"]
					n.global_position = Vector3(lerpf(n.global_position.x, land.x, delta * 2.5), sin(k * PI) * 1.4, lerpf(n.global_position.z, land.z, delta * 2.5))
					if a["fly"] <= 0.0: a["home"] = land; n.position.y = 0.0
				else:
					n.position.y = 0.0; n.rotation.x = absf(sin(a["t"] * 5.0)) * 0.25  # 쪼기

## 낮밤 — 해가 한 바퀴 돌고(12분), 저녁엔 빛이 붉어지며 가로등·실내 램프가 켜진다
func _daylight(delta: float) -> void:
	clock = fmod(clock + delta / DAY_LEN, 1.0)
	if _sun == null: return
	var ang := clock * TAU
	_sun.rotation_degrees = Vector3(-10.0 - 60.0 * maxf(0.0, sin(ang)), 28.0 + clock * 120.0, 0)
	var day := clampf(sin(ang) * 1.6 + 0.2, 0.0, 1.0)
	if weather == "rain": day *= 0.55
	elif weather == "cloudy": day *= 0.8
	_sun.light_energy = 0.15 + 1.0 * day
	_sun.light_color = Color(1.0, 0.86 + 0.14 * day, 0.72 + 0.28 * day)
	var env := ($WorldEnvironment as WorldEnvironment).environment
	env.ambient_light_energy = 0.22 + 0.4 * day
	env.background_color = Color(0.93, 0.94, 0.92, 1).lerp(Color(0.12, 0.10, 0.16, 1), 1.0 - day)
	var night := day < 0.35
	for l in lamps:
		l.visible = night; l.light_energy = 1.3 if night else 0.0

## 나무 — 기둥 + 구 셋(잎 두 톤). 크기 k 로 서로 다르게. 줄기만 막힌다
func _tree(at: Vector3, k: float) -> void:
	var trunk := MeshInstance3D.new()
	var cm := CylinderMesh.new(); cm.top_radius = 0.09 * k; cm.bottom_radius = 0.14 * k; cm.height = 1.0 * k
	trunk.mesh = cm; trunk.material_override = _mat(Color("8a6a4a"))
	trunk.position = at + Vector3(0, 0.5 * k, 0)
	var sb := StaticBody3D.new(); var cs := CollisionShape3D.new(); var sh := CylinderShape3D.new(); sh.radius = 0.16 * k; sh.height = 1.0 * k; cs.shape = sh; sb.add_child(cs); trunk.add_child(sb)
	_add(trunk)
	spots.append({ "pos": at, "kind": "tree", "yaw": 0.0 })
	for i in 3:
		var s := MeshInstance3D.new()
		var sm := SphereMesh.new(); var rr := (0.75 - i * 0.12) * k
		sm.radius = rr; sm.height = rr * 2.0; sm.radial_segments = 14; sm.rings = 8
		s.mesh = sm; s.material_override = _mat(Color("8fb06a") if i % 2 == 0 else Color("6e9a55"))
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
	spots.append({ "pos": at, "kind": "bench", "yaw": 0.0 })

func _lamp(at: Vector3) -> void:
	var post := MeshInstance3D.new()
	var cm := CylinderMesh.new(); cm.top_radius = 0.035; cm.bottom_radius = 0.05; cm.height = 2.2
	post.mesh = cm; post.material_override = _mat(Color("4a4a52"))
	post.position = at + Vector3(0, 1.1, 0)
	_add(post)
	_box(Vector3(0.26, 0.3, 0.26), at + Vector3(0, 2.2, 0), _mat(Color("e8c766")), false)
	spots.append({ "pos": at + Vector3(0.25, 0, 0), "kind": "lamp", "yaw": -PI / 2.0 })
	var l := OmniLight3D.new(); l.light_color = Color("e8c766"); l.light_energy = 0.6; l.omni_range = 4.0
	l.position = at + Vector3(0, 2.3, 0)
	_add(l)
	lamps.append(l)

func _fence(at: Vector3, len: float) -> void:
	var paper := _mat(Color("efe9e2"))
	var n := int(len / 0.5)
	for i in n + 1:
		_box(Vector3(0.08, 0.7, 0.05), at + Vector3(i * 0.5, 0, 0), paper)
	_box(Vector3(len + 0.08, 0.06, 0.04), at + Vector3(len / 2.0, 0.25, 0), paper)
	_box(Vector3(len + 0.08, 0.06, 0.04), at + Vector3(len / 2.0, 0.5, 0), paper)

## 집을 수 있는 것 — 작은 기하 하나씩(사과 = 구, 컵 = 원기둥, 신문 = 납작한 상자). 손에 들면 hand_r 의 자식이 된다
func _item(kind: String, at: Vector3) -> void:
	items.append(make_item(kind, at))

func make_item(kind: String, at: Vector3) -> MeshInstance3D:
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
	return mi

# ── 조작 ──
func _physics_process(delta: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var grounded := body.is_on_floor()
	var dir := Vector3(Input.get_axis("move_left", "move_right"), 0, Input.get_axis("move_up", "move_down"))
	if dir.length() > 1.0:
		dir = dir.normalized()
	# 넘어짐: 1.6초 누웠다가 0.6초에 걸쳐 일어난다. 그동안 입력은 없다
	if down_until > now:
		body.velocity = Vector3(lerpf(body.velocity.x, 0.0, 0.2), body.velocity.y - G * delta, lerpf(body.velocity.z, 0.0, 0.2))
		body.move_and_slide(); player.lying = true; player.move_dir = Vector3.ZERO; player.speed = 0.0
		return
	if down_until > 0.0 and down_until <= now and getup_until < 0.0:
		down_until = -1.0; getup_until = now + 0.6; player.lying = false; player.action = "getup"; player.action_t = 0.0
	if getup_until > now:
		player.action_t = 1.0 - (getup_until - now) / 0.6; body.velocity = Vector3.ZERO
		return
	if getup_until > 0.0 and getup_until <= now:
		getup_until = -1.0; player.action = ""; player.action_t = 0.0
	# 앉아 있으면 아무 방향키로 일어난다
	if not seat.is_empty():
		if dir != Vector3.ZERO or Input.is_action_just_pressed("jump"):
			seat = {}; player.seated = false
			var tw := create_tween(); tw.set_ease(Tween.EASE_OUT); tw.set_trans(Tween.TRANS_QUAD)
			tw.tween_property(body, "position", Vector3(body.position.x, 0.02, body.position.z + 0.45), 0.25)
		else:
			_interact_check(now)
			return
	for a in ["move_left", "move_right", "move_up", "move_down"]:
		if Input.is_action_just_pressed(a):
			if a == last_tap and now - last_tap_at < 0.25 and grounded:
				dash_until = now + 0.18
			last_tap = a; last_tap_at = now
	# 더블탭 순간은 대시(2.4배 0.18초), 그 뒤 방향키를 놓지 않는 한 달리기(1.9배) 유지. 0.12초 이상 놓으면 걷기로
	if dir == Vector3.ZERO:
		if idle_since < 0.0: idle_since = now
		if now - idle_since > 0.12: running = false
	else:
		idle_since = -1.0
	if now < dash_until: running = true
	var speed := WALK * (2.4 if now < dash_until else (1.9 if running else 1.0))
	var can_move := not (player.action == "throw" and (action_until >= now or throw_charge >= 0.0)) and not jet and not resting
	var v := body.velocity
	var hv := Vector3(v.x, 0, v.z)
	if jet:
		pass  # 제트킥: 쏘아진 속도 그대로
	elif can_move and dir != Vector3.ZERO:
		# 부드럽지만 빠른 반응: 땅에선 0.12초쯤에 목표 속도, 공중에선 더 느리게
		var accel := 26.0 if grounded else 9.0
		hv = hv.move_toward(dir * speed, accel * delta)
		player.move_dir = dir; player.speed = hv.length()
	else:
		hv = hv.move_toward(Vector3.ZERO, (30.0 if grounded else 3.0) * delta)
		player.move_dir = Vector3.ZERO; player.speed = 0.0
	v.x = hv.x; v.z = hv.z
	if grounded and hv.length() > 0.1:
		_step_up(hv * delta)
	if not grounded:
		v.y -= G * delta
	elif Input.is_action_just_pressed("jump"):
		# 가변 점프(운영자: 톡 = 살짝, 길게 = 높이): 누르는 즉시 최소 홉으로 뜨고, 누르고 있는 동안 JUMP_HOLD 초까지 위로 더 밀어 올린다
		v.y = HOP + hv.length() * 0.12
		jump_hold_until = now + JUMP_HOLD
		jump_from_speed = hv.length(); dash_jump = running or now < dash_until
		jump_at = -1.0
	if jump_hold_until > now and Input.is_action_pressed("jump") and v.y > 0.0:
		v.y += 13.0 * delta   # 0.28초 다 누르면 약 +3.6 → 최대 높이 두 배 남짓
		if hv.length() > 0.5:
			var f := hv.normalized(); v.x += f.x * 5.0 * delta; v.z += f.z * 5.0 * delta
	elif not Input.is_action_pressed("jump"):
		jump_hold_until = -1.0
	if push_at >= 0.0 and now >= push_at:
		var f := fwd_dir()
		v += f * push_amount; v.y = maxf(v.y, push_lift) if push_lift > 0.0 else v.y
		push_at = -1.0
		_strike(hit_kind)
	if jet:
		_strike("jet")
	body.velocity = v
	body.move_and_slide()
	body.position.x = clampf(body.position.x, -WORLD_X + 1.0, WORLD_X - 1.0)
	body.position.z = clampf(body.position.z, -WORLD_Z + 1.0, WORLD_Z - 1.0)
	# 착지: 빠르게 떨어졌으면 0.12초 무릎 반동, 달려서 착지하면 속도는 그대로 이어진다
	if jet and body.is_on_floor() and body.velocity.y <= 0.0 and not was_airborne:
		was_airborne = true  # 뜨지 못한 제트킥은 이번 프레임에 착지로 처리(안전장치)
	if was_airborne and body.is_on_floor():
		dash_jump = false
		if player.vertical < -4.5 or jet:
			land_until = now + (0.2 if jet else 0.12)
		if jet:
			jet = false; action_until = now + 0.2  # 착지 마무리(발을 거두는 뒤 절반)
			body.velocity = Vector3(body.velocity.x * 0.35, 0, body.velocity.z * 0.35)
	was_airborne = not body.is_on_floor()
	var land_k := clampf((land_until - now) / 0.12, 0.0, 1.0) * 0.6 if land_until > now else 0.0
	player.crouch = land_k
	player.airborne = not body.is_on_floor()
	player.jet = jet
	player.vertical = body.velocity.y
	# X·Z 는 공중에서도 된다(점프킥·점프 주먹). 들고 있을 때 X 는 던지기(웹 규칙)
	# 던지기: 들고 있을 때 X 를 누르는 동안 팔을 뒤로 감고(action_t 가 0.44 에서 멈춤), 떼면 앞으로 던진다. 오래 누를수록 멀리
	if player.carrying and throw_charge < 0.0 and action_until < now and Input.is_action_just_pressed("hit"):
		throw_charge = now; player.action = "throw"
	if throw_charge >= 0.0:
		var held := minf(THROW_MAX, now - throw_charge)
		player.action_t = minf(0.44, held / 0.25 * 0.44)
		if Input.is_action_just_released("hit") or not player.carrying:
			var power := held / THROW_MAX
			throw_charge = -1.0
			action_until = now + 0.28; throw_at = now + 0.06
			throw_power = power
	if action_until < now and throw_charge < 0.0:
		if Input.is_action_just_pressed("hit"):
			if grounded and not running:
				# 연속기: 왼 잽 → 오른 스트레이트 → 왼 훅. 0.45초 안에 이어 누르면 다음 타, 늦으면 처음부터
				if now > combo_open_until: combo = 0
				player.punch_side = [-1.0, 1.0, -1.0][combo]; player.punch_kind = ["jab", "cross", "hook"][combo]
				var dur: float = [0.22, 0.28, 0.32][combo]
				action_until = now + dur; push_at = now + dur * 0.15; push_amount = [0.35, 0.6, 0.5][combo]; push_lift = 0.0
				hit_kind = "punch"
				combo_open_until = action_until + 0.45; combo = (combo + 1) % 3
			else:
				player.punch_side = 1.0; player.punch_kind = "cross"
				action_until = now + 0.28
				push_at = now + 0.28 * 0.15; push_amount = 2.2 if not grounded else 1.8; push_lift = 1.0 if not grounded else 0.0
				hit_kind = "air" if not grounded else "punch"
			player.action = "punch"
		elif Input.is_action_just_pressed("kick"):
			if not grounded and dash_jump:  # 제트킥은 대시 중 점프 → 공중에서 Z 일 때만(운영자 2026-09-28)
				# 제트킥(운영자 2026-09-28): 앞으로 쏘아지며 비행 킥 자세를 착지까지 유지한다
				jet = true; player.action = "kick"; action_until = now + 9.0; hit_kind = "jet"
				var f := fwd_dir()
				body.velocity = Vector3(f.x * 6.0, maxf(body.velocity.y, 1.6), f.z * 6.0)  # 비거리 9→6(너무 멀리 나갔다)  # 그 자리에서 몸에 적용(버그: move_and_slide 뒤라 v 만 바꾸면 뜨지 못했다)
				was_airborne = true
			else:
				player.action = "kick"; action_until = now + 0.34
				# 달리는 중 Z 는 강한 러닝 킥(넘어뜨림, 앞으로 크게 밀림); 공중은 점프킥; 서서는 보통 발차기
				hit_kind = "runkick" if (grounded and running) else "kick"
				push_at = now + 0.34 * 0.15; push_amount = 2.6 if hit_kind == "runkick" else (1.6 if not grounded else 1.0); push_lift = 0.0
	if throw_at >= 0.0 and now >= throw_at and player.carrying:
		throw_at = -1.0
		var it := player.release(self, body.global_position + Vector3(0, 0.95, 0) + fwd_dir() * 0.35)
		flying.append({ "node": it, "vel": fwd_dir() * lerpf(4.0, 11.0, throw_power) + Vector3(0, lerpf(2.2, 4.2, throw_power), 0) + Vector3(body.velocity.x, 0, body.velocity.z) * 0.5, "spin": randf_range(4.0, 9.0) })
	if throw_charge >= 0.0:
		pass  # 감는 중 — action_t 는 위에서
	elif action_until >= now:
		if player.action == "throw":
			player.action_t = 0.45 + (1.0 - (action_until - now) / 0.28) * 0.55  # 놓는 절반만
		elif jet:
			player.action_t = 0.35
		else:
			var dur := 0.28 if player.action == "punch" else (0.34 if player.action == "kick" else 0.4)
			player.action_t = 1.0 - (action_until - now) / dur
			if player.action == "kick" and player.action_t < 0.35 and action_until - now > 0.3:
				player.action_t = 0.35 + (1.0 - (action_until - now) / 0.2) * 0.65  # 제트킥 착지 마무리: 뻗은 상태에서 거둔다
	else:
		player.action = ""; player.action_t = 0.0
	if shake_until > 0.0 and now >= shake_until:
		shake_until = -1.0; player.pose_request = ""
	if use_until > 0.0 and now >= use_until:
		use_until = -1.0
		if player.pose_request in ["eat", "drink", "wave"]: player.pose_request = ""
	if (reading or leaning or resting) and dir != Vector3.ZERO:
		reading = false; leaning = false; resting = false; player.pose_request = ""
	if not carrying_big.is_empty() and player.pose_request == "": player.pose_request = "carry"
	_interact_check(now)
	_fly(delta)
	_cutaway()
	_daylight(delta)
	_stream()
	_weather(delta)
	_animals(delta)

var cam_kick := 0.0
var shake_until := -1.0
var bites := 0            # 사과 한입 수(3입이면 사라진다)
var use_until := -1.0     # 먹기·마시기 자세가 끝나는 시각
var reading := false      # 신문 읽는 중(움직이면 끝)
var leaning := false      # 가로등에 기댄 중(움직이면 끝)

## 가구 들기(C 길게) — 두 손에 들고 옮긴다(carry 자세). 든 동안 충돌은 끈다
func _pick_furniture(now: float) -> void:
	if not carrying_big.is_empty() or player.carrying: return
	var p := body.global_position
	var best: Dictionary = {}; var bd := 9.0
	for m in movables:
		var d: float = p.distance_to(m["node"].global_position)
		if d < 0.9 and d < bd: best = m; bd = d
	if best.is_empty(): return
	var n: Node3D = best["node"]
	_set_solid(n, false)
	n.get_parent().remove_child(n); player.socket_belt.add_child(n)
	n.position = Vector3(0, 0.45, 0.42); n.rotation = Vector3.ZERO
	carrying_big = best; player.pose_request = "carry"
	player.action = "grab"; action_until = now + 0.4

## 문 열기/닫기 — 사람도 주민도 이걸 쓴다
func set_door(dr: Dictionary, open: bool) -> void:
	if dr["open"] == open: return
	dr["open"] = open
	var tw := create_tween(); tw.set_ease(Tween.EASE_OUT); tw.set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(dr["hinge"], "rotation:y", 1.85 if open else 0.0, 0.45)

## 앞 부채꼴(70°) 안, 사거리 안의 주민을 맞힌다. 무거운 한 방(제트킥·점프 주먹·훅)은 바로 넘어진다
func _strike(kind: String) -> void:
	var reach := 1.3 if kind == "jet" else (1.15 if kind == "kick" or kind == "runkick" else 0.95)
	var heavy := kind == "jet" or kind == "air" or kind == "runkick" or (kind == "punch" and player.punch_kind == "hook")
	var f := fwd_dir(); var p := body.global_position
	var now := Time.get_ticks_msec() / 1000.0
	for r in residents:
		if r.state == "down" or (kind == "jet" and float(r.get_meta("jet_hit_at", -9.0)) > now - 1.0):
			continue
		var to: Vector3 = r.global_position - p; to.y = 0.0
		var d := to.length()
		if d < reach and d > 0.05 and f.dot(to.normalized()) > 0.34:
			r.hit(f, body, heavy)
			if kind == "jet": r.set_meta("jet_hit_at", now)
			cam_kick = 0.06 if heavy else 0.03

## 주민이 나를 친다 — 같은 규칙: 움찔, 3초 안에 세 대면 넘어진다
func resident_hits_player(_r: Node3D, dir: Vector3) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if down_until > now or getup_until > now: return
	if now - my_last_hit > 3.0: my_hits = 0
	my_hits += 1; my_last_hit = now
	jet = false; throw_charge = -1.0; seat = {}; player.seated = false
	if my_hits >= 3:
		my_hits = 0
		down_until = now + 1.6; player.lying = true; player.action = ""; action_until = now
		body.velocity = dir * 3.5 + Vector3(0, 2.0, 0)
		if player.carrying:
			var it: Node3D = player.release(self, body.global_position + dir * 0.6 + Vector3(0, 0.1, 0)); items.append(it)
	else:
		player.action = "flinch"; action_until = now + 0.3
		body.velocity = dir * 1.6
	cam_kick = 0.05

const STEP := 0.42
## 낮은 턱 오르기: 앞으로 가려는 만큼 움직여 보고 막히면, STEP 위에서 같은 이동이 되는지 본 뒤 올라선다(그 자리엔 바닥이 있어야 한다)
func _step_up(motion: Vector3) -> void:
	step_up(body, motion)

## 공용: 사람도 주민도 같은 턱 오르기(운영자 2026-09-28: 주민이 문 앞 계단에서 막혀 집에 못 들어갔다)
static func step_up(b: CharacterBody3D, motion: Vector3) -> void:
	if motion.length() < 0.0005: return
	var xf := b.global_transform
	if not b.test_move(xf, motion):
		return
	var up := xf.translated(Vector3(0, STEP, 0))
	if b.test_move(up, motion):
		return
	var ahead := up.translated(motion + motion.normalized() * 0.06)
	var probe := PhysicsTestMotionParameters3D.new()
	probe.from = ahead; probe.motion = Vector3(0, -STEP, 0)
	var res := PhysicsTestMotionResult3D.new()
	if b.test_move(ahead, Vector3(0, -STEP, 0)) and PhysicsServer3D.body_test_motion(b.get_rid(), probe, res):
		var rise := STEP - res.get_travel().length()
		if rise > 0.02 and rise <= STEP:
			b.global_position += Vector3(0, rise + 0.01, 0)

func fwd_dir() -> Vector3:
	return Vector3(sin(player.rotation.y), 0, cos(player.rotation.y))

## 던져진 것의 포물선 — 중력, 바닥에 닿으면 멈추고 다시 집을 수 있는 목록으로
func _fly(delta: float) -> void:
	for f in flying.duplicate():
		var n: Node3D = f["node"]
		f["vel"] += Vector3(0, -G, 0) * delta
		n.global_position += f["vel"] * delta
		n.rotation.x += f["spin"] * delta
		if n.global_position.y <= 0.06:
			n.global_position.y = 0.06
			n.rotation = Vector3.ZERO
			flying.erase(f)
			items.append(n)

## C — 들고 있으면 앞에 내려놓기; 아니면 가장 가까운 것: 물건(0.8m) · 문(1.3m) · 벤치(1.0m)
func _interact_check(now: float) -> void:
	# 짧게 누르면 상호작용, 0.45초 길게 누르면 가구 들기(의자는 앉는 것과 겹쳐서)
	if Input.is_action_just_pressed("act") and action_until < now:
		act_down_at = now
	var long_press := act_down_at >= 0.0 and Input.is_action_pressed("act") and now - act_down_at >= 0.45
	var tap := act_down_at >= 0.0 and Input.is_action_just_released("act") and now - act_down_at < 0.45
	if long_press: act_down_at = -1.0
	elif tap: act_down_at = -1.0
	elif not Input.is_action_pressed("act"): act_down_at = -1.0
	if not (long_press or tap) or action_until >= now:
		return
	if long_press:
		_pick_furniture(now)
		return
	var p := body.global_position
	var fwd := Vector3(sin(player.rotation.y), 0, cos(player.rotation.y))
	if not carrying_big.is_empty():
		# 내려놓기: 앞 0.7m, 바닥에. 주민 자리도 같이 옮긴다
		var n: Node3D = carrying_big["node"]
		n.get_parent().remove_child(n); add_child(n)
		n.global_position = Vector3(p.x, 0.0, p.z) + fwd * 0.7; n.rotation = Vector3(0, player.rotation.y, 0)
		_set_solid(n, true)
		if carrying_big["spot"]: carrying_big["spot"]["pos"] = n.global_position; carrying_big["spot"]["yaw"] = player.rotation.y
		carrying_big = {}; player.pose_request = ""
		player.action = "grab"; action_until = now + 0.4
		return
	if player.carrying:
		var kind := String(player.carrying.get_meta("kind", ""))
		if kind == "apple":
			# 먹기: 한 번에 한입, 세 입이면 사라진다(운영자: 상호작용은 끝까지)
			bites += 1; player.pose_request = "eat"; use_until = now + 0.9; action_until = now + 0.9
			if bites >= 3:
				bites = 0; var core := player.carrying; player.release(self, Vector3.ZERO); core.queue_free()
			return
		if kind == "cup":
			player.pose_request = "drink"; use_until = now + 1.2; action_until = now + 1.2
			return
		if kind == "paper":
			reading = not reading; player.pose_request = "read" if reading else ""
			return
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
	for sp in spots:
		if sp["kind"] != "tree" and sp["kind"] != "lamp": continue
		var d2: float = p.distance_to(sp["pos"])
		if d2 < 1.0 and d2 < best_d: best = { "kind": sp["kind"], "spot": sp }; best_d = d2
	for r in residents:
		var d3: float = p.distance_to(r.global_position)
		if d3 < 1.3 and d3 < best_d and r.state != "down": best = { "kind": "resident", "node": r }; best_d = d3
	for m in movables:
		var d4: float = p.distance_to(m["node"].global_position)
		if d4 < 0.9 and d4 < best_d: best = { "kind": "furniture", "entry": m }; best_d = d4
	for sp in spots:
		if sp["kind"] != "bed" and sp["kind"] != "shelf": continue
		var d5: float = Vector2(p.x - sp["pos"].x, p.z - sp["pos"].z).length()
		if d5 < 1.1 and d5 < best_d: best = { "kind": sp["kind"], "spot": sp }; best_d = d5
	if best.is_empty():
		return
	match best["kind"]:
		"furniture":
			var e: Dictionary = best["entry"]
			var n: Node3D = e["node"]
			if e["kind"] == "chair":
				# 의자에 앉기(벤치와 같은 규칙)
				seat = { "pos": n.global_position, "yaw": n.rotation.y, "chair": true }
				player.seated = true; player.move_dir = Vector3.ZERO; player.speed = 0.0; body.velocity = Vector3.ZERO
				var tw := create_tween(); tw.set_ease(Tween.EASE_IN_OUT); tw.set_trans(Tween.TRANS_QUAD)
				tw.tween_property(body, "position", n.global_position + Vector3(0, 0.03, 0.02), 0.3)
				player.face(n.rotation.y)
			elif e["kind"] == "lamp":
				var l: OmniLight3D = n.get_meta("light"); l.visible = not l.visible
				player.action = "grab"; action_until = now + 0.3
		"bed":
			# 눕기: 침대 위에서 쉬는 자세. 방향키로 일어난다
			var sp: Dictionary = best["spot"]
			resting = true; player.pose_request = "rest"; player.face(sp["yaw"])
			body.velocity = Vector3.ZERO
			var tw := create_tween(); tw.set_ease(Tween.EASE_IN_OUT); tw.set_trans(Tween.TRANS_QUAD)
			tw.tween_property(body, "position", sp["pos"] + Vector3(0, 0.02, 0), 0.35)
		"shelf":
			# 선반에서 책을 꺼내 읽는다(움직이면 끝)
			var sp: Dictionary = best["spot"]
			reading = true; player.pose_request = "read"; player.face(sp["yaw"])
		"lamp":
			# 가로등에 기대기(2D lean) — 움직이면 풀린다
			var sp: Dictionary = best["spot"]
			leaning = true; player.pose_request = "lean"; player.face(sp["yaw"])
		"resident":
			# 인사: 손을 흔들면 주민이 돌아보고 답한다
			var r: Node3D = best["node"]
			player.pose_request = "wave"; use_until = now + 1.2; action_until = now + 0.3
			player.face(atan2(r.global_position.x - p.x, r.global_position.z - p.z))
			r.greet(body)
		"tree":
			var sp: Dictionary = best["spot"]
			player.face(atan2(sp["pos"].x - p.x, sp["pos"].z - p.z))
			player.pose_request = "shake"; shake_until = now + 1.2; action_until = now + 1.2
			var apple := make_item("apple", sp["pos"] + Vector3(randf_range(-0.5, 0.5), 1.6, randf_range(0.2, 0.7)))
			flying.append({ "node": apple, "vel": Vector3(0, 0.5, 0), "spin": 3.0 })  # 흔들면 사과가 떨어진다
		"item":
			var it: Node3D = best["node"]
			items.erase(it)
			player.hold(it)
			player.action = "grab"; action_until = now + 0.4
		"door":
			set_door(best["door"], not best["door"]["open"])
		"bench":
			var b: Dictionary = best["bench"]
			seat = b
			player.seated = true
			player.move_dir = Vector3.ZERO; player.speed = 0.0
			body.velocity = Vector3.ZERO
			# 세 자리(왼·가운데·오른쪽) 중 지금 선 곳에서 가장 가까운 자리에 앉는다 — 가운데만 고집하지 않는다
			var best_slot: Vector3 = b["pos"]; var bd := 99.0
			for off in [-0.45, 0.0, 0.45]:
				var slot: Vector3 = b["pos"] + Vector3(cos(b["yaw"]) * off, 0, -sin(b["yaw"]) * off)
				var d := body.global_position.distance_to(slot)
				if d < bd: bd = d; best_slot = slot
			var tw := create_tween(); tw.set_ease(Tween.EASE_IN_OUT); tw.set_trans(Tween.TRANS_QUAD)
			tw.tween_property(body, "position", best_slot + Vector3(0, 0.03, 0.02), 0.35)  # 순간이동 대신 미끄러져 앉는다
			player.face(b["yaw"])

var _hud_at := 0.0
func _hud(now: float) -> void:
	if now - _hud_at < 0.5: return
	_hud_at = now
	var c := { "routine": 0, "walk": 0, "busy": 0, "chase": 0, "down": 0, "getup": 0 }
	for r in residents: c[r.state] = c.get(r.state, 0) + 1
	var hour := int(fmod(clock * 24.0 + 6.0, 24.0))
	var leg := get_node_or_null("UI/Legend") as Label
	if leg: leg.text = "← → ↑ ↓ move · SPACE jump (hold: higher) · X punch · Z kick · C use · V view   |   %02d:00 · %s · residents walk %d busy %d chase %d down %d" % [hour, weather, c["walk"], c["busy"], c["chase"], c["down"]]

var view_25d := true   # V 로 전환: true = 2.5D 옆시점(낮은 카메라·직교 투영, 웹 광장 느낌) / false = 3/4 내려다보기
var _v_down := false

func _process(delta: float) -> void:
	_hud(Time.get_ticks_msec() / 1000.0)
	if Input.is_key_pressed(KEY_V) and not _v_down:
		view_25d = not view_25d
	_v_down = Input.is_key_pressed(KEY_V)
	var px := clampf(body.position.x, -WORLD_X + 6.0, WORLD_X - 6.0)
	if view_25d:
		# 2.5D: 앞에서 살짝 위(약 13°)에서 보는 낮은 옆시점, 직교 투영이라 원근 왜곡이 없다 — 깊이(앞뒤)는 화면 위아래로만 읽힌다
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		cam.size = lerpf(cam.size, 9.5, minf(1.0, delta * 4.0))
		var want := Vector3(px, 3.4, clampf(body.position.z, -WORLD_Z + 2.0, WORLD_Z) + 11.0)
		cam.position = cam.position.lerp(want, minf(1.0, delta * 4.0))
		if cam_kick > 0.0:
			cam.position += Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * cam_kick; cam_kick = maxf(0.0, cam_kick - delta * 0.3)
		cam.look_at(Vector3(cam.position.x, 0.9, cam.position.z - 11.0), Vector3.UP)
	else:
		# 3/4 시점: 플레이어 뒤·위에서 내려다본다
		cam.projection = Camera3D.PROJECTION_PERSPECTIVE
		var want := Vector3(px, 0, clampf(body.position.z, -WORLD_Z + 6.0, WORLD_Z - 4.0)) + Vector3(0, 8.5, 7.5)
		cam.position = cam.position.lerp(want, minf(1.0, delta * 4.0))
		if cam_kick > 0.0:
			cam.position += Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * cam_kick; cam_kick = maxf(0.0, cam_kick - delta * 0.3)
		cam.look_at(Vector3(cam.position.x, 0.6, cam.position.z - 7.5), Vector3.UP)
