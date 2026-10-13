class_name BoardView
extends CanvasLayer
## 게시판 보기(운영자 2026-10-13: "게시판 보려 할 때 시점이 바뀌면서 그게 뭔지 보여야지, 글들 수정하거나 할 수 있어야") —
## 판 앞에서 C 를 누르면 카메라가 판 앞으로 다가가고(town_social _board_cam) 이 창이 뜬다: 꽂힌 글(쓴 사람·언제·내용),
## 내 글엔 고치기·지우기, 아래 칸에 써서 붙이기. 글은 방(poz_net, climb-room 의 world.board)에 남아 같은 마을의 모두가 같이 본다.
## 비로그인은 읽기만. 연결이 없으면 이 컴퓨터에만 남는 글(records)로 쓴다. Esc·닫기로 나간다(그동안 몸은 멈춘다 — typing)

signal closed

var town: Node
var board := "square"
var title := "Notice board"
var _list: VBoxContainer
var _edit: LineEdit
var _post_btn: Button
var _editing_id := ""
var _hint: Label

func open(t: Node, key: String, name: String) -> void:
	town = t; board = key; title = name; layer = 36
	var root := Control.new(); root.set_anchors_preset(Control.PRESET_FULL_RECT); root.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(root)
	var p := PanelContainer.new()
	p.anchor_left = 0.56; p.anchor_right = 0.97; p.anchor_top = 0.08; p.anchor_bottom = 0.92
	var sb := StyleBoxFlat.new(); sb.bg_color = Color(0.97, 0.955, 0.937, 0.97); sb.border_color = Color("7b526c"); sb.set_border_width_all(2); sb.set_corner_radius_all(10); sb.set_content_margin_all(14)
	p.add_theme_stylebox_override("panel", sb); root.add_child(p)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 8); p.add_child(v)
	var h := Label.new(); h.text = title.to_upper(); h.add_theme_font_size_override("font_size", 20); h.add_theme_color_override("font_color", Color("1b0c15")); v.add_child(h)
	_hint = Label.new(); _hint.add_theme_font_size_override("font_size", 12); _hint.add_theme_color_override("font_color", Color("7b526c")); _hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; v.add_child(_hint)
	var sc := ScrollContainer.new(); sc.size_flags_vertical = Control.SIZE_EXPAND_FILL; sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; v.add_child(sc)
	_list = VBoxContainer.new(); _list.size_flags_horizontal = Control.SIZE_EXPAND_FILL; _list.add_theme_constant_override("separation", 6); sc.add_child(_list)
	_edit = LineEdit.new(); _edit.placeholder_text = "Write a note (200 characters)"; _edit.max_length = 200; v.add_child(_edit)
	_edit.text_submitted.connect(func(_s: String) -> void: _submit())
	var row := HBoxContainer.new(); v.add_child(row)
	_post_btn = Button.new(); _post_btn.text = "Pin it"; _post_btn.pressed.connect(_submit); row.add_child(_post_btn)
	var close := Button.new(); close.text = "Close (Esc)"; close.pressed.connect(close_view); row.add_child(close)
	refresh()
	_edit.grab_focus()

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and (e as InputEventKey).keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled(); close_view()

func close_view() -> void:
	closed.emit(); queue_free()

func refresh() -> void:
	if _list == null: return
	for c in _list.get_children(): c.queue_free()
	var posts: Array = town.call("board_posts", board)
	var me: int = int(town.call("board_me"))
	var can_write: bool = town.call("board_can_write")
	_hint.text = ("Everyone in town sees these." if town.call("board_shared") else "Not connected — notes stay on this computer.") + ("" if can_write else "  Sign in (S) to write.")
	_edit.editable = can_write; _post_btn.disabled = not can_write
	if posts.is_empty():
		var e := Label.new(); e.text = "Nothing pinned yet."; e.add_theme_color_override("font_color", Color("7b526c")); _list.add_child(e)
	for i in range(posts.size() - 1, -1, -1):   # 새 글이 위
		var pst: Dictionary = posts[i]
		var card := PanelContainer.new()
		var cs := StyleBoxFlat.new(); cs.bg_color = Color("efe2cf") if int(pst.get("uid", -1)) != me else Color("f3e3ec"); cs.set_corner_radius_all(6); cs.set_content_margin_all(8)
		card.add_theme_stylebox_override("panel", cs); _list.add_child(card)
		var cv := VBoxContainer.new(); card.add_child(cv)
		var who := Label.new(); who.text = "%s · %s%s" % [String(pst.get("handle", "someone")), _ago(float(pst.get("at", 0))), " · edited" if pst.get("edited", false) else ""]
		who.add_theme_font_size_override("font_size", 11); who.add_theme_color_override("font_color", Color("7b526c")); cv.add_child(who)
		var body := Label.new(); body.text = String(pst.get("body", "")); body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; body.add_theme_color_override("font_color", Color("1b0c15")); cv.add_child(body)
		if int(pst.get("uid", -1)) == me and can_write:
			var r := HBoxContainer.new(); cv.add_child(r)
			var ed := Button.new(); ed.text = "Edit"; ed.flat = true; r.add_child(ed)
			var id := String(pst.get("id", ""))
			ed.pressed.connect(func() -> void: _editing_id = id; _edit.text = String(pst.get("body", "")); _post_btn.text = "Save"; _edit.grab_focus())
			var del := Button.new(); del.text = "Remove"; del.flat = true; r.add_child(del)
			del.pressed.connect(func() -> void: town.call("board_remove", board, id))

func _submit() -> void:
	var s := _edit.text.strip_edges()
	if s == "": return
	if _editing_id != "": town.call("board_edit", board, _editing_id, s)
	else: town.call("board_post", board, s)
	_editing_id = ""; _edit.text = ""; _post_btn.text = "Pin it"

static func _ago(at_ms: float) -> String:
	if at_ms <= 0.0: return "just now"
	var s := (Time.get_unix_time_from_system() * 1000.0 - at_ms) / 1000.0
	if s < 60.0: return "just now"
	if s < 3600.0: return "%d min ago" % int(s / 60.0)
	if s < 86400.0: return "%d h ago" % int(s / 3600.0)
	return "%d days ago" % int(s / 86400.0)
