class_name KeyHelp
extends PanelContainer
## 조작법 창(운영자 2026-10-06: "단축키 명령어도 따로 볼 수 있는 곳이 있어야") — H 로 열고 닫는다. 마을·게임마다 제 목록(rows)
## 채팅 입력 중엔 H 가 글자라 열지 않는다(chat)

var chat: ChatBox = null

func setup(title: String, rows: Array) -> void:
	visible = false; position = Vector2(170, 36); mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new(); sb.bg_color = Color(0.97, 0.96, 0.94, 0.96); sb.border_color = Color("7b526c")
	sb.set_border_width_all(2); sb.set_corner_radius_all(8); sb.set_content_margin_all(16); add_theme_stylebox_override("panel", sb)
	var g := GridContainer.new(); g.columns = 2; g.add_theme_constant_override("h_separation", 18); g.add_theme_constant_override("v_separation", 4)
	var box := VBoxContainer.new(); add_child(box)
	var h := Label.new(); h.text = title + "   (H to close)"; h.add_theme_color_override("font_color", Color("7b526c")); h.add_theme_font_size_override("font_size", 15); box.add_child(h)
	box.add_child(g)
	for r in rows:
		for i in 2:
			var l := Label.new(); l.text = String(r[i])
			l.add_theme_color_override("font_color", Color("1b0c15") if i == 1 else Color("7b526c")); l.add_theme_font_size_override("font_size", 14)
			g.add_child(l)

func _input(e: InputEvent) -> void:
	if not (e is InputEventKey) or not e.pressed or e.echo or (e as InputEventKey).keycode != KEY_H: return
	if chat and chat.typing: return
	if get_parent() is CanvasItem and not (get_parent() as CanvasItem).is_visible_in_tree(): return
	visible = not visible
