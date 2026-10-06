class_name GameMenu
extends CanvasLayer
## 게임 메뉴(운영자 2026-10-06: "단축키를 저렇게 띄워서 성의 없이 알려줄 거 아니잖아", "esc 눌러서 설정·종료 같은 게 나오고, 키 설정에서 바꿀 수 있게", "단축키 설명은 따로 띄워서") —
## Esc: 메뉴(계속·조작·설정·계정·나가기). 조작: 묶음별 키 캡 목록 — 키를 누르고 새 키를 치면 바뀐다(user://keys.json 에 남는다), 기본값으로 되돌리기. H 는 조작 화면을 바로.
## 설정: 소리 크기·전체 화면·FPS 표시(user://settings.json). 메뉴가 열린 동안 몸은 멈춘다(town_social typing 과 같은 길). 마을은 멈추지 않는다(다른 사람이 있으니까)

const KEYS_FILE := "user://keys.json"
const SETTINGS_FILE := "user://settings.json"
## [묶음, 행동, 이름] — 행동이 InputMap 에 없으면 기본 키로 만든다(ensure_actions)
const ROWS := [
	["Move", "move_up", "Walk up"], ["Move", "move_down", "Walk down"], ["Move", "move_left", "Walk left"], ["Move", "move_right", "Walk right"], ["Move", "jump", "Jump (hold: higher)"],
	["Fight", "hit", "Punch · throw (hold while carrying)"], ["Fight", "kick", "Kick"],
	["Use", "act", "Use · doors · sit · get in (hold: carry furniture)"],
	["People", "chat", "Chat"], ["People", "emote_1", "Wave"], ["People", "emote_2", "Cheer"], ["People", "emote_3", "Bow"], ["People", "emote_4", "Dance"], ["People", "emote_5", "Lie down"],
	["Camera", "zoom_in", "Zoom in"], ["Camera", "zoom_out", "Zoom out"],
	["Menu", "controls", "Controls (this screen)"], ["Menu", "sign_in", "Sign in (desktop)"],
]
const EXTRA := { "chat": KEY_ENTER, "emote_1": KEY_1, "emote_2": KEY_2, "emote_3": KEY_3, "emote_4": KEY_4, "emote_5": KEY_5, "zoom_in": KEY_EQUAL, "zoom_out": KEY_MINUS, "controls": KEY_H, "sign_in": KEY_S }
const NOTES := "Mouse wheel zooms too. Double-tap a direction to dash. In a car: Up/Down drive, Left/Right steer, Jump = handbrake drift, Use = get out. Next to a resident's car: Use rides along, Punch at the door pulls the driver out."

var town: Node = null
var open := false
var _defaults := {}            # 행동 -> [keycode] (처음 InputMap)
var _root: Control
var _pages := {}
var _wait_action := ""         # 새 키를 기다리는 행동
var _key_buttons := {}
var _fps: Label
var settings := { "volume": 0.8, "fullscreen": false, "fps": false }

static func ensure_actions() -> void:
	for a in EXTRA:
		if not InputMap.has_action(a):
			InputMap.add_action(a)
			var e := InputEventKey.new(); e.keycode = EXTRA[a]; InputMap.action_add_event(a, e)

func _ready() -> void:
	layer = 40; process_mode = Node.PROCESS_MODE_ALWAYS
	ensure_actions()
	for r in ROWS: _defaults[r[1]] = _keys_of(r[1])
	_load_keys(); _load_settings()
	_build()
	_fps = Label.new(); _fps.position = Vector2(12, 8); _fps.add_theme_color_override("font_color", Color("7b526c")); _fps.visible = bool(settings["fps"]); add_child(_fps)

func _process(_d: float) -> void:
	if _fps.visible: _fps.text = "%d fps" % Engine.get_frames_per_second()

func _keys_of(a: String) -> Array:
	var out := []
	for e in InputMap.action_get_events(a):
		if e is InputEventKey: out.append((e as InputEventKey).keycode if (e as InputEventKey).keycode != 0 else (e as InputEventKey).physical_keycode)
	return out

func _set_key(a: String, code: int) -> void:
	for e in InputMap.action_get_events(a):
		if e is InputEventKey: InputMap.action_erase_event(a, e)
	var k := InputEventKey.new(); k.keycode = code; InputMap.action_add_event(a, k)

static func key_name(code: int) -> String:
	var s := OS.get_keycode_string(code)
	return { "Equal": "=", "Minus": "-", "Space": "Space", "Enter": "Enter", "Escape": "Esc" }.get(s, s)

## 행동의 첫 키 이름 — 안내 문구가 바뀐 키를 따라가게
static func key_of(a: String) -> String:
	for e in InputMap.action_get_events(a):
		if e is InputEventKey: return key_name((e as InputEventKey).keycode if (e as InputEventKey).keycode != 0 else (e as InputEventKey).physical_keycode)
	return "?"

# ── 저장 ──
func _load_keys() -> void:
	if not FileAccess.file_exists(KEYS_FILE): return
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(KEYS_FILE))
	if d is Dictionary:
		for a in d: if InputMap.has_action(a): _set_key(a, int(d[a]))

func _save_keys() -> void:
	var d := {}
	for r in ROWS:
		var ks := _keys_of(r[1])
		if not ks.is_empty() and ks != _defaults[r[1]]: d[r[1]] = ks[0]
	var f := FileAccess.open(KEYS_FILE, FileAccess.WRITE)
	if f: f.store_string(JSON.stringify(d))

func _load_settings() -> void:
	if FileAccess.file_exists(SETTINGS_FILE):
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(SETTINGS_FILE))
		if d is Dictionary: settings.merge(d, true)
	_apply_settings()

func _save_settings() -> void:
	var f := FileAccess.open(SETTINGS_FILE, FileAccess.WRITE)
	if f: f.store_string(JSON.stringify(settings))
	_apply_settings()

func _apply_settings() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(0.001, float(settings["volume"]))))
	if not OS.has_feature("web"):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if settings["fullscreen"] else DisplayServer.WINDOW_MODE_WINDOWED)
	if _fps: _fps.visible = bool(settings["fps"])

# ── 화면 ──
func _style(bg: Color, border := Color("7b526c")) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new(); sb.bg_color = bg; sb.border_color = border; sb.set_border_width_all(2); sb.set_corner_radius_all(10); sb.set_content_margin_all(18)
	return sb

func _label(t: String, size := 16, c := Color("1b0c15")) -> Label:
	var l := Label.new(); l.text = t; l.add_theme_font_size_override("font_size", size); l.add_theme_color_override("font_color", c)
	return l

func _button(t: String, cb: Callable, wide := 220) -> Button:
	var b := Button.new(); b.text = t; b.custom_minimum_size = Vector2(wide, 40); b.focus_mode = Control.FOCUS_ALL
	b.add_theme_font_size_override("font_size", 17)
	b.add_theme_stylebox_override("normal", _style(Color("f7f4ef"), Color("cfc7c2"))); b.add_theme_stylebox_override("hover", _style(Color("efe2ea"))); b.add_theme_stylebox_override("pressed", _style(Color("e2cfdb")))
	b.add_theme_stylebox_override("focus", _style(Color("efe2ea")))
	for s in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]: b.add_theme_color_override(s, Color("1b0c15"))
	b.pressed.connect(cb)
	return b

func _build() -> void:
	_root = Control.new(); _root.set_anchors_preset(Control.PRESET_FULL_RECT); _root.visible = false; add_child(_root)
	var dim := ColorRect.new(); dim.color = Color(0.06, 0.02, 0.05, 0.55); dim.set_anchors_preset(Control.PRESET_FULL_RECT); _root.add_child(dim)
	var center := CenterContainer.new(); center.set_anchors_preset(Control.PRESET_FULL_RECT); _root.add_child(center)
	# 메인
	var main := PanelContainer.new(); main.add_theme_stylebox_override("panel", _style(Color("f7f4ef"))); center.add_child(main)
	var mv := VBoxContainer.new(); mv.add_theme_constant_override("separation", 10); main.add_child(mv)
	mv.add_child(_label("poz", 34)); mv.add_child(_label("Paused for you. The town keeps going.", 13, Color("7b526c")))
	mv.add_child(_button("Resume", close_menu)); mv.add_child(_button("Controls", func() -> void: _show("controls")))
	mv.add_child(_button("Settings", func() -> void: _show("settings"))); mv.add_child(_button("Account", func() -> void: _show("account")))
	if not OS.has_feature("web"): mv.add_child(_button("Quit to desktop", func() -> void: get_tree().root.propagate_notification(NOTIFICATION_WM_CLOSE_REQUEST); get_tree().quit()))
	_pages["main"] = main
	_pages["controls"] = _controls_page(center)
	_pages["settings"] = _settings_page(center)
	_pages["account"] = _account_page(center)

func _page(center: Control, title: String) -> VBoxContainer:
	var p := PanelContainer.new(); p.add_theme_stylebox_override("panel", _style(Color("f7f4ef"))); p.visible = false; center.add_child(p)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 8); p.add_child(v)
	var top := HBoxContainer.new(); v.add_child(top)
	top.add_child(_label(title, 26)); var sp := Control.new(); sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL; top.add_child(sp)
	top.add_child(_button("Back", func() -> void: _show("main"), 90))
	return v

## 조작 — 묶음 제목 + 줄마다 [키 캡 단추] 설명. 단추를 누르면 "Press a key…" — 다음 키가 그 행동의 키
func _controls_page(center: Control) -> Control:
	var v := _page(center, "Controls")
	v.add_child(_label("Click a key, then press the new one. Esc cancels.", 13, Color("7b526c")))
	var scroll := ScrollContainer.new(); scroll.custom_minimum_size = Vector2(620, 320); v.add_child(scroll)
	var grid := VBoxContainer.new(); grid.add_theme_constant_override("separation", 4); grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL; scroll.add_child(grid)
	var last := ""
	for r in ROWS:
		if r[0] != last:
			last = r[0]; var g := _label(String(r[0]).to_upper(), 12, Color("ad7096")); grid.add_child(g)
		var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 14); grid.add_child(row)
		var a: String = r[1]
		var kb := _button(key_of(a), func() -> void: _wait_key(a), 120)
		kb.custom_minimum_size = Vector2(120, 30)
		_key_buttons[a] = kb; row.add_child(kb); row.add_child(_label(String(r[2]), 15))
	var notes := _label(NOTES, 12, Color("7b526c")); notes.custom_minimum_size = Vector2(620, 0); notes.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; v.add_child(notes)
	v.add_child(_button("Reset to defaults", _reset_keys, 200))
	return v.get_parent()

func _settings_page(center: Control) -> Control:
	var v := _page(center, "Settings")
	var vr := HBoxContainer.new(); v.add_child(vr); vr.add_child(_label("Volume", 16))
	var sl := HSlider.new(); sl.min_value = 0.0; sl.max_value = 1.0; sl.step = 0.05; sl.value = float(settings["volume"]); sl.custom_minimum_size = Vector2(260, 30)
	sl.value_changed.connect(func(x: float) -> void: settings["volume"] = x; _save_settings()); vr.add_child(sl)
	if not OS.has_feature("web"):
		var fs := CheckBox.new(); fs.text = "Full screen"; fs.button_pressed = bool(settings["fullscreen"]); fs.add_theme_color_override("font_color", Color("1b0c15"))
		fs.toggled.connect(func(on: bool) -> void: settings["fullscreen"] = on; _save_settings()); v.add_child(fs)
	var fp := CheckBox.new(); fp.text = "Show FPS"; fp.button_pressed = bool(settings["fps"]); fp.add_theme_color_override("font_color", Color("1b0c15"))
	fp.toggled.connect(func(on: bool) -> void: settings["fps"] = on; _save_settings()); v.add_child(fp)
	v.add_child(_label("Version " + PozUpdate.version(), 12, Color("7b526c")))
	return v.get_parent()

func _account_page(center: Control) -> Control:
	var v := _page(center, "Account")
	var who := _label("", 16); who.name = "Who"; v.add_child(who)
	v.add_child(_button("Sign in through the browser", func() -> void: _net_call("sign_in"); close_menu(), 300))
	v.add_child(_button("Sign out on this computer", func() -> void: _net_call("sign_out"); _refresh_account(), 300))
	v.add_child(_label("Signing in keeps your coins and records with your population.town account.", 12, Color("7b526c")))
	return v.get_parent()

func _net_call(m: String) -> void:
	var net: PozNet = get_tree().root.get_node_or_null("PozNet") as PozNet
	if net and net.account: net.account.call(m)
	elif m == "sign_in" and town: town.call("say_toast", "In the browser version you are signed in from population.town.")

func _refresh_account() -> void:
	var net: PozNet = get_tree().root.get_node_or_null("PozNet") as PozNet
	var w := (_pages["account"] as Control).find_child("Who", true, false) as Label
	if w: w.text = ("Signed in as %s" % net.handle) if net and not net.guest else "Guest — not signed in"

func _show(name: String) -> void:
	for k in _pages: (_pages[k] as Control).visible = k == name
	if name == "account": _refresh_account()
	if name == "controls": for a in _key_buttons: (_key_buttons[a] as Button).text = key_of(a)

func open_menu(page := "main") -> void:
	open = true; _root.visible = true; _show(page)

func close_menu() -> void:
	open = false; _root.visible = false; _wait_action = ""

func _wait_key(a: String) -> void:
	_wait_action = a; (_key_buttons[a] as Button).text = "Press a key…"

func _reset_keys() -> void:
	for a in _defaults:
		if not (_defaults[a] as Array).is_empty(): _set_key(a, int(_defaults[a][0]))
	_save_keys(); _show("controls")

func _input(e: InputEvent) -> void:
	if not (e is InputEventKey) or not e.pressed or e.echo: return
	var k := e as InputEventKey
	if open and _wait_action == "" and k.keycode != KEY_ESCAPE: get_viewport().set_input_as_handled(); return   # 메뉴가 열린 동안 키는 게임으로 안 간다(단추는 마우스)
	if _wait_action != "":
		if k.keycode != KEY_ESCAPE: _set_key(_wait_action, k.keycode); _save_keys()
		_wait_action = ""; _show("controls"); get_viewport().set_input_as_handled(); return
	if town == null or not is_instance_valid(town) or not town.visible: return   # 미니게임 안(마을이 숨었다)에선 그 게임의 Esc
	var chat: Variant = town.get("chat")
	if chat != null and (chat as ChatBox).typing: return
	if k.keycode == KEY_ESCAPE:
		if open: close_menu()
		else: open_menu()
		get_viewport().set_input_as_handled()
	elif not open and e.is_action_pressed("controls"):
		open_menu("controls"); get_viewport().set_input_as_handled()
