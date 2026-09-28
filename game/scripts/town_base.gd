class_name TownBase
extends Node3D
## 마을의 상태와 공용 도우미 — 모든 마을 스크립트의 밑바탕(상속 사슬: base → build → places → systems → player → town3d).
## 여기엔 상수·상태 변수와 재료·상자·구역 같은 기초 도우미만 둔다. 기능은 위 계층에.

## 3D 마을 시제품 — 오메가루비 식 3/4 시점(운영자 2026-09-28: "최소한 오메가루비 같은 퀄리티"). 전부 코드로 만든 기하:
## 속이 빈 집(벽 네 장, 창은 기하, 경첩 달린 문짝 — 열고 들어간다), 기둥+구 나무, 타일 바닥과 자갈길, 벤치·가로등·울타리,
## 방향광 하나와 그림자, 툰 확산, 입체 졸라맨(Stick3D). 상호작용은 C 하나: 들고 있으면 내려놓기, 아니면 가까운 것부터 — 물건 집기 · 문 열닫기 · 벤치 앉기.
const TILE := 2.0

const WALK := 2.6

const G := 22.0

## 점프는 짧은 홉(Climb 의 힘 모으기는 마을에 안 맞는다) — 벤치(0.45m)·계단·낮은 담 위에 올라설 만큼, 집 벽은 못 넘는다
const HOP := 5.4

const JUMP_FULL := 7.4   # 꽉 찬 점프(약 1.25m). 톡 치면 상승이 끊겨 홉이 된다

const JUMP_HOLD := 0.28   # 점프 홀드 최대(초) — 누르는 동안 더 높이·멀리(가변 점프)

const WALL := 0.16

const WORLD_X := 46.0    # 세계 반폭(m): 서쪽 공원(-46..-16) · 마을(-16..16) · 동쪽 시장(16..46)

const WORLD_Z := 26.0    # 세계 반깊이(m): 큰길 z≈2 · 북쪽 골목 z≈-13(집 세 채, 2026-09-28 비전 런) · 남쪽 강 z 9..12 · 다리 건너 풀밭 z 12..25

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

var jump_cut_ok := false

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

var lamps: Array = []   # 저녁에 켜지는 불 {light, bulb}

var clock := 0.3        # 0..1 하루 — 0.3 = 아침에서 시작

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

var houses: Array = []

var movables: Array = []       # 옮길 수 있는 가구 {node, kind, spot}

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

var swings: Array = []      # {pivot, len, angle, vel, seat_pos(at), riding}

var riding: Dictionary = {}  # 내가 타고 있는 그네

var weather := "clear"      # clear | cloudy | rain

var weather_until := 90.0

var rain: CPUParticles3D

var wet: MeshInstance3D

var _wrng := RandomNumberGenerator.new()

var animals: Array = []

var crowns: Array = []   # 흔들리는 잎 뭉치 {node, phase, k}

var wind_t := 0.0

var petting_until := -1.0

var pet_dog: Dictionary = {}

## 입는 것(모자·안경·가방) — Wear 가 만든 노드를 세계에 두고 집을 수 있게 한다
func make_wearable(kind: String, at: Vector3, color := Color("ad7096")) -> Node3D:
	var n := Wear.make(kind, color)
	n.position = at + Vector3(0, 0.08, 0)
	add_child(n)
	return n

func make_item(kind: String, at: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	match kind:
		"apple":
			var s := SphereMesh.new(); s.radius = 0.07; s.height = 0.14; mi.mesh = s; mi.material_override = _mat(Color("ff2d55"))
			mi.position = at + Vector3(0, 0.07, 0)
		"cup":
			var c := CylinderMesh.new(); c.top_radius = 0.06; c.bottom_radius = 0.05; c.height = 0.13; mi.mesh = c; mi.material_override = _mat(Color("f7f4ef"))
			mi.position = at + Vector3(0, 0.065, 0)
		"bread":
			var b2 := CapsuleMesh.new(); b2.radius = 0.06; b2.height = 0.24; mi.mesh = b2; mi.material_override = _mat(Color("b48a5a"))
			mi.rotation.z = PI / 2.0; mi.position = at + Vector3(0, 0.06, 0)
		"tomato", "cabbage", "pumpkin":
			# 텃밭 작물(run 70) — 사과와 같은 구, 종류마다 색과 크기. 세 입에 먹는다(FOOD)
			var cs := SphereMesh.new(); var cr: float = { "tomato": 0.07, "cabbage": 0.11, "pumpkin": 0.13 }[kind]; cs.radius = cr; cs.height = cr * 1.7
			var cc: Color = { "tomato": Color("ff2d55"), "cabbage": Color("7fb05a"), "pumpkin": Color("d98a2a") }[kind]
			mi.mesh = cs; mi.material_override = _mat(cc)
			mi.position = at + Vector3(0, cr * 0.85, 0)
		"can":
			# 물뿌리개(run 70): 양철 몸통 + 앞으로 숙인 주둥이 + 손잡이, 주둥이 끝에 물방울 입자(붓는 동안만 — StickPoses.drops)
			var cb := CylinderMesh.new(); cb.top_radius = 0.065; cb.bottom_radius = 0.075; cb.height = 0.15; mi.mesh = cb; mi.material_override = _mat(Color("6f8fa0"))
			mi.position = at + Vector3(0, 0.075, 0)
			var sp := _box(Vector3(0.03, 0.03, 0.2), Vector3(0, 0.02, 0.12), _mat(Color("6f8fa0")), false, mi); sp.rotation.x = -0.6
			_box(Vector3(0.025, 0.025, 0.12), Vector3(0, 0.1, 0.0), _mat(Color("4a4a52")), false, mi)
			var dr := CPUParticles3D.new(); dr.amount = 24; dr.lifetime = 0.55; dr.emitting = false; dr.local_coords = false
			dr.direction = Vector3(0, -0.6, 0.6); dr.spread = 8.0; dr.initial_velocity_min = 0.5; dr.initial_velocity_max = 0.8; dr.gravity = Vector3(0, -7, 0)
			dr.mesh = SphereMesh.new(); (dr.mesh as SphereMesh).radius = 0.012; (dr.mesh as SphereMesh).height = 0.024
			var dm := StandardMaterial3D.new(); dm.albedo_color = Color("8fb8cc"); dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; dr.material_override = dm
			dr.position = Vector3(0, 0.08, 0.24); mi.add_child(dr); mi.set_meta("drops", dr)
		_:
			var b := BoxMesh.new(); b.size = Vector3(0.22, 0.02, 0.16); mi.mesh = b; mi.material_override = _mat(Color("efe9e2"))
			mi.position = at + Vector3(0, 0.01, 0)
	mi.set_meta("kind", kind)
	add_child(mi)
	return mi

var cam_kick := 0.0
var pushing: Dictionary = {}   # 내가 밀어 주는 그네

var shake_until := -1.0

var use_until := -1.0     # 먹기·마시기 자세가 끝나는 시각

var reading := false      # 신문 읽는 중(움직이면 끝)

var leaning := false      # 가로등에 기댄 중(움직이면 끝)

const STEP := 0.42

const FOOD := ["apple", "bread", "tomato", "cabbage", "pumpkin"]   # C 로 한입씩 먹는 것 — 텃밭 작물도(run 70)

var _hud_at := 0.0

var view_25d := true   # V 로 전환: true = 2.5D 옆시점(낮은 카메라·직교 투영, 웹 광장 느낌) / false = 3/4 내려다보기

var _v_down := false
