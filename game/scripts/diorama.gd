extends Node3D
## 3D 디오라마 — 같은 SVG 에셋을 진짜 3D 바닥 위에 종이 인형처럼 세운다(페이퍼 마리오 식). 2D 무대(main.tscn)와 비교용.
## "저해상도여도 부자연스럽지 않게"(운영자 2026-09-28): 모든 것 밑에 닿는 그림자, 멀수록 종이색으로 옅어짐, 판은 카메라를 향해 선다,
## 조명은 쓰지 않는다(unshaded — 빛 방향이 제각각인 것이 가장 부자연스럽다).

const PIXEL := 0.02            # 1 SVG px = 0.02 m → 졸라맨 42px ≈ 0.84 m
const PAPER := Color("f7f4ef")
const ROWS := [0.0, -3.0, -6.0]  # 앞·중간·뒤 줄의 z

@onready var camera: Camera3D = $Camera3D

func _ready() -> void:
	_ground()
	_props()
	var p := preload("res://scripts/diorama_player.gd").new()
	p.name = "Player"
	add_child(p)
	p.position = Vector3(0, 0, 1.2)

## 카메라는 플레이어를 옆으로 부드럽게 따라온다(벨트스크롤) — 높이·기울기는 고정, 세계 끝에서 멈춘다
func _process(delta: float) -> void:
	var p := get_node_or_null("Player") as Node3D
	if p == null:
		return
	var want := clampf(p.position.x, -10.0, 10.0)
	camera.position.x = lerpf(camera.position.x, want, minf(1.0, delta * 5.0))

func _ground() -> void:
	var g := MeshInstance3D.new()
	var m := PlaneMesh.new(); m.size = Vector2(80, 40)
	g.mesh = m
	var mat := StandardMaterial3D.new(); mat.albedo_color = Color("e6e0da"); mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	g.material_override = mat
	g.position = Vector3(0, 0, -8)
	add_child(g)
	# 뒤쪽 벽 — 웹 무대의 top 선처럼, 세계가 어디서 끝나는지 보이게
	var wall := MeshInstance3D.new()
	var q := QuadMesh.new(); q.size = Vector2(80, 12)
	wall.mesh = q
	var wm := StandardMaterial3D.new(); wm.albedo_color = Color("dfe6ea"); wm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	wall.material_override = wm
	wall.position = Vector3(0, 6, -9.5)
	add_child(wall)

func _props() -> void:
	var f := FileAccess.open("res://assets/manifest.json", FileAccess.READ)
	if f == null:
		push_error("diorama: assets/manifest.json missing — run `node game/tools/assets.mjs`")
		return
	var data: Dictionary = JSON.parse_string(f.get_as_text())
	var x := -14.0
	var row := 0
	for a in data.get("assets", []):
		# 소지품·아이콘·졸라맨 판은 세우지 않는다; 타일·벽면(tile)은 3D 마을의 텍스처라 여기 없다
		if a["cat"] in ["items", "ui", "figures"] or a.get("tile", false):
			continue
		var z: float = ROWS[row % ROWS.size()]
		var y := 0.0
		if a["cat"] == "sky":
			y = 5.0 + float(row % 2)
			z = -9.0
		make_sprite("res://assets/svg/%s.svg" % a["id"], Vector3(x, y, z), a["cat"] != "sky")
		x += float(a["w"]) * PIXEL + 0.9
		row += 1
		if x > 14.0:
			x = -14.0 + float(row % 3) * 0.7

## 발끝이 pos 에 닿게 세운 종이 판 + 닿는 그림자. 멀수록 종이색으로 옅어진다(공기 원근)
func make_sprite(path: String, pos: Vector3, shadow: bool) -> Sprite3D:
	var s := Sprite3D.new()
	s.texture = load(path)
	s.pixel_size = PIXEL
	s.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	s.shaded = false
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var h := float(s.texture.get_height()) * PIXEL
	s.position = pos + Vector3(0, h / 2.0, 0)
	var fade := clampf((-pos.z) / 12.0, 0.0, 0.55)
	s.modulate = Color.WHITE.lerp(PAPER, fade)
	add_child(s)
	if shadow:
		add_child(_shadow(pos, float(s.texture.get_width()) * PIXEL))
	return s

func _shadow(pos: Vector3, w: float) -> MeshInstance3D:
	var sh := MeshInstance3D.new()
	var q := QuadMesh.new(); q.size = Vector2(maxf(0.4, w * 0.8), maxf(0.2, w * 0.28))
	sh.mesh = q
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.1, 0.05, 0.08, 0.16)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sh.material_override = mat
	sh.rotation_degrees.x = -90.0
	sh.position = pos + Vector3(0, 0.005, 0.05)
	return sh
