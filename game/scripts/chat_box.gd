class_name ChatBox
extends Control
## 채팅(운영자 2026-10-06: "게임이 시작하는 거니까 채팅 같은 것도") — 마을·Climb·레이싱이 같이 쓰는 부품. 지금 방(PozNet)의 채팅을 읽고 쓴다.
## Enter: 입력줄 열기 / 보내기 · Esc: 닫기. 입력 중엔 busy() 가 참 — 쓰는 쪽이 그동안 조작을 멈춘다(글자가 X·Z·SPACE 로도 읽히니까).
## 왼쪽 아래 기록 6줄, 말한 사람 머리 위에 말풍선(me_node = 내 몸, 남은 PozNet.others 의 졸라맨). 비로그인은 보기만
## 부모 UI 가 숨으면(미니게임 중 마을) 같이 숨고, 부모가 멈추면 같이 멈춘다 — 미니게임은 제 ChatBox 를 따로 둔다

const KEEP := 6
var me_node: Node3D = null      # 내 말풍선을 달 곳
var bubble_y := 1.75            # 졸라맨 머리 위 높이(그 게임의 눈금)
var typing := false
var _closed_at := -1.0
var _log: VBoxContainer
var _in: LineEdit
var _net: PozNet

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_log = VBoxContainer.new(); _log.position = Vector2(12, 300); _log.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(_log)
	_in = LineEdit.new(); _in.position = Vector2(12, 430); _in.size = Vector2(420, 28); _in.max_length = 140; _in.visible = false
	_in.placeholder_text = "Say something — Enter to send, Esc to close"; add_child(_in)
	_in.text_submitted.connect(_send)

func _process(_d: float) -> void:   # PozNet 은 마을이 준비된 뒤에 생긴다 — 찾으면 붙는다
	if _net == null:
		_net = get_tree().root.get_node_or_null("PozNet") as PozNet
		if _net: _net.message.connect(_on_room)

## 입력 중이거나 방금 닫았다(Esc·Enter 가 같은 프레임에 게임의 "나가기"·"점프"로 읽히지 않게 0.2초)
func busy() -> bool:
	return typing or (_closed_at > 0.0 and Time.get_ticks_msec() / 1000.0 - _closed_at < 0.2)

func _input(e: InputEvent) -> void:
	if not is_visible_in_tree() or not (e is InputEventKey) or not e.pressed or e.echo: return
	var k: int = (e as InputEventKey).keycode
	if typing:
		if k == KEY_ESCAPE: _close(); get_viewport().set_input_as_handled()
	elif e.is_action_pressed("chat") or k == KEY_KP_ENTER:
		typing = true; _in.visible = true; _in.grab_focus(); get_viewport().set_input_as_handled()

func _send(t: String) -> void:
	t = t.strip_edges()
	if t != "":
		if _net == null or _net.guest:
			line("", "Log in on population.town to chat.")
		else:
			_net.send_chat(t); line(_net.handle, t)
			if me_node: bubble(me_node, t, bubble_y)
	_close()

func _close() -> void:
	typing = false; _closed_at = Time.get_ticks_msec() / 1000.0
	_in.text = ""; _in.visible = false; _in.release_focus()

## 기록 한 줄 — who 가 비면 안내문
func line(who: String, t: String) -> void:
	var l := Label.new(); l.text = t if who == "" else "%s: %s" % [who, t]
	l.add_theme_color_override("font_color", Color("7b526c") if who == "" else Color("1b0c15")); l.add_theme_color_override("font_outline_color", Color("f7f4ef"))
	l.add_theme_constant_override("outline_size", 6); l.add_theme_font_size_override("font_size", 14)
	_log.add_child(l)
	while _log.get_child_count() > KEEP:
		var old := _log.get_child(0); _log.remove_child(old); old.queue_free()
	_log.position.y = 424.0 - _log.get_combined_minimum_size().y

func _on_room(m: Dictionary) -> void:
	if String(m.get("t", "")) != "chat" or not is_inside_tree() or not can_process(): return
	var id := int(m.get("uid", 0))
	if id == _net.me: return
	var o: Dictionary = _net.others.get(id, {})
	line(String(m.get("handle", o.get("handle", "?"))), String(m.get("body", "")))
	var g: Variant = o.get("node")
	if g is Node3D and is_instance_valid(g): bubble(g, String(m.get("body", "")), bubble_y)

## 말풍선 — 머리 위 글자, 길이에 따라 4~8초. 같은 사람이 또 말하면 바꿔 단다
static func bubble(on: Node3D, t: String, y: float) -> void:
	var b := on.get_node_or_null("bubble") as Label3D
	if b == null:
		b = Label3D.new(); b.name = "bubble"; b.font_size = 52; b.pixel_size = 0.002; b.modulate = Color("1b0c15"); b.outline_size = 10; b.outline_modulate = Color("f7f4ef")
		b.billboard = BaseMaterial3D.BILLBOARD_ENABLED; b.no_depth_test = true; b.width = 420.0; b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		on.add_child(b)
	b.position = Vector3(0, y, 0); b.text = t; b.visible = true
	var n := int(b.get_meta("n", 0)) + 1; b.set_meta("n", n)
	on.get_tree().create_timer(minf(8.0, 4.0 + t.length() * 0.05)).timeout.connect(func() -> void:
		if is_instance_valid(b) and int(b.get_meta("n", 0)) == n: b.visible = false)
