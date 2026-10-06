class_name ClimbSigns
extends CanvasLayer
## Climb 안내판(운영자 2026-10-06: "이렇게 화면에 글로 표현하지 말고, 안에 표지판을 세워 두고 C 로 보면 확대해서 볼 수 있게") —
## 쉼터 층마다 판 하나: 0층은 오르는 법(지금 키 이름으로 — Esc 메뉴에서 바꾸면 따라 바뀐다), 쉼터는 층 안내, 손도끼 층 앞은 경고.
## 가까이 가면 판 위에 "C" 가 뜨고, C 로 판을 크게 띄운다(종이판). C·Esc 로 닫는다. 읽는 동안 몸은 멈춘다(climb 의 locked)

var game: Node3D = null
var signs: Array = []          # {x, y(px), text, tag: Label3D}
var reading := false
var _closed_at := -1.0
var _panel: PanelContainer
var _text: Label

func _ready() -> void:
	layer = 30
	_panel = PanelContainer.new(); _panel.visible = false
	var sb := StyleBoxFlat.new(); sb.bg_color = Color("efe2cf"); sb.border_color = Color("6b4a35"); sb.set_border_width_all(10); sb.set_corner_radius_all(6); sb.set_content_margin_all(28)
	_panel.add_theme_stylebox_override("panel", sb)
	var center := CenterContainer.new(); center.set_anchors_preset(Control.PRESET_FULL_RECT); center.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(center)
	center.add_child(_panel)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 12); _panel.add_child(v)
	_text = Label.new(); _text.add_theme_font_size_override("font_size", 20); _text.add_theme_color_override("font_color", Color("1b0c15")); _text.custom_minimum_size = Vector2(560, 0); _text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; v.add_child(_text)
	var hint := Label.new(); hint.text = "C or Esc: close"; hint.add_theme_font_size_override("font_size", 13); hint.add_theme_color_override("font_color", Color("7b526c")); v.add_child(hint)

func busy() -> bool:
	return reading or (_closed_at > 0.0 and Time.get_ticks_msec() / 1000.0 - _closed_at < 0.25)

## 쉼터 층의 판 — climb._build_band 가 쉼터 발판을 지을 때 부른다(node = 발판, w = 발판 폭 m, rest = 발판 자료 px)
func place(node: Node3D, n: int, w: float, rest: Dictionary, gear_band: int, every: int) -> void:
	var text := _text_for(n, gear_band, every)
	var at := Vector3(w * 0.05 if n > 0 else 2.2, 0, -0.75)
	var wood := StandardMaterial3D.new(); wood.albedo_color = Color("6b4a35")
	var paper := StandardMaterial3D.new(); paper.albedo_color = Color("efe2cf")
	for p in [[Vector3(0.08, 1.3, 0.08), Vector3(-0.45, 0.65, 0), wood], [Vector3(0.08, 1.3, 0.08), Vector3(0.45, 0.65, 0), wood], [Vector3(1.1, 0.7, 0.06), Vector3(0, 1.2, 0), paper]]:
		var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = p[0]; mi.mesh = bm; mi.material_override = p[2]; mi.position = at + p[1]; node.add_child(mi)
	var title := Label3D.new(); title.text = text.split("\n")[0]; title.font_size = 48; title.pixel_size = 0.004; title.modulate = Color("1b0c15"); title.outline_size = 0
	title.position = at + Vector3(0, 1.3, 0.04); node.add_child(title)
	var tag := Label3D.new(); tag.text = "C"; tag.font_size = 72; tag.pixel_size = 0.004; tag.modulate = Color("ad7096"); tag.outline_size = 10; tag.outline_modulate = Color("f7f4ef")
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED; tag.no_depth_test = true; tag.position = at + Vector3(0, 1.9, 0.1); tag.visible = false; node.add_child(tag)
	var px := float(rest.get("x", 0.0)) + float(rest.get("w", 0.0)) / 2.0 + at.x * 36.0   # 발판 x 는 왼쪽 끝(px), 1m = 36px
	signs = signs.filter(func(s: Dictionary) -> bool: return is_instance_valid(s["tag"]))   # 지운 층의 판은 뺀다
	signs.append({ "x": px, "y": float(rest.get("y", 0.0)), "text": text, "tag": tag })

func _text_for(n: int, gear_band: int, every: int) -> String:
	var k := func(a: String) -> String: return GameMenu.key_of(a)
	if n == 0:
		return "HOW TO CLIMB\n\nWalk: %s / %s.\nJump: hold %s to charge, let go to jump. Longer is higher. Steer in the air.\nHolds: press %s next to a hold to grab it, then jump off it.\nRock walls (above 1 km): you need an ice axe. Each axe belongs to whoever finds it first.\nCamps: every %d floors. %s at a camp door leaves here; next time you start here.\nShove: %s next to another climber.\nChat: %s.  Leave the tower: Esc." % [k.call("move_left"), k.call("move_right"), k.call("jump"), k.call("move_up"), every, k.call("act"), k.call("hit"), k.call("chat")]
	if n >= gear_band - every and n < gear_band:
		return "ROCK AHEAD — FLOOR %d\n\nThe walls above are sheer. Without an ice axe you will not get past them.\nAxes are hidden on the short cuts of the floors just below. Someone may have taken the near ones." % n
	return "FLOOR %d — CAMP\n\nRest here. %s at the door: leave the tower, and start from this camp next time.\nThe next camp is %d floors up." % [n, GameMenu.key_of("act"), every]

## 매 틱 — 가까운 판 위에 C, C 로 읽기. 읽었으면 true(그 틱의 C 는 판이 먹는다)
func tick(px: float, py: float, c_pressed: bool) -> bool:
	var near: Dictionary = {}
	for s in signs:
		if not is_instance_valid(s["tag"]): continue
		var ok := absf(px - float(s["x"])) < 70.0 and absf(py - float(s["y"])) < 80.0
		(s["tag"] as Label3D).visible = ok and not reading
		if ok: near = s
	if c_pressed and not reading and not near.is_empty():
		_open(String(near["text"])); return true
	return false

func _open(text: String) -> void:
	reading = true; _text.text = text; _panel.visible = true

func _close() -> void:
	reading = false; _panel.visible = false; _closed_at = Time.get_ticks_msec() / 1000.0

func _input(e: InputEvent) -> void:
	if not reading or not (e is InputEventKey) or not e.pressed or e.echo: return
	if e.is_action_pressed("act") or (e as InputEventKey).keycode == KEY_ESCAPE:
		_close(); get_viewport().set_input_as_handled()
